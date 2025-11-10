package HelloPerld::Model::Base;

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Database::Postgres;

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

1;

__END__

=head1 AUTHOR

TheBoosh.Zone Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 TheBoosh.Zone

=cut