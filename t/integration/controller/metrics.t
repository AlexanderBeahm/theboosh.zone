#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'metrics endpoint returns 200' => sub {
    $t->get_ok('/metrics')
      ->status_is(200, 'Metrics endpoint returns 200');
};

subtest 'metrics endpoint returns Prometheus format' => sub {
    $t->get_ok('/metrics')
      ->status_is(200)
      ->content_type_like(qr{text/plain.*charset=utf-8}i, 'Content-Type is text/plain with charset');

    my $content = $t->tx->res->body;
    ok($content, 'Response body is not empty');

    # Prometheus format uses # for comments/HELP/TYPE
    like($content, qr/^# (HELP|TYPE)/m, 'Contains Prometheus-style comments');
};

subtest 'metrics contains expected HTTP metrics' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for HTTP request metrics
    like($content, qr/http_requests_total/, 'Contains http_requests_total metric');
    like($content, qr/http_request_duration_seconds/, 'Contains http_request_duration_seconds metric');
    like($content, qr/http_requests_in_progress/, 'Contains http_requests_in_progress metric');
};

subtest 'metrics contains app_info' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for app info metric
    like($content, qr/app_info/, 'Contains app_info metric');
    like($content, qr/app_info\{.*version/, 'app_info has version label');
    like($content, qr/app_info\{.*environment/, 'app_info has environment label');
};

subtest 'metrics contains database connection status' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for database connection status metric
    like($content, qr/app_database_connection_status/, 'Contains app_database_connection_status metric');
};

subtest 'metrics contains business metrics' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for business metrics
    like($content, qr/app_articles_total/, 'Contains app_articles_total metric');
    like($content, qr/app_media_files_total/, 'Contains app_media_files_total metric');
    like($content, qr/app_tags_total/, 'Contains app_tags_total metric');
};

subtest 'metrics contains error tracking' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for error metrics
    like($content, qr/app_errors_total/, 'Contains app_errors_total metric');
};

subtest 'metrics contains login attempt tracking' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for login attempt metrics
    like($content, qr/app_admin_login_attempts_total/, 'Contains app_admin_login_attempts_total metric');
};

subtest 'metrics contains article view tracking' => sub {
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Check for article view metrics
    like($content, qr/app_article_views_total/, 'Contains app_article_views_total metric');
    like($content, qr/app_article_views_by_ip_total/, 'Contains app_article_views_by_ip_total metric');
};

subtest 'metrics endpoint increments request counter' => sub {
    # Make a few requests to increment counters
    $t->get_ok('/api/tags')->status_is(200);
    $t->get_ok('/health')->status_is(200);

    # Check metrics
    $t->get_ok('/metrics')
      ->status_is(200);

    my $content = $t->tx->res->body;

    # Should have recorded these requests
    like($content, qr/http_requests_total\{.*method="GET"/, 'Has GET method requests recorded');
};

subtest 'metrics does not track itself' => sub {
    # Get initial metrics
    $t->get_ok('/metrics')->status_is(200);

    my $content = $t->tx->res->body;

    # /metrics endpoint should not appear in the recorded endpoints
    # (it skips itself to avoid recursion)
    unlike($content, qr{endpoint="/metrics"}, 'Metrics endpoint not tracked in metrics');
};

done_testing();
