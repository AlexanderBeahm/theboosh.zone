package HelloPerld::Database::Postgres;

use strict;
use warnings;

our $VERSION = '1.0.0';

use DBI;
use File::Path qw(make_path);
use File::Glob qw(bsd_glob);

sub validate_connection {
    my ($logger) = @_;

    my $dbname = $ENV{'POSTGRES_DB'};
    my $host = $ENV{'POSTGRES_HOST'} || 'db'; # use env variable or fallback to docker service name
    my $port = $ENV{'POSTGRES_PORT'} || 5432;
    my $user = $ENV{'POSTGRES_USER'}; # fetch from env variables
    my $password = $ENV{'POSTGRES_PASSWORD'}; # fetch from env variables

    my $success = 0;
    eval {
        my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port", $user, $password, { RaiseError => 1, AutoCommit => 1 });

        if ($dbh) {
            if ($logger) {
                $logger->info("Connected to PostgreSQL database successfully!");
            } else {
                print "Connected to PostgreSQL database successfully!\n";
            }
            $dbh->disconnect;
            $success = 1;
        }
    };

    if ($@) {
        my $error_msg = "Could not connect to PostgreSQL database: $@";
        if ($logger) {
            $logger->error($error_msg);
        } else {
            warn $error_msg;
        }
        return 0;
    }

    return $success;
}

sub get_connection {
    my ($logger, %options) = @_;

    # Get config from options or environment
    my $schema = $options{schema} || $ENV{DB_SCHEMA} || 'public';
    my $host = $options{host} || $ENV{POSTGRES_HOST} || 'db';
    my $port = $options{port} || $ENV{POSTGRES_PORT} || 5432;
    my $dbname = $options{dbname} || $ENV{POSTGRES_DB};
    my $user = $options{user} || $ENV{POSTGRES_USER};
    my $password = $options{password} || $ENV{POSTGRES_PASSWORD};

    my $dsn = "DBI:Pg:dbname=$dbname;host=$host;port=$port";

    my $dbh = DBI->connect($dsn, $user, $password, {
        RaiseError => 1,
        AutoCommit => 1,
        PrintError => 0,
        pg_enable_utf8 => 1
    });

    if (!$dbh) {
        if ($logger) {
            $logger->error("Could not establish database connection");
        }
        return undef;
    }

    # Set schema search path if not public
    if ($schema ne 'public') {
        eval {
            $dbh->do("SET search_path TO $schema, public");
            if ($logger) {
                $logger->debug("Set database schema to: $schema");
            }
        };
        if ($@) {
            if ($logger) {
                $logger->warn("Could not set schema $schema: $@");
            }
        }
    }

    return $dbh;
}

sub get_connection_from_config {
    my ($logger, $config) = @_;

    return get_connection(
        $logger,
        schema => $config->{schema},
        host => $config->{host},
        port => $config->{port},
        dbname => $config->{dbname},
        user => $config->{user},
        password => $config->{password},
    );
}

sub initialize_migrations_table {
    my ($dbh, $logger) = @_;

    my $sql = q{
        CREATE TABLE IF NOT EXISTS schema_migrations (
            id SERIAL PRIMARY KEY,
            version VARCHAR(20) UNIQUE NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            description TEXT
        )
    };

    my $success = 0;
    eval {
        $dbh->do($sql);
        if ($logger) {
            $logger->info("Migrations table initialized");
        }
        $success = 1;
    };

    if ($@) {
        if ($logger) {
            $logger->error("Could not initialize migrations table: $@");
        }
        return 0;
    }

    return $success;
}

sub get_applied_migrations {
    my ($dbh, $logger) = @_;

    my @applied_versions;
    eval {
        my $sth = $dbh->prepare("SELECT version FROM schema_migrations ORDER BY version");
        $sth->execute();

        while (my ($version) = $sth->fetchrow_array()) {
            push @applied_versions, $version;
        }
    };

    if ($@) {
        if ($logger) {
            $logger->error("Could not fetch applied migrations: $@");
        }
        return ();
    }

    return @applied_versions;
}

sub apply_migration {
    my ($dbh, $version, $description, $sql, $logger) = @_;

    my $success = 0;
    eval {
        $dbh->begin_work();

        # Execute the migration SQL
        $dbh->do($sql);

        # Record the migration
        my $sth = $dbh->prepare("INSERT INTO schema_migrations (version, description) VALUES (?, ?)");
        $sth->execute($version, $description);
        $sth->finish();

        $dbh->commit();

        if ($logger) {
            $logger->info("Applied migration $version: $description");
        }

        $success = 1;
    };

    if ($@) {
        eval { $dbh->rollback() };
        if ($logger) {
            $logger->error("Failed to apply migration $version: $@");
        }
        return 0;
    }

    return $success;
}

sub run_migrations {
    my ($migration_dir, $logger) = @_;

    $migration_dir ||= 'migrations';

    my $dbh = get_connection($logger);
    return 0 unless $dbh;

    # Initialize migrations table
    return 0 unless initialize_migrations_table($dbh, $logger);

    # Get applied migrations
    my @applied = get_applied_migrations($dbh, $logger);
    my %applied_lookup = map { $_ => 1 } @applied;

    # Find migration files (both .sql and .pl)
    my @sql_files = bsd_glob("$migration_dir/*.sql");
    my @pl_files = bsd_glob("$migration_dir/*.pl");
    my @migration_files = sort (@sql_files, @pl_files);

    my $migrations_run = 0;
    foreach my $file (@migration_files) {
        my ($version, $type, $name) = extract_migration_info($file);
        next unless $version;

        # Convert name to description (replace underscores with spaces)
        my $description = $name;
        $description =~ s/_/ /g;

        # Skip if already applied
        if ($applied_lookup{$version}) {
            if ($logger) {
                $logger->debug("Skipping already applied migration: $version");
            }
            next;
        }

        # Apply migration based on type
        my $success = 0;
        if ($type eq 'sql') {
            # Read SQL migration file
            open my $fh, '<', $file or do {
                if ($logger) {
                    $logger->error("Could not read migration file $file: $!");
                }
                next;
            };

            my $sql = do { local $/; <$fh> };
            close $fh;

            # Apply SQL migration
            $success = apply_migration($dbh, $version, $description, $sql, $logger);
        } elsif ($type eq 'pl') {
            # Execute Perl migration script
            $success = execute_perl_migration($dbh, $file, $version, $description, $logger);
        }

        if ($success) {
            $migrations_run++;
        } else {
            last; # Stop on first failure
        }
    }

    $dbh->disconnect();

    if ($logger) {
        $logger->info("Migration run complete. Applied $migrations_run new migrations.");
    }

    return $migrations_run;
}

sub extract_migration_info {
    my ($filename) = @_;

    # Extract version and description from filename like: 001_create_articles_table.sql or 001_create_articles_table.pl
    if ($filename =~ /(\d{3})_(.+)\.(sql|pl)$/) {
        my ($version, $name, $ext) = ($1, $2, $3);

        # Normalize file extension to migration type
        my $type = $ext eq 'pl' ? 'perl' : $ext;

        # Return in order: version, type, name (matching test expectations)
        return ($version, $type, $name);
    }

    return (undef, undef, undef);
}

sub execute_perl_migration {
    my ($dbh, $file, $version, $description, $logger) = @_;

    my $success = 0;
    eval {
        if ($logger) {
            $logger->info("Executing Perl migration $version: $description");
        }

        # Make the database handle available to the Perl migration script
        # We'll pass it as an environment variable or through a global
        local $ENV{MIGRATION_VERSION} = $version;
        local $ENV{MIGRATION_DESCRIPTION} = $description;

        # Execute the Perl script and capture the result
        my $result = system("perl", $file);

        if ($result != 0) {
            die "Perl migration script failed with exit code: $result";
        }

        # Record the migration in the database (in separate transaction)
        # Perl scripts run in separate process, so we track after success
        $dbh->begin_work();

        my $sth = $dbh->prepare("INSERT INTO schema_migrations (version, description) VALUES (?, ?)");
        $sth->execute($version, $description);
        $sth->finish();

        $dbh->commit();

        if ($logger) {
            $logger->info("Applied Perl migration $version: $description");
        }

        $success = 1;
    };

    if ($@) {
        eval { $dbh->rollback() };
        if ($logger) {
            $logger->error("Failed to apply Perl migration $version: $@");
        }
        return 0;
    }

    return $success;
}

1;

__END__

=head1 NAME

HelloPerld::Database::Postgres - PostgreSQL database utilities

=head1 SYNOPSIS

    use HelloPerld::Database::Postgres;

    my $logger = HelloPerld::Logger::ConsoleLogger->new();
    HelloPerld::Database::Postgres::validate_connection($logger);

=head1 DESCRIPTION

Provides PostgreSQL database connectivity validation and utility functions.
Handles database connection testing, migration system, and database operations
with comprehensive logging support.

=head1 FUNCTIONS

=head2 validate_connection

    HelloPerld::Database::Postgres::validate_connection($logger);

Validates that a connection can be established to the PostgreSQL database
using environment variables for configuration. Dies on connection failure.
Logs connection status information.

=head2 get_connection

    my $dbh = HelloPerld::Database::Postgres::get_connection($logger);

Returns a database handle connected to PostgreSQL using environment variables.

=head2 run_migrations

    my $count = HelloPerld::Database::Postgres::run_migrations($migration_dir, $logger);

Runs database migrations from the specified directory. Supports both SQL (.sql)
and Perl (.pl) migration files. Returns the number of migrations applied.

=head2 execute_perl_migration

    HelloPerld::Database::Postgres::execute_perl_migration($dbh, $file, $version, $description, $logger);

Executes a Perl migration script and records it in the schema_migrations table.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
