package HelloPerld::Model::Radio;

use strict;
use warnings;

our $VERSION = '1.0.0';

use parent 'HelloPerld::Model::Base';
use Carp qw(croak);

=head1 NAME

HelloPerld::Model::Radio - Model for radio configuration management

=head1 SYNOPSIS

    my $radio = HelloPerld::Model::Radio->new(
        db_config => $db_config,
        logger => $logger
    );

    my $playlist_url = $radio->get_playlist_url();
    $radio->set_playlist_url($url, $user_id);

=head1 DESCRIPTION

This model handles radio configuration storage and retrieval, primarily
for managing the .m3u playlist URL configuration.

=cut

=head2 get_config

Get a configuration value by key.

    my $value = $radio->get_config('playlist_url');

Returns the config value or undef if not found.

=cut

sub get_config {
    my ($self, $key) = @_;
    croak "Configuration key is required" unless defined $key;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sth = $dbh->prepare(q{
        SELECT config_value, description, updated_at
        FROM radio_config
        WHERE config_key = ?
    });

    $sth->execute($key);
    my $row = $sth->fetchrow_hashref;

    return $row ? $row->{config_value} : undef;
}

=head2 get_all_config

Get all configuration entries.

    my $configs = $radio->get_all_config();

Returns an arrayref of hashrefs containing all configuration entries.

=cut

sub get_all_config {
    my ($self) = @_;

    my $dbh = $self->_get_dbh();
    return [] unless $dbh;

    my $sth = $dbh->prepare(q{
        SELECT config_key, config_value, description, updated_by, updated_at
        FROM radio_config
        ORDER BY config_key
    });

    $sth->execute();

    my @configs;
    while (my $row = $sth->fetchrow_hashref) {
        push @configs, $row;
    }

    return \@configs;
}

=head2 set_config

Set a configuration value.

    $radio->set_config('playlist_url', $url, $user_id);

Returns 1 on success, dies on failure.

=cut

sub set_config {
    my ($self, $key, $value, $user_id) = @_;
    croak "Configuration key is required" unless defined $key;
    croak "Configuration value is required" unless defined $value;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    # Use upsert (INSERT ... ON CONFLICT UPDATE) to handle both insert and update
    my $sth = $dbh->prepare(q{
        INSERT INTO radio_config (config_key, config_value, updated_by)
        VALUES (?, ?, ?)
        ON CONFLICT (config_key)
        DO UPDATE SET
            config_value = EXCLUDED.config_value,
            updated_by = EXCLUDED.updated_by,
            updated_at = CURRENT_TIMESTAMP
    });

    $sth->execute($key, $value, $user_id);

    $self->_log_info("Radio config updated: $key by user " . ($user_id // 'system'));

    return 1;
}

=head2 get_playlist_url

Get the current playlist URL.

    my $url = $radio->get_playlist_url();

Convenience method for getting the playlist_url config value.

=cut

sub get_playlist_url {
    my ($self) = @_;
    return $self->get_config('playlist_url') || '';
}

=head2 set_playlist_url

Set the playlist URL.

    $radio->set_playlist_url($url, $user_id);

Convenience method for setting the playlist_url config value.
Validates that the URL is not empty.

=cut

sub set_playlist_url {
    my ($self, $url, $user_id) = @_;
    croak "Playlist URL cannot be empty" unless defined $url && length($url) > 0;

    # Basic URL validation
    unless ($url =~ m{^(?:https?://|/)} || $url =~ m{\.m3u8?$}) {
        croak "Invalid playlist URL format";
    }

    return $self->set_config('playlist_url', $url, $user_id);
}

=head2 get_total_duration

Get the total duration of the playlist in seconds.

    my $duration = $radio->get_total_duration();

Returns the duration or undef if not set.

=cut

sub get_total_duration {
    my ($self) = @_;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sth = $dbh->prepare(q{
        SELECT total_duration
        FROM radio_config
        WHERE config_key = 'playlist_url'
    });

    $sth->execute();
    my $row = $sth->fetchrow_hashref;

    return $row ? $row->{total_duration} : undef;
}

=head2 set_total_duration

Set the total duration of the playlist.

    $radio->set_total_duration($duration_in_seconds);

Returns 1 on success.

=cut

sub set_total_duration {
    my ($self, $duration) = @_;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sth = $dbh->prepare(q{
        UPDATE radio_config
        SET total_duration = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE config_key = 'playlist_url'
    });

    $sth->execute($duration);

    $self->_log_info("Radio total duration updated: " . ($duration // 'NULL'));

    return 1;
}

=head2 get_playlist_metadata

Get playlist metadata including URL, duration, and update time.

    my $metadata = $radio->get_playlist_metadata();

Returns hashref with: url, total_duration, updated_at, or undef if not configured.

=cut

sub get_playlist_metadata {
    my ($self) = @_;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sth = $dbh->prepare(q{
        SELECT config_value as url, total_duration, updated_at
        FROM radio_config
        WHERE config_key = 'playlist_url'
    });

    $sth->execute();
    my $row = $sth->fetchrow_hashref;

    return $row;
}

=head2 delete_config

Delete a configuration entry.

    $radio->delete_config('some_key');

Returns 1 on success.

=cut

sub delete_config {
    my ($self, $key) = @_;
    croak "Configuration key is required" unless defined $key;

    my $dbh = $self->_get_dbh();
    return undef unless $dbh;

    my $sth = $dbh->prepare(q{
        DELETE FROM radio_config WHERE config_key = ?
    });

    $sth->execute($key);

    $self->_log_info("Radio config deleted: $key");

    return 1;
}

1;

=head1 AUTHOR

TheBoosh.Zone Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025, TheBoosh.Zone

=cut
