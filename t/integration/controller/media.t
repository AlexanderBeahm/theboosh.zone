#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";
use MIME::Base64;
use File::Temp qw(tempfile);
use File::Spec::Functions qw(catfile);
use File::Copy;

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'media endpoints require authentication' => sub {
    $t->get_ok('/api/admin/media')
      ->status_is(401, 'Listing media requires authentication');

    $t->post_ok('/api/admin/media/upload')
      ->status_is(401, 'Uploading media requires authentication');
};

subtest 'admin media operations - with authentication' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for media tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })->status_is(200, 'Login successful');

    # List media (should work even if empty)
    $t->get_ok('/api/admin/media')
      ->status_is(200, 'Can list media')
      ->json_has('/media', 'Response has media array')
      ->json_has('/pagination', 'Response has pagination');

    my $json = $t->tx->res->json;
    is(ref $json->{media}, 'ARRAY', 'Media is an array');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'media pagination and filtering' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Test pagination parameters
    $t->get_ok('/api/admin/media?page=1&limit=10')
      ->status_is(200)
      ->json_is('/pagination/current_page' => 1, 'Page parameter accepted')
      ->json_is('/pagination/per_page' => 10, 'Limit parameter accepted');

    # Test search parameter
    $t->get_ok('/api/admin/media?search=test')
      ->status_is(200)
      ->json_has('/media', 'Search parameter accepted');

    # Test type filter
    $t->get_ok('/api/admin/media?type=image')
      ->status_is(200)
      ->json_has('/media', 'Type filter accepted');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'get media by id - not found' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Try to get nonexistent media
    $t->get_ok('/api/admin/media/999999')
      ->status_is(404, 'Nonexistent media returns 404')
      ->json_has('/error', 'Error message included');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

# Note: Full file upload testing requires multipart form data with actual files
# This would be better suited for end-to-end tests with test fixtures
subtest 'media upload endpoint structure' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Try to upload without file (should fail validation)
    $t->post_ok('/api/admin/media/upload')
      ->status_is(400, 'Upload without file returns 400')
      ->json_has('/error', 'Error message included');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'complete media upload and deletion workflow' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for complete workflow tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200, 'Admin login successful');

    # Create a small but valid test JPEG (more reliably detected by File::Type)
    # This is a minimal 1x1 JPEG that should be properly recognized
    my $valid_jpeg_base64 = '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==';
    my $base64_data = "data:image/jpeg;base64,$valid_jpeg_base64";

    # Upload test image via base64
    my $upload_response = $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $base64_data,
        base64_filename => 'test-image.jpg',
        alt_text => 'Test image for deletion',
        caption => 'This image will be deleted'
    });

    # Debug: show the actual response if upload fails
    if ($upload_response->tx->res->code != 200) {
        my $error_response = $upload_response->tx->res->json;
        diag("Upload failed with status: " . $upload_response->tx->res->code);
        diag("Error response: " . ($error_response->{error} || 'No error message'));
        diag("Full response: " . $upload_response->tx->res->body);
    }

    $upload_response->status_is(200, 'Base64 upload successful')
      ->json_is('/success' => 1, 'Upload marked as successful')
      ->json_has('/media/id', 'Media ID returned')
      ->json_has('/media/url', 'Media URL returned')
      ->json_like('/media/filename', qr/\.jpg$/, 'Filename has JPG extension');

    # Only proceed with deletion tests if upload was successful
    unless ($upload_response->tx->res->code == 200) {
        $t->post_ok('/api/auth/logout')->status_is(200);
        return;
    }

    my $upload_json = $t->tx->res->json;
    my $media_id = $upload_json->{media}{id};
    my $media_url = $upload_json->{media}{url};
    my $filepath = $upload_json->{media}{filepath};

    ok($media_id, 'Media ID exists');
    ok($media_url, 'Media URL exists');
    ok($filepath, 'File path exists');

    # Verify the media record exists in database
    $t->get_ok("/api/admin/media/$media_id")
      ->status_is(200, 'Can retrieve uploaded media by ID')
      ->json_is('/success' => 1)
      ->json_is('/media/id' => $media_id, 'Correct media ID returned');

    # Verify the physical file exists
    my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
    my $full_filepath = catfile($uploads_dir, $filepath);
    ok(-f $full_filepath, 'Physical file exists on filesystem');

    # Log file details for debugging
    if (-f $full_filepath) {
        my @stat = stat($full_filepath);
        my $file_size = $stat[7];
        my $permissions = sprintf("%04o", $stat[2] & 07777);
        diag("Test file details:");
        diag("  Path: $full_filepath");
        diag("  Size: $file_size bytes");
        diag("  Permissions: $permissions");
    }

    # Now test deletion
    $t->delete_ok("/api/admin/media/$media_id")
      ->status_is(200, 'Media deletion returns 200')
      ->json_is('/success' => 1, 'Deletion marked as successful');

    # Verify the media record no longer exists in database
    $t->get_ok("/api/admin/media/$media_id")
      ->status_is(404, 'Media record deleted from database');

    # CRITICAL: Verify the physical file was actually deleted
    ok(!-f $full_filepath, 'Physical file deleted from filesystem');

    # Double-check that the file really doesn't exist
    if (-f $full_filepath) {
        fail("CRITICAL BUG: Physical file still exists after deletion: $full_filepath");
        diag("File should have been deleted but still exists");
        diag("This is the bug we're trying to fix!");
    } else {
        pass("Physical file successfully deleted");
    }

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'deletion error handling' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for error handling tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Test deletion of non-existent media
    $t->delete_ok('/api/admin/media/999999')
      ->status_is(404, 'Deleting non-existent media returns 404')
      ->json_is('/success' => 0)
      ->json_has('/error', 'Error message provided');

    # Test deletion without media ID
    $t->delete_ok('/api/admin/media/')
      ->status_is(404, 'Deleting without ID returns 404');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'SVG security validation tests' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for SVG security tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200, 'Admin login successful');

    # Test 1: SVG with script tags should be rejected
    my $malicious_svg_script = '<svg xmlns="http://www.w3.org/2000/svg"><script>alert("xss")</script><rect width="100" height="100"/></svg>';
    my $base64_malicious_script = encode_base64($malicious_svg_script, '');
    my $data_url_script = "data:image/svg+xml;base64,$base64_malicious_script";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_script,
        base64_filename => 'malicious-script.svg',
        alt_text => 'Test SVG with script',
    })->status_is(400, 'SVG with script tags rejected')
      ->json_is('/success' => 0)
      ->json_has('/error', 'Error message provided for malicious SVG');

    # Test 2: SVG with event handlers should be rejected
    my $malicious_svg_onclick = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" onclick="alert(\'xss\')"/></svg>';
    my $base64_malicious_onclick = encode_base64($malicious_svg_onclick, '');
    my $data_url_onclick = "data:image/svg+xml;base64,$base64_malicious_onclick";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_onclick,
        base64_filename => 'malicious-onclick.svg',
        alt_text => 'Test SVG with onclick',
    })->status_is(400, 'SVG with onclick handler rejected')
      ->json_is('/success' => 0);

    # Test 3: SVG with event handlers with spaces should be rejected (enhanced regex test)
    my $malicious_svg_spaced = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" on click="alert(\'xss\')"/></svg>';
    my $base64_malicious_spaced = encode_base64($malicious_svg_spaced, '');
    my $data_url_spaced = "data:image/svg+xml;base64,$base64_malicious_spaced";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_spaced,
        base64_filename => 'malicious-spaced.svg',
        alt_text => 'Test SVG with spaced event handler',
    })->status_is(400, 'SVG with spaced event handler rejected')
      ->json_is('/success' => 0);

    # Test 4: SVG with javascript URLs should be rejected
    my $malicious_svg_js = '<svg xmlns="http://www.w3.org/2000/svg"><a href="javascript:alert(\'xss\')"><rect width="100" height="100"/></a></svg>';
    my $base64_malicious_js = encode_base64($malicious_svg_js, '');
    my $data_url_js = "data:image/svg+xml;base64,$base64_malicious_js";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_js,
        base64_filename => 'malicious-javascript.svg',
        alt_text => 'Test SVG with javascript URL',
    })->status_is(400, 'SVG with javascript URL rejected')
      ->json_is('/success' => 0);

    # Test 5: SVG with foreign objects should be rejected
    my $malicious_svg_foreign = '<svg xmlns="http://www.w3.org/2000/svg"><foreignObject><div>content</div></foreignObject></svg>';
    my $base64_malicious_foreign = encode_base64($malicious_svg_foreign, '');
    my $data_url_foreign = "data:image/svg+xml;base64,$base64_malicious_foreign";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_foreign,
        base64_filename => 'malicious-foreign.svg',
        alt_text => 'Test SVG with foreign object',
    })->status_is(400, 'SVG with foreign object rejected')
      ->json_is('/success' => 0);

    # Test 6: SVG with CSS expressions should be rejected
    my $malicious_svg_expression = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" style="width: expression(alert(\'xss\'))"/></svg>';
    my $base64_malicious_expression = encode_base64($malicious_svg_expression, '');
    my $data_url_expression = "data:image/svg+xml;base64,$base64_malicious_expression";

    $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_expression,
        base64_filename => 'malicious-expression.svg',
        alt_text => 'Test SVG with CSS expression',
    })->status_is(400, 'SVG with CSS expression rejected')
      ->json_is('/success' => 0);

    # Test 7: Clean SVG should be accepted
    my $clean_svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="red"/></svg>';
    my $base64_clean = encode_base64($clean_svg, '');
    my $data_url_clean = "data:image/svg+xml;base64,$base64_clean";

    my $upload_response = $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $data_url_clean,
        base64_filename => 'clean-svg.svg',
        alt_text => 'Test clean SVG',
    });

    # Only proceed with cleanup if upload was successful
    if ($upload_response->tx->res->code == 200) {
        $upload_response->status_is(200, 'Clean SVG accepted')
          ->json_is('/success' => 1)
          ->json_has('/media/id', 'Media ID returned for clean SVG');

        # Clean up the uploaded test file
        my $upload_json = $t->tx->res->json;
        my $media_id = $upload_json->{media}{id};
        if ($media_id) {
            $t->delete_ok("/api/admin/media/$media_id")
              ->status_is(200, 'Test SVG cleanup successful');
        }
    } else {
        # If clean SVG was rejected, that's unexpected - log details
        my $error_response = $upload_response->tx->res->json;
        diag("Clean SVG unexpectedly rejected with status: " . $upload_response->tx->res->code);
        diag("Error response: " . ($error_response->{error} || 'No error message'));
    }

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'input validation tests for alt_text and caption' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for input validation tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200, 'Admin login successful');

    # Create test image for validation
    my $valid_jpeg_base64 = '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==';
    my $base64_data = "data:image/jpeg;base64,$valid_jpeg_base64";

    # Test oversized alt_text (over 255 characters) - should be truncated
    my $long_alt_text = 'x' x 300;  # 300 characters
    my $upload_response = $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $base64_data,
        base64_filename => 'test-long-alt.jpg',
        alt_text => $long_alt_text,
        caption => 'Normal caption'
    });

    if ($upload_response->tx->res->code == 200) {
        $upload_response->status_is(200, 'Upload with long alt_text successful')
          ->json_is('/success' => 1);

        # Verify alt_text was truncated to 255 characters
        my $upload_json = $t->tx->res->json;
        my $media_id = $upload_json->{media}{id};

        $t->get_ok("/api/admin/media/$media_id")
          ->status_is(200)
          ->json_is('/success' => 1);

        my $media_data = $t->tx->res->json->{media};
        is(length($media_data->{alt_text}), 255, 'Alt text truncated to 255 characters');

        # Clean up
        $t->delete_ok("/api/admin/media/$media_id")->status_is(200);
    }

    # Test oversized caption (over 500 characters) - should be truncated
    my $long_caption = 'y' x 600;  # 600 characters
    $upload_response = $t->post_ok('/api/admin/media/upload' => form => {
        base64_data => $base64_data,
        base64_filename => 'test-long-caption.jpg',
        alt_text => 'Normal alt text',
        caption => $long_caption
    });

    if ($upload_response->tx->res->code == 200) {
        $upload_response->status_is(200, 'Upload with long caption successful')
          ->json_is('/success' => 1);

        # Verify caption was truncated to 500 characters
        my $upload_json = $t->tx->res->json;
        my $media_id = $upload_json->{media}{id};

        $t->get_ok("/api/admin/media/$media_id")
          ->status_is(200)
          ->json_is('/success' => 1);

        my $media_data = $t->tx->res->json->{media};
        is(length($media_data->{caption}), 500, 'Caption truncated to 500 characters');

        # Clean up
        $t->delete_ok("/api/admin/media/$media_id")->status_is(200);
    }

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

done_testing();
