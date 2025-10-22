package HelloPerld::Model::Article;

use strict;
use warnings;

our $VERSION = '1.0.0';

use HelloPerld::Database::Postgres;

sub new {
    my ($class, %args) = @_;

    my $self = {
        logger => $args{logger},
        db_config => $args{db_config} || {},
    };

    return bless $self, $class;
}

sub get_all {
    my ($self, %params) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    my $limit = $params{limit} || 20;
    my $offset = $params{offset} || 0;
    my $published_only = $params{published_only};
    my $tag_filter = $params{tag_filter};

    my $sql = q{
        SELECT DISTINCT a.id, a.title, a.slug, a.excerpt, a.author,
               a.published_at, a.date_added, a.date_updated, a.is_published,
               a.meta_description, a.featured_image
        FROM articles a
    };

    my @where_conditions;
    my @bind_params;

    if (defined $published_only) {
        push @where_conditions, "a.is_published = ?";
        push @bind_params, $published_only ? 1 : 0;
    }

    if ($tag_filter) {
        $sql .= q{
            INNER JOIN article_tags at ON a.id = at.article_id
            INNER JOIN tags t ON at.tag_id = t.id
        };
        push @where_conditions, "t.slug = ?";
        push @bind_params, $tag_filter;
    }

    if (@where_conditions) {
        $sql .= " WHERE " . join(" AND ", @where_conditions);
    }

    $sql .= " ORDER BY a.published_at DESC, a.date_added DESC";
    $sql .= " LIMIT ? OFFSET ?";
    push @bind_params, $limit, $offset;

    my $articles;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute(@bind_params);

        my @articles_array;
        while (my $row = $sth->fetchrow_hashref()) {
            push @articles_array, $row;
        }
        $sth->finish();
        $dbh->disconnect();

        # Fetch tags for each article after disconnecting
        foreach my $article (@articles_array) {
            $article->{tags} = $self->get_article_tags($article->{id});
        }

        $articles = \@articles_array;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch articles: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $articles;
}

sub get_by_slug {
    my ($self, $slug) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    my $sql = q{
        SELECT id, title, slug, content, excerpt, author,
               published_at, date_added, date_updated, is_published,
               meta_description, featured_image
        FROM articles
        WHERE slug = ?
    };

    my $article;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($slug);

        $article = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch article by slug '$slug': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    # Fetch tags after successful query
    if ($article) {
        $article->{tags} = $self->get_article_tags($article->{id});
    }

    return $article;
}

sub get_by_id {
    my ($self, $id) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    my $sql = q{
        SELECT id, title, slug, content, excerpt, author,
               published_at, date_added, date_updated, is_published,
               meta_description, featured_image
        FROM articles
        WHERE id = ?
    };

    my $article;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($id);

        $article = $sth->fetchrow_hashref();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch article by ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    # Fetch tags after successful query
    if ($article) {
        $article->{tags} = $self->get_article_tags($article->{id});
    }

    return $article;
}

sub create {
    my ($self, $article_data) = @_;

    # If not passed as a hashref, assume it's named parameters
    unless (ref($article_data) eq 'HASH') {
        my %params = @_;
        shift @_;  # Remove $self
        $article_data = { @_ };
    }

    # Security: Validate input lengths to prevent DoS via memory exhaustion
    if (defined $article_data->{content} && length($article_data->{content}) > 1_000_000) {
        if ($self->{logger}) {
            $self->{logger}->error("Article content exceeds maximum length of 1MB");
        }
        return undef;
    }
    if (defined $article_data->{title} && length($article_data->{title}) > 500) {
        if ($self->{logger}) {
            $self->{logger}->error("Article title exceeds maximum length of 500 characters");
        }
        return undef;
    }
    if (defined $article_data->{excerpt} && length($article_data->{excerpt}) > 2000) {
        if ($self->{logger}) {
            $self->{logger}->error("Article excerpt exceeds maximum length of 2000 characters");
        }
        return undef;
    }

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    # Generate slug from title if not provided
    if (!$article_data->{slug}) {
        $article_data->{slug} = $self->generate_slug($article_data->{title});
    }

    # Set default author if not provided
    $article_data->{author} //= 'Alex Beahm';

    my $article_id;
    my $tag_ids = $article_data->{tag_ids};

    eval {
        $dbh->begin_work();

        my $sql = q{
            INSERT INTO articles (title, slug, content, excerpt, author,
                                published_at, is_published, meta_description, featured_image)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $article_data->{title},
            $article_data->{slug},
            $article_data->{content},
            $article_data->{excerpt},
            $article_data->{author},
            $article_data->{published_at},
            $article_data->{is_published} // 0,
            $article_data->{meta_description},
            $article_data->{featured_image}
        );

        ($article_id) = $sth->fetchrow_array();
        $sth->finish();

        $dbh->commit();
        $dbh->disconnect();
    };

    if ($@) {
        $dbh->rollback();
        if ($self->{logger}) {
            $self->{logger}->error("Failed to create article: $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    # Add tags AFTER article is committed (so foreign key constraint is satisfied)
    if ($self->{logger}) {
        $self->{logger}->info("About to set tags for article $article_id. tag_ids = " .
            (defined $tag_ids ? "array with " . scalar(@{$tag_ids}) . " elements: [" . join(", ", @{$tag_ids}) . "]" : "undef"));
    }

    if ($article_id && $tag_ids && @{$tag_ids}) {
        my $tag_result = $self->set_article_tags($article_id, $tag_ids);
        unless ($tag_result) {
            if ($self->{logger}) {
                $self->{logger}->error("Article created but failed to set tags for article ID '$article_id'");
            }
            # Article was created successfully, so continue
        }
    } else {
        if ($self->{logger}) {
            $self->{logger}->warn("Skipping set_article_tags: article_id=$article_id, tag_ids is " .
                (defined $tag_ids ? "array with " . scalar(@{$tag_ids}) . " elements" : "undef"));
        }
    }

    # Fetch and return the complete article object
    return $self->get_by_id($article_id);
}

sub update {
    my ($self, $id, $article_data) = @_;

    # If not passed as a hashref, assume it's named parameters
    unless (ref($article_data) eq 'HASH') {
        my @args = @_;
        shift @args; # Remove $self
        shift @args; # Remove $id
        $article_data = { @args };
    }

    # Security: Validate input lengths to prevent DoS via memory exhaustion
    if (defined $article_data->{content} && length($article_data->{content}) > 1_000_000) {
        if ($self->{logger}) {
            $self->{logger}->error("Article content exceeds maximum length of 1MB");
        }
        return undef;
    }
    if (defined $article_data->{title} && length($article_data->{title}) > 500) {
        if ($self->{logger}) {
            $self->{logger}->error("Article title exceeds maximum length of 500 characters");
        }
        return undef;
    }
    if (defined $article_data->{excerpt} && length($article_data->{excerpt}) > 2000) {
        if ($self->{logger}) {
            $self->{logger}->error("Article excerpt exceeds maximum length of 2000 characters");
        }
        return undef;
    }

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    my $rows_affected;
    my $should_update_tags = exists $article_data->{tag_ids};
    my $tag_ids = $article_data->{tag_ids};

    eval {
        $dbh->begin_work();

        # Build dynamic SQL to only update provided fields
        my @set_clauses = ('date_updated = CURRENT_TIMESTAMP');
        my @bind_params = ();

        my @valid_fields = qw(title slug content excerpt author published_at is_published meta_description featured_image);

        foreach my $field (@valid_fields) {
            if (exists $article_data->{$field}) {
                push @set_clauses, "$field = ?";
                push @bind_params, $article_data->{$field};
            }
        }

        my $sql = "UPDATE articles SET " . join(', ', @set_clauses) . " WHERE id = ?";
        push @bind_params, $id;

        my $sth = $dbh->prepare($sql);
        $rows_affected = $sth->execute(@bind_params);

        $dbh->commit();
        $dbh->disconnect();
    };

    if ($@) {
        $dbh->rollback();
        if ($self->{logger}) {
            $self->{logger}->error("Failed to update article ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    # Update tags AFTER article is committed (so foreign key constraint is satisfied)
    if ($should_update_tags) {
        my $tag_result = $self->set_article_tags($id, $tag_ids);
        unless ($tag_result) {
            if ($self->{logger}) {
                $self->{logger}->error("Article updated but failed to set tags for article ID '$id'");
            }
            # Article was updated successfully, so still return rows_affected
        }
    }

    return $rows_affected;
}

sub delete {
    my ($self, $id) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return undef unless $dbh;

    my $rows_affected;
    eval {
        my $sql = "DELETE FROM articles WHERE id = ?";
        my $sth = $dbh->prepare($sql);
        $rows_affected = $sth->execute($id);

        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to delete article ID '$id': $@");
        }
        $dbh->disconnect() if $dbh;
        return undef;
    }

    return $rows_affected;
}

sub get_article_tags {
    my ($self, $article_id) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return [] unless $dbh;

    my $sql = q{
        SELECT t.id, t.name, t.slug
        FROM tags t
        INNER JOIN article_tags at ON t.id = at.tag_id
        WHERE at.article_id = ?
        ORDER BY t.name
    };

    my $tags;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute($article_id);

        my @tags_array;
        while (my $row = $sth->fetchrow_hashref()) {
            push @tags_array, $row;
        }
        $sth->finish();

        $dbh->disconnect();
        $tags = \@tags_array;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to fetch tags for article ID '$article_id': $@");
        }
        $dbh->disconnect() if $dbh;
        return [];
    }

    return $tags;
}

sub set_article_tags {
    my ($self, $article_id, $tag_ids, $dbh) = @_;

    # If no database handle provided, get a new connection
    my $should_disconnect = 0;
    unless ($dbh) {
        if ($self->{db_config} && %{$self->{db_config}}) {
            $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
        } else {
            $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
        }
        return 0 unless $dbh;
        $should_disconnect = 1;
    }

    my $success = 0;
    eval {
        # Remove existing tags
        my $delete_sql = "DELETE FROM article_tags WHERE article_id = ?";
        my $delete_sth = $dbh->prepare($delete_sql);
        $delete_sth->execute($article_id);

        # Add new tags
        if ($tag_ids && @$tag_ids) {
            my $insert_sql = "INSERT INTO article_tags (article_id, tag_id) VALUES (?, ?)";
            my $insert_sth = $dbh->prepare($insert_sql);

            foreach my $tag_id (@$tag_ids) {
                $insert_sth->execute($article_id, $tag_id);
            }
        }

        $success = 1;
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to set tags for article ID '$article_id': $@");
        }
        $dbh->disconnect() if $should_disconnect;
        return 0;
    }

    $dbh->disconnect() if $should_disconnect;
    return $success;
}

sub generate_slug {
    my ($self, $title) = @_;

    # Convert to lowercase and replace spaces/special chars with hyphens
    my $slug = lc($title);
    $slug =~ s/[^a-z0-9\s-]//g;     # Remove non-alphanumeric chars (except spaces and hyphens)
    $slug =~ s/\s+/-/g;             # Replace spaces with hyphens
    $slug =~ s/--+/-/g;             # Replace multiple hyphens with single
    $slug =~ s/^-|-$//g;            # Remove leading/trailing hyphens

    return $slug;
}

sub get_count {
    my ($self, %params) = @_;

    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres::get_connection_from_config($self->{logger}, $self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres::get_connection($self->{logger});
    }
    return 0 unless $dbh;

    my $published_only = $params{published_only};
    my $tag_filter = $params{tag_filter};

    my $sql = "SELECT COUNT(DISTINCT a.id) FROM articles a";
    my @where_conditions;
    my @bind_params;

    if (defined $published_only) {
        push @where_conditions, "a.is_published = ?";
        push @bind_params, $published_only ? 1 : 0;
    }

    if ($tag_filter) {
        $sql .= q{
            INNER JOIN article_tags at ON a.id = at.article_id
            INNER JOIN tags t ON at.tag_id = t.id
        };
        push @where_conditions, "t.slug = ?";
        push @bind_params, $tag_filter;
    }

    if (@where_conditions) {
        $sql .= " WHERE " . join(" AND ", @where_conditions);
    }

    my $count;
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->execute(@bind_params);

        ($count) = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
    };

    if ($@) {
        if ($self->{logger}) {
            $self->{logger}->error("Failed to get article count: $@");
        }
        $dbh->disconnect() if $dbh;
        return 0;
    }

    return $count || 0;
}

1;

__END__

=head1 NAME

HelloPerld::Model::Article - Article data model and database operations

=head1 SYNOPSIS

    use HelloPerld::Model::Article;

    my $article_model = HelloPerld::Model::Article->new(logger => $logger);

    # Get all articles with pagination
    my $articles = $article_model->get_all(limit => 10, offset => 0);

    # Get article by slug
    my $article = $article_model->get_by_slug('my-article-slug');

    # Create new article
    my $article_id = $article_model->create({
        title => 'My Article',
        content => 'Article content...',
        is_published => 1
    });

=head1 DESCRIPTION

This module provides database operations for articles in the HelloPerld application.
It handles CRUD operations, tag associations, and provides methods for retrieving
articles with various filtering and pagination options.

=head1 SECURITY

This module implements several security best practices:

=over 4

=item * B<SQL Injection Prevention>: All database queries use prepared statements with
parameterized queries. User input is never interpolated directly into SQL.

=item * B<Input Length Validation>: Content is limited to 1MB, titles to 500 characters,
and excerpts to 2000 characters to prevent memory exhaustion attacks.

=item * B<Error Handling>: Database errors are logged but generic errors are returned
to prevent information disclosure.

=item * B<Access Control>: Published/unpublished status is enforced at the model level
to ensure proper authorization checks in controllers.

=back

=head1 METHODS

=head2 new

Creates a new Article model instance.

=head2 get_all

Retrieves articles with optional filtering and pagination.

=head2 get_by_slug

Retrieves a single article by its slug.

=head2 get_by_id

Retrieves a single article by its ID.

=head2 create

Creates a new article.

=head2 update

Updates an existing article.

=head2 delete

Deletes an article by ID.

=head2 get_article_tags

Retrieves tags associated with an article.

=head2 set_article_tags

Sets the tags for an article.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 Alex Beahm

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
