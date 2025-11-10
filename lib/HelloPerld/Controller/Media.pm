package HelloPerld::Controller::Media;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use strict;
use warnings;

use HelloPerld::Model::Media;
use HelloPerld::Util::ErrorResponse qw(error_response);
use Imager;
use File::Path qw(make_path);
use File::Copy;
use File::Basename qw(fileparse dirname);
use File::Spec::Functions qw(catfile catdir);
use File::Temp qw(tempfile);
use MIME::Types;
use MIME::Base64;
use Digest::SHA qw(sha256_hex);
use Time::Local;

# Upload media file
sub upload ($self) {
    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }
    my $upload = $self->req->upload('file');

    # Support both form parameters and JSON body (like other endpoints)
    my $body = $self->req->json || {};
    my $base64_data = $self->param('base64_data') || $body->{base64_data};
    my $base64_filename = $self->param('base64_filename') || $body->{base64_filename};

    # Support both file upload and base64 data
    unless ($upload || $base64_data) {
        return error_response($self, 'validation', 'No file uploaded or base64 data provided',
            code => 'VAL015',
            details => { expected_fields => ['file', 'base64_data'] }
        );
    }

    # Get configuration
    my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
    my $max_size = $ENV{UPLOAD_MAX_SIZE} || 5242880; # 5MB default
    my $allowed_types = $ENV{UPLOAD_ALLOWED_TYPES} || 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml';

    my @allowed_mime_types = split /,/, $allowed_types;
    my %allowed_types_hash = map { $_ => 1 } @allowed_mime_types;

    # Initialize variables for both upload types
    my ($file_size, $mime_type, $original_filename, $file_data);

    if ($upload) {
        # Handle regular file upload
        $file_size = $upload->size;
        $mime_type = $upload->headers->content_type;
        $original_filename = $upload->filename;
    } elsif ($base64_data) {
        # Handle base64 data upload
        # Expect format: data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAAAAAAAD...
        my ($data_uri_prefix, $encoded_data) = split /,/, $base64_data, 2;

        unless ($encoded_data) {
            return error_response($self, 'validation', 'Invalid base64 data format. Expected data URI format: data:mime/type;base64,data',
                code => 'VAL016',
                details => { expected_format => 'data:mime/type;base64,data' }
            );
        }

        # Extract MIME type from data URI
        if ($data_uri_prefix =~ /data:([^;]+);base64/) {
            $mime_type = $1;
        } else {
            return error_response($self, 'validation', 'Could not determine MIME type from base64 data',
                code => 'VAL017',
                details => { data_uri_prefix => $data_uri_prefix }
            );
        }

        # Decode base64 data
        eval {
            $file_data = decode_base64($encoded_data);
        };
        if ($@) {
            return error_response($self, 'validation', 'Failed to decode base64 data',
                code => 'VAL018',
                details => { decode_error => $@ }
            );
        }

        $file_size = length($file_data);

        # Secure extension mapping based on MIME type
        my %mime_to_ext = (
            'image/jpeg' => 'jpg',
            'image/png'  => 'png',
            'image/gif'  => 'gif',
            'image/webp' => 'webp',
            'image/svg+xml' => 'svg'
        );
        my $ext = $mime_to_ext{$mime_type} || 'bin';

        $original_filename = $base64_filename || "pasted-image-" . time() . ".$ext";
    }

    # Validate file size
    if ($file_size > $max_size) {
        return error_response($self, 'validation', "File size exceeds maximum allowed size of " . int($max_size / 1048576) . "MB",
            code => 'VAL019',
            details => {
                file_size => $file_size,
                max_size => $max_size,
                max_size_mb => int($max_size / 1048576)
            }
        );
    }

    # Validate MIME type
    unless ($allowed_types_hash{$mime_type}) {
        return error_response($self, 'validation', "File type not allowed. Allowed types: " . join(', ', @allowed_mime_types),
            code => 'VAL020',
            details => {
                file_type => $mime_type,
                allowed_types => \@allowed_mime_types
            }
        );
    }

    # Server-side file content validation - SECURITY CRITICAL
    # Multi-layer validation approach:
    # 1. MIME type and size validation (already done above)
    # 2. File signature/magic number validation
    # 3. Image processing validation for image files

    my $file_content;
    if ($upload) {
        $file_content = $upload->asset->slurp;
    } elsif ($file_data) {
        $file_content = $file_data;
    }

    # Validate file signatures (magic numbers) for common types
    my $is_valid_signature = $self->_validate_file_signature($file_content, $mime_type);
    unless ($is_valid_signature) {
        $self->app->log->warn("File signature validation failed for MIME type: $mime_type");
        return error_response($self, 'validation', "File content does not match declared file type",
            code => 'MEDIA001',
            details => { mime_type => $mime_type },
            skip_logging => 1 # Already logged above
        );
    }

    # Additional validation for images using Imager library
    # This ensures the file is actually parseable as an image
    if ($mime_type =~ /^image\// && $mime_type ne 'image/svg+xml') {
        my $validation_img = Imager->new();

        # Try to read the file content
        my $can_read;
        if ($upload) {
            # Create a secure temporary file for validation (Imager needs a file path)
            my ($temp_fh, $temp_file) = tempfile(UNLINK => 1);
            eval {
                binmode $temp_fh;
                print $temp_fh $file_content;
                close $temp_fh;

                $can_read = $validation_img->read(file => $temp_file);
                # No need to unlink - UNLINK => 1 handles cleanup automatically
            };
            if ($@) {
                $self->app->log->error("Image validation error: $@");
                $can_read = 0;
            }
        } elsif ($file_data) {
            # For base64 data, read from data directly
            $can_read = $validation_img->read(data => $file_data);
        }

        unless ($can_read) {
            my $error_msg = $validation_img->errstr() || "Unknown image validation error";
            $self->app->log->warn("Image processing validation failed: $error_msg");
            return error_response($self, 'validation', "File appears to be corrupted or is not a valid image",
                code => 'MEDIA002',
                details => { validation_error => $error_msg },
                skip_logging => 1 # Already logged above
            );
        }

        $self->app->log->info("Image content validation passed for MIME type: $mime_type");
    }

    # Special validation for SVG files (XML-based, requires different approach)
    if ($mime_type eq 'image/svg+xml') {
        my $is_valid_svg = $self->_validate_svg_content($file_content);
        unless ($is_valid_svg) {
            $self->app->log->warn("SVG validation failed - potentially malicious content");
            return error_response($self, 'validation', "SVG file contains invalid or potentially dangerous content",
                code => 'MEDIA003',
                details => { file_type => 'SVG' },
                skip_logging => 1 # Already logged above
            );
        }
    }

    $self->app->log->info("File validation passed for MIME type: $mime_type");

    # Generate unique filename
    my ($name, $path, $ext) = fileparse($original_filename, qr/\.[^.]*/);
    my $unique_id = sha256_hex($original_filename . time() . rand());
    my $unique_filename = substr($unique_id, 0, 16) . lc($ext);

    # Create date-based directory structure (YYYY/MM)
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $date_path = sprintf("%04d/%02d", $year, $mon);
    my $full_dir = catdir($uploads_dir, $date_path);

    # Create directory if it doesn't exist
    unless (-d $full_dir) {
        eval {
            make_path($full_dir, { chmod => 0755 });
        };
        if ($@) {
            $self->app->log->error("Failed to create upload directory: $@");
            return error_response($self, 'server_error', "Failed to create upload directory",
                code => 'MEDIA004',
                details => { directory => $full_dir, error => $@ },
                skip_logging => 1 # Already logged above
            );
        }
    }

    # Full file path (using secure path construction)
    my $filepath = catfile($date_path, $unique_filename);
    my $full_filepath = catfile($uploads_dir, $filepath);

    # Save the file
    eval {
        if ($upload) {
            # Save regular file upload
            $upload->move_to($full_filepath);
        } elsif ($file_data) {
            # Save base64 decoded data
            open(my $fh, '>', $full_filepath) or die "Cannot open file $full_filepath: $!";
            binmode $fh;
            print $fh $file_data;
            close $fh;
        }
    };
    if ($@) {
        $self->app->log->error("Failed to save file: $@");
        return error_response($self, 'server_error', "Failed to save file",
            code => 'MEDIA005',
            details => { filepath => $full_filepath, error => $@ },
            skip_logging => 1 # Already logged above
        );
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

    # Get optional metadata from request (support both form and JSON) with length validation
    my $alt_text_raw = $self->param('alt_text') || $body->{alt_text} || '';
    my $caption_raw = $self->param('caption') || $body->{caption} || '';

    # Apply length limits to prevent oversized inputs
    my $alt_text = substr($alt_text_raw, 0, 255);
    my $caption = substr($caption_raw, 0, 500);

    # Log if input was truncated for debugging
    if (length($alt_text_raw) > 255) {
        $self->app->log->warn("Alt text truncated from " . length($alt_text_raw) . " to 255 characters");
    }
    if (length($caption_raw) > 500) {
        $self->app->log->warn("Caption truncated from " . length($caption_raw) . " to 500 characters");
    }

    # Create media record in database
    my $media_model = HelloPerld::Model::Media->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $media = $media_model->create(
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
        return error_response($self, 'server_error', 'Failed to create media record in database',
            code => 'DB012'
        );
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

    my $media_model = HelloPerld::Model::Media->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $result = $media_model->get_all(%params);

    unless ($result) {
        return error_response($self, 'server_error', 'Failed to fetch media',
            code => 'DB013'
        );
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
        return error_response($self, 'validation', 'Media ID is required',
            code => 'VAL021',
            details => { field => 'id' }
        );
    }

    my $media_model = HelloPerld::Model::Media->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $media = $media_model->get_by_id($id);

    unless ($media) {
        return error_response($self, 'not_found', 'Media not found',
            code => 'MEDIA006',
            details => { id => $id }
        );
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
    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }
    my $id = $self->param('id');

    unless ($id) {
        return error_response($self, 'validation', 'Media ID is required',
            code => 'VAL022',
            details => { field => 'id' }
        );
    }

    # Get request body with length validation
    my $body = $self->req->json || {};
    my $alt_text_raw = $self->param('alt_text') || $body->{alt_text} || '';
    my $caption_raw = $self->param('caption') || $body->{caption} || '';

    # Apply length limits to prevent oversized inputs
    my $alt_text = substr($alt_text_raw, 0, 255);
    my $caption = substr($caption_raw, 0, 500);

    # Log if input was truncated for debugging
    if (length($alt_text_raw) > 255) {
        $self->app->log->warn("Alt text truncated from " . length($alt_text_raw) . " to 255 characters in update");
    }
    if (length($caption_raw) > 500) {
        $self->app->log->warn("Caption truncated from " . length($caption_raw) . " to 500 characters in update");
    }

    my $media_model = HelloPerld::Model::Media->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $media = $media_model->update($id,
        alt_text => $alt_text,
        caption => $caption
    );

    unless ($media) {
        return error_response($self, 'server_error', 'Failed to update media',
            code => 'DB014',
            details => { id => $id }
        );
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
    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }
    my $id = $self->param('id');

    unless ($id) {
        return error_response($self, 'validation', 'Media ID is required',
            code => 'VAL023',
            details => { field => 'id' }
        );
    }

    my $media_model = HelloPerld::Model::Media->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # First, get the media record to obtain file path before deletion
    my $media_record = $media_model->get_by_id($id);
    unless ($media_record) {
        return error_response($self, 'not_found', 'Media not found',
            code => 'MEDIA007',
            details => { id => $id }
        );
    }

    # Construct full file path
    my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
    my $full_filepath = catfile($uploads_dir, $media_record->{filepath});

    $self->app->log->info("Attempting to delete media ID: $id");
    $self->app->log->info("File path: $full_filepath");
    $self->app->log->info("File exists before delete: " . (-f $full_filepath ? "YES" : "NO"));

    # Check file permissions and existence before attempting deletion
    my $file_deletion_success = 1;
    my $file_deletion_error = '';

    if (-f $full_filepath) {
        # Log file permissions for debugging
        my $perms = sprintf("%04o", (stat($full_filepath))[2] & 07777);
        $self->app->log->info("File permissions: $perms");

        # Check if directory is writable
        my $dir = dirname($full_filepath);
        my $dir_writable = -w $dir;
        $self->app->log->info("Directory writable: " . ($dir_writable ? "YES" : "NO"));

        # Attempt file deletion
        unless (unlink $full_filepath) {
            $file_deletion_success = 0;
            $file_deletion_error = $!;
            $self->app->log->error("Failed to delete file: $full_filepath - Error: $!");
        } else {
            $self->app->log->info("Successfully deleted file: $full_filepath");
        }
    } else {
        $self->app->log->warn("File not found for deletion: $full_filepath");
        # Continue with database deletion even if file doesn't exist (cleanup orphaned records)
    }

    # Only delete from database if file deletion succeeded (or file didn't exist)
    if ($file_deletion_success) {
        my $result = $media_model->delete($id);
        unless ($result) {
            $self->app->log->error("Failed to delete media record from database for ID: $id");
            return error_response($self, 'server_error', 'Failed to delete media record from database',
                code => 'DB015',
                details => { id => $id },
                skip_logging => 1 # Already logged above
            );
        }

        # Add cache invalidation headers to help browsers clear cached content
        $self->res->headers->header('Clear-Site-Data' => '"cache"');
        $self->res->headers->cache_control('no-cache, no-store, must-revalidate');
        $self->res->headers->header('Pragma' => 'no-cache');
        $self->res->headers->header('Expires' => '0');

        return $self->render(json => {
            success => 1,
            message => 'Media deleted successfully'
        });
    } else {
        # File deletion failed, don't delete database record
        return error_response($self, 'server_error', "Failed to delete physical file: $file_deletion_error",
            code => 'MEDIA008',
            details => {
                id => $id,
                filepath => $full_filepath,
                error => $file_deletion_error
            }
        );
    }
}

# Private helper method: Validate file signature (magic numbers)
sub _validate_file_signature ($self, $content, $mime_type) {
    return 0 unless $content;

    # Get first 16 bytes for magic number checking
    my $header = substr($content, 0, 16);

    # Magic number signatures for common image formats
    # Reference: https://en.wikipedia.org/wiki/List_of_file_signatures
    my %signatures = (
        'image/jpeg' => [
            qr/^\xFF\xD8\xFF/,  # JPEG/JFIF
        ],
        'image/png' => [
            qr/^\x89PNG\r\n\x1A\n/,  # PNG signature
        ],
        'image/gif' => [
            qr/^GIF87a/,  # GIF87a
            qr/^GIF89a/,  # GIF89a
        ],
        'image/webp' => [
            qr/^RIFF....WEBP/s,  # WebP (RIFF container)
        ],
        'image/svg+xml' => [
            qr/^\s*<\?xml/,          # XML declaration
            qr/^\s*<svg/,            # Direct SVG tag
            qr/^\s*<!DOCTYPE\s+svg/i, # SVG DOCTYPE
        ],
    );

    # Get expected signatures for this MIME type
    my $expected_sigs = $signatures{$mime_type};
    unless ($expected_sigs) {
        # Unknown MIME type - reject for security
        $self->app->log->warn("No signature validation defined for MIME type: $mime_type");
        return 0;
    }

    # Check if file header matches any of the expected signatures
    foreach my $sig (@$expected_sigs) {
        if ($header =~ $sig) {
            return 1; # Valid signature found
        }
    }

    # Also check full content for SVG (might have leading whitespace/comments)
    if ($mime_type eq 'image/svg+xml') {
        my $first_1kb = substr($content, 0, 1024);
        foreach my $sig (@$expected_sigs) {
            if ($first_1kb =~ $sig) {
                return 1;
            }
        }
    }

    return 0; # No matching signature found
}

# Private helper method: Validate SVG content for security
sub _validate_svg_content ($self, $content) {
    return 0 unless $content;

    # SVG security checks - prevent XXE, script injection, etc.

    # 1. Basic XML structure check
    unless ($content =~ /<svg/i) {
        $self->app->log->warn("SVG validation failed: No <svg> tag found");
        return 0;
    }

    # 2. Check for dangerous elements/attributes (blacklist approach)
    my @dangerous_patterns = (
        qr/<script[>\s]/i,           # Script tags
        qr/\bon\w+\s*=/is,           # Event handlers (onclick, onload, etc.) - enhanced with word boundary and multiline
        qr/on\s+\w+\s*=/is,          # Event handlers with spaces (e.g., "on click=")
        qr/<iframe[>\s]/i,           # Iframes
        qr/<embed[>\s]/i,            # Embed tags
        qr/<object[>\s]/i,           # Object tags
        qr/<!ENTITY/i,               # External entities (XXE vulnerability)
        qr/<!DOCTYPE[^>]*\[/i,       # DOCTYPE with internal DTD
        qr/javascript:/i,            # JavaScript URLs
        qr/data:text\/html/i,        # Data URLs with HTML
        qr/<foreignObject[>\s]/i,    # Foreign objects (can embed HTML)
        qr/expression\s*\(/i,        # CSS expressions (IE legacy vulnerability)
        qr/\@import/i,               # CSS imports (potential for external content)
        qr/xlink:href\s*=\s*["']javascript:/i, # XLink JavaScript URLs
    );

    foreach my $pattern (@dangerous_patterns) {
        if ($content =~ $pattern) {
            $self->app->log->warn("SVG validation failed: Dangerous pattern detected");
            return 0;
        }
    }

    # 3. Size check - prevent billion laughs attack
    if (length($content) > 5_000_000) { # 5MB limit for SVG
        $self->app->log->warn("SVG validation failed: File too large");
        return 0;
    }

    # 4. Depth check - prevent deeply nested XML (DoS)
    my $depth = ($content =~ tr/<//);
    if ($depth > 10000) { # Reasonable limit for SVG tags
        $self->app->log->warn("SVG validation failed: Too many XML tags");
        return 0;
    }

    return 1; # SVG appears safe
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
