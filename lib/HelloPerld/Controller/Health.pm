package HelloPerld::Controller::Health;

use strict;
use warnings;

our $VERSION = '1.0.0';

use Mojo::Base 'Mojolicious::Controller', -signatures;
use HelloPerld::Server;
use HelloPerld::Database::Postgres;
use POSIX qw(strftime);

sub getHealthStatus ($self) {
    my $timestamp = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());

    if (HelloPerld::Server::health_check($self->app->logger_instance)) {
        $self->render(json => {
            status => 'healthy',
            timestamp => $timestamp
        });
    } else {
        $self->render(json => {
            status => 'unhealthy',
            timestamp => $timestamp
        }, status => 503);
    }
}

sub get_readiness_status ($self) {
    my $timestamp = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());

    # Test database connectivity directly
    eval {
        HelloPerld::Database::Postgres::validate_connection($self->app->logger_instance);
    };

    if ($@) {
        # Database not available
        $self->app->logger_instance->warn("Readiness check failed: Database unavailable - $@");
        $self->render(json => {
            status => 'not_ready',
            database => 'unavailable',
            timestamp => $timestamp
        }, status => 503);
    } else {
        # Database is ready
        $self->app->logger_instance->debug("Readiness check passed: Database connected");
        $self->render(json => {
            status => 'ready',
            database => 'connected',
            timestamp => $timestamp
        });
    }
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Health - Health check endpoint controller

=head1 SYNOPSIS

    # Used automatically by Mojolicious routing
    # GET /health endpoint - liveness check
    # GET /health/ready endpoint - readiness check

=head1 DESCRIPTION

Mojolicious controller that provides health check endpoints for monitoring
the application status. Provides both liveness and readiness checks for
containerized deployment environments.

- Liveness check (/health): Tests if the application is running
- Readiness check (/health/ready): Tests if the application is ready to serve traffic

=head1 METHODS

=head2 getHealthStatus

    $self->getHealthStatus();

Endpoint handler for GET /health requests. Performs comprehensive health
checks including database connectivity and returns appropriate HTTP status
and JSON response indicating system health. This is a liveness check.

=head2 get_readiness_status

    $self->get_readiness_status();

Endpoint handler for GET /health/ready requests. Tests real-time database
connectivity to determine if the application is ready to serve traffic.
Returns 200 if ready, 503 if not ready. This is a readiness check suitable
for load balancer and orchestration system integration.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut