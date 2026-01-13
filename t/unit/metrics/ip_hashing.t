#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Note: Testing private method _hash_ip_for_metrics
# In Perl, private methods (starting with _) are still accessible
use HelloPerld::Controller::Metrics;

# Access the private method via package symbol table
no strict 'refs';
my $hash_method = *{'HelloPerld::Controller::Metrics::_hash_ip_for_metrics'}{CODE};

subtest 'IPv4 hashing' => sub {
    my $ip = '192.168.1.123';
    my $hashed = $hash_method->($ip);
    is($hashed, '192.168.1.x', 'IPv4 last octet replaced with x');
};

subtest 'IPv4 edge cases' => sub {
    is($hash_method->('10.0.0.1'), '10.0.0.x', 'IPv4 10.0.0.1');
    is($hash_method->('172.16.0.1'), '172.16.0.x', 'IPv4 172.16.0.1');
    is($hash_method->('1.2.3.4'), '1.2.3.x', 'IPv4 1.2.3.4');
};

subtest 'IPv6 hashing' => sub {
    # Standard compressed IPv6
    my $ip = '2001:db8::1';
    my $hashed = $hash_method->($ip);
    is($hashed, '2001:db8::x', 'IPv6 compressed format hashed correctly');

    # Full IPv6 address
    my $full_ipv6 = '2001:0db8:0000:0000:0000:0000:0000:0001';
    my $full_hashed = $hash_method->($full_ipv6);
    is($full_hashed, '2001:db8::x', 'IPv6 full format hashed correctly');

    # IPv6 loopback
    my $loopback = '::1';
    my $loopback_hashed = $hash_method->($loopback);
    is($loopback_hashed, '::x', 'IPv6 loopback hashed correctly');

    # IPv6 with mid-address compression
    # fe80::1:2:3 has non-empty groups: fe80, 1, 2, 3
    # First two non-empty groups: fe80 and 1
    my $mid_compress = 'fe80::1:2:3';
    my $mid_hashed = $hash_method->($mid_compress);
    is($mid_hashed, 'fe80:1::x', 'IPv6 mid-compression hashed correctly');

    # Full IPv6 with zeros
    my $full_zeros = 'fe80:0:0:0:1:2:3:4';
    my $zeros_hashed = $hash_method->($full_zeros);
    is($zeros_hashed, 'fe80:0::x', 'IPv6 full format with zeros hashed correctly');
};

subtest 'unknown IP handling' => sub {
    is($hash_method->(undef), 'unknown', 'Undef returns unknown');
    is($hash_method->(''), 'unknown', 'Empty string returns unknown');
};

subtest 'invalid IP format' => sub {
    my $invalid = 'not-an-ip';
    my $hashed = $hash_method->($invalid);
    is($hashed, $invalid, 'Invalid format returns as-is');
};

done_testing();
