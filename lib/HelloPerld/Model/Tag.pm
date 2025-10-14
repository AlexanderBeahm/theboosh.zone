package HelloPerld::Model::Tag;

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

sub get_all {
    my ($self, %params) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $limit = $params{limit} || 100;
    my $offset = $params{offset} || 0;
    my $order_by = $params{order_by} || 'name';

    my $sql = q{
        SELECT id, name, slug, date_added
        FROM tags
        ORDER BY
    };

    if ($order_by eq 'usage') {
        $sql .= q{
            (SELECT COUNT(*) FROM article_tags WHERE tag_id = tags.id) DESC,
            name ASC
        };
    } else {
        $sql .= "name ASC";
    }

    $sql .= " LIMIT ? OFFSET ?";

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($limit, $offset);

        my @tags;
        while (my $row = $sth->fetchrow_hashref()) {
            # Get usage count for this tag
            $row->{usage_count} = $self->get_tag_usage_count($row->{id});
            push @tags, $row;
        }

        $dbh->disconnect();
        return \@tags;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch tags: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub get_by_id {
    my ($self, $id) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $sql = q{
        SELECT id, name, slug, date_added
        FROM tags
        WHERE id = ?
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($id);

        my $tag = $sth->fetchrow_hashref();

        if ($tag) {
            $tag->{usage_count} = $self->get_tag_usage_count($tag->{id});
        }

        $dbh->disconnect();
        return $tag;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch tag by ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub get_by_slug {
    my ($self, $slug) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $sql = q{
        SELECT id, name, slug, date_added
        FROM tags
        WHERE slug = ?
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug);

        my $tag = $sth->fetchrow_hashref();

        if ($tag) {
            $tag->{usage_count} = $self->get_tag_usage_count($tag->{id});
        }

        $dbh->disconnect();
        return $tag;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch tag by slug '$slug': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub get_by_name {
    my ($self, $name) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    my $sql = q{
        SELECT id, name, slug, date_added
        FROM tags
        WHERE name = ?
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($name);

        my $tag = $sth->fetchrow_hashref();

        if ($tag) {
            $tag->{usage_count} = $self->get_tag_usage_count($tag->{id});
        }

        $dbh->disconnect();
        return $tag;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch tag by name '$name': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub create {
    my ($self, $tag_data) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    # Generate slug from name if not provided
    if (!$tag_data->{slug}) {
        $tag_data->{slug} = $self->generate_slug($tag_data->{name});
    }

    eval {
        my $sql = q{
            INSERT INTO tags (name, slug)
            VALUES (?, ?)
            RETURNING id
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute($tag_data->{name}, $tag_data->{slug});

        my ($tag_id) = $sth->fetchrow_array();

        $dbh->disconnect();
        return $tag_id;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to create tag: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub update {
    my ($self, $id, $tag_data) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    eval {
        my $sql = q{
            UPDATE tags
            SET name = ?, slug = ?
            WHERE id = ?
        };

        my $sth = $dbh->prepare($sql);
        my $rows_affected = $sth->execute($tag_data->{name}, $tag_data->{slug}, $id);

        $dbh->disconnect();
        return $rows_affected;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to update tag ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub delete {
    my ($self, $id) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return undef unless $dbh;

    eval {
        my $sql = "DELETE FROM tags WHERE id = ?";
        my $sth = $dbh->prepare($sql);
        my $rows_affected = $sth->execute($id);

        $dbh->disconnect();
        return $rows_affected;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to delete tag ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }
}

sub get_tag_usage_count {
    my ($self, $tag_id) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return 0 unless $dbh;

    my $sql = q{
        SELECT COUNT(*)
        FROM article_tags at
        INNER JOIN articles a ON at.article_id = a.id
        WHERE at.tag_id = ? AND a.is_published = true
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($tag_id);

        my ($count) = $sth->fetchrow_array();
        $dbh->disconnect();

        return $count || 0;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get tag usage count for ID '$tag_id': $@");
        }
        $dbh->disconnect() if $dbh;
        return 0;
    }
}

sub get_popular_tags {
    my ($self, $limit) = @_;

    $limit ||= 10;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return [] unless $dbh;

    my $sql = q{
        SELECT t.id, t.name, t.slug, t.date_added,
               COUNT(at.article_id) as usage_count
        FROM tags t
        LEFT JOIN article_tags at ON t.id = at.tag_id
        LEFT JOIN articles a ON at.article_id = a.id AND a.is_published = true
        GROUP BY t.id, t.name, t.slug, t.date_added
        HAVING COUNT(at.article_id) > 0
        ORDER BY usage_count DESC, t.name ASC
        LIMIT ?
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($limit);

        my @tags;
        while (my $row = $sth->fetchrow_hashref()) {
            push @tags, $row;
        }

        $dbh->disconnect();
        return \@tags;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch popular tags: $@");
        }
        $dbh->disconnect() if $dbh;
        return [];
    }
}

sub search {
    my ($self, $search_term, $limit) = @_;

    $limit ||= 20;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return [] unless $dbh;

    my $sql = q{
        SELECT id, name, slug, date_added
        FROM tags
        WHERE name ILIKE ?
        ORDER BY name ASC
        LIMIT ?
    };

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute("%$search_term%", $limit);

        my @tags;
        while (my $row = $sth->fetchrow_hashref()) {
            $row->{usage_count} = $self->get_tag_usage_count($row->{id});
            push @tags, $row;
        }

        $dbh->disconnect();
        return \@tags;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to search tags with term '$search_term': $@");
        }
        $dbh->disconnect() if $dbh;
        return [];
    }
}

sub find_or_create_by_name {
    my ($self, $name) = @_;

    # First try to find existing tag
    my $existing_tag = $self->get_by_name($name);
    return $existing_tag if $existing_tag;

    # Create new tag if not found
    my $tag_id = $self->create({
        name => $name,
        slug => $self->generate_slug($name)
    });

    return $tag_id ? $self->get_by_id($tag_id) : undef;
}

sub generate_slug {
    my ($self, $name) = @_;

    # Convert to lowercase and replace spaces/special chars with hyphens
    my $slug = lc($name);
    $slug =~ s/[^a-z0-9\s-]//g;     # Remove non-alphanumeric chars (except spaces and hyphens)
    $slug =~ s/\s+/-/g;             # Replace spaces with hyphens
    $slug =~ s/--+/-/g;             # Replace multiple hyphens with single
    $slug =~ s/^-|-$//g;            # Remove leading/trailing hyphens

    return $slug;
}

sub get_count {
    my ($self) = @_;

    my $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    return 0 unless $dbh;

    my $sql = "SELECT COUNT(*) FROM tags";

    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute();

        my ($count) = $sth->fetchrow_array();
        $dbh->disconnect();

        return $count || 0;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get tag count: $@");
        }
        $dbh->disconnect() if $dbh;
        return 0;
    }
}

1;

__END__

=head1 NAME

HelloPerld::Model::Tag - Tag data model and database operations

=head1 SYNOPSIS

    use HelloPerld::Model::Tag;

    my $tag_model = HelloPerld::Model::Tag->new(logger => $logger);

    # Get all tags
    my $tags = $tag_model->get_all();

    # Get tag by slug
    my $tag = $tag_model->get_by_slug('perl');

    # Create new tag
    my $tag_id = $tag_model->create({
        name => 'Perl Programming',
        slug => 'perl'
    });

    # Find or create tag by name
    my $tag = $tag_model->find_or_create_by_name('JavaScript');

=head1 DESCRIPTION

This module provides database operations for tags in the HelloPerld application.
It handles CRUD operations and provides methods for retrieving tags with usage
statistics and search capabilities.

=head1 METHODS

=head2 new

Creates a new Tag model instance.

=head2 get_all

Retrieves all tags with optional ordering and pagination.

=head2 get_by_id

Retrieves a single tag by its ID.

=head2 get_by_slug

Retrieves a single tag by its slug.

=head2 get_by_name

Retrieves a single tag by its name.

=head2 create

Creates a new tag.

=head2 update

Updates an existing tag.

=head2 delete

Deletes a tag by ID.

=head2 get_popular_tags

Retrieves the most frequently used tags.

=head2 search

Searches for tags by name.

=head2 find_or_create_by_name

Finds an existing tag by name or creates a new one.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut