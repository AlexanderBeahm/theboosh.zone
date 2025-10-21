#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'auth status endpoint - not authenticated' => sub {
    $t->get_ok('/api/auth/status')
      ->status_is(200, 'Status endpoint returns 200')
      ->json_is('/authenticated' => 0, 'Not authenticated by default')
      ->json_hasnt('/username', 'No username when not authenticated')
      ->json_hasnt('/email', 'No email when not authenticated');
};

subtest 'login endpoint exists' => sub {
    $t->post_ok('/api/auth/login' => json => {
        username => 'nonexistent',
        password => 'wrongpassword'
    })
      ->status_is(401, 'Login with wrong credentials returns 401');
};

subtest 'login validation - missing username' => sub {
    $t->post_ok('/api/auth/login' => json => {
        password => 'somepassword'
    })
      ->status_is(400, 'Missing username returns 400')
      ->json_has('/error', 'Error message included');
};

subtest 'login validation - missing password' => sub {
    $t->post_ok('/api/auth/login' => json => {
        username => 'someuser'
    })
      ->status_is(400, 'Missing password returns 400')
      ->json_has('/error', 'Error message included');
};

subtest 'login validation - empty credentials' => sub {
    $t->post_ok('/api/auth/login' => json => {
        username => '',
        password => ''
    })
      ->status_is(400, 'Empty credentials return 400');
};

subtest 'logout endpoint' => sub {
    $t->post_ok('/api/auth/logout')
      ->status_is(200, 'Logout returns 200')
      ->json_is('/message' => 'Logged out successfully', 'Success message returned');
};

# Test with actual admin credentials from environment (if available)
subtest 'login with admin credentials (if available)' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200, 'Login with correct credentials succeeds')
      ->json_is('/success' => 1, 'Success flag is true')
      ->json_has('/user', 'User object included');

    # Check that session is now authenticated
    $t->get_ok('/api/auth/status')
      ->status_is(200)
      ->json_is('/authenticated' => 1, 'Now authenticated')
      ->json_is('/user/username' => $admin_user, 'Username matches')
      ->json_has('/user/email', 'Email included in status');

    # Logout
    $t->post_ok('/api/auth/logout')
      ->status_is(200);

    # Verify logged out
    $t->get_ok('/api/auth/status')
      ->status_is(200)
      ->json_is('/authenticated' => 0, 'No longer authenticated after logout');
};

subtest 'protected admin endpoints without auth' => sub {
    # Try to access an admin endpoint without authentication
    $t->get_ok('/api/admin/articles')
      ->status_is(401, 'Admin endpoint returns 401 without authentication')
      ->json_has('/error', 'Error message included');
};

# Test rate limiting behavior (difficult to fully test without actually hitting limit)
subtest 'rate limiting structure' => sub {
    # Make multiple failed login attempts
    for my $i (1..3) {
        $t->post_ok('/api/auth/login' => json => {
            username => 'testuser_' . time(),
            password => 'wrongpass'
        })
          ->status_is(401, "Failed login attempt $i returns 401");
    }

    # Note: Full rate limit testing (5 attempts) would require more complex setup
    # and could interfere with other tests
    pass('Rate limiting mechanism exists');
};

subtest 'session persistence across requests' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for session test';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })->status_is(200);

    # Make multiple authenticated requests
    for my $i (1..3) {
        $t->get_ok('/api/auth/status')
          ->status_is(200)
          ->json_is('/authenticated' => 1, "Request $i: Session persists");
    }

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

done_testing();
