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
    # Note: Authentication is handled by the /admin route middleware

    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }

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

        # Calculate and store total duration for sync
        # Wrap in eval to prevent duration calculation errors from failing the entire update
        my $total_duration;
        eval {
            $total_duration = $self->_calculate_playlist_duration($playlist_url);
        };

        if ($@) {
            $self->app->logger_instance->warn("Duration calculation failed: $@");
            $total_duration = undef;
        }

        if (defined $total_duration) {
            $radio_model->set_total_duration($total_duration);
            $self->app->logger_instance->info("Calculated playlist duration: $total_duration seconds");
        } else {
            # For live streams or if duration can't be determined, set to NULL
            $radio_model->set_total_duration(undef);
            $self->app->logger_instance->info("Playlist duration set to NULL (live stream or unable to calculate)");
        }
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

=head2 delete_playlist

Admin endpoint to delete the current playlist configuration.

DELETE /api/admin/radio/playlist

Requires authentication.

=cut

sub delete_playlist ($self) {
    # Note: Authentication is handled by the /admin route middleware

    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }

    # Get user from session
    my $user_id = $self->session('admin_user_id');

    unless ($user_id) {
        return error_response($self, 'unauthorized', 'Authentication required',
            code => 'AUTH001'
        );
    }

    my $radio_model = HelloPerld::Model::Radio->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    eval {
        $radio_model->delete_config('playlist_url');
    };

    if ($@) {
        $self->app->logger_instance->error("Failed to delete playlist: $@");
        return error_response($self, 'server_error', 'Failed to delete playlist configuration',
            code => 'DB002'
        );
    }

    $self->app->logger_instance->info("Playlist deleted by user $user_id");

    return $self->render(json => {
        success => 1,
        message => 'Playlist deleted successfully'
    });
}

=head2 get_sync_info

Public endpoint to get synchronization information for the radio stream.

GET /api/radio/sync-info

Returns server time, playlist metadata, and calculated playback position.

=cut

sub get_sync_info ($self) {
    my $radio_model = HelloPerld::Model::Radio->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # Get playlist metadata
    my $metadata = $radio_model->get_playlist_metadata();

    unless ($metadata && $metadata->{url}) {
        return $self->render(json => {
            success => 1,
            sync_info => {
                configured => 0,
                message => 'No playlist configured'
            }
        });
    }

    # Get current server time
    my $server_time = time();

    # Parse updated_at timestamp to epoch
    my $updated_at = $metadata->{updated_at};
    my $start_epoch;

    if ($updated_at =~ /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
        # PostgreSQL timestamp format: YYYY-MM-DD HH:MM:SS
        require Time::Local;
        $start_epoch = Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1);
    } else {
        $self->app->logger_instance->error("Failed to parse updated_at timestamp: $updated_at");
        return error_response($self, 'server_error', 'Failed to parse playlist timestamp',
            code => 'SYNC001'
        );
    }

    my $total_duration = $metadata->{total_duration};
    my $playlist_url = $metadata->{url};
    my $is_hls = $playlist_url =~ /\.m3u8$/i;

    # Calculate elapsed time since playlist was uploaded
    my $elapsed = $server_time - $start_epoch;

    $self->app->logger_instance->info("Sync calculation: elapsed=$elapsed, total_duration=" . ($total_duration // 'undef') . ", is_hls=$is_hls");

    # Calculate current position
    my $current_position;
    my $current_track_index = 0;

    if (defined $total_duration && $total_duration > 0) {
        # Calculate position within loop
        $current_position = $elapsed % $total_duration;

        $self->app->logger_instance->info("Position after modulo: $current_position");

        if ($is_hls) {
            # For HLS VOD streams, current_position is already correct
            # It represents the position within the single looping stream
            $current_track_index = 0;
        } else {
            # For regular playlists, fetch and parse tracks to find current track
            my $tracks = $self->_fetch_and_parse_playlist($playlist_url);

            if ($tracks && @$tracks) {
                my $accumulated_time = 0;

                for (my $i = 0; $i < @$tracks; $i++) {
                    my $track_duration = $tracks->[$i]->{duration};
                    $track_duration = 0 if $track_duration < 0; # Handle unknown durations

                    if ($current_position < $accumulated_time + $track_duration) {
                        $current_track_index = $i;
                        $current_position = $current_position - $accumulated_time;
                        last;
                    }

                    $accumulated_time += $track_duration;
                }
            }
        }
    } else {
        # Live stream or unknown duration - just use elapsed time
        $current_position = $elapsed;
    }

    return $self->render(json => {
        success => 1,
        sync_info => {
            configured => 1,
            server_time => $server_time,
            playlist_start_time => $start_epoch,
            playlist_url => $playlist_url,
            total_duration => $total_duration,
            elapsed_time => $elapsed,
            current_position => $current_position,
            current_track_index => $current_track_index,
            is_hls => $is_hls ? 1 : 0
        }
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

=head2 _calculate_playlist_duration

Internal method to calculate total duration of a playlist.

Returns duration in seconds, or undef for live streams or if unable to calculate.

=cut

sub _calculate_playlist_duration ($self, $url) {
    my $is_hls = $url =~ /\.m3u8$/i;

    if ($is_hls) {
        # For HLS streams, try to fetch and parse the manifest
        my $ua = Mojo::UserAgent->new;
        $ua->max_redirects(3);
        $ua->connect_timeout(5);
        $ua->request_timeout(15);

        my $tx = $ua->get($url);

        if (my $err = $tx->error) {
            $self->app->logger_instance->error("Failed to fetch HLS manifest for duration: " . $err->{message});
            return undef;
        }

        unless ($tx->res->is_success) {
            $self->app->logger_instance->error("HLS manifest fetch failed: HTTP " . $tx->res->code);
            return undef;
        }

        my $content = $tx->res->body;

        $self->app->logger_instance->info("HLS manifest fetched, checking for duration...");

        # Parse HLS manifest for duration
        # Check if this is a master playlist (contains #EXT-X-STREAM-INF) or media playlist
        if ($content =~ /#EXT-X-STREAM-INF/) {
            # This is a master playlist - need to fetch the actual media playlist
            $self->app->logger_instance->info("Detected HLS master playlist, looking for media playlist...");

            # Extract first media playlist URL
            my @lines = split /\r?\n/, $content;
            for (my $i = 0; $i < @lines; $i++) {
                if ($lines[$i] =~ /^#EXT-X-STREAM-INF/) {
                    # Next line should be the URL
                    if ($i + 1 < @lines && $lines[$i + 1] !~ /^#/) {
                        my $media_url = $lines[$i + 1];

                        # Make URL absolute if relative
                        unless ($media_url =~ /^https?:/) {
                            my $base_url = $url;
                            $base_url =~ s/[^\/]+$//;  # Remove filename
                            $media_url = $base_url . $media_url;
                        }

                        $self->app->logger_instance->info("Found media playlist: $media_url");

                        # Recursively call this function with the media playlist URL
                        return $self->_calculate_playlist_duration($media_url);
                    }
                }
            }

            $self->app->logger_instance->warn("Could not find media playlist in master playlist");
            return undef;
        }

        # Look for #EXT-X-ENDLIST to determine if VOD
        if ($content =~ /#EXT-X-ENDLIST/) {
            # VOD stream - has an end
            my $total_duration = 0;
            my @lines = split /\r?\n/, $content;

            for my $line (@lines) {
                if ($line =~ /^#EXTINF:([\d.]+)/) {
                    $total_duration += $1;
                }
            }

            if ($total_duration > 0) {
                $self->app->logger_instance->info("Calculated HLS duration: $total_duration seconds");
                return int($total_duration);
            }
        }

        # Live stream or unable to determine - return undef
        $self->app->logger_instance->info("HLS stream appears to be live or duration unknown");
        return undef;

    } else {
        # Regular M3U playlist
        my $tracks = $self->_fetch_and_parse_playlist($url);

        unless ($tracks && @$tracks) {
            $self->app->logger_instance->warn("Failed to fetch/parse playlist for duration calculation");
            return undef;
        }

        my $total_duration = 0;
        my $has_unknown_durations = 0;

        for my $track (@$tracks) {
            my $duration = $track->{duration};

            if ($duration && $duration > 0) {
                $total_duration += $duration;
            } else {
                $has_unknown_durations = 1;
            }
        }

        if ($has_unknown_durations) {
            $self->app->logger_instance->warn("Some tracks have unknown durations, total may be inaccurate");
        }

        return $total_duration > 0 ? $total_duration : undef;
    }
}

1;

=head1 AUTHOR

TheBoosh.Zone Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025, TheBoosh.Zone

=cut
