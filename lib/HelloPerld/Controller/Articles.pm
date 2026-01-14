package HelloPerld::Controller::Articles;
use Mojo::Base 'Mojolicious::Controller';

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Model::Article;
use HelloPerld::Model::ArticleView;
use HelloPerld::Model::Tag;
use HelloPerld::Controller::Metrics;
use HelloPerld::Util::ErrorResponse qw(error_response);
use JSON qw(decode_json);

sub get_all {
    my $self = shift;

    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # Get query parameters
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || 20;
    my $tag_filter = $self->param('tag');

    # Default behavior based on route:
    # - Public route (/api/articles): always show only published (1)
    # - Admin route (/api/admin/articles): show all articles (undef) unless filtered
    my $published_only;
    if (defined($self->param('published'))) {
        $published_only = $self->param('published');
    } else {
        # Check if this is the admin route using stash value set by router
        my $is_admin_route = $self->stash('is_admin_route') // 0;

        # Default to published only for public routes, or all for admin routes
        $published_only = $is_admin_route ? undef : 1;
    }

    # Calculate offset
    my $offset = ($page - 1) * $limit;

    # Validate parameters
    if ($limit > 100) {
        return error_response($self, 'validation', 'Limit cannot exceed 100',
            code => 'VAL002',
            details => { field => 'limit', value => $limit, max => 100 }
        );
    }

    # Get articles
    my $articles = $article_model->get_all(
        limit => $limit,
        offset => $offset,
        tag_filter => $tag_filter,
        published_only => $published_only
    );

    unless (defined $articles) {
        return error_response($self, 'server_error', 'Failed to retrieve articles',
            code => 'DB001'
        );
    }

    # Get total count for pagination
    my $total_count = $article_model->get_count(
        tag_filter => $tag_filter,
        published_only => $published_only
    );

    my $total_pages = int(($total_count + $limit - 1) / $limit);

    # Format response
    return $self->render(json => {
        success => 1,
        articles => $articles,
        pagination => {
            current_page => $page,
            total_pages => $total_pages,
            total_count => $total_count,
            per_page => $limit,
            has_next => $page < $total_pages,
            has_prev => $page > 1
        }
    });
}

sub get_by_slug {
    my $self = shift;

    my $slug = $self->param('slug');

    unless ($slug) {
        return error_response($self, 'validation', 'Article slug is required',
            code => 'VAL001',
            details => { field => 'slug' }
        );
    }

    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $article = $article_model->get_by_slug($slug);

    unless ($article) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART001',
            details => { slug => $slug }
        );
    }

    # Check if article is published (unless admin)
    if (!$article->{is_published} && !$self->_is_admin()) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART002',
            details => { slug => $slug }
        );
    }

    # Track article view (non-blocking, wrapped in eval to not affect request)
    # Only track for non-admin users viewing published articles
    if ($article->{is_published} && !$self->_is_admin()) {
        eval {
            my $ip_address = $self->client_ip();

            # Track in Prometheus
            HelloPerld::Controller::Metrics->inc_article_view($article->{id}, $ip_address);

            # Store in database
            my $view_model = HelloPerld::Model::ArticleView->new(
                logger => $self->app->logger_instance,
                db_config => $self->db_config
            );
            $view_model->create($article->{id}, $ip_address);
        };
        if ($@) {
            $self->app->logger_instance->warn("Failed to track article view: $@");
        }
    }

    return $self->render(json => {
        success => 1,
        article => $article
    });
}

sub get_by_id {
    my $self = shift;

    my $id = $self->param('id');

    unless ($id && $id =~ /^\d+$/) {
        return error_response($self, 'validation', 'Valid article ID is required',
            code => 'VAL003',
            details => { field => 'id', value => $id }
        );
    }

    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $article = $article_model->get_by_id($id);

    unless ($article) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART003',
            details => { id => $id }
        );
    }

    # Check if article is published (unless admin)
    if (!$article->{is_published} && !$self->_is_admin()) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART004',
            details => { id => $id }
        );
    }

    return $self->render(json => {
        success => 1,
        article => $article
    });
}

sub create {
    my $self = shift;

    # Note: Authentication is handled by the /admin route middleware

    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }

    # Get article data from request
    my $article_data = $self->_parse_article_request();

    unless ($article_data) {
        return error_response($self, 'bad_request', 'Invalid article data',
            code => 'REQ001'
        );
    }

    # Validate required fields
    unless ($article_data->{title} && $article_data->{content}) {
        my @missing_fields;
        push @missing_fields, 'title' unless $article_data->{title};
        push @missing_fields, 'content' unless $article_data->{content};

        return error_response($self, 'validation', 'Required fields are missing',
            code => 'VAL004',
            details => { missing_fields => \@missing_fields }
        );
    }

    # Process tags
    if ($article_data->{tags}) {
        $article_data->{tag_ids} = $self->_process_tags($article_data->{tags});
        delete $article_data->{tags};
    }

    # Set publish timestamp if publishing
    if ($article_data->{is_published} && !$article_data->{published_at}) {
        $article_data->{published_at} = 'NOW()';
    }

    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $created_article = $article_model->create($article_data);

    unless ($created_article) {
        return error_response($self, 'server_error', 'Failed to create article',
            code => 'DB002'
        );
    }

    $self->app->logger_instance->info("Article created with ID " . $created_article->{id} . " by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Article created successfully',
        article => $created_article
    }, status => 201);
}

sub update {
    my $self = shift;

    # Note: Authentication is handled by the /admin route middleware

    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }

    my $id = $self->param('id');

    unless ($id && $id =~ /^\d+$/) {
        return error_response($self, 'validation', 'Valid article ID is required',
            code => 'VAL003',
            details => { field => 'id', value => $id }
        );
    }

    # Check if article exists
    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $existing_article = $article_model->get_by_id($id);

    unless ($existing_article) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART005',
            details => { id => $id }
        );
    }

    # Get updated article data
    my $article_data = $self->_parse_article_request();

    unless ($article_data) {
        return error_response($self, 'bad_request', 'Invalid article data',
            code => 'REQ001'
        );
    }

    # Process tags
    if (exists $article_data->{tags}) {
        $article_data->{tag_ids} = $self->_process_tags($article_data->{tags});
        delete $article_data->{tags};
    }

    # Handle published_at timestamp
    if ($article_data->{is_published} && !$existing_article->{is_published} && !$article_data->{published_at}) {
        # Article being published for the first time
        $article_data->{published_at} = 'NOW()';
    }

    # Update article
    my $rows_affected = $article_model->update($id, $article_data);

    unless ($rows_affected) {
        return error_response($self, 'server_error', 'Failed to update article',
            code => 'DB003',
            details => { id => $id }
        );
    }

    # Return updated article
    my $updated_article = $article_model->get_by_id($id);

    $self->app->logger_instance->info("Article ID $id updated by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Article updated successfully',
        article => $updated_article
    });
}

sub delete {
    my $self = shift;

    # Note: Authentication is handled by the /admin route middleware

    # CSRF protection
    unless ($self->csrf_protect) {
        return error_response($self, 'forbidden', 'CSRF validation failed',
            code => 'SEC001'
        );
    }

    my $id = $self->param('id');

    unless ($id && $id =~ /^\d+$/) {
        return error_response($self, 'validation', 'Valid article ID is required',
            code => 'VAL003',
            details => { field => 'id', value => $id }
        );
    }

    my $article_model = HelloPerld::Model::Article->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # Check if article exists before deleting
    my $existing_article = $article_model->get_by_id($id);

    unless ($existing_article) {
        return error_response($self, 'not_found', 'Article not found',
            code => 'ART006',
            details => { id => $id }
        );
    }

    my $rows_affected = $article_model->delete($id);

    unless ($rows_affected) {
        return error_response($self, 'server_error', 'Failed to delete article',
            code => 'DB004',
            details => { id => $id }
        );
    }

    $self->app->logger_instance->info("Article ID $id deleted by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Article deleted successfully'
    });
}

sub _is_admin {
    my $self = shift;

    my $user_id = $self->session('admin_user_id');
    return $user_id ? 1 : 0;
}

sub _parse_article_request {
    my $self = shift;

    my $content_type = $self->req->headers->content_type || '';

    my $data;

    if ($content_type =~ /application\/json/) {
        # JSON request
        eval {
            my $json_text = $self->req->body;
            $data = decode_json($json_text) if $json_text;
        };

        if ($@) {
            $self->app->logger_instance->error("Failed to parse JSON request: $@");
            return undef;
        }
    } else {
        # Form data request
        $data = {
            title => $self->param('title'),
            slug => $self->param('slug'),
            content => $self->param('content'),
            excerpt => $self->param('excerpt'),
            author => $self->param('author'),
            is_published => $self->param('is_published'),
            meta_description => $self->param('meta_description'),
            featured_image => $self->param('featured_image'),
            published_at => $self->param('published_at')
        };

        # Handle tags from form data
        my @tags = $self->param('tags[]');
        $data->{tags} = \@tags if @tags;
    }

    # Clean up undefined values
    if ($data) {
        foreach my $key (keys %$data) {
            delete $data->{$key} unless defined $data->{$key};
        }
    }

    return $data;
}

sub _process_tags {
    my ($self, $tag_names) = @_;

    return [] unless $tag_names && ref($tag_names) eq 'ARRAY';

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my @tag_ids;

    foreach my $tag_name (@$tag_names) {
        next unless $tag_name;

        # Find or create tag
        my $tag = $tag_model->find_or_create_by_name($tag_name);

        if ($tag && $tag->{id}) {
            push @tag_ids, $tag->{id};
        } else {
            $self->app->logger_instance->warn("Failed to create/find tag: $tag_name");
        }
    }

    return \@tag_ids;
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Articles - Article management controller

=head1 SYNOPSIS

    # Public routes
    $r->get('/api/articles')->to('Articles#get_all');
    $r->get('/api/articles/:slug')->to('Articles#get_by_slug');

    # Admin routes (protected)
    my $admin = $r->under('/api/admin')->to('Auth#require_auth');
    $admin->post('/articles')->to('Articles#create');
    $admin->put('/articles/:id')->to('Articles#update');
    $admin->delete('/articles/:id')->to('Articles#delete');

=head1 DESCRIPTION

This controller handles article management operations including listing,
creation, updating, and deletion. Public routes serve published articles
while admin routes provide full CRUD functionality.

=head1 METHODS

=head2 get_all

Retrieves articles with pagination and filtering options.

Query parameters:
- page: Page number (default: 1)
- limit: Articles per page (default: 20, max: 100)
- tag: Filter by tag slug
- published: Filter by published status (default: 1)

=head2 get_by_slug

Retrieves a single article by its slug. Only shows published articles
to non-admin users.

=head2 get_by_id

Retrieves a single article by its ID. Admin-only access for unpublished articles.

=head2 create

Creates a new article. Admin authentication required.

=head2 update

Updates an existing article. Admin authentication required.

=head2 delete

Deletes an article. Admin authentication required.

=head1 REQUEST FORMAT

Articles can be submitted as JSON or form data. Required fields:
- title: Article title
- content: Article content (markdown)

Optional fields:
- slug: URL slug (auto-generated if not provided)
- excerpt: Short description
- author: Author name (defaults to Alex Beahm)
- is_published: Publication status
- meta_description: SEO meta description
- featured_image: Featured image URL
- tags: Array of tag names

=head1 RESPONSE FORMAT

All responses are JSON with the following structure:

    {
        "success": 1|0,
        "message": "Success/error message",
        "article": { ... },        # Single article
        "articles": [ ... ],       # Multiple articles
        "pagination": { ... },     # Pagination info for lists
        "error": "Error message"   # On failure
    }

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
