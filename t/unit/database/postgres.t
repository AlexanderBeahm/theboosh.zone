#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use lib 't/lib';
use TestHelper qw(mock_logger);

use_ok('HelloPerld::Database::Postgres');

my $logger = mock_logger();

subtest 'extract_migration_info' => sub {
    my ($version, $type, $name);

    ($version, $type, $name) = HelloPerld::Database::Postgres::extract_migration_info('001_create_articles_table.sql');
    is($version, '001', 'Extract version from SQL migration');
    is($type, 'sql', 'Extract type from SQL migration');
    is($name, 'create_articles_table', 'Extract name from SQL migration');

    ($version, $type, $name) = HelloPerld::Database::Postgres::extract_migration_info('005_create_default_admin_user.pl');
    is($version, '005', 'Extract version from Perl migration');
    is($type, 'perl', 'Extract type from Perl migration');
    is($name, 'create_default_admin_user', 'Extract name from Perl migration');

    ($version, $type, $name) = HelloPerld::Database::Postgres::extract_migration_info('123_my_complex_migration_name.sql');
    is($version, '123', 'Extract three-digit version');
    is($name, 'my_complex_migration_name', 'Extract complex name');

    ($version, $type, $name) = HelloPerld::Database::Postgres::extract_migration_info('invalid_filename.txt');
    ok(!defined $version, 'Invalid filename returns undef version');
    ok(!defined $type, 'Invalid filename returns undef type');
    ok(!defined $name, 'Invalid filename returns undef name');
};

subtest 'module can be loaded' => sub {
    can_ok('HelloPerld::Database::Postgres', qw(
        get_connection
        validate_connection
        initialize_migrations_table
        get_applied_migrations
        apply_migration
        run_migrations
        extract_migration_info
    ));
};

# Note: Full integration tests for database operations should be in
# t/integration/database/postgres.t where we can use a real test database

done_testing();
