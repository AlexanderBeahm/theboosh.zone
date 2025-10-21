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

subtest 'health endpoint exists' => sub {
    $t->get_ok('/health')
      ->status_is(200, 'Health endpoint returns 200 OK');
};

subtest 'health endpoint returns JSON' => sub {
    $t->get_ok('/health')
      ->status_is(200)
      ->header_is('Content-Type' => 'application/json;charset=UTF-8')
      ->or(sub { diag explain $t->tx->res->headers })
      ->json_is('/status' => 'healthy', 'Status is healthy')
      ->json_has('/timestamp', 'Response includes timestamp');
};

subtest 'health endpoint structure' => sub {
    $t->get_ok('/health')
      ->status_is(200)
      ->json_has('/status', 'Has status field')
      ->json_has('/timestamp', 'Has timestamp field');

    my $json = $t->tx->res->json;
    ok(exists $json->{status}, 'JSON has status key');
    ok(exists $json->{timestamp}, 'JSON has timestamp key');
    like($json->{timestamp}, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, 'Timestamp is ISO 8601 format');
};

# Note: If database is unavailable, this test may fail with 503
# In a full integration environment with test database, we should get 200
subtest 'health check with database validation' => sub {
    $t->get_ok('/health');

    my $status = $t->tx->res->code;
    my $json = $t->tx->res->json;

    if ($status == 200) {
        is($json->{status}, 'healthy', 'Database is healthy');
        pass('Health check passed with database connectivity');
    } elsif ($status == 503) {
        is($json->{status}, 'unhealthy', 'Database is unhealthy');
        pass('Health check properly reports unhealthy status when DB unavailable');
    } else {
        fail("Unexpected status code: $status");
    }
};

done_testing();
