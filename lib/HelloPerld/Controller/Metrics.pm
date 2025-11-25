package HelloPerld::Controller::Metrics;

use strict;
use warnings;

our $VERSION = '1.0.0';

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Prometheus::Tiny::Shared;
use HelloPerld::Database::Postgres;
use Time::HiRes qw(time);

# Shared Prometheus instance for multi-worker support (hypnotoad)
my $prom;

sub _get_prometheus {
    unless ($prom) {
        my $metrics_file = $ENV{PROMETHEUS_METRICS_FILE} || '/tmp/hello-perld-metrics';
        $prom = Prometheus::Tiny::Shared->new(
            filename => $metrics_file
        );
        _declare_metrics($prom);
    }
    return $prom;
}

sub _declare_metrics {
    my ($p) = @_;

    # HTTP request metrics
    $p->declare('http_requests_total',
        help => 'Total number of HTTP requests',
        type => 'counter'
    );

    $p->declare('http_request_duration_seconds',
        help => 'HTTP request duration in seconds',
        type => 'histogram',
        buckets => [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    );

    $p->declare('http_requests_in_progress',
        help => 'Number of HTTP requests currently being processed',
        type => 'gauge'
    );

    # Application info
    $p->declare('app_info',
        help => 'Application information',
        type => 'gauge'
    );

    # Database metrics
    $p->declare('app_database_queries_total',
        help => 'Total number of database queries',
        type => 'counter'
    );

    $p->declare('app_database_query_duration_seconds',
        help => 'Database query duration in seconds',
        type => 'histogram',
        buckets => [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1]
    );

    $p->declare('app_database_connection_status',
        help => 'Database connection status (1 = connected, 0 = disconnected)',
        type => 'gauge'
    );

    # Business metrics
    $p->declare('app_articles_total',
        help => 'Total number of articles by status',
        type => 'gauge'
    );

    $p->declare('app_media_files_total',
        help => 'Total number of media files',
        type => 'gauge'
    );

    $p->declare('app_tags_total',
        help => 'Total number of tags',
        type => 'gauge'
    );

    $p->declare('app_admin_login_attempts_total',
        help => 'Total admin login attempts',
        type => 'counter'
    );

    # Session metrics
    $p->declare('app_active_sessions',
        help => 'Estimated number of active sessions',
        type => 'gauge'
    );

    # Error metrics
    $p->declare('app_errors_total',
        help => 'Total number of application errors',
        type => 'counter'
    );
}

# Get the shared Prometheus instance for use by other parts of the app
sub get_instance {
    return _get_prometheus();
}

# Increment request counter
sub inc_request ($class, $method, $endpoint, $status) {
    my $p = _get_prometheus();
    $p->inc('http_requests_total', {
        method => $method,
        endpoint => $endpoint,
        status => $status
    });
}

# Observe request duration
sub observe_request_duration ($class, $method, $endpoint, $duration) {
    my $p = _get_prometheus();
    $p->histogram_observe('http_request_duration_seconds', $duration, {
        method => $method,
        endpoint => $endpoint
    });
}

# Track requests in progress
sub inc_in_progress ($class) {
    my $p = _get_prometheus();
    $p->inc('http_requests_in_progress');
}

sub dec_in_progress ($class) {
    my $p = _get_prometheus();
    $p->dec('http_requests_in_progress');
}

# Database metrics
sub inc_db_query ($class, $operation) {
    my $p = _get_prometheus();
    $p->inc('app_database_queries_total', { operation => $operation });
}

sub observe_db_duration ($class, $operation, $duration) {
    my $p = _get_prometheus();
    $p->histogram_observe('app_database_query_duration_seconds', $duration, {
        operation => $operation
    });
}

# Login attempt tracking
sub inc_login_attempt ($class, $success) {
    my $p = _get_prometheus();
    $p->inc('app_admin_login_attempts_total', { success => $success ? 'true' : 'false' });
}

# Error tracking
sub inc_error ($class, $type) {
    my $p = _get_prometheus();
    $p->inc('app_errors_total', { type => $type });
}

# Metrics endpoint handler
sub get_metrics ($self) {
    my $p = _get_prometheus();

    # Update app info
    $p->set('app_info', 1, {
        version => $HelloPerld::VERSION || '1.0.0',
        environment => $ENV{MOJO_MODE} || 'development'
    });

    # Update database connection status
    $self->_update_db_status($p);

    # Update business metrics
    $self->_update_business_metrics($p);

    # Render Prometheus format
    $self->res->headers->content_type('text/plain; version=0.0.4; charset=utf-8');
    $self->render(text => $p->format);
}

sub _update_db_status ($self, $p) {
    my $connected = 0;
    eval {
        my $dbh;
        if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
            $dbh = HelloPerld::Database::Postgres::get_connection_from_config(
                $self->app->logger_instance,
                $self->db_config
            );
        } else {
            # Fallback to environment variables
            $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
        }
        if ($dbh) {
            $connected = 1;
            $dbh->disconnect();
        }
    };
    if ($@) {
        $self->app->logger_instance->warn("Database status check failed: $@");
    }
    $p->set('app_database_connection_status', $connected);
}

sub _update_business_metrics ($self, $p) {
    eval {
        my $dbh;
        if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
            $dbh = HelloPerld::Database::Postgres::get_connection_from_config(
                $self->app->logger_instance,
                $self->db_config
            );
        } else {
            # Fallback to environment variables
            $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
        }
        return unless $dbh;

        # Count articles by status
        my $sth = $dbh->prepare("SELECT is_published, COUNT(*) FROM articles GROUP BY is_published");
        $sth->execute();
        while (my ($is_published, $count) = $sth->fetchrow_array()) {
            my $status = $is_published ? 'published' : 'draft';
            $p->set('app_articles_total', $count, { status => $status });
        }
        $sth->finish();

        # Count media files
        $sth = $dbh->prepare("SELECT COUNT(*) FROM media");
        $sth->execute();
        my ($media_count) = $sth->fetchrow_array();
        $p->set('app_media_files_total', $media_count || 0);
        $sth->finish();

        # Count tags
        $sth = $dbh->prepare("SELECT COUNT(*) FROM tags");
        $sth->execute();
        my ($tag_count) = $sth->fetchrow_array();
        $p->set('app_tags_total', $tag_count || 0);
        $sth->finish();

        $dbh->disconnect();
    };
    if ($@) {
        $self->app->logger_instance->warn("Failed to update business metrics: $@");
    }
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Metrics - Prometheus metrics endpoint controller

=head1 SYNOPSIS

    # Used automatically by Mojolicious routing
    # GET /metrics endpoint - Prometheus format metrics

=head1 DESCRIPTION

Mojolicious controller that provides Prometheus-compatible metrics endpoint
for monitoring the application. Uses Prometheus::Tiny::Shared for multi-worker
support with hypnotoad.

=head1 METRICS EXPOSED

=head2 HTTP Metrics

=over 4

=item http_requests_total{method, endpoint, status}

Counter of total HTTP requests

=item http_request_duration_seconds{method, endpoint}

Histogram of HTTP request durations

=item http_requests_in_progress

Gauge of currently processing requests

=back

=head2 Database Metrics

=over 4

=item app_database_queries_total{operation}

Counter of database queries by operation type

=item app_database_query_duration_seconds{operation}

Histogram of database query durations

=item app_database_connection_status

Gauge indicating database connectivity (1=connected, 0=disconnected)

=back

=head2 Business Metrics

=over 4

=item app_articles_total{status}

Gauge of total articles by published status

=item app_media_files_total

Gauge of total media files

=item app_tags_total

Gauge of total tags

=back

=head1 CLASS METHODS

=head2 get_instance

Returns the shared Prometheus::Tiny::Shared instance for use by other modules.

=head2 inc_request($method, $endpoint, $status)

Increment the HTTP request counter.

=head2 observe_request_duration($method, $endpoint, $duration)

Record HTTP request duration in the histogram.

=head2 inc_db_query($operation)

Increment database query counter.

=head2 observe_db_duration($operation, $duration)

Record database query duration.

=head2 inc_login_attempt($success)

Track admin login attempts (success or failure).

=head2 inc_error($type)

Track application errors by type.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
