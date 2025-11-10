package HelloPerld::Util::ErrorResponse;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(error_response);

=head1 NAME

HelloPerld::Util::ErrorResponse - Standardized error response helper

=head1 SYNOPSIS

    use HelloPerld::Util::ErrorResponse qw(error_response);

    # In controller methods
    return error_response($self, 'validation', 'Title is required',
        code => 'VAL001',
        details => { field => 'title' }
    );

=head1 DESCRIPTION

Provides standardized error response format across all API endpoints.
Ensures consistent status codes, response structure, and error handling.

=cut

sub error_response {
    my ($controller, $type, $message, %options) = @_;

    # Validate required parameters
    unless ($controller && $type && $message) {
        die "error_response requires controller, type, and message parameters";
    }

    # HTTP status code mapping
    my %status_codes = (
        validation     => 422,  # Unprocessable Entity (better than 400 for validation)
        bad_request    => 400,  # Bad Request (malformed JSON, etc.)
        not_found      => 404,  # Resource not found
        unauthorized   => 401,  # Authentication required
        forbidden      => 403,  # CSRF, permissions
        conflict       => 409,  # Resource already exists
        rate_limit     => 429,  # Too many requests
        server_error   => 500,  # Database errors, internal failures
        unavailable    => 503,  # Service temporarily unavailable
    );

    my $status = $status_codes{$type} || 500;

    # Generate request ID if not available
    my $request_id = $controller->can('request_id') ? $controller->request_id() : _generate_request_id();

    # Standardized error response format
    my $response = {
        success      => 0,
        error        => $message,
        error_type   => $type,
        timestamp    => time(),
        request_id   => $request_id,
    };

    # Optional fields
    $response->{error_code} = $options{code} if $options{code};
    $response->{details} = $options{details} if $options{details};

    # Set retry-after header for rate limiting and unavailable service
    if ($type eq 'rate_limit' && $options{retry_after}) {
        $controller->res->headers->header('Retry-After' => $options{retry_after});
    }
    if ($type eq 'unavailable' && $options{retry_after}) {
        $controller->res->headers->header('Retry-After' => $options{retry_after});
    }

    # Log the error with context (but don't duplicate logging if already logged)
    unless ($options{skip_logging}) {
        my $logger = $controller->app->logger_instance;
        if ($logger) {
            $logger->error({
                request_id   => $request_id,
                error_type   => $type,
                message      => $message,
                status_code  => $status,
                user_id      => $controller->session('admin_user_id'),
                endpoint     => $controller->req->url->path,
                method       => $controller->req->method,
            });
        }
    }

    return $controller->render(json => $response, status => $status);
}

# Simple UUID-like request ID generator
sub _generate_request_id {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        int(rand(0x10000)), int(rand(0x10000)),
        int(rand(0x10000)),
        int(rand(0x10000)) | 0x4000,
        int(rand(0x10000)) | 0x8000,
        int(rand(0x10000)), int(rand(0x10000)), int(rand(0x10000))
    );
}

1;

__END__

=head1 ERROR TYPES

=head2 validation (422)

Used for input validation errors like missing required fields, invalid formats, or values out of range.

    return error_response($self, 'validation', 'Title is required',
        code => 'VAL001',
        details => { field => 'title' }
    );

=head2 bad_request (400)

Used for malformed requests like invalid JSON, wrong content-type, or structurally invalid requests.

    return error_response($self, 'bad_request', 'Invalid JSON format');

=head2 not_found (404)

Used when requested resource doesn't exist.

    return error_response($self, 'not_found', 'Article not found',
        code => 'ART001',
        details => { slug => $slug }
    );

=head2 unauthorized (401)

Used when authentication is required but not provided or invalid.

    return error_response($self, 'unauthorized', 'Authentication required');

=head2 forbidden (403)

Used for valid authentication but insufficient permissions or CSRF token failures.

    return error_response($self, 'forbidden', 'CSRF token required');

=head2 conflict (409)

Used when resource already exists or operation conflicts with current state.

    return error_response($self, 'conflict', 'Tag with this name already exists',
        code => 'TAG001',
        details => { name => $tag_name }
    );

=head2 rate_limit (429)

Used when client exceeds rate limits.

    return error_response($self, 'rate_limit', 'Too many requests',
        retry_after => 300
    );

=head2 server_error (500)

Used for internal server errors, database failures, or unexpected conditions.

    return error_response($self, 'server_error', 'Database connection failed',
        code => 'DB001'
    );

=head2 unavailable (503)

Used when service is temporarily unavailable due to maintenance or overload.

    return error_response($self, 'unavailable', 'Service temporarily unavailable',
        retry_after => 60
    );

=head1 RESPONSE FORMAT

All error responses follow this standardized format:

    {
        "success": 0,
        "error": "Human-readable error message",
        "error_type": "validation",
        "timestamp": 1699123456,
        "request_id": "12ab34cd-5678-90ef-1234-567890abcdef",
        "error_code": "VAL001",     // Optional
        "details": {                // Optional
            "field": "title"
        }
    }

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut