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

done_testing();
