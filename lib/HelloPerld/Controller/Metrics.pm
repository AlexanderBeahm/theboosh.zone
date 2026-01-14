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

    # Article viewership metrics
    $p->declare('app_article_views_total',
        help => 'Total number of article views by article ID and IP hash',
        type => 'counter'
    );

    $p->declare('app_article_views_by_ip_total',
        help => 'Total article views per IP hash',
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

# Hash IP address for Prometheus metrics (limits cardinality)
sub _hash_ip_for_metrics {
    my ($ip) = @_;
    return 'unknown' unless $ip;

    # IPv4: Replace last octet with 'x' (e.g., 192.168.1.123 -> 192.168.1.x)
    if ($ip =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$/) {
        return "$1.x";
    }

    # IPv6: Handle both full and compressed formats
    # Goal: Extract first two groups to identify network prefix, then mask the rest
    # Examples: 2001:db8::1 -> 2001:db8::x
    #           2001:0db8:0000:0000:0000:0000:0000:0001 -> 2001:db8::x
    #           ::1 -> ::x
    #           fe80::1 -> fe80::x (only one visible group before ::)
    if ($ip =~ /:/) {
        # Handle loopback and addresses starting with :: first
        if ($ip =~ /^::/) {
            return "::x";
        }

        # Split on colons to get groups
        my @groups = split /:/, $ip, -1;  # -1 preserves trailing empty strings

        # Filter out empty strings (from ::) and get first two non-empty groups
        my @non_empty = grep { $_ ne '' } @groups;

        if (@non_empty >= 2) {
            # Have at least two groups
            my $g1 = $non_empty[0];
            my $g2 = $non_empty[1];
            # Remove leading zeros for cleaner output
            $g1 =~ s/^0+([0-9a-fA-F])/$1/;
            $g2 =~ s/^0+([0-9a-fA-F])/$1/;
            return "${g1}:${g2}::x";
        } elsif (@non_empty == 1) {
            # Only one group (like fe80::1 where 1 might be after ::)
            # Check if first element before :: is non-empty
            my $g1 = $non_empty[0];
            $g1 =~ s/^0+([0-9a-fA-F])/$1/;
            return "${g1}::x";
        }
    }

    # Fallback: return as-is if format is unrecognized
    return $ip;
}

# Track article view
sub inc_article_view ($class, $article_id, $ip_address) {
    my $p = _get_prometheus();
    my $ip_hash = _hash_ip_for_metrics($ip_address);

    # Increment per-article metric
    $p->inc('app_article_views_total', {
        article_id => $article_id,
        ip_hash => $ip_hash
    });

    # Increment per-IP metric
    $p->inc('app_article_views_by_ip_total', {
        ip_hash => $ip_hash
    });
}

# Database connection cache (30-second TTL)
my $dbh_cache = { dbh => undef, expires_at => 0 };

# Business metrics cache (60-second TTL)
my $business_metrics_cache = {
    data => {},
    expires_at => 0
};

# Get cached database connection
sub _get_cached_dbh {
    my ($self) = @_;
    my $now = time();

    # Check if cached connection is still valid
    if ($dbh_cache->{dbh} && $now < $dbh_cache->{expires_at}) {
        # Verify connection is still alive
        eval { $dbh_cache->{dbh}->ping(); };
        if (!$@) {
            return $dbh_cache->{dbh};
        }
        # Connection is dead, clean up
        eval { $dbh_cache->{dbh}->disconnect(); };
        $dbh_cache->{dbh} = undef;
    }

    # Create new connection
    my $dbh;
    eval {
        if ($self->can('db_config') && $self->db_config && %{$self->db_config}) {
            $dbh = HelloPerld::Database::Postgres::get_connection_from_config(
                $self->app->logger_instance,
                $self->db_config
            );
        } else {
            $dbh = HelloPerld::Database::Postgres::get_connection($self->app->logger_instance);
        }
    };

    if ($dbh) {
        $dbh_cache->{dbh} = $dbh;
        $dbh_cache->{expires_at} = $now + 30;  # 30-second TTL
    }

    return $dbh;
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

    # Update business metrics (with caching)
    $self->_update_business_metrics($p);

    # Render Prometheus format
    $self->res->headers->content_type('text/plain; version=0.0.4; charset=utf-8');
    $self->render(text => $p->format);
}

sub _update_db_status ($self, $p) {
    my $connected = 0;
    my $dbh;
    eval {
        $dbh = $self->_get_cached_dbh();
        if ($dbh) {
            $connected = 1;
        }
    };
    if ($@) {
        $self->app->logger_instance->warn("Database status check failed: $@");
    }
    $p->set('app_database_connection_status', $connected);
}

sub _update_business_metrics ($self, $p) {
    my $now = time();

    # Check if cached metrics are still valid
    if ($now < $business_metrics_cache->{expires_at} && %{$business_metrics_cache->{data}}) {
        my $cached = $business_metrics_cache->{data};

        # Apply cached values to Prometheus
        if (exists $cached->{articles}) {
            for my $status (keys %{$cached->{articles}}) {
                $p->set('app_articles_total', $cached->{articles}{$status}, { status => $status });
            }
        }
        $p->set('app_media_files_total', $cached->{media_count} || 0);
        $p->set('app_tags_total', $cached->{tag_count} || 0);
        return;
    }

    # Fetch fresh metrics from database
    my $dbh;
    eval {
        $dbh = $self->_get_cached_dbh();
        return unless $dbh;

        my $metrics_data = {};

        # Count articles by status
        my $sth = $dbh->prepare("SELECT is_published, COUNT(*) FROM articles GROUP BY is_published");
        $sth->execute();
        $metrics_data->{articles} = {};
        while (my ($is_published, $count) = $sth->fetchrow_array()) {
            my $status = $is_published ? 'published' : 'draft';
            $metrics_data->{articles}{$status} = $count;
            $p->set('app_articles_total', $count, { status => $status });
        }
        $sth->finish();

        # Count media files
        $sth = $dbh->prepare("SELECT COUNT(*) FROM media");
        $sth->execute();
        my ($media_count) = $sth->fetchrow_array();
        $metrics_data->{media_count} = $media_count || 0;
        $p->set('app_media_files_total', $metrics_data->{media_count});
        $sth->finish();

        # Count tags
        $sth = $dbh->prepare("SELECT COUNT(*) FROM tags");
        $sth->execute();
        my ($tag_count) = $sth->fetchrow_array();
        $metrics_data->{tag_count} = $tag_count || 0;
        $p->set('app_tags_total', $metrics_data->{tag_count});
        $sth->finish();

        # Update cache
        $business_metrics_cache->{data} = $metrics_data;
        $business_metrics_cache->{expires_at} = $now + 60;  # 60-second TTL
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
