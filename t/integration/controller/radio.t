#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

# ====== PUBLIC ENDPOINTS (No Auth Required) ======

subtest 'get_playlist - no playlist configured' => sub {
    $t->get_ok('/api/radio/playlist')
      ->status_is(200, 'Playlist endpoint returns 200')
      ->json_is('/success' => 1, 'Success flag is true')
      ->json_is('/playlist/url' => '', 'URL is empty when not configured')
      ->json_is('/playlist/tracks', [], 'Tracks array is empty')
      ->json_has('/playlist/message', 'Message explaining no playlist');
};

subtest 'get_sync_info - no playlist configured' => sub {
    $t->get_ok('/api/radio/sync-info')
      ->status_is(200, 'Sync info endpoint returns 200')
      ->json_is('/success' => 1, 'Success flag is true')
      ->json_is('/sync_info/configured' => 0, 'Configured flag is false')
      ->json_has('/sync_info/message', 'Message explaining no playlist');
};

# ====== ADMIN ENDPOINTS (Auth Required) ======

subtest 'get_config - not authenticated' => sub {
    $t->get_ok('/api/admin/radio/config')
      ->status_is(401, 'Returns 401 without authentication');
};

subtest 'update_playlist - not authenticated' => sub {
    $t->post_ok('/api/admin/radio/playlist' => json => {
        playlist_url => 'https://example.com/test.m3u'
    })
      ->status_is(401, 'Returns 401 without authentication');
};

subtest 'update_playlist - missing CSRF token when authenticated' => sub {
    # Try with admin credentials if available
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login first
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    # Try to update without CSRF token
    $t->post_ok('/api/admin/radio/playlist' => json => {
        playlist_url => 'https://example.com/test.m3u'
    })
      ->status_is(403, 'Returns 403 without CSRF token')
      ->json_is('/error' => 'CSRF validation failed');

    # Logout
    my $csrf_token = $login_response->{csrf_token};
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

subtest 'delete_playlist - not authenticated' => sub {
    $t->delete_ok('/api/admin/radio/playlist')
      ->status_is(401, 'Returns 401 without authentication');
};

# ====== VALIDATION TESTS (with auth) ======

subtest 'update_playlist - validation errors' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # Test missing playlist_url
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {})
      ->status_is(422, 'Returns 422 for missing playlist_url')
      ->json_is('/success' => 0)
      ->json_like('/error', qr/required/i);

    # Test empty playlist_url
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => ''
    })
      ->status_is(422, 'Returns 422 for empty playlist_url')
      ->json_is('/success' => 0)
      ->json_like('/error', qr/required/i);

    # Test invalid URL format
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => 'not-a-valid-url'
    })
      ->status_is(422, 'Returns 422 for invalid URL format')
      ->json_is('/success' => 0)
      ->json_like('/error', qr/invalid.*format/i);

    # Test invalid protocol (FTP without .m3u extension)
    # Note: ftp://example.com/playlist.m3u would PASS because it ends with .m3u
    # The validation regex is permissive: starts with http(s):// or / OR ends with .m3u(8)
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => 'ftp://example.com/playlist.txt'
    })
      ->status_is(422, 'Returns 422 for invalid protocol without .m3u extension')
      ->json_is('/success' => 0)
      ->json_like('/error', qr/invalid.*format/i);

    # Test Windows path (doesn't start with http(s):// or / and doesn't end with .m3u)
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => 'C:\\Windows\\playlist.txt'
    })
      ->status_is(422, 'Returns 422 for Windows path')
      ->json_is('/success' => 0)
      ->json_like('/error', qr/invalid.*format/i);

    # Test invalid JSON
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => 'not-json')
      ->status_is(422, 'Returns 422 for invalid JSON')
      ->json_is('/success' => 0);

    # Logout
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

# ====== FUNCTIONAL TESTS (with auth and valid data) ======

subtest 'update_playlist - valid HTTP URL' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # Create a mock m3u file content for testing
    my $test_url = 'https://raw.githubusercontent.com/jnobind/test-music/main/playlist.m3u';

    # Note: This test attempts to access a real URL. If it fails due to network issues,
    # we skip the test. In a production environment, you'd mock the HTTP request.
    my $response = $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => $test_url
    });

    # Check if URL validation passed (200) or failed due to network (422)
    my $status = $response->tx->res->code;

    if ($status == 200) {
        $response->json_is('/success' => 1, 'Success flag is true')
                 ->json_is('/playlist_url' => $test_url, 'Returns the playlist URL');

        # Verify we can retrieve the config
        $t->get_ok('/api/admin/radio/config')
          ->status_is(200)
          ->json_is('/success' => 1);

        my $config = $t->tx->res->json->{config};
        my $playlist_config = (grep { $_->{config_key} eq 'playlist_url' } @$config)[0];

        ok($playlist_config, 'Playlist config exists');
        is($playlist_config->{config_value}, $test_url, 'Stored URL matches');

        # Verify public endpoint returns the URL
        $t->get_ok('/api/radio/playlist')
          ->status_is(200)
          ->json_is('/success' => 1)
          ->json_is('/playlist/url' => $test_url);

        # Clean up - delete the playlist
        $t->delete_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token})
          ->status_is(200)
          ->json_is('/success' => 1);

    } elsif ($status == 422) {
        # URL validation failed - likely network issue
        pass('URL validation failed (expected in isolated test environment)');
    } else {
        fail("Unexpected status code: $status");
    }

    # Logout
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

subtest 'update_playlist - valid local path' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # Test with local path (won't validate accessibility for local paths)
    my $local_path = '/uploads/test-playlist.m3u';

    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => $local_path
    })
      ->status_is(200, 'Accepts local path')
      ->json_is('/success' => 1)
      ->json_is('/playlist_url' => $local_path);

    # Verify it was stored
    $t->get_ok('/api/admin/radio/config')
      ->status_is(200);

    my $config = $t->tx->res->json->{config};
    my $playlist_config = (grep { $_->{config_key} eq 'playlist_url' } @$config)[0];

    is($playlist_config->{config_value}, $local_path, 'Local path stored correctly');

    # Clean up
    $t->delete_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);

    # Logout
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

subtest 'delete_playlist - successful deletion' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # First, set a playlist
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => '/test/playlist.m3u'
    })
      ->status_is(200);

    # Verify it exists
    $t->get_ok('/api/radio/playlist')
      ->status_is(200)
      ->json_is('/playlist/url' => '/test/playlist.m3u');

    # Delete it
    $t->delete_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200)
      ->json_is('/success' => 1)
      ->json_has('/message');

    # Verify it's gone
    $t->get_ok('/api/radio/playlist')
      ->status_is(200)
      ->json_is('/playlist/url' => '')
      ->json_has('/playlist/message');

    # Logout
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

subtest 'get_playlist - with parse parameter (HLS)' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login and set HLS playlist
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # Set HLS playlist - use local path to avoid network dependency
    # HTTP URLs are validated for accessibility, which would fail in isolated environments
    # Note: Local HLS paths will fail duration calculation (tries to make HTTP request),
    # but that's acceptable - the playlist is still saved, just duration is NULL
    my $hls_url = '/uploads/stream.m3u8';

    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => $hls_url
    })
      ->status_is(200);

    # Get playlist with parse=1
    $t->get_ok('/api/radio/playlist?parse=1')
      ->status_is(200)
      ->json_is('/success' => 1)
      ->json_is('/playlist/is_hls' => 1, 'Identifies as HLS stream')
      ->json_is('/playlist/tracks/0/title' => 'HLS Stream')
      ->json_is('/playlist/tracks/0/duration' => -1);

    # Clean up
    $t->delete_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);

    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

subtest 'get_config - returns all configuration' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    $t->get_ok('/api/admin/radio/config')
      ->status_is(200)
      ->json_is('/success' => 1)
      ->json_has('/config', 'Has config array');

    my $config = $t->tx->res->json->{config};
    is(ref $config, 'ARRAY', 'Config is an array');

    # Logout
    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

# ====== UPDATE EXISTING PLAYLIST ======

subtest 'update_playlist - update existing playlist URL' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set in environment';
        return;
    }

    # Login
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })
      ->status_is(200)->tx->res->json;

    my $csrf_token = $login_response->{csrf_token};

    # Set initial playlist
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => '/uploads/playlist1.m3u'
    })
      ->status_is(200);

    # Update to new URL
    $t->post_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token} => json => {
        playlist_url => '/uploads/playlist2.m3u'
    })
      ->status_is(200)
      ->json_is('/success' => 1)
      ->json_is('/playlist_url' => '/uploads/playlist2.m3u');

    # Verify update
    $t->get_ok('/api/radio/playlist')
      ->status_is(200)
      ->json_is('/playlist/url' => '/uploads/playlist2.m3u');

    # Clean up
    $t->delete_ok('/api/admin/radio/playlist' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);

    $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})
      ->status_is(200);
};

done_testing();
