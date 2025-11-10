package HelloPerld::Controller::Tags;
use Mojo::Base 'Mojolicious::Controller';

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Model::Tag;
use HelloPerld::Util::ErrorResponse qw(error_response);
use JSON qw(decode_json);

sub get_all {
    my $self = shift;

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # Get query parameters
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || 50;
    my $order_by = $self->param('order') || 'name';

    # Calculate offset
    my $offset = ($page - 1) * $limit;

    # Validate parameters
    if ($limit > 100) {
        return error_response($self, 'validation', 'Limit cannot exceed 100',
            code => 'VAL002',
            details => { field => 'limit', value => $limit, max => 100 }
        );
    }

    unless ($order_by =~ /^(name|usage)$/) {
        return error_response($self, 'validation', 'Order must be either "name" or "usage"',
            code => 'VAL009',
            details => { field => 'order', value => $order_by, allowed_values => ['name', 'usage'] }
        );
    }

    # Get tags
    my $tags = $tag_model->get_all(
        limit => $limit,
        offset => $offset,
        order_by => $order_by
    );

    unless (defined $tags) {
        return error_response($self, 'server_error', 'Failed to retrieve tags',
            code => 'DB006'
        );
    }

    # Get total count for pagination
    my $total_count = $tag_model->get_count();
    my $total_pages = int(($total_count + $limit - 1) / $limit);

    return $self->render(json => {
        success => 1,
        tags => $tags,
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

sub get_popular {
    my $self = shift;

    my $limit = $self->param('limit') || 10;

    # Validate limit
    if ($limit > 50) {
        return error_response($self, 'validation', 'Limit cannot exceed 50',
            code => 'VAL010',
            details => { field => 'limit', value => $limit, max => 50 }
        );
    }

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $popular_tags = $tag_model->get_popular_tags($limit);

    unless (defined $popular_tags) {
        return error_response($self, 'server_error', 'Failed to retrieve popular tags',
            code => 'DB007'
        );
    }

    return $self->render(json => {
        success => 1,
        tags => $popular_tags
    });
}

sub get_by_slug {
    my $self = shift;

    my $slug = $self->param('slug');

    unless ($slug) {
        return error_response($self, 'validation', 'Tag slug is required',
            code => 'VAL011',
            details => { field => 'slug' }
        );
    }

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $tag = $tag_model->get_by_slug($slug);

    unless ($tag) {
        return error_response($self, 'not_found', 'Tag not found',
            code => 'TAG001',
            details => { slug => $slug }
        );
    }

    return $self->render(json => {
        success => 1,
        tag => $tag
    });
}

sub get_by_id {
    my $self = shift;

    my $id = $self->param('id');

    unless ($id && $id =~ /^\d+$/) {
        return error_response($self, 'validation', 'Valid tag ID is required',
            code => 'VAL012',
            details => { field => 'id', value => $id }
        );
    }

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $tag = $tag_model->get_by_id($id);

    unless ($tag) {
        return error_response($self, 'not_found', 'Tag not found',
            code => 'TAG002',
            details => { id => $id }
        );
    }

    return $self->render(json => {
        success => 1,
        tag => $tag
    });
}

sub search {
    my $self = shift;

    my $q = $self->param('q');
    my $limit = $self->param('limit') || 20;

    unless ($q) {
        return error_response($self, 'validation', 'Search query is required',
            code => 'VAL013',
            details => { field => 'q' }
        );
    }

    # Validate limit
    if ($limit > 50) {
        return error_response($self, 'validation', 'Limit cannot exceed 50',
            code => 'VAL010',
            details => { field => 'limit', value => $limit, max => 50 }
        );
    }

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $tags = $tag_model->search($q, $limit);

    unless (defined $tags) {
        return error_response($self, 'server_error', 'Failed to search tags',
            code => 'DB008',
            details => { search_query => $q }
        );
    }

    return $self->render(json => {
        success => 1,
        tags => $tags,
        search_query => $q
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

    # Get tag data from request
    my $tag_data = $self->_parse_tag_request();

    unless ($tag_data && $tag_data->{name}) {
        return error_response($self, 'validation', 'Tag name is required',
            code => 'VAL014',
            details => { field => 'name' }
        );
    }

    # Check if tag already exists
    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $existing_tag = $tag_model->get_by_name($tag_data->{name});

    if ($existing_tag) {
        return error_response($self, 'conflict', 'Tag with this name already exists',
            code => 'TAG003',
            details => { name => $tag_data->{name} }
        );
    }

    # Generate slug if not provided
    unless ($tag_data->{slug}) {
        $tag_data->{slug} = $tag_model->generate_slug($tag_data->{name});
    }

    my $created_tag = $tag_model->create($tag_data);

    unless ($created_tag) {
        return error_response($self, 'server_error', 'Failed to create tag',
            code => 'DB009',
            details => { name => $tag_data->{name} }
        );
    }

    $self->app->logger_instance->info("Tag created with ID " . $created_tag->{id} . " by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Tag created successfully',
        tag => $created_tag
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
        return error_response($self, 'validation', 'Valid tag ID is required',
            code => 'VAL012',
            details => { field => 'id', value => $id }
        );
    }

    # Check if tag exists
    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );
    my $existing_tag = $tag_model->get_by_id($id);

    unless ($existing_tag) {
        return error_response($self, 'not_found', 'Tag not found',
            code => 'TAG004',
            details => { id => $id }
        );
    }

    # Get updated tag data
    my $tag_data = $self->_parse_tag_request();

    unless ($tag_data && $tag_data->{name}) {
        return error_response($self, 'validation', 'Tag name is required',
            code => 'VAL014',
            details => { field => 'name' }
        );
    }

    # Check if another tag with this name exists (excluding current tag)
    if ($tag_data->{name} ne $existing_tag->{name}) {
        my $duplicate_tag = $tag_model->get_by_name($tag_data->{name});
        if ($duplicate_tag && $duplicate_tag->{id} != $id) {
            return error_response($self, 'conflict', 'Another tag with this name already exists',
                code => 'TAG005',
                details => { name => $tag_data->{name}, existing_id => $duplicate_tag->{id} }
            );
        }
    }

    # Generate slug if not provided
    unless ($tag_data->{slug}) {
        $tag_data->{slug} = $tag_model->generate_slug($tag_data->{name});
    }

    # Update tag
    my $rows_affected = $tag_model->update($id, $tag_data);

    unless ($rows_affected) {
        return error_response($self, 'server_error', 'Failed to update tag',
            code => 'DB010',
            details => { id => $id }
        );
    }

    # Return updated tag
    my $updated_tag = $tag_model->get_by_id($id);

    $self->app->logger_instance->info("Tag ID $id updated by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Tag updated successfully',
        tag => $updated_tag
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
        return error_response($self, 'validation', 'Valid tag ID is required',
            code => 'VAL012',
            details => { field => 'id', value => $id }
        );
    }

    my $tag_model = HelloPerld::Model::Tag->new(
        logger => $self->app->logger_instance,
        db_config => $self->db_config
    );

    # Check if tag exists and get usage count
    my $existing_tag = $tag_model->get_by_id($id);

    unless ($existing_tag) {
        return error_response($self, 'not_found', 'Tag not found',
            code => 'TAG006',
            details => { id => $id }
        );
    }

    # Check if tag is in use
    if ($existing_tag->{usage_count} > 0) {
        return error_response($self, 'conflict', 'Cannot delete tag that is currently in use by articles',
            code => 'TAG007',
            details => { id => $id, usage_count => $existing_tag->{usage_count} }
        );
    }

    my $rows_affected = $tag_model->delete($id);

    unless ($rows_affected) {
        return error_response($self, 'server_error', 'Failed to delete tag',
            code => 'DB011',
            details => { id => $id }
        );
    }

    $self->app->logger_instance->info("Tag ID $id deleted by admin user " . $self->session('admin_username'));

    return $self->render(json => {
        success => 1,
        message => 'Tag deleted successfully'
    });
}

sub _is_admin {
    my $self = shift;

    my $user_id = $self->session('admin_user_id');
    return $user_id ? 1 : 0;
}

sub _parse_tag_request {
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
            name => $self->param('name'),
            slug => $self->param('slug')
        };
    }

    # Clean up undefined values
    if ($data) {
        foreach my $key (keys %$data) {
            delete $data->{$key} unless defined $data->{$key};
        }

        # Trim whitespace from name
        if ($data->{name}) {
            $data->{name} =~ s/^\s+|\s+$//g;
        }

        # Validate name
        if ($data->{name} && length($data->{name}) > 100) {
            return undef;
        }
    }

    return $data;
}

1;

__END__

=head1 NAME

HelloPerld::Controller::Tags - Tag management controller

=head1 SYNOPSIS

    # Public routes
    $r->get('/api/tags')->to('Tags#get_all');
    $r->get('/api/tags/popular')->to('Tags#get_popular');
    $r->get('/api/tags/search')->to('Tags#search');
    $r->get('/api/tags/:slug')->to('Tags#get_by_slug');

    # Admin routes (protected)
    my $admin = $r->under('/api/admin')->to('Auth#require_auth');
    $admin->post('/tags')->to('Tags#create');
    $admin->put('/tags/:id')->to('Tags#update');
    $admin->delete('/tags/:id')->to('Tags#delete');

=head1 DESCRIPTION

This controller handles tag management operations including listing,
searching, creation, updating, and deletion. Public routes serve tag
information while admin routes provide full CRUD functionality.

=head1 METHODS

=head2 get_all

Retrieves all tags with pagination and ordering options.

Query parameters:
- page: Page number (default: 1)
- limit: Tags per page (default: 50, max: 100)
- order: Sort order - 'name' or 'usage' (default: name)

=head2 get_popular

Retrieves the most popular tags (sorted by usage count).

Query parameters:
- limit: Number of tags to return (default: 10, max: 50)

=head2 get_by_slug

Retrieves a single tag by its slug.

=head2 get_by_id

Retrieves a single tag by its ID.

=head2 search

Searches for tags by name.

Query parameters:
- q: Search query (required)
- limit: Number of results (default: 20, max: 50)

=head2 create

Creates a new tag. Admin authentication required.

=head2 update

Updates an existing tag. Admin authentication required.

=head2 delete

Deletes a tag (only if not in use). Admin authentication required.

=head1 REQUEST FORMAT

Tags can be submitted as JSON or form data. Required fields:
- name: Tag name (max 100 characters)

Optional fields:
- slug: URL slug (auto-generated if not provided)

=head1 RESPONSE FORMAT

All responses are JSON with the following structure:

    {
        "success": 1|0,
        "message": "Success/error message",
        "tag": { ... },            # Single tag
        "tags": [ ... ],           # Multiple tags
        "pagination": { ... },     # Pagination info for lists
        "error": "Error message"   # On failure
    }

Each tag object includes:
- id: Tag ID
- name: Tag name
- slug: URL slug
- usage_count: Number of published articles using this tag
- date_added: Creation timestamp

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
