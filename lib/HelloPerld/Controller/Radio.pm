package HelloPerld::Controller::Radio;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Model::Radio;
use HelloPerld::Util::ErrorResponse qw(error_response);
use Mojo::UserAgent;

=head1 NAME

HelloPerld::Controller::Radio - Controller for radio streaming configuration

=head1 DESCRIPTION

Handles radio playlist configuration endpoints. Public endpoint for fetching
current playlist, admin endpoints for managing configuration.

=cut

=head2 get_playlist

Public endpoint to get current playlist configuration.

GET /api/radio/playlist

Returns the playlist URL and optionally fetches and parses the .m3u file.

=cut

sub get_playlist ($self) {
    my $radio_model = HelloPerld::Model::Radio->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    my $playlist_url = $radio_model->get_playlist_url();

    unless ($playlist_url) {
        return $self->render(json => {
            success => 1,
            playlist => {
                url => '',
                tracks => [],
                message => 'No playlist configured'
            }
        });
    }

    # If client requests parsed tracks, fetch and parse the .m3u
    # BUT: Do not parse M3U8 HLS streams - they should be handled by HLS.js on the frontend
    my $parse = $self->param('parse') // 0;
    my $is_hls = $playlist_url =~ /\.m3u8$/i;

    if ($parse && !$is_hls) {
        # Only parse regular M3U playlists, not HLS streams
        my $tracks = $self->_fetch_and_parse_playlist($playlist_url);

        if ($tracks) {
            return $self->render(json => {
                success => 1,
                playlist => {
                    url => $playlist_url,
                    tracks => $tracks
                }
            });
        } else {
            # Failed to fetch/parse, but still return the URL
            return $self->render(json => {
                success => 1,
                playlist => {
                    url => $playlist_url,
                    tracks => [],
                    error => 'Failed to fetch or parse playlist'
                }
            });
        }
    } elsif ($parse && $is_hls) {
        # For HLS streams, return URL with a single "track" entry
        # The frontend will handle HLS manifest parsing
        return $self->render(json => {
            success => 1,
            playlist => {
                url => $playlist_url,
                tracks => [{
                    title => 'HLS Stream',
                    artist => 'Live Stream',
                    url => $playlist_url,
                    duration => -1
                }],
                is_hls => 1
            }
        });
    }

    # Just return the URL without parsing
    return $self->render(json => {
        success => 1,
        playlist => {
            url => $playlist_url
        }
    });
}

=head2 get_config

Admin endpoint to get current radio configuration.

GET /api/admin/radio/config

Requires authentication.

=cut

sub get_config ($self) {
    my $radio_model = HelloPerld::Model::Radio->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    my $configs = $radio_model->get_all_config();

    return $self->render(json => {
        success => 1,
        config => $configs
    });
}

=head2 update_playlist

Admin endpoint to update playlist URL.

POST /api/admin/radio/playlist

Requires authentication and CSRF token.

Request body:
{
    "playlist_url": "https://example.com/playlist.m3u"
}

=cut

sub update_playlist ($self) {
    # Get user from session
    my $user_id = $self->session('admin_user_id');

    unless ($user_id) {
        return error_response($self, 'unauthorized', 'Authentication required',
            code => 'AUTH001'
        );
    }

    # Get and validate request body
    my $json = $self->req->json;

    unless ($json && ref $json eq 'HASH') {
        return error_response($self, 'validation', 'Invalid JSON request body',
            code => 'VAL001'
        );
    }

    my $playlist_url = $json->{playlist_url};

    unless (defined $playlist_url && length($playlist_url) > 0) {
        return error_response($self, 'validation', 'Playlist URL is required',
            code => 'VAL002',
            details => { field => 'playlist_url' }
        );
    }

    # Basic URL validation
    unless ($playlist_url =~ m{^(?:https?://|/)} || $playlist_url =~ m{\.m3u8?$}i) {
        return error_response($self, 'validation',
            'Invalid playlist URL format. Must be HTTP(S) URL or local path ending in .m3u or .m3u8',
            code => 'VAL003',
            details => { field => 'playlist_url', value => $playlist_url }
        );
    }

    # Optional: Validate that the URL is accessible (for HTTP URLs)
    if ($playlist_url =~ m{^https?://}) {
        my $validation_result = $self->_validate_playlist_url($playlist_url);
        unless ($validation_result->{valid}) {
            return error_response($self, 'validation',
                'Playlist URL is not accessible: ' . $validation_result->{error},
                code => 'VAL004',
                details => { field => 'playlist_url', value => $playlist_url }
            );
        }
    }

    # Update configuration
    my $radio_model = HelloPerld::Model::Radio->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    eval {
        $radio_model->set_playlist_url($playlist_url, $user_id);
    };

    if ($@) {
        $self->app->logger_instance->error("Failed to update playlist URL: $@");
        return error_response($self, 'server_error', 'Failed to update playlist configuration',
            code => 'DB001'
        );
    }

    $self->app->logger_instance->info("Playlist URL updated by user $user_id: $playlist_url");

    return $self->render(json => {
        success => 1,
        message => 'Playlist URL updated successfully',
        playlist_url => $playlist_url
    });
}

=head2 _validate_playlist_url

Internal method to validate that a playlist URL is accessible.

Returns hashref: { valid => 1/0, error => 'message' }

=cut

sub _validate_playlist_url ($self, $url) {
    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(3);
    $ua->connect_timeout(5);
    $ua->request_timeout(10);

    my $tx = $ua->head($url);

    if (my $err = $tx->error) {
        return {
            valid => 0,
            error => $err->{message}
        };
    }

    # Check if response is successful
    unless ($tx->res->is_success) {
        return {
            valid => 0,
            error => 'HTTP ' . $tx->res->code . ' ' . $tx->res->message
        };
    }

    return { valid => 1 };
}

=head2 _fetch_and_parse_playlist

Internal method to fetch and parse a .m3u playlist file.

Returns arrayref of track hashrefs or undef on error.

=cut

sub _fetch_and_parse_playlist ($self, $url) {
    my $content;

    if ($url =~ m{^https?://}) {
        # Fetch from HTTP(S)
        my $ua = Mojo::UserAgent->new;
        $ua->max_redirects(3);
        $ua->connect_timeout(5);
        $ua->request_timeout(15);

        my $tx = $ua->get($url);

        if (my $err = $tx->error) {
            $self->app->logger_instance->error("Failed to fetch playlist: " . $err->{message});
            return undef;
        }

        unless ($tx->res->is_success) {
            $self->app->logger_instance->error("Playlist fetch failed: HTTP " . $tx->res->code);
            return undef;
        }

        $content = $tx->res->body;
    } else {
        # Read from local file (relative to app root or absolute path)
        my $file_path = $url;
        $file_path =~ s{^/}{}; # Remove leading slash for relative path

        unless (-f $file_path) {
            $self->app->logger_instance->error("Playlist file not found: $file_path");
            return undef;
        }

        eval {
            open my $fh, '<', $file_path or die "Cannot open file: $!";
            local $/;
            $content = <$fh>;
            close $fh;
        };

        if ($@) {
            $self->app->logger_instance->error("Failed to read playlist file: $@");
            return undef;
        }
    }

    # Parse M3U format
    return $self->_parse_m3u($content);
}

=head2 _parse_m3u

Internal method to parse M3U playlist content.

Returns arrayref of track hashrefs:
[
    { title => 'Track Title', artist => 'Artist Name', url => 'http://...', duration => 123 },
    ...
]

=cut

sub _parse_m3u ($self, $content) {
    my @tracks;
    my $current_track = {};

    my @lines = split /\r?\n/, $content;

    for my $line (@lines) {
        $line =~ s/^\s+|\s+$//g; # Trim whitespace
        next unless length $line;
        next if $line =~ /^#EXTM3U/; # Skip header

        if ($line =~ /^#EXTINF:(-?\d+),(.*)$/) {
            # Extended info line
            $current_track->{duration} = $1;
            my $info = $2;

            # Try to parse "Artist - Title" format
            if ($info =~ /^(.+?)\s*-\s*(.+)$/) {
                $current_track->{artist} = $1;
                $current_track->{title} = $2;
            } else {
                $current_track->{title} = $info;
                $current_track->{artist} = 'Unknown Artist';
            }
        } elsif ($line =~ /^#/) {
            # Other comment/metadata line, skip
            next;
        } else {
            # This is a URL line
            $current_track->{url} = $line;

            # Add track to list if we have at least a URL
            if ($current_track->{url}) {
                $current_track->{title} //= 'Unknown Track';
                $current_track->{artist} //= 'Unknown Artist';
                $current_track->{duration} //= -1;

                push @tracks, { %$current_track };
            }

            # Reset for next track
            $current_track = {};
        }
    }

    return \@tracks;
}

1;

=head1 AUTHOR

TheBoosh.Zone Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025, TheBoosh.Zone

=cut
