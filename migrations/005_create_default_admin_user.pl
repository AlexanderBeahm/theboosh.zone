#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib" }

use File::Spec;

# This is a Perl migration script that creates the default admin user
# It will be executed by the migration system when running database migrations

# Get migration metadata from environment variables
my $version = $ENV{MIGRATION_VERSION} || '005';
my $description = $ENV{MIGRATION_DESCRIPTION} || 'create default admin user';

print "Running migration $version: $description\n";

# Build path to the create_admin_user script
my $script_path = File::Spec->catfile($FindBin::Bin, '..', 'script', 'create_admin_user');

# Check if the script exists
unless (-f $script_path) {
    die "ERROR: Admin user creation script not found at: $script_path\n";
}

# Check if the script is executable
unless (-x $script_path) {
    die "ERROR: Admin user creation script is not executable: $script_path\n";
}

# Execute the admin user creation script
print "Executing admin user creation script...\n";

my $result = system("perl", $script_path);

if ($result == 0) {
    print "✅ Admin user migration completed successfully\n";
    exit 0;
} else {
    my $exit_code = $result >> 8;
    print "❌ Admin user creation failed with exit code: $exit_code\n";
    exit 1;
}

__END__

=head1 NAME

005_create_default_admin_user.pl - Database migration to create default admin user

=head1 DESCRIPTION

This migration script creates a default admin user for the TheBoosh.Zone application.
It calls the script/create_admin_user script to perform the actual user creation.

The migration is idempotent - it will not fail if the admin user already exists.

=head1 ENVIRONMENT VARIABLES

The migration system provides:
- MIGRATION_VERSION - The migration version number
- MIGRATION_DESCRIPTION - The migration description

The admin user creation requires:
- ADMIN_USERNAME - Admin username (default: 'admin')
- ADMIN_EMAIL - Admin email address (required)
- ADMIN_PASSWORD - Admin password (required, minimum 8 characters)

=head1 USAGE

This migration is executed automatically by the migration system:

    perl script/migrate

Make sure to set the required environment variables before running migrations:

    export ADMIN_USERNAME=admin
    export ADMIN_EMAIL=your-email@example.com
    export ADMIN_PASSWORD=your-secure-password
    perl script/migrate

=head1 SEE ALSO

- script/create_admin_user - The actual admin user creation script
- HelloPerld::Database::Postgres - The migration system
- HelloPerld::Controller::Auth - Admin authentication controller

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut