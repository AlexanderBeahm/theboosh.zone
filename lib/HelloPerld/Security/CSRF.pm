package HelloPerld::Security::CSRF;
use strict;
use warnings;

use Crypt::Random qw(makerandom_octet);
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64url decode_base64url);
use Time::HiRes qw(time);

=head1 NAME

HelloPerld::Security::CSRF - CSRF token generation and validation

=head1 SYNOPSIS

    use HelloPerld::Security::CSRF;

    # Generate a CSRF token for a session
    my $token = HelloPerld::Security::CSRF::generate_token($session_id, $secret_key);

    # Validate a CSRF token
    my $is_valid = HelloPerld::Security::CSRF::validate_token(
        $token, $session_id, $secret_key, $max_age_seconds
    );

=head1 DESCRIPTION

This module provides secure CSRF (Cross-Site Request Forgery) protection
using time-based tokens with HMAC validation.

=cut

=head2 generate_token

Generates a CSRF token for a given session.

    my $token = generate_token($session_id, $secret_key);

Parameters:
- session_id: Unique identifier for the user session
- secret_key: Application secret for HMAC signing

Returns: Base64URL-encoded CSRF token

=cut

sub generate_token {
    my ($session_id, $secret_key) = @_;

    die "session_id is required" unless defined $session_id;
    die "secret_key is required" unless defined $secret_key;

    # Generate random nonce (16 bytes = 128 bits)
    my $nonce = makerandom_octet(Length => 16);

    # Current timestamp
    my $timestamp = int(time());

    # Create payload: timestamp + session_id + nonce
    my $payload = pack('N', $timestamp) . $session_id . $nonce;

    # Generate HMAC signature
    my $signature = _hmac_sha256($payload, $secret_key);

    # Combine payload + signature
    my $token_data = $payload . $signature;

    # Encode as base64url for safe transmission
    return encode_base64url($token_data);
}

=head2 validate_token

Validates a CSRF token against a session and timestamp.

    my $is_valid = validate_token($token, $session_id, $secret_key, $max_age);

Parameters:
- token: Base64URL-encoded CSRF token to validate
- session_id: Expected session identifier
- secret_key: Application secret for HMAC verification
- max_age_seconds: Maximum age in seconds (default: 3600 = 1 hour)

Returns: 1 if valid, 0 if invalid

=cut

sub validate_token {
    my ($token, $session_id, $secret_key, $max_age_seconds) = @_;

    # Default max age: 1 hour
    $max_age_seconds //= 3600;

    return 0 unless defined $token && $token ne '';
    return 0 unless defined $session_id;
    return 0 unless defined $secret_key;

    # Decode the token
    my $token_data;
    eval {
        $token_data = decode_base64url($token);
    };
    return 0 if $@ || !defined $token_data;

    # Token must be at least 4 (timestamp) + session_id + 16 (nonce) + 32 (signature) bytes
    my $min_length = 4 + length($session_id) + 16 + 32;
    return 0 if length($token_data) < $min_length;

    # Extract components
    my $timestamp = unpack('N', substr($token_data, 0, 4));
    my $extracted_session = substr($token_data, 4, length($session_id));
    my $nonce = substr($token_data, 4 + length($session_id), 16);
    my $provided_signature = substr($token_data, 4 + length($session_id) + 16, 32);

    # Verify session ID matches
    return 0 unless $extracted_session eq $session_id;

    # Check timestamp (not too old, not from future)
    my $current_time = int(time());
    my $token_age = $current_time - $timestamp;

    # Reject tokens from the future (allow 30 seconds clock skew)
    return 0 if $timestamp > $current_time + 30;

    # Reject expired tokens
    return 0 if $token_age > $max_age_seconds;

    # Reconstruct payload and verify signature
    my $payload = pack('N', $timestamp) . $session_id . $nonce;
    my $expected_signature = _hmac_sha256($payload, $secret_key);

    # Constant-time comparison to prevent timing attacks
    return _secure_compare($provided_signature, $expected_signature);
}

=head2 _hmac_sha256 (private)

Computes HMAC-SHA256 of data with given key.

=cut

sub _hmac_sha256 {
    my ($data, $key) = @_;

    my $block_size = 64; # SHA-256 block size
    my $key_length = length($key);

    # Keys longer than block size are shortened by hashing
    if ($key_length > $block_size) {
        $key = sha256_hex($key);
        $key = pack('H*', $key); # Convert hex back to binary
        $key_length = length($key);
    }

    # Keys shorter than block size are padded with zeros
    if ($key_length < $block_size) {
        $key .= "\x00" x ($block_size - $key_length);
    }

    # Compute HMAC
    my $o_key_pad = $key ^ ("\x5c" x $block_size);
    my $i_key_pad = $key ^ ("\x36" x $block_size);

    my $inner_hash = sha256_hex($i_key_pad . $data);
    my $hmac = sha256_hex($o_key_pad . pack('H*', $inner_hash));

    return pack('H*', $hmac); # Return as binary
}

=head2 _secure_compare (private)

Constant-time string comparison to prevent timing attacks.

=cut

sub _secure_compare {
    my ($a, $b) = @_;

    return 0 if length($a) != length($b);

    my $result = 0;
    for my $i (0 .. length($a) - 1) {
        $result |= ord(substr($a, $i, 1)) ^ ord(substr($b, $i, 1));
    }

    return $result == 0 ? 1 : 0;
}

1;

__END__

=head1 SECURITY NOTES

=over 4

=item * Uses cryptographically secure random number generation via Crypt::Random

=item * Implements HMAC-SHA256 for token integrity verification

=item * Includes timestamp to prevent replay attacks

=item * Uses constant-time comparison to prevent timing attacks

=item * Tokens are bound to specific session IDs

=item * Configurable token expiration (default: 1 hour)

=item * Resistant to CSRF token prediction and brute force attacks

=back

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut