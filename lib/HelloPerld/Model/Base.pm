package HelloPerld::Model::Base;

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Database::Postgres;
use HelloPerld::Controller::Metrics;
use Time::HiRes qw(time);

=head1 NAME

HelloPerld::Model::Base - Base class for all model objects

=head1 DESCRIPTION

Provides common functionality for all model classes, including database connection
management and shared utilities.

=head1 METHODS

=cut

sub new {
    my ($class, %args) = @_;

    my $self = {
        logger => $args{logger},
        db_config => $args{db_config} || {},
    };

    return bless $self, $class;
}

=head2 _get_dbh()

Returns a database handle using either custom config or default connection.
This replaces the duplicated database connection code across all models.

Returns:
    $dbh - Database handle on success
    undef - On connection failure

=cut

sub _get_dbh {
    my ($self) = @_;

    if ($self->{db_config} && %{$self->{db_config}}) {
        return HelloPerld::Database::Postgres::get_connection_from_config(
            $self->{logger},
            $self->{db_config}
        );
    }

    return HelloPerld::Database::Postgres::get_connection($self->{logger});
}

=head2 _log_error($message)

Convenience method for error logging.

=cut

sub _log_error {
    my ($self, $message) = @_;

    if ($self->{logger}) {
        $self->{logger}->error($message);
    } else {
        warn "Error: $message\n";
    }
}

=head2 _log_info($message)

Convenience method for info logging.

=cut

sub _log_info {
    my ($self, $message) = @_;

    if ($self->{logger}) {
        $self->{logger}->info($message);
    }
}

=head2 _execute_query($dbh, $sql, $operation, @params)

Execute a database query with metrics tracking.
Returns the statement handle after execution.

=cut

sub _execute_query {
    my ($self, $dbh, $sql, $operation, @params) = @_;

    my $start_time = time();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    my $duration = time() - $start_time;

    # Track metrics
    HelloPerld::Controller::Metrics->inc_db_query($operation);
    HelloPerld::Controller::Metrics->observe_db_duration($operation, $duration);

    return $sth;
}

=head2 _execute_query_single($dbh, $sql, $operation, @params)

Execute a database query and return a single row as hashref.
Includes metrics tracking.

=cut

sub _execute_query_single {
    my ($self, $dbh, $sql, $operation, @params) = @_;

    my $sth = $self->_execute_query($dbh, $sql, $operation, @params);
    my $result = $sth->fetchrow_hashref();
    $sth->finish();

    return $result;
}

=head2 _execute_query_all($dbh, $sql, $operation, @params)

Execute a database query and return all rows as array of hashrefs.
Includes metrics tracking.

=cut

sub _execute_query_all {
    my ($self, $dbh, $sql, $operation, @params) = @_;

    my $sth = $self->_execute_query($dbh, $sql, $operation, @params);
    my @results;
    while (my $row = $sth->fetchrow_hashref()) {
        push @results, $row;
    }
    $sth->finish();

    return \@results;
}

1;

__END__

=head1 AUTHOR

TheBoosh.Zone Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 TheBoosh.Zone

=cut