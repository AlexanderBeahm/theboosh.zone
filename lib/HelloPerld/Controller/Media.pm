package HelloPerld::Controller::Media;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use strict;
use warnings;

use HelloPerld::Model::Media;
use Imager;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use MIME::Types;
use Digest::SHA qw(sha256_hex);
use Time::Local;

# Upload media file
sub upload ($self) {
    my $upload = $self->req->upload('file');

    unless ($upload) {
        return $self->render(json => {
            success => 0,
            error => 'No file uploaded'
        }, status => 400);
    }

    # Get configuration
    my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
    my $max_size = $ENV{UPLOAD_MAX_SIZE} || 5242880; # 5MB default
    my $allowed_types = $ENV{UPLOAD_ALLOWED_TYPES} || 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml';

    my @allowed_mime_types = split /,/, $allowed_types;
    my %allowed_types_hash = map { $_ => 1 } @allowed_mime_types;

    # Validate file size
    my $file_size = $upload->size;
    if ($file_size > $max_size) {
        return $self->render(json => {
            success => 0,
            error => "File size exceeds maximum allowed size of " . int($max_size / 1048576) . "MB"
        }, status => 400);
    }

    # Get MIME type
    my $mime_type = $upload->headers->content_type;

    # Validate MIME type
    unless ($allowed_types_hash{$mime_type}) {
        return $self->render(json => {
            success => 0,
            error => "File type not allowed. Allowed types: " . join(', ', @allowed_mime_types)
        }, status => 400);
    }

    # Get original filename
    my $original_filename = $upload->filename;

    # Generate unique filename
    my ($name, $path, $ext) = fileparse($original_filename, qr/\.[^.]*/);
    my $unique_id = sha256_hex($original_filename . time() . rand());
    my $unique_filename = substr($unique_id, 0, 16) . lc($ext);

    # Create date-based directory structure (YYYY/MM)
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $date_path = sprintf("%04d/%02d", $year, $mon);
    my $full_dir = "$uploads_dir/$date_path";

    # Create directory if it doesn't exist
    unless (-d $full_dir) {
        eval {
            make_path($full_dir, { chmod => 0755 });
        };
        if ($@) {
            return $self->render(json => {
                success => 0,
                error => "Failed to create upload directory: $@"
            }, status => 500);
        }
    }

    # Full file path
    my $filepath = "$date_path/$unique_filename";
    my $full_filepath = "$uploads_dir/$filepath";

    # Save the uploaded file
    eval {
        $upload->move_to($full_filepath);
    };
    if ($@) {
        return $self->render(json => {
            success => 0,
            error => "Failed to save file: $@"
        }, status => 500);
    }

    # Get image dimensions if it's an image
    my ($width, $height);
    if ($mime_type =~ /^image\// && $mime_type ne 'image/svg+xml') {
        my $img = Imager->new();
        if ($img->read(file => $full_filepath)) {
            $width = $img->getwidth();
            $height = $img->getheight();
        }
    }

    # Get uploaded_by from session
    my $uploaded_by = $self->session('admin_user_id');

    # Get optional metadata from request
    my $alt_text = $self->param('alt_text');
    my $caption = $self->param('caption');

    # Create media record in database
    my $media = HelloPerld::Model::Media->create(
        filename => $unique_filename,
        original_filename => $original_filename,
        filepath => $filepath,
        mime_type => $mime_type,
        file_size => $file_size,
        width => $width,
        height => $height,
        uploaded_by => $uploaded_by,
        alt_text => $alt_text,
        caption => $caption
    );

    unless ($media) {
        # Clean up the uploaded file if database insert fails
        unlink $full_filepath;
        return $self->render(json => {
            success => 0,
            error => 'Failed to create media record in database'
        }, status => 500);
    }

    # Add URL to the response
    $media->{url} = "/uploads/$filepath";

    return $self->render(json => {
        success => 1,
        media => $media
    });
}

# Get all media with pagination
sub get_all ($self) {
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || 20;
    my $mime_type = $self->param('mime_type');
    my $search = $self->param('search');

    my %params = (
        page => $page,
        limit => $limit
    );

    $params{mime_type} = $mime_type if $mime_type;
    $params{search} = $search if $search;

    my $result = HelloPerld::Model::Media->get_all(%params);

    unless ($result) {
        return $self->render(json => {
            success => 0,
            error => 'Failed to fetch media'
        }, status => 500);
    }

    # Add URLs to all media items
    foreach my $media (@{$result->{media}}) {
        $media->{url} = "/uploads/" . $media->{filepath};
    }

    return $self->render(json => {
        success => 1,
        media => $result->{media},
        pagination => $result->{pagination}
    });
}

# Get media by ID
sub get_by_id ($self) {
    my $id = $self->param('id');

    unless ($id) {
        return $self->render(json => {
            success => 0,
            error => 'Media ID is required'
        }, status => 400);
    }

    my $media = HelloPerld::Model::Media->get_by_id($id);

    unless ($media) {
        return $self->render(json => {
            success => 0,
            error => 'Media not found'
        }, status => 404);
    }

    # Add URL to the response
    $media->{url} = "/uploads/" . $media->{filepath};

    return $self->render(json => {
        success => 1,
        media => $media
    });
}

# Update media metadata (alt_text, caption)
sub update ($self) {
    my $id = $self->param('id');

    unless ($id) {
        return $self->render(json => {
            success => 0,
            error => 'Media ID is required'
        }, status => 400);
    }

    # Get request body
    my $body = $self->req->json || {};
    my $alt_text = $self->param('alt_text') || $body->{alt_text};
    my $caption = $self->param('caption') || $body->{caption};

    my $media = HelloPerld::Model::Media->update($id,
        alt_text => $alt_text,
        caption => $caption
    );

    unless ($media) {
        return $self->render(json => {
            success => 0,
            error => 'Failed to update media'
        }, status => 500);
    }

    # Add URL to the response
    $media->{url} = "/uploads/" . $media->{filepath};

    return $self->render(json => {
        success => 1,
        media => $media
    });
}

# Delete media
sub delete ($self) {
    my $id = $self->param('id');

    unless ($id) {
        return $self->render(json => {
            success => 0,
            error => 'Media ID is required'
        }, status => 400);
    }

    my $result = HelloPerld::Model::Media->delete($id);

    unless ($result) {
        return $self->render(json => {
            success => 0,
            error => 'Media not found or failed to delete'
        }, status => 404);
    }

    # Delete the physical file
    my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
    my $full_filepath = "$uploads_dir/" . $result->{filepath};

    $self->app->log->info("Attempting to delete file: $full_filepath");
    $self->app->log->info("File exists before delete: " . (-f $full_filepath ? "YES" : "NO"));

    if (-f $full_filepath) {
        $self->app->log->info("File permissions: " . sprintf("%04o", (stat($full_filepath))[2] & 07777));

        if (unlink $full_filepath) {
            $self->app->log->info("Successfully deleted file: $full_filepath");
        } else {
            $self->app->log->error("Failed to delete file: $full_filepath - Error: $!");
            warn "Failed to delete file $full_filepath: $!";
        }
    } else {
        $self->app->log->warn("File not found for deletion: $full_filepath");
    }

    return $self->render(json => {
        success => 1,
        message => 'Media deleted successfully'
    });
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Media - Media file upload and management

=head1 SYNOPSIS

    # In your application
    $routes->post('/api/admin/media/upload')->to('Media#upload');
    $routes->get('/api/admin/media')->to('Media#get_all');
    $routes->get('/api/admin/media/:id')->to('Media#get_by_id');
    $routes->put('/api/admin/media/:id')->to('Media#update');
    $routes->delete('/api/admin/media/:id')->to('Media#delete');

=head1 DESCRIPTION

This controller handles media file uploads and management, including:
- File upload with validation (type and size)
- Image dimension extraction
- Unique filename generation
- Organized directory structure (YYYY/MM)
- CRUD operations on media metadata

=head1 METHODS

=head2 upload

Handles file upload via multipart/form-data. Validates file type and size,
generates unique filename, extracts image dimensions, and stores metadata.

=head2 get_all

Returns paginated list of media files with optional filtering by mime_type
or search query.

=head2 get_by_id

Returns a single media item by ID.

=head2 update

Updates media metadata (alt_text and caption).

=head2 delete

Deletes media record and physical file.

=cut
