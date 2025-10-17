package TestHelper;

use strict;
use warnings;
use DBD::Mock;
use HelloPerld::Logger::ConsoleLogger;
use Exporter 'import';

our @EXPORT_OK = qw(
    mock_dbh
    mock_logger
    create_test_article_data
    create_test_tag_data
    create_test_media_data
    create_test_user_data
    setup_mock_session
    mock_article_result
    mock_tag_result
    mock_media_result
);

# Create a mock database handle with DBD::Mock
sub mock_dbh {
    my %options = @_;

    my $dbh = DBI->connect(
        'DBI:Mock:',
        '',
        '',
        { RaiseError => 1, PrintError => 0 }
    ) or die "Cannot create mock database handle";

    return $dbh;
}

# Create a mock logger for testing
sub mock_logger {
    return HelloPerld::Logger::ConsoleLogger->new(
        name => 'test',
        level => 'ERROR'  # Suppress logs during tests unless ERROR
    );
}

# Generate test article data
sub create_test_article_data {
    my %overrides = @_;

    my $defaults = {
        id => 1,
        title => 'Test Article',
        slug => 'test-article',
        content => 'This is test content with **markdown**.',
        excerpt => 'Test excerpt',
        author => 'Test Author',
        is_published => 1,
        published_at => '2024-01-15 10:00:00',
        date_added => '2024-01-15 10:00:00',
        date_updated => '2024-01-15 10:00:00',
        meta_description => 'Test meta description',
        featured_image => '/uploads/2024/01/test.jpg',
    };

    return { %$defaults, %overrides };
}

# Generate test tag data
sub create_test_tag_data {
    my %overrides = @_;

    my $defaults = {
        id => 1,
        name => 'Test Tag',
        slug => 'test-tag',
        date_added => '2024-01-15 10:00:00',
        usage_count => 5,
    };

    return { %$defaults, %overrides };
}

# Generate test media data
sub create_test_media_data {
    my %overrides = @_;

    my $defaults = {
        id => 1,
        filename => 'abc123.jpg',
        original_filename => 'test-image.jpg',
        filepath => '/uploads/2024/01/abc123.jpg',
        mime_type => 'image/jpeg',
        file_size => 102400,
        width => 1920,
        height => 1080,
        uploaded_by => 1,
        created_at => '2024-01-15 10:00:00',
        alt_text => 'Test image',
        caption => 'Test caption',
    };

    return { %$defaults, %overrides };
}

# Generate test user data
sub create_test_user_data {
    my %overrides = @_;

    my $defaults = {
        id => 1,
        username => 'testadmin',
        email => 'test@example.com',
        password_hash => 'a' x 96,  # Mock hash (32 char salt + 64 char hash)
        created_at => '2024-01-15 10:00:00',
    };

    return { %$defaults, %overrides };
}

# Setup mock session for Test::Mojo
sub setup_mock_session {
    my ($t, %session_data) = @_;

    my $defaults = {
        admin_user_id => 1,
        admin_username => 'testadmin',
        admin_email => 'test@example.com',
    };

    my $session = { %$defaults, %session_data };

    # Set session data in the test instance
    $t->app->sessions->cookie_name('hello_perld_session');

    return $session;
}

# Create mock article result for DBD::Mock
sub mock_article_result {
    my @articles = @_;

    my @rows;
    for my $article (@articles) {
        push @rows, [
            $article->{id},
            $article->{title},
            $article->{slug},
            $article->{content},
            $article->{excerpt},
            $article->{author},
            $article->{published_at},
            $article->{date_added},
            $article->{date_updated},
            $article->{is_published},
            $article->{meta_description},
            $article->{featured_image},
        ];
    }

    return {
        sql => qr/SELECT.*FROM articles/i,
        results => [
            ['id', 'title', 'slug', 'content', 'excerpt', 'author',
             'published_at', 'date_added', 'date_updated', 'is_published',
             'meta_description', 'featured_image'],
            @rows
        ]
    };
}

# Create mock tag result for DBD::Mock
sub mock_tag_result {
    my @tags = @_;

    my @rows;
    for my $tag (@tags) {
        push @rows, [
            $tag->{id},
            $tag->{name},
            $tag->{slug},
            $tag->{date_added},
            $tag->{usage_count} // 0,
        ];
    }

    return {
        sql => qr/SELECT.*FROM tags/i,
        results => [
            ['id', 'name', 'slug', 'date_added', 'usage_count'],
            @rows
        ]
    };
}

# Create mock media result for DBD::Mock
sub mock_media_result {
    my @media = @_;

    my @rows;
    for my $item (@media) {
        push @rows, [
            $item->{id},
            $item->{filename},
            $item->{original_filename},
            $item->{filepath},
            $item->{mime_type},
            $item->{file_size},
            $item->{width},
            $item->{height},
            $item->{uploaded_by},
            $item->{created_at},
            $item->{alt_text},
            $item->{caption},
        ];
    }

    return {
        sql => qr/SELECT.*FROM media/i,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            @rows
        ]
    };
}

1;

__END__

=head1 NAME

TestHelper - Shared testing utilities for TheBoosh.Zone

=head1 SYNOPSIS

    use lib 't/lib';
    use TestHelper qw(mock_dbh mock_logger create_test_article_data);

    my $dbh = mock_dbh();
    my $logger = mock_logger();
    my $article = create_test_article_data(title => 'Custom Title');

=head1 DESCRIPTION

This module provides shared utilities for testing TheBoosh.Zone backend code,
including mock database handles, test data generators, and session helpers.

=head1 FUNCTIONS

=head2 mock_dbh()

Creates a DBD::Mock database handle for testing without a real database.

=head2 mock_logger()

Creates a console logger configured for test environments (ERROR level only).

=head2 create_test_article_data(%overrides)

Generates test article data with sensible defaults. Pass key-value pairs to override.

=head2 create_test_tag_data(%overrides)

Generates test tag data with sensible defaults.

=head2 create_test_media_data(%overrides)

Generates test media data with sensible defaults.

=head2 create_test_user_data(%overrides)

Generates test user data with sensible defaults.

=head2 setup_mock_session($t, %session_data)

Sets up a mock admin session for Test::Mojo tests.

=head2 mock_article_result(@articles)

Creates a DBD::Mock result set for article queries.

=head2 mock_tag_result(@tags)

Creates a DBD::Mock result set for tag queries.

=head2 mock_media_result(@media)

Creates a DBD::Mock result set for media queries.

=head1 AUTHOR

Alex Beahm <alexanderbeahm@gmail.com>

=cut
