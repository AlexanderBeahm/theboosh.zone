package HelloPerld;
use Mojo::Base 'Mojolicious';

our $VERSION = '1.0.0';

use HelloPerld::Logger::LoggerFactory;

sub startup {
    my $self = shift;

    # Initialize logger
    $self->helper(logger_instance => sub {
        state $logger = HelloPerld::Logger::LoggerFactory->create_default_logger();
        return $logger;
    });

    # Configure template path
    $self->renderer->paths->[0] = 'lib/HelloPerld/Templates';

    # Configure static file serving
    push @{$self->static->paths}, 'lib/HelloPerld/Public';

    # Use a hook to handle static files before any routing/plugin processing
    $self->hook(before_dispatch => sub {
        my $c = shift;
        my $path = $c->req->url->path->to_string;

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

    # Configure session management
    $self->sessions->default_expiration(86400); # 24 hours
    $self->secrets(['your-secret-key-change-in-production']); # TODO: Use environment variable

    # Configure OpenAPI plugin
    $self->plugin('OpenAPI' => {
        url => $self->home->rel_file('swagger/swagger.json')
    });

    # Configure SwaggerUI plugin
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

    # API Routes
    my $api = $self->routes->under('/api');

    # Authentication routes
    $api->post('/auth/login')->to('Auth#login');
    $api->post('/auth/logout')->to('Auth#logout');
    $api->get('/auth/status')->to('Auth#status');

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
            return $c->render(json => {
                success => 0,
                error => 'Authentication required'
            }, status => 401);
        }

        return 1;
    });

    # Protected article management routes
    $admin->get('/articles')->to('Articles#get_all'); # Admin can see unpublished
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

    # SPA fallback routing - catch all non-API routes and serve index.html
    # This allows Vue Router history mode to work correctly
    # IMPORTANT: Define this AFTER all API/Swagger routes to ensure proper route priority
    $self->routes->get('/*')->to(cb => sub {
        my $c = shift;
        my $path = $c->req->url->path->to_string;

        # Skip API routes and existing routes
        return if $path =~ m{^/(api|swagger)};

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
        $c->res->headers->header('X-Frame-Options' => 'DENY');
        $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
        $c->res->headers->header('X-XSS-Protection' => '1; mode=block');
        $c->res->headers->header('Referrer-Policy' => 'strict-origin-when-cross-origin');
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