#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;

# Ensure lib paths are correct
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'security headers on main route' => sub {
    $t->get_ok('/')
      ->status_is(200, 'Main route returns 200 OK')
      ->header_is('X-Frame-Options' => 'DENY', 'X-Frame-Options header is set')
      ->header_is('X-Content-Type-Options' => 'nosniff', 'X-Content-Type-Options header is set')
      ->header_is('X-XSS-Protection' => '1; mode=block', 'X-XSS-Protection header is set')
      ->header_is('Referrer-Policy' => 'strict-origin-when-cross-origin', 'Referrer-Policy header is set')
      ->header_exists('Content-Security-Policy', 'CSP header exists on main route');
};

subtest 'CSP header presence on API routes' => sub {
    $t->get_ok('/api/articles')
      ->status_is(200)
      ->header_exists('Content-Security-Policy', 'CSP header exists on articles API');

    $t->get_ok('/api/csrf-token')
      ->status_is(200)
      ->header_exists('Content-Security-Policy', 'CSP header exists on CSRF token API');

    $t->get_ok('/health')
      ->status_is(200)
      ->header_exists('Content-Security-Policy', 'CSP header exists on health endpoint');
};

subtest 'CSP trusted domains verification' => sub {
    $t->get_ok('/')
      ->status_is(200);

    my $csp = $t->tx->res->headers->header('Content-Security-Policy');
    ok($csp, 'CSP header exists');

    # Test for trusted embed domains
    like($csp, qr/youtube\.com/, 'CSP includes youtube.com in frame-src');
    like($csp, qr/www\.youtube\.com/, 'CSP includes www.youtube.com in frame-src');
    like($csp, qr/bandcamp\.com/, 'CSP includes bandcamp.com in frame-src');
    like($csp, qr/vimeo\.com/, 'CSP includes vimeo.com in frame-src');
    like($csp, qr/spotify\.com/, 'CSP includes spotify.com in frame-src');
    like($csp, qr/soundcloud\.com/, 'CSP includes soundcloud.com in frame-src');
};

subtest 'CSP core directives verification' => sub {
    $t->get_ok('/api/articles')
      ->status_is(200);

    my $csp = $t->tx->res->headers->header('Content-Security-Policy');
    ok($csp, 'CSP header exists');

    # Test core CSP directives
    like($csp, qr/default-src 'self'/, 'CSP includes default-src self');
    like($csp, qr/script-src 'self'/, 'CSP includes script-src self');
    like($csp, qr/style-src 'self' 'unsafe-inline'/, 'CSP includes style-src with unsafe-inline');
    like($csp, qr/img-src 'self' data:/, 'CSP includes img-src with data URLs');
    like($csp, qr/object-src 'none'/, 'CSP includes object-src none');
    like($csp, qr/frame-ancestors 'none'/, 'CSP includes frame-ancestors none');
};

subtest 'Swagger routes CSP exception' => sub {
    # Swagger routes should NOT have the standard CSP header
    # They need different CSP to allow inline scripts for Swagger UI

    # Note: These tests may return 404 if Swagger is disabled in current environment
    # That's expected behavior - we're testing the CSP behavior when enabled

    $t->get_ok('/swagger');
    my $status = $t->tx->res->code;

    if ($status == 200) {
        # Swagger is enabled, verify it has different CSP handling
        my $csp = $t->tx->res->headers->header('Content-Security-Policy');

        if ($csp) {
            # If CSP exists on Swagger route, it should allow unsafe-inline for scripts
            like($csp, qr/script-src.*'unsafe-inline'/, 'Swagger CSP allows unsafe-inline scripts');
        } else {
            pass('Swagger route has no CSP header (acceptable for Swagger UI)');
        }

        pass('Swagger route accessible and handled appropriately');
    } elsif ($status == 404) {
        pass('Swagger route returns 404 (disabled in this environment)');
    } else {
        fail("Unexpected status code for Swagger route: $status");
    }
};

subtest 'security headers consistency across routes' => sub {
    my @test_routes = ('/', '/health', '/api/articles', '/api/csrf-token');

    for my $route (@test_routes) {
        $t->get_ok($route, "Testing route: $route");

        # All routes should have these security headers
        $t->header_is('X-Frame-Options' => 'DENY', "X-Frame-Options on $route")
          ->header_is('X-Content-Type-Options' => 'nosniff', "X-Content-Type-Options on $route")
          ->header_is('X-XSS-Protection' => '1; mode=block', "X-XSS-Protection on $route")
          ->header_is('Referrer-Policy' => 'strict-origin-when-cross-origin', "Referrer-Policy on $route")
          ->header_exists('Content-Security-Policy', "CSP exists on $route");
    }
};

done_testing();