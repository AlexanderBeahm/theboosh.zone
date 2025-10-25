#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";
use MIME::Base64;

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

done_testing();
