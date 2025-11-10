package HelloPerld;
use Mojo::Base 'Mojolicious';

our $VERSION = '1.0.0';

use HelloPerld::Logger::LoggerFactory;
use HelloPerld::Security::CSRF;

sub startup {
    my $self = shift;

    # Load environment-specific configuration
    my $mode = $self->mode; # Gets from MOJO_MODE env var or --mode flag
    my $config_file = $self->home->rel_file("config/hello-perld.$mode.conf");

    $self->plugin('Config' => {
        file => $config_file,
        default => {}
    });

    $self->log->info("Loading configuration for mode: $mode");
    $self->log->info("Config file: $config_file");

    # Validate production configuration
    if ($mode eq 'production' || $mode eq 'staging') {
        my $session_secret = $self->config->{session}->{secret};
        die "SESSION_SECRET must be set for $mode!"
            if !$session_secret || $session_secret eq 'development-secret-change-me';

        die "Database configuration missing for $mode!"
            unless $self->config->{database}->{host}
                && $self->config->{database}->{user}
                && $self->config->{database}->{password};
    }

    # Initialize logger
    $self->helper(logger_instance => sub {
        state $logger = HelloPerld::Logger::LoggerFactory->create_default_logger();
        return $logger;
    });

    # Add helper for database config
    $self->helper(db_config => sub {
        my $c = shift;
        return $c->app->config->{database};
    });

    # Add CSRF protection helpers
    $self->helper(csrf_token => sub {
        my $c = shift;
        my $session_id = $c->session('admin_user_id') || 'anonymous';
        my $secret_key = $c->app->secrets->[0];

        return HelloPerld::Security::CSRF::generate_token($session_id, $secret_key);
    });

    $self->helper(csrf_protect => sub {
        my $c = shift;

        # Skip CSRF protection for GET requests (safe methods)
        return 1 if $c->req->method eq 'GET';

        # Get CSRF token from header or form parameter
        my $token = $c->req->headers->header('X-CSRF-Token') ||
                   $c->req->headers->header('X-Requested-With-Token') ||
                   $c->param('_csrf_token');

        return 0 unless $token; # No token provided

        # Get session ID and secret
        my $session_id = $c->session('admin_user_id') || 'anonymous';
        my $secret_key = $c->app->secrets->[0];

        # Validate token (1 hour max age)
        return HelloPerld::Security::CSRF::validate_token($token, $session_id, $secret_key, 3600);
    });

    # Helper to get CSRF token for responses
    $self->helper(csrf_token_response => sub {
        my $c = shift;
        return {
            csrf_token => $c->csrf_token,
            expires_in => 3600 # 1 hour
        };
    });

    # Configure template path
    $self->renderer->paths->[0] = 'lib/HelloPerld/Templates';

    # Configure static file serving
    push @{$self->static->paths}, 'lib/HelloPerld/Public';

    # Serve uploaded media files - MUST be first route to take precedence over OpenAPI
    $self->routes->get('/uploads/*filepath' => sub {
        my $c = shift;
        my $filepath = $c->param('filepath');

        # Prevent directory traversal attacks
        if ($filepath =~ /\.\./ || $filepath =~ /^\//) {
            return $c->render(text => 'Forbidden', status => 403);
        }

        my $uploads_dir = $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads';
        my $full_path = "$uploads_dir/$filepath";

        $c->app->log->info("Looking for file: $full_path");
        $c->app->log->info("File exists: " . (-f $full_path ? "YES" : "NO"));

        if (-f $full_path) {
            # Add cache control headers to prevent aggressive caching
            # This ensures browsers validate with server before using cached content
            $c->res->headers->cache_control('no-cache, must-revalidate, max-age=0');
            $c->res->headers->header('Pragma' => 'no-cache');
            $c->res->headers->header('Expires' => 'Thu, 01 Jan 1970 00:00:00 GMT');

            return $c->reply->file($full_path);
        } else {
            return $c->reply->not_found;
        }
    });

    # Use a hook to handle other static files
    $self->hook(before_dispatch => sub {
        my $c = shift;
        my $path = $c->req->url->path->to_string;

        # Skip uploads directory - handled by dedicated route
        return if $path =~ m{^/uploads/};

        # Check if this is a static file request (including .map files for source maps)
        if ($path =~ /\.(css|js|mjs|map|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf)$/i) {
            my $file = substr($path, 1); # Remove leading slash

            # Prevent directory traversal attacks
            if ($file =~ /\.\./ || $file =~ /^\//) {
                $c->render(text => 'Forbidden', status => 403);
                return;
            }

            if ($c->reply->static($file)) {
                $c->rendered; # Mark as rendered to prevent further processing
            }
        }
    });

    # Define custom routes BEFORE OpenAPI plugin
    # Serve the built Vue.js SPA
    $self->routes->get('/')->to(cb => sub {
        my $c = shift;
        # Serve the built index.html from Vite
        my $index_file = $c->app->home->rel_file('lib/HelloPerld/Public/dist/index.html');
        if (-e $index_file) {
            $c->reply->file($index_file);
        } else {
            # Fallback to template if dist hasn't been built yet
            $c->render(template => 'index');
        }
    });

    # Health check endpoints (outside API namespace for direct access)
    $self->routes->get('/health')->to('Health#getHealthStatus');
    $self->routes->get('/health/ready')->to('Health#get_readiness_status');

    # Configure session management from config
    my $session_config = $self->config->{session};
    $self->secrets([$session_config->{secret}]);
    $self->sessions->default_expiration($session_config->{expiration});

    # Configure session security based on environment
    if (defined $session_config->{secure}) {
        $self->sessions->secure($session_config->{secure});
    }
    if (defined $session_config->{samesite}) {
        $self->sessions->samesite($session_config->{samesite});
    }

    # Configure HttpOnly via hook since it's not directly supported by sessions
    if (defined $session_config->{httponly} && $session_config->{httponly}) {
        $self->hook(after_dispatch => sub {
            my $c = shift;

            # Apply HttpOnly to session cookies in response
            my $cookie_name = $c->app->sessions->cookie_name || 'mojolicious';

            # Check if a session cookie is being set in the response
            my @cookies = grep { $_->name eq $cookie_name } @{$c->res->cookies};
            for my $cookie (@cookies) {
                $cookie->httponly(1) if $cookie->can('httponly');
            }
        });
    }

    # Configure OpenAPI plugin - limit to /api routes only
    # TEMPORARILY DISABLED to test uploads route
    # $self->plugin('OpenAPI' => {
    #     url => $self->home->rel_file('swagger/swagger.json'),
    #     route => $self->routes->under('/api')
    # });

    # Configure SwaggerUI plugin - only in development
    if ($self->config->{swagger_enabled}) {
        $self->plugin('SwaggerUI' => {
            route => $self->routes->any('/swagger'),
            url => '/swagger.json',
            favicon => '/thebooshzone.ico'
        });

        # Serve the swagger.json file
        $self->routes->get('/swagger.json')->to(cb => sub {
            my $c = shift;
            $c->reply->file($c->app->home->rel_file('swagger/swagger.json'));
        });

        $self->log->info("Swagger UI enabled at /swagger");
    } else {
        # Return 404 for swagger routes in production/staging
        $self->routes->get('/swagger')->to(cb => sub {
            my $c = shift;
            $c->reply->not_found;
        });

        $self->routes->get('/swagger.json')->to(cb => sub {
            my $c = shift;
            $c->reply->not_found;
        });

        $self->log->info("Swagger UI disabled for this environment");
    }

    # API Routes
    my $api = $self->routes->under('/api');

    # Authentication routes
    $api->post('/auth/login')->to('Auth#login');
    $api->post('/auth/logout')->to('Auth#logout');
    $api->get('/auth/status')->to('Auth#status');

    # CSRF token endpoint
    $api->get('/csrf-token')->to(cb => sub {
        my $c = shift;
        $c->render(json => {
            success => 1,
            data => $c->csrf_token_response
        });
    });

    # Public article routes
    $api->get('/articles')->to('Articles#get_all');
    $api->get('/articles/:slug')->to('Articles#get_by_slug');

    # Public tag routes
    $api->get('/tags')->to('Tags#get_all');
    $api->get('/tags/popular')->to('Tags#get_popular');
    $api->get('/tags/search')->to('Tags#search');
    $api->get('/tags/:slug')->to('Tags#get_by_slug');

    # Admin routes (protected)
    my $admin = $api->under('/admin')->to(cb => sub {
        my $c = shift;

        # Check if user is authenticated
        my $user_id = $c->session('admin_user_id');
        unless ($user_id) {
            $c->render(json => {
                success => 0,
                error => 'Authentication required'
            }, status => 401);
            return 0; # Stop processing - don't continue to controller
        }

        return 1;
    });

    # Protected article management routes
    $admin->get('/articles')->to('Articles#get_all', is_admin_route => 1); # Admin can see unpublished
    $admin->get('/articles/:id')->to('Articles#get_by_id');
    $admin->post('/articles')->to('Articles#create');
    $admin->put('/articles/:id')->to('Articles#update');
    $admin->delete('/articles/:id')->to('Articles#delete');

    # Protected tag management routes
    $admin->get('/tags/:id')->to('Tags#get_by_id');
    $admin->post('/tags')->to('Tags#create');
    $admin->put('/tags/:id')->to('Tags#update');
    $admin->delete('/tags/:id')->to('Tags#delete');

    # Protected auth management routes
    $admin->post('/auth/change-password')->to('Auth#change_password');

    # Protected media management routes
    $admin->post('/media/upload')->to('Media#upload');
    $admin->get('/media')->to('Media#get_all');
    $admin->get('/media/:id')->to('Media#get_by_id');
    $admin->put('/media/:id')->to('Media#update');
    $admin->delete('/media/:id')->to('Media#delete');

    # SPA fallback routing - catch all non-API routes and serve index.html
    # This allows Vue Router history mode to work correctly
    # IMPORTANT: Define this AFTER all API/Swagger routes to ensure proper route priority
    $self->routes->get('/*')->to(cb => sub {
        my $c = shift;
        my $path = $c->req->url->path->to_string;

        # Skip API routes, swagger, and uploads
        return if $path =~ m{^/(api|swagger|uploads)};

        # Serve SPA index.html for all other routes
        my $index_file = $c->app->home->rel_file('lib/HelloPerld/Public/dist/index.html');
        if (-e $index_file) {
            $c->reply->file($index_file);
        } else {
            $c->reply->not_found;
        }
    });

    # Add security headers
    $self->hook(after_dispatch => sub {
        my $c = shift;
        my $path = $c->req->url->path->to_string;

        # Basic security headers (apply to all routes)
        $c->res->headers->header('X-Frame-Options' => 'DENY');
        $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
        $c->res->headers->header('X-XSS-Protection' => '1; mode=block');
        $c->res->headers->header('Referrer-Policy' => 'strict-origin-when-cross-origin');

        # Skip CSP for Swagger UI (needs inline scripts) but apply to all other routes
        unless ($path =~ m{^/swagger}) {
            # Content Security Policy - Modern XSS protection
            my $csp = join('; ',
                "default-src 'self'",                           # Only allow resources from same origin by default
                "script-src 'self'",                            # Only scripts from same origin (no inline, no eval)
                "style-src 'self' 'unsafe-inline'",             # Styles from same origin + inline (Vue.js components need this)
                "img-src 'self' data:",                         # Images from same origin + data URLs (for base64 images)
                "font-src 'self'",                              # Web fonts from same origin only
                "connect-src 'self'",                           # AJAX/fetch only to same origin (API calls)
                "media-src 'self'",                             # Audio/video from same origin only
                "object-src 'none'",                            # No plugins (Flash, Java applets, etc.)
                "base-uri 'self'",                              # Restrict <base> tag to same origin
                "form-action 'self'",                           # Forms can only submit to same origin
                "frame-ancestors 'none'",                       # Prevent embedding in frames (like X-Frame-Options)
                "upgrade-insecure-requests"                     # Automatically upgrade HTTP to HTTPS in production
            );

            $c->res->headers->header('Content-Security-Policy' => $csp);
        }
    });

    # Log startup
    $self->logger_instance->info("HelloPerld web application started! Hello, perld!");
}

1;

__END__

=head1 NAME

HelloPerld - A Mojolicious web application with structured logging

=head1 SYNOPSIS

    use HelloPerld;

    # Start the application
    my $app = HelloPerld->new;
    $app->start;

=head1 DESCRIPTION

HelloPerld is a Mojolicious-based web application that demonstrates best practices
for Perl web development including structured logging, database connectivity,
and OpenAPI/Swagger documentation.

The application provides:
- RESTful API endpoints with OpenAPI specification
- Multiple logging backends (Console, Database, JSON file)
- Health check endpoints for monitoring
- Swagger UI for API documentation

=head1 METHODS

=head2 startup

Initializes the application, configures routes, plugins, and logging.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
