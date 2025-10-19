package HelloPerld::Model::Media;
use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Database::Postgres;

sub new {
    my ($class, %args) = @_;

    my $self = {
        logger => $args{logger},
    };

    return bless $self, $class;
}

sub create {
    my ($self, %params) = @_;

    # Convert named parameters to hashref if not already a hashref
    my $media_data;
    if (ref($_[1]) eq 'HASH') {
        $media_data = $_[1];
    } else {
        $media_data = \%params;
    }

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $result;
    eval {
        my $sql = q{
            INSERT INTO media (
                filename, original_filename, filepath, mime_type,
                file_size, width, height, uploaded_by, alt_text, caption
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id, filename, original_filename, filepath, mime_type,
                      file_size, width, height, uploaded_by, created_at,
                      alt_text, caption
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $media_data->{filename},
            $media_data->{original_filename},
            $media_data->{filepath},
            $media_data->{mime_type},
            $media_data->{file_size},
            $media_data->{width},
            $media_data->{height},
            $media_data->{uploaded_by},
            $media_data->{alt_text},
            $media_data->{caption}
        );

        $result = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        warn "Error creating media record: $@";
        return undef;
    }

    return $result;
}

sub get_all {
    my ($self, %params) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $page = $params{page} || 1;
    my $limit = $params{limit} || 20;
    my $offset = ($page - 1) * $limit;

    my ($results, $total_count);
    eval {
        # Build WHERE clause for filtering
        my @where_conditions;
        my @where_params;

        if ($params{mime_type}) {
            push @where_conditions, "mime_type = ?";
            push @where_params, $params{mime_type};
        }

        if ($params{search}) {
            push @where_conditions, "(original_filename ILIKE ? OR alt_text ILIKE ? OR caption ILIKE ?)";
            my $search_term = '%' . $params{search} . '%';
            push @where_params, $search_term, $search_term, $search_term;
        }

        my $where_clause = @where_conditions ? "WHERE " . join(" AND ", @where_conditions) : "";

        # Get total count
        my $count_sql = "SELECT COUNT(*) FROM media $where_clause";
        my $count_sth = $dbh->prepare($count_sql);
        $count_sth->execute(@where_params);
        ($total_count) = $count_sth->fetchrow_array();
        $count_sth->finish();

        # Get paginated results
        my $sql = qq{
            SELECT id, filename, original_filename, filepath, mime_type,
                   file_size, width, height, uploaded_by, created_at,
                   alt_text, caption
            FROM media
            $where_clause
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute(@where_params, $limit, $offset);

        $results = [];
        while (my $row = $sth->fetchrow_hashref()) {
            push @$results, $row;
        }
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        warn "Error fetching media: $@";
        return undef;
    }

    # For simple mode (used by tests), return just the array
    # For paginated mode (used by controllers), return pagination structure
    if ($params{simple}) {
        return $results;
    }

    # Calculate pagination info
    my $total_pages = int(($total_count + $limit - 1) / $limit);
    my $has_next = $page < $total_pages;
    my $has_prev = $page > 1;

    return {
        media => $results,
        pagination => {
            current_page => $page,
            total_pages => $total_pages,
            total_count => $total_count,
            per_page => $limit,
            has_next => $has_next ? 1 : 0,
            has_prev => $has_prev ? 1 : 0
        }
    };
}

sub get_by_id {
    my ($self, $id) = @_;

    return undef unless $id;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $result;
    eval {
        my $sql = q{
            SELECT id, filename, original_filename, filepath, mime_type,
                   file_size, width, height, uploaded_by, created_at,
                   alt_text, caption
            FROM media
            WHERE id = ?
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute($id);
        $result = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        warn "Error fetching media by ID: $@";
        return undef;
    }

    return $result;
}

sub update {
    my ($self, $id, %params) = @_;

    # Convert named parameters to hashref if not already a hashref
    my $media_data;
    if (ref($_[2]) eq 'HASH') {
        $media_data = $_[2];
    } else {
        $media_data = \%params;
    }

    return undef unless $id;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $result;
    eval {
        my $sql = q{
            UPDATE media
            SET alt_text = ?, caption = ?
            WHERE id = ?
            RETURNING id, filename, original_filename, filepath, mime_type,
                      file_size, width, height, uploaded_by, created_at,
                      alt_text, caption
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $media_data->{alt_text},
            $media_data->{caption},
            $id
        );

        $result = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        warn "Error updating media: $@";
        return undef;
    }

    return $result;
}

sub delete {
    my ($self, $id) = @_;

    return undef unless $id;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $result;
    eval {
        # First get the file info so we can delete the file
        my $select_sql = q{SELECT filepath FROM media WHERE id = ?};
        my $select_sth = $dbh->prepare($select_sql);
        $select_sth->execute($id);
        $result = $select_sth->fetchrow_hashref();
        $select_sth->finish();

        # Delete from database
        my $delete_sql = q{DELETE FROM media WHERE id = ?};
        my $delete_sth = $dbh->prepare($delete_sql);
        $delete_sth->execute($id);
        $delete_sth->finish();

        $dbh->disconnect();
    };

    if ($@) {
        warn "Error deleting media: $@";
        return undef;
    }

    return $result;
}

sub get_count {
    my ($self, %params) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return 0 unless $dbh;

    my $count;
    eval {
        # Build WHERE clause for filtering
        my @where_conditions;
        my @where_params;

        if ($params{type}) {
            push @where_conditions, "mime_type LIKE ?";
            push @where_params, $params{type} . '%';
        }

        if ($params{search}) {
            push @where_conditions, "(original_filename ILIKE ? OR alt_text ILIKE ? OR caption ILIKE ?)";
            my $search_term = '%' . $params{search} . '%';
            push @where_params, $search_term, $search_term, $search_term;
        }

        my $where_clause = @where_conditions ? "WHERE " . join(" AND ", @where_conditions) : "";

        my $sql = "SELECT COUNT(*) FROM media $where_clause";
        my $sth = $dbh->prepare($sql);
        $sth->execute(@where_params);
        ($count) = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get media count: $@");
        }
        $dbh->disconnect() if $dbh;
        return 0;
    }

    return $count || 0;
}

1;

__END__

=head1 NAME

HelloPerld::Model::Media - Media file database operations

=head1 SYNOPSIS

    use HelloPerld::Model::Media;

    # Create media record
    my $media = HelloPerld::Model::Media->create(
        filename => 'abc123.jpg',
        original_filename => 'photo.jpg',
        filepath => '2025/10/abc123.jpg',
        mime_type => 'image/jpeg',
        file_size => 123456,
        width => 1920,
        height => 1080,
        uploaded_by => 1
    );

    # Get all media with pagination
    my $result = HelloPerld::Model::Media->get_all(page => 1, limit => 20);

    # Get by ID
    my $media = HelloPerld::Model::Media->get_by_id(1);

    # Update alt text and caption
    my $updated = HelloPerld::Model::Media->update(1,
        alt_text => 'Description',
        caption => 'Photo caption'
    );

    # Delete media
    my $deleted = HelloPerld::Model::Media->delete(1);

=head1 DESCRIPTION

This module provides database operations for managing media file metadata.

=cut
