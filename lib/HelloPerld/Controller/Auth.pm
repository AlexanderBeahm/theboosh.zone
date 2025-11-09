package HelloPerld::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Database::Postgres;
use Digest::SHA qw(sha256_hex);
use Crypt::Random qw(makerandom_octet);
use Crypt::Bcrypt qw(bcrypt bcrypt_check);
use JSON qw(encode_json decode_json);

sub login {
    my $self = shift;

    # Try to get params from OpenAPI validation first, fallback to standard param
    my $body = $self->req->json || {};
    my $username = $self->param('username') || $body->{username};
    my $password = $self->param('password') || $body->{password};

    unless ($username && $password) {
        return $self->render(json => {
            success => 0,
            error => 'Username and password are required'
        }, status => 400);
    }

    # Rate limiting check
    if ($self->_is_rate_limited($username)) {
        return $self->render(json => {
            success => 0,
            error => 'Too many login attempts. Please try again later.'
        }, status => 429);
    }

    my $user = $self->_authenticate_user($username, $password);

    if ($user) {
        # Create session
        $self->session(
            admin_user_id => $user->{id},
            admin_username => $user->{username},
            admin_email => $user->{email}
        );

        # Update last login time
        $self->_update_last_login($user->{id});

        # Clear rate limiting
        $self->_clear_rate_limit($username);

        $self->app->logger_instance->info("Admin user '$username' logged in successfully");

        return $self->render(json => {
            success => 1,
            user => {
                id => $user->{id},
                username => $user->{username},
                email => $user->{email}
            },
            %{$self->csrf_token_response}
        });
    } else {
        # Track failed login attempt
        $self->_track_failed_login($username);

        $self->app->logger_instance->warn("Failed login attempt for username '$username'");

        return $self->render(json => {
            success => 0,
            error => 'Invalid username or password'
        }, status => 401);
    }
}

sub logout {
    my $self = shift;

    # CSRF protection for logout
    unless ($self->csrf_protect) {
        return $self->render(json => {
            success => 0,
            error => 'CSRF validation failed'
        }, status => 403);
    }

    my $username = $self->session('admin_username') || 'unknown';

    # Clear session
    $self->session(expires => 1);

    $self->app->logger_instance->info("Admin user '$username' logged out");

    return $self->render(json => {
        success => 1,
        message => 'Logged out successfully'
    });
}

sub status {
    my $self = shift;

    if ($self->_is_authenticated()) {
        return $self->render(json => {
            authenticated => 1,
            user => {
                id => $self->session('admin_user_id'),
                username => $self->session('admin_username'),
                email => $self->session('admin_email')
            },
            %{$self->csrf_token_response}
        });
    } else {
        return $self->render(json => {
            authenticated => 0
        });
    }
}

sub change_password {
    my $self = shift;

    unless ($self->_is_authenticated()) {
        return $self->render(json => {
            success => 0,
            error => 'Authentication required'
        }, status => 401);
    }

    # CSRF protection for password change
    unless ($self->csrf_protect) {
        return $self->render(json => {
            success => 0,
            error => 'CSRF validation failed'
        }, status => 403);
    }

    my $current_password = $self->param('current_password');
    my $new_password = $self->param('new_password');
    my $confirm_password = $self->param('confirm_password');

    unless ($current_password && $new_password && $confirm_password) {
        return $self->render(json => {
            success => 0,
            error => 'All password fields are required'
        }, status => 400);
    }

    if ($new_password ne $confirm_password) {
        return $self->render(json => {
            success => 0,
            error => 'New password and confirmation do not match'
        }, status => 400);
    }

    if (length($new_password) < 8) {
        return $self->render(json => {
            success => 0,
            error => 'New password must be at least 8 characters long'
        }, status => 400);
    }

    my $user_id = $self->session('admin_user_id');
    my $username = $self->session('admin_username');

    # Verify current password
    my $user = $self->_get_user_by_id($user_id);
    unless ($user && $self->_verify_password($current_password, $user->{password_hash})) {
        return $self->render(json => {
            success => 0,
            error => 'Current password is incorrect'
        }, status => 400);
    }

    # Update password
    if ($self->_update_password($user_id, $new_password)) {
        $self->app->logger_instance->info("Password changed for admin user '$username'");

        return $self->render(json => {
            success => 1,
            message => 'Password changed successfully'
        });
    } else {
        return $self->render(json => {
            success => 0,
            error => 'Failed to update password'
        }, status => 500);
    }
}

sub _is_authenticated {
    my $self = shift;

    my $user_id = $self->session('admin_user_id');
    return $user_id ? 1 : 0;
}

sub _authenticate_user {
    my ($self, $username, $password) = @_;

    $self->app->logger_instance->info("Auth attempt - username: '$username', password length: " . length($password));

    # Use db_config if available (multi-environment support), fallback to environment variables
    my $dbh;
    if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->app->logger_instance, $self->db_config);
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
    }
    return undef unless $dbh;

    my $sql = q{
        SELECT id, username, password_hash, email
        FROM admin_users
        WHERE username = ? AND is_active = true
    };

    my $authenticated_user;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($username);

        my $user = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();

        if ($user) {
            $self->app->logger_instance->info("User found: " . $user->{username} . ", hash length: " . length($user->{password_hash}));
            my $verify_result = $self->_verify_password($password, $user->{password_hash});
            $self->app->logger_instance->info("Password verification result: " . ($verify_result ? "SUCCESS" : "FAILED"));
            if ($verify_result) {
                $authenticated_user = $user;
            }
        } else {
            $self->app->logger_instance->info("User not found in database");
        }
    };

    if ($@) {
        $self->app->logger_instance->error("Authentication query failed: $@");
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $authenticated_user;
}

sub _get_user_by_id {
    my ($self, $user_id) = @_;

    # Use db_config if available (multi-environment support), fallback to environment variables
    my $dbh;
    if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->app->logger_instance, $self->db_config);
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
    }
    return undef unless $dbh;

    my $sql = q{
        SELECT id, username, password_hash, email
        FROM admin_users
        WHERE id = ? AND is_active = true
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($user_id);

        my $user = $sth->fetchrow_hashref();
        $dbh->disconnect();

        return $user;
    };

    if ($@) {
        $self->app->logger_instance->error("User lookup failed: $@");
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub _hash_password {
    my ($self, $password) = @_;

    # Use bcrypt with cost factor 12 (recommended security level)
    # bcrypt automatically handles salt generation when salt parameter is omitted
    use Crypt::Bcrypt qw(bcrypt);
    return bcrypt($password, '2b', 12, makerandom_octet(Length => 16));
}

sub _verify_password {
    my ($self, $password, $stored_hash) = @_;

    return 0 unless $stored_hash;

    # Detect hash format: bcrypt starts with $2b$, SHA-256 is exactly 96 hex chars
    if ($stored_hash =~ /^\$2[abxy]\$/) {
        # New bcrypt hash - use bcrypt_check for verification
        return bcrypt_check($password, $stored_hash) ? 1 : 0;
    } elsif (length($stored_hash) == 96 && $stored_hash =~ /^[0-9a-fA-F]{96}$/) {
        # Legacy SHA-256 hash - maintain backward compatibility
        return $self->_verify_sha256_password($password, $stored_hash);
    } else {
        # Unknown hash format
        return 0;
    }
}

sub _verify_sha256_password {
    my ($self, $password, $stored_hash) = @_;

    # Legacy verification for existing SHA-256 passwords
    # Extract salt (first 32 characters)
    my $salt = substr($stored_hash, 0, 32);

    # Extract hash (remaining 64 characters)
    my $stored_hash_only = substr($stored_hash, 32);

    # Hash the provided password with the extracted salt
    my $computed_hash = sha256_hex($password . $salt);

    # Compare hashes using constant-time comparison
    return $self->_constant_time_compare($computed_hash, $stored_hash_only);
}

sub _constant_time_compare {
    my ($self, $a, $b) = @_;

    return 0 if length($a) != length($b);

    my $result = 0;
    for my $i (0 .. length($a) - 1) {
        $result |= ord(substr($a, $i, 1)) ^ ord(substr($b, $i, 1));
    }

    return $result == 0;
}

sub _update_last_login {
    my ($self, $user_id) = @_;

    # Use db_config if available (multi-environment support), fallback to environment variables
    my $dbh;
    if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->app->logger_instance, $self->db_config);
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
    }
    return 0 unless $dbh;

    eval {
        my $sql = "UPDATE admin_users SET last_login = CURRENT_TIMESTAMP WHERE id = ?";
        my $sth = $dbh->prepare($sql);
        $sth->execute($user_id);
        $dbh->disconnect();
    };

    if ($@) {
        $self->app->logger_instance->error("Failed to update last login: $@");
        $dbh->disconnect() if $dbh;
        return 0;
    }

    return 1;
}

sub _update_password {
    my ($self, $user_id, $new_password) = @_;

    # Use db_config if available (multi-environment support), fallback to environment variables
    my $dbh;
    if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->app->logger_instance, $self->db_config);
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
    }
    return 0 unless $dbh;

    my $password_hash = $self->_hash_password($new_password);

    eval {
        my $sql = "UPDATE admin_users SET password_hash = ? WHERE id = ?";
        my $sth = $dbh->prepare($sql);
        $sth->execute($password_hash, $user_id);
        $dbh->disconnect();
    };

    if ($@) {
        $self->app->logger_instance->error("Failed to update password: $@");
        $dbh->disconnect() if $dbh;
        return 0;
    }

    return 1;
}

# Enhanced in-memory rate limiting with file persistence
my %login_attempts = ();
my $rate_limit_file = $ENV{RATE_LIMIT_FILE} || '/tmp/hello-perld-rate-limits.json';

# Load rate limit data from file on first use
sub _load_rate_limits {
    return if %login_attempts; # Already loaded

    return unless -f $rate_limit_file;

    eval {
        open my $fh, '<', $rate_limit_file or return;
        my $content = do { local $/; <$fh> };
        close $fh;

        return unless $content;

        my $data = decode_json($content);
        %login_attempts = %{$data} if $data && ref($data) eq 'HASH';
    };

    # Clean up expired entries on load
    my $now = time();
    for my $username (keys %login_attempts) {
        my $attempts = $login_attempts{$username} || [];
        @$attempts = grep { $now - $_ < 900 } @$attempts; # 15 minutes
        delete $login_attempts{$username} unless @$attempts;
    }
}

# Save rate limit data to file
sub _save_rate_limits {
    eval {
        # Ensure directory exists for the file path
        require File::Path;
        require File::Basename;
        my $dir = File::Basename::dirname($rate_limit_file);
        File::Path::make_path($dir) unless -d $dir;

        open my $fh, '>', $rate_limit_file or return;
        print $fh encode_json(\%login_attempts);
        close $fh;
    };
}

sub _is_rate_limited {
    my ($self, $username) = @_;

    # Load rate limits from file if not already loaded
    _load_rate_limits();

    my $now = time();
    my $attempts = $login_attempts{$username} || [];

    # Remove attempts older than 15 minutes
    @$attempts = grep { $now - $_ < 900 } @$attempts;
    $login_attempts{$username} = $attempts;

    # Check if more than 5 attempts in the last 15 minutes
    return scalar(@$attempts) >= 5;
}

sub _track_failed_login {
    my ($self, $username) = @_;

    # Load rate limits from file if not already loaded
    _load_rate_limits();

    my $now = time();
    $login_attempts{$username} ||= [];
    push @{$login_attempts{$username}}, $now;

    # Save to file after tracking failed login
    _save_rate_limits();
}

sub _clear_rate_limit {
    my ($self, $username) = @_;

    # Load rate limits from file if not already loaded
    _load_rate_limits();

    delete $login_attempts{$username};

    # Save to file after clearing rate limit
    _save_rate_limits();
}

# Middleware for protecting admin routes
sub require_auth {
    my ($self, $controller, $action) = @_;

    unless ($self->_is_authenticated()) {
        $self->render(json => {
            success => 0,
            error => 'Authentication required'
        }, status => 401);
        return undef;  # Explicitly stop further processing
    }

    # Continue to the intended action
    return 1;
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Auth - Authentication controller for admin users

=head1 SYNOPSIS

    # In your routes
    $r->post('/api/auth/login')->to('Auth#login');
    $r->post('/api/auth/logout')->to('Auth#logout');
    $r->get('/api/auth/status')->to('Auth#status');

    # Protected route example
    my $admin = $r->under('/api/admin')->to('Auth#require_auth');
    $admin->get('/articles')->to('Articles#get_all');

=head1 DESCRIPTION

This controller handles authentication for admin users including login, logout,
session management, and route protection. It includes security features like
password hashing, rate limiting, and constant-time password comparison.

=head1 METHODS

=head2 login

Authenticates a user with username and password. Creates a session on success.

=head2 logout

Logs out the current user by expiring their session.

=head2 status

Returns the current authentication status and user information.

=head2 change_password

Allows authenticated users to change their password.

=head2 require_auth

Middleware method to protect admin routes. Returns 401 if not authenticated.

=head1 SECURITY FEATURES

=over 4

=item * Password hashing with random salts

=item * Constant-time password comparison to prevent timing attacks

=item * Rate limiting on login attempts (5 attempts per 15 minutes)

=item * Session-based authentication

=item * Secure password requirements (minimum 8 characters)

=back

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
