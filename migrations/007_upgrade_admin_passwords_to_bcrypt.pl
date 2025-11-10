#!/usr/bin/env perl

# Add library path BEFORE any other use statements
BEGIN {
    use FindBin;
    use File::Spec;
    use Cwd qw(abs_path);

    # Calculate library path relative to migration script location
    my $lib_path = File::Spec->catdir($FindBin::Bin, '..', 'lib');
    $lib_path = abs_path($lib_path);

    # Untaint for taint mode compatibility
    $lib_path =~ /^(.+)$/ or die "Unable to untaint library path";
    $lib_path = $1;

    # Add to library search path
    unshift @INC, $lib_path;
}

use strict;
use warnings;

use HelloPerld::Database::Postgres;
use Digest::SHA qw(sha256_hex);
use Crypt::Random qw(makerandom_octet);
use Crypt::Bcrypt qw(bcrypt);

# This migration upgrades existing SHA-256 admin passwords to bcrypt
# It is idempotent and safe to run multiple times

print "Migration 007: Upgrading admin passwords from SHA-256 to bcrypt\n";

# Get required environment variables (untaint for taint mode)
my $admin_username = $ENV{'ADMIN_USERNAME'} || 'admin';
$admin_username =~ /^([a-zA-Z0-9_]+)$/ or die "Invalid admin username format";
$admin_username = $1;

my $admin_password = $ENV{'ADMIN_PASSWORD'};
if ($admin_password) {
    # Untaint password - allow reasonable password characters
    $admin_password =~ /^(.{8,})$/ or die "Invalid admin password format";
    $admin_password = $1;
}

unless ($admin_password) {
    print "SKIPPING: ADMIN_PASSWORD environment variable not set\n";
    print "To upgrade existing admin passwords to bcrypt, set ADMIN_PASSWORD\n";
    print "and run this migration again.\n";
    exit 0;
}

# Validate password strength
if (length($admin_password) < 8) {
    die "ERROR: Password must be at least 8 characters long\n";
}

# Get database connection
my $dbh = HelloPerld::Database::Postgres::get_connection();
unless ($dbh) {
    die "ERROR: Could not connect to database\n";
}

eval {
    # Find admin users with SHA-256 passwords (96 hex characters)
    my $find_sql = q{
        SELECT id, username, password_hash
        FROM admin_users
        WHERE LENGTH(password_hash) = 96
        AND password_hash ~ '^[0-9a-fA-F]{96}$'
    };

    my $find_sth = $dbh->prepare($find_sql);
    $find_sth->execute();

    my @legacy_users;
    while (my $user = $find_sth->fetchrow_hashref()) {
        push @legacy_users, $user;
    }
    $find_sth->finish();

    if (@legacy_users == 0) {
        print "✅ No SHA-256 passwords found. All admin passwords already use bcrypt.\n";
        $dbh->disconnect();
        exit 0;
    }

    print "Found " . scalar(@legacy_users) . " admin user(s) with SHA-256 passwords:\n";
    for my $user (@legacy_users) {
        print "  - ID: $user->{id}, Username: $user->{username}\n";
    }

    # For security, we can only upgrade passwords when we have the plaintext
    # This means we can only upgrade the main admin user whose password we know
    my $upgraded_count = 0;

    for my $user (@legacy_users) {
        if ($user->{username} eq $admin_username) {
            print "Upgrading password for admin user: $user->{username}\n";

            # Verify the current password matches before upgrading
            my $legacy_hash = $user->{password_hash};
            my $salt = substr($legacy_hash, 0, 32);
            my $stored_hash = substr($legacy_hash, 32);
            my $computed_hash = sha256_hex($admin_password . $salt);

            if ($computed_hash eq $stored_hash) {
                # Password matches - upgrade to bcrypt
                my $bcrypt_hash = bcrypt($admin_password, '2b', 12, makerandom_octet(Length => 16));

                my $update_sql = "UPDATE admin_users SET password_hash = ? WHERE id = ?";
                my $update_sth = $dbh->prepare($update_sql);
                $update_sth->execute($bcrypt_hash, $user->{id});
                $update_sth->finish();

                print "✅ Successfully upgraded password for user: $user->{username}\n";
                $upgraded_count++;
            } else {
                print "⚠️  WARNING: ADMIN_PASSWORD does not match current password for user: $user->{username}\n";
                print "   Skipping upgrade for security. Update ADMIN_PASSWORD or use script/update_admin_password\n";
            }
        } else {
            print "⚠️  Cannot automatically upgrade user: $user->{username}\n";
            print "   Use script/update_admin_password with correct credentials to upgrade manually\n";
        }
    }

    if ($upgraded_count > 0) {
        print "✅ Migration completed successfully. Upgraded $upgraded_count password(s) to bcrypt.\n";
    } else {
        print "ℹ️  No passwords were upgraded. Manual intervention may be required.\n";
    }

    $dbh->disconnect();
};

if ($@) {
    print "❌ Migration failed: $@\n";
    $dbh->disconnect() if $dbh;
    exit 1;
}

__END__

=head1 NAME

007_upgrade_admin_passwords_to_bcrypt.pl - Upgrade admin passwords from SHA-256 to bcrypt

=head1 DESCRIPTION

This migration script upgrades existing admin user passwords from the legacy
SHA-256 + salt format to the secure bcrypt format.

For security reasons, this script can only upgrade passwords when the plaintext
password is available via environment variables. This ensures we don't
accidentally corrupt password hashes.

=head1 ENVIRONMENT VARIABLES

=over 4

=item * ADMIN_USERNAME - Admin username to upgrade (default: 'admin')

=item * ADMIN_PASSWORD - Current plaintext password (required for verification)

=back

=head1 SECURITY NOTES

- The script verifies the current password before upgrading
- Only upgrades passwords that match the provided ADMIN_PASSWORD
- Uses bcrypt with cost factor 12 for new passwords
- Idempotent - safe to run multiple times
- Will not corrupt existing bcrypt passwords

=head1 USAGE

For staging/production deployment:

    # Set environment variables in your deployment
    export ADMIN_USERNAME=admin
    export ADMIN_PASSWORD=your_current_admin_password

    # Run the migration
    perl migrations/007_upgrade_admin_passwords_to_bcrypt.pl

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=cut