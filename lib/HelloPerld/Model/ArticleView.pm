package HelloPerld::Model::ArticleView;

use strict;
use warnings;

our $VERSION = '1.0.0';

use parent 'HelloPerld::Model::Base';

=head1 NAME

HelloPerld::Model::ArticleView - Model for tracking article viewership

=head1 DESCRIPTION

Handles database operations for article view tracking, including storing views
and querying view statistics by article slug or IP address.

=cut

=head2 create($slug, $ip_address)

Insert a new article view record.

Parameters:
    $slug - Article slug
    $ip_address - Client IP address (IPv4 or IPv6)

Returns:
    $id - Inserted record ID on success
    undef - On failure

=cut

sub create {
    my ($self, $slug, $ip_address) = @_;

    return undef unless $slug && $ip_address;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sql = q{
        INSERT INTO article_views (article_slug, ip_address, viewed_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        RETURNING id
    };

    my $id;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug, $ip_address);
        my ($inserted_id) = $sth->fetchrow_array();
        $sth->finish();
        $id = $inserted_id;
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to create article view: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $id;
}

=head2 get_views_by_slug($slug, $limit, $offset)

Get view records for a specific article.

Parameters:
    $slug - Article slug
    $limit - Maximum number of records to return (default: 100)
    $offset - Number of records to skip (default: 0)

Returns:
    \@views - Arrayref of view records (hashrefs) on success
    undef - On failure

=cut

sub get_views_by_slug {
    my ($self, $slug, $limit, $offset) = @_;

    return undef unless $slug;

    $limit = $limit || 100;
    $offset = $offset || 0;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sql = q{
        SELECT id, article_slug, ip_address, viewed_at
        FROM article_views
        WHERE article_slug = ?
        ORDER BY viewed_at DESC
        LIMIT ? OFFSET ?
    };

    my $views;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug, $limit, $offset);
        my @views_array;
        while (my $row = $sth->fetchrow_hashref()) {
            push @views_array, $row;
        }
        $sth->finish();
        $views = \@views_array;
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get views by slug: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $views;
}

=head2 get_views_by_ip($ip, $limit, $offset)

Get view records for a specific IP address.

Parameters:
    $ip - IP address
    $limit - Maximum number of records to return (default: 100)
    $offset - Number of records to skip (default: 0)

Returns:
    \@views - Arrayref of view records (hashrefs) on success
    undef - On failure

=cut

sub get_views_by_ip {
    my ($self, $ip, $limit, $offset) = @_;

    return undef unless $ip;

    $limit = $limit || 100;
    $offset = $offset || 0;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sql = q{
        SELECT id, article_slug, ip_address, viewed_at
        FROM article_views
        WHERE ip_address = ?
        ORDER BY viewed_at DESC
        LIMIT ? OFFSET ?
    };

    my $views;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($ip, $limit, $offset);
        my @views_array;
        while (my $row = $sth->fetchrow_hashref()) {
            push @views_array, $row;
        }
        $sth->finish();
        $views = \@views_array;
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get views by IP: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $views;
}

=head2 get_unique_ips_by_slug($slug)

Count unique IP addresses that viewed a specific article.

Parameters:
    $slug - Article slug

Returns:
    $count - Number of unique IPs on success
    undef - On failure

=cut

sub get_unique_ips_by_slug {
    my ($self, $slug) = @_;

    return undef unless $slug;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sql = q{
        SELECT COUNT(DISTINCT ip_address)
        FROM article_views
        WHERE article_slug = ?
    };

    my $count;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug);
        ($count) = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get unique IPs by slug: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $count || 0;
}

=head2 get_total_views_by_slug($slug)

Get total view count for a specific article.

Parameters:
    $slug - Article slug

Returns:
    $count - Total view count on success
    undef - On failure

=cut

sub get_total_views_by_slug {
    my ($self, $slug) = @_;

    return undef unless $slug;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sql = q{
        SELECT COUNT(*)
        FROM article_views
        WHERE article_slug = ?
    };

    my $count;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug);
        ($count) = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get total views by slug: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $count || 0;
}

1;

__END__

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
