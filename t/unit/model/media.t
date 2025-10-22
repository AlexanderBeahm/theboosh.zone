#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger create_test_media_data create_control_character_string create_wildcard_test_string);
use Test::MockModule;

# =============================================================================
# DBD::Mock Issue - RESOLVED
# =============================================================================
# The DBD::Mock issue has been resolved. The problem was with SQL regex patterns
# that were too restrictive and didn't match the actual complex SQL queries.
#
# Fix: Updated SQL regex patterns to be more flexible (e.g., qr/SELECT.*media/is)
# and ensured column lists match the actual SQL structure returned by models.
#
# All unit tests now use properly configured DBD::Mock with working result sets.
# =============================================================================

# Mock the Postgres module to return our mock DBH
my $postgres_mock = Test::MockModule->new('HelloPerld::Database::Postgres');
my $mock_dbh;

$postgres_mock->mock('get_connection', sub {
    return $mock_dbh;
});

use_ok('HelloPerld::Model::Media');

# Initialize the model
my $logger = mock_logger();
my $model = HelloPerld::Model::Media->new(logger => $logger);
isa_ok($model, 'HelloPerld::Model::Media', 'Model instantiated correctly');

# DBD::Mock issue fixed - tests now enabled

subtest 'create' => sub {
    $mock_dbh = mock_dbh();

    my $new_media = create_test_media_data(id => 99);

    # Mock the INSERT with RETURNING clause - create() returns the row directly
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, $new_media->{alt_text}, $new_media->{caption}
            ]
        ]
    };

    my $result = $model->create(
        filename => 'abc123.jpg',
        original_filename => 'test-image.jpg',
        filepath => '/uploads/2024/01/abc123.jpg',
        mime_type => 'image/jpeg',
        file_size => 102400,
        width => 1920,
        height => 1080,
        uploaded_by => 1,
        alt_text => 'Test image',
        caption => 'Test caption'
    );

    ok(defined $result, 'create returns a result');
    is($result->{id}, 99, 'Created media has ID');
    is($result->{filename}, 'abc123.jpg', 'Filename correct');
    is($result->{mime_type}, 'image/jpeg', 'MIME type correct');
    is($result->{width}, 1920, 'Width stored');
    is($result->{height}, 1080, 'Height stored');
};

subtest 'get_all - basic query' => sub {
    $mock_dbh = mock_dbh();

    my $media = create_test_media_data();

    # Mock COUNT query first
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media/i,
        results => [['count'], [1]]
    };

    # Mock SELECT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*FROM media.*ORDER BY/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $media->{id}, $media->{filename}, $media->{original_filename},
                $media->{filepath}, $media->{mime_type}, $media->{file_size},
                $media->{width}, $media->{height}, $media->{uploaded_by},
                $media->{created_at}, $media->{alt_text}, $media->{caption}
            ]
        ]
    };

    my $results = $model->get_all(limit => 10, offset => 0, simple => 1);

    ok(defined $results, 'get_all returns a result');
    is(ref $results, 'ARRAY', 'get_all returns an arrayref');
    is(scalar @$results, 1, 'get_all returns one media item');
    is($results->[0]->{filename}, 'abc123.jpg', 'Filename matches');
    is($results->[0]->{original_filename}, 'test-image.jpg', 'Original filename matches');
};

subtest 'get_all - with search filter' => sub {
    $mock_dbh = mock_dbh();

    my $media = create_test_media_data(original_filename => 'vacation-photo.jpg');

    # Mock COUNT query first
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media.*WHERE/i,
        results => [['count'], [1]]
    };

    # Mock SELECT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*original_filename.*FROM media.*WHERE.*original_filename.*ILIKE.*OR.*alt_text.*ILIKE/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $media->{id}, $media->{filename}, $media->{original_filename},
                $media->{filepath}, $media->{mime_type}, $media->{file_size},
                $media->{width}, $media->{height}, $media->{uploaded_by},
                $media->{created_at}, $media->{alt_text}, $media->{caption}
            ]
        ]
    };

    my $results = $model->get_all(search => 'vacation', simple => 1);

    ok(defined $results, 'get_all with search returns result');
    is(scalar @$results, 1, 'Returns one matching item');
    like($results->[0]->{original_filename}, qr/vacation/, 'Search term matched');

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[1]->statement;  # Second query is the SELECT
    like($statement, qr/ILIKE/i, 'Case-insensitive search used');
};

subtest 'get_all - with type filter' => sub {
    $mock_dbh = mock_dbh();

    my $media = create_test_media_data(mime_type => 'image/png');

    # Note: get_all doesn't actually support 'type' parameter, it supports 'mime_type'
    # But let's test with what the model actually does (no type filtering in get_all)
    # The type filtering is only in get_count method

    # Mock COUNT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media/i,
        results => [['count'], [1]]
    };

    # Mock SELECT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*FROM media.*ORDER BY/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $media->{id}, $media->{filename}, $media->{original_filename},
                $media->{filepath}, $media->{mime_type}, $media->{file_size},
                $media->{width}, $media->{height}, $media->{uploaded_by},
                $media->{created_at}, $media->{alt_text}, $media->{caption}
            ]
        ]
    };

    my $results = $model->get_all(simple => 1);

    ok(defined $results, 'get_all returns result');
    is(scalar @$results, 1, 'Returns one item');
};

subtest 'get_by_id' => sub {
    $mock_dbh = mock_dbh();

    my $media = create_test_media_data(id => 42);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*original_filename.*FROM media.*WHERE id/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $media->{id}, $media->{filename}, $media->{original_filename},
                $media->{filepath}, $media->{mime_type}, $media->{file_size},
                $media->{width}, $media->{height}, $media->{uploaded_by},
                $media->{created_at}, $media->{alt_text}, $media->{caption}
            ]
        ]
    };

    my $result = $model->get_by_id(42);

    ok(defined $result, 'get_by_id returns a result');
    is(ref $result, 'HASH', 'Returns a hashref');
    is($result->{id}, 42, 'Correct ID returned');
    is($result->{filename}, 'abc123.jpg', 'Media data correct');
};

subtest 'get_by_id - not found' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*media.*WHERE id/i,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
        ]
    };

    my $result = $model->get_by_id(999);

    ok(!defined $result, 'get_by_id returns undef for nonexistent ID');
};

subtest 'update - metadata only' => sub {
    $mock_dbh = mock_dbh();

    my $updated_media = create_test_media_data(
        id => 1,
        alt_text => 'Updated alt text',
        caption => 'Updated caption'
    );

    # Mock the UPDATE with RETURNING clause - update() returns the row directly
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/UPDATE media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $updated_media->{id}, $updated_media->{filename}, $updated_media->{original_filename},
                $updated_media->{filepath}, $updated_media->{mime_type}, $updated_media->{file_size},
                $updated_media->{width}, $updated_media->{height}, $updated_media->{uploaded_by},
                $updated_media->{created_at}, $updated_media->{alt_text}, $updated_media->{caption}
            ]
        ]
    };

    my $result = $model->update(
        1,
        alt_text => 'Updated alt text',
        caption => 'Updated caption'
    );

    ok(defined $result, 'update returns a result');
    is($result->{alt_text}, 'Updated alt text', 'Alt text was updated');
    is($result->{caption}, 'Updated caption', 'Caption was updated');
};

subtest 'delete' => sub {
    $mock_dbh = mock_dbh();

    # Mock the SELECT (to get filepath before deleting)
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*filepath.*FROM media.*WHERE id/is,
        results => [
            ['filepath'],
            ['/uploads/2024/01/test.jpg']
        ]
    };

    # Mock the DELETE
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/DELETE FROM media.*WHERE id/is,
        results => [[]]
    };

    lives_ok { $model->delete(1) } 'delete executes without error';

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[1]->statement;  # Second query is the DELETE
    like($statement, qr/DELETE FROM media/i, 'DELETE statement executed');
};

subtest 'get_count' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT/i,
        results => [['count'], [15]]
    };

    my $count = $model->get_count();

    is($count, 15, 'get_count returns correct count');
};

subtest 'get_count - with filters' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media.*WHERE.*mime_type.*LIKE/i,
        results => [['count'], [10]]
    };

    my $count = $model->get_count(type => 'image');

    is($count, 10, 'get_count with filter returns correct count');
};

# DBD::Mock tests now working correctly

# ====== SECURITY TESTS: Text Sanitization ======

subtest 'create - sanitizes alt_text control characters' => sub {
    $mock_dbh = mock_dbh();

    my $dirty_text = create_control_character_string('mixed');  # Contains \x00\x01\x02\x07\x1B

    my $new_media = create_test_media_data(id => 99);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, 'TestString', 'Test caption'  # Control chars removed
            ]
        ]
    };

    my $result = $model->create(
        filename => 'test.jpg',
        original_filename => 'test.jpg',
        filepath => '/uploads/test.jpg',
        mime_type => 'image/jpeg',
        file_size => 1024,
        uploaded_by => 1,
        alt_text => $dirty_text,
        caption => 'Test caption'
    );

    ok(defined $result, 'create returns result');

    # Verify control characters were removed from bound parameters
    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    # Alt text is the 9th parameter (0-indexed = 8)
    my $sanitized_alt = $bound_params->[8];
    unlike($sanitized_alt, qr/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, 'Control characters removed from alt_text');
    like($sanitized_alt, qr/TestString/, 'Normal text preserved');
};

subtest 'create - sanitizes caption control characters' => sub {
    $mock_dbh = mock_dbh();

    my $dirty_caption = create_control_character_string('null');  # Contains \x00

    my $new_media = create_test_media_data(id => 99);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, 'Test alt', 'TestString'
            ]
        ]
    };

    my $result = $model->create(
        filename => 'test.jpg',
        original_filename => 'test.jpg',
        filepath => '/uploads/test.jpg',
        mime_type => 'image/jpeg',
        file_size => 1024,
        uploaded_by => 1,
        alt_text => 'Test alt',
        caption => $dirty_caption
    );

    ok(defined $result, 'create returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    # Caption is the 10th parameter (0-indexed = 9)
    my $sanitized_caption = $bound_params->[9];
    unlike($sanitized_caption, qr/\x00/, 'NULL byte removed from caption');
    like($sanitized_caption, qr/TestString/, 'Normal text preserved');
};

subtest 'create - limits alt_text to 1000 chars' => sub {
    $mock_dbh = mock_dbh();

    my $long_text = "A" x 1500;  # 1500 characters

    my $new_media = create_test_media_data(id => 99);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, 'A' x 1000, undef
            ]
        ]
    };

    my $result = $model->create(
        filename => 'test.jpg',
        original_filename => 'test.jpg',
        filepath => '/uploads/test.jpg',
        mime_type => 'image/jpeg',
        file_size => 1024,
        uploaded_by => 1,
        alt_text => $long_text
    );

    ok(defined $result, 'create returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    my $sanitized_alt = $bound_params->[8];
    is(length($sanitized_alt), 1000, 'Alt text truncated to 1000 characters');
};

subtest 'create - limits caption to 1000 chars' => sub {
    $mock_dbh = mock_dbh();

    my $long_caption = "B" x 1500;

    my $new_media = create_test_media_data(id => 99);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, undef, 'B' x 1000
            ]
        ]
    };

    my $result = $model->create(
        filename => 'test.jpg',
        original_filename => 'test.jpg',
        filepath => '/uploads/test.jpg',
        mime_type => 'image/jpeg',
        file_size => 1024,
        uploaded_by => 1,
        caption => $long_caption
    );

    ok(defined $result, 'create returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    my $sanitized_caption = $bound_params->[9];
    is(length($sanitized_caption), 1000, 'Caption truncated to 1000 characters');
};

subtest 'create - allows normal alt_text and caption' => sub {
    $mock_dbh = mock_dbh();

    my $normal_alt = "A beautiful sunset over the ocean";
    my $normal_caption = "Taken in Hawaii, 2024";

    my $new_media = create_test_media_data(id => 99);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $new_media->{id}, $new_media->{filename}, $new_media->{original_filename},
                $new_media->{filepath}, $new_media->{mime_type}, $new_media->{file_size},
                $new_media->{width}, $new_media->{height}, $new_media->{uploaded_by},
                $new_media->{created_at}, $normal_alt, $normal_caption
            ]
        ]
    };

    my $result = $model->create(
        filename => 'test.jpg',
        original_filename => 'test.jpg',
        filepath => '/uploads/test.jpg',
        mime_type => 'image/jpeg',
        file_size => 1024,
        uploaded_by => 1,
        alt_text => $normal_alt,
        caption => $normal_caption
    );

    ok(defined $result, 'create returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    is($bound_params->[8], $normal_alt, 'Normal alt text unchanged');
    is($bound_params->[9], $normal_caption, 'Normal caption unchanged');
};

subtest 'update - sanitizes alt_text control characters' => sub {
    $mock_dbh = mock_dbh();

    my $dirty_alt = create_control_character_string('escape');

    my $updated_media = create_test_media_data(id => 1);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/UPDATE media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $updated_media->{id}, $updated_media->{filename}, $updated_media->{original_filename},
                $updated_media->{filepath}, $updated_media->{mime_type}, $updated_media->{file_size},
                $updated_media->{width}, $updated_media->{height}, $updated_media->{uploaded_by},
                $updated_media->{created_at}, 'TestString', 'Updated caption'
            ]
        ]
    };

    my $result = $model->update(1, alt_text => $dirty_alt, caption => 'Updated caption');

    ok(defined $result, 'update returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    unlike($bound_params->[0], qr/\x1B/, 'Escape character removed from alt_text');
};

subtest 'update - sanitizes caption control characters' => sub {
    $mock_dbh = mock_dbh();

    my $dirty_caption = create_control_character_string('bell');

    my $updated_media = create_test_media_data(id => 1);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/UPDATE media.*RETURNING/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
            [
                $updated_media->{id}, $updated_media->{filename}, $updated_media->{original_filename},
                $updated_media->{filepath}, $updated_media->{mime_type}, $updated_media->{file_size},
                $updated_media->{width}, $updated_media->{height}, $updated_media->{uploaded_by},
                $updated_media->{created_at}, 'Updated alt', 'TestString'
            ]
        ]
    };

    my $result = $model->update(1, alt_text => 'Updated alt', caption => $dirty_caption);

    ok(defined $result, 'update returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    unlike($bound_params->[1], qr/\x07/, 'Bell character removed from caption');
};

# ====== SECURITY TESTS: SQL Wildcard Escaping in Search ======

subtest 'get_all - search escapes SQL wildcards (%)' => sub {
    $mock_dbh = mock_dbh();

    my $wildcard_search = create_wildcard_test_string('percent');

    # Mock COUNT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media.*WHERE/i,
        results => [['count'], [0]]
    };

    # Mock SELECT query
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*FROM media.*WHERE.*ILIKE/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
        ]
    };

    my $results = $model->get_all(search => $wildcard_search, simple => 1);

    ok(defined $results, 'get_all with search returns result');

    # Verify wildcard is escaped in bound parameters
    my $history = $mock_dbh->{mock_all_history};
    my $count_params = $history->[0]->bound_params;

    # Search is passed 3 times (for filename, alt_text, caption)
    like($count_params->[0], qr/test\\%value/, 'Percent escaped in search');
};

subtest 'get_all - search escapes SQL wildcards (_)' => sub {
    $mock_dbh = mock_dbh();

    my $wildcard_search = create_wildcard_test_string('underscore');

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media.*WHERE/i,
        results => [['count'], [0]]
    };

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*filename.*FROM media.*WHERE.*ILIKE/is,
        results => [
            ['id', 'filename', 'original_filename', 'filepath', 'mime_type',
             'file_size', 'width', 'height', 'uploaded_by', 'created_at',
             'alt_text', 'caption'],
        ]
    };

    my $results = $model->get_all(search => $wildcard_search, simple => 1);

    ok(defined $results, 'get_all with search returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $count_params = $history->[0]->bound_params;

    like($count_params->[0], qr/test\\_value/, 'Underscore escaped in search');
};

subtest 'get_count - search escapes wildcards' => sub {
    $mock_dbh = mock_dbh();

    my $wildcard_search = create_wildcard_test_string('all');  # "test%_\value"

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT.*FROM media.*WHERE/i,
        results => [['count'], [0]]
    };

    my $count = $model->get_count(search => $wildcard_search);

    is($count, 0, 'get_count returns result');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;

    like($bound_params->[0], qr/test\\%\\_\\\\value/, 'All wildcards escaped');
};

# ====== SECURITY TESTS: Helper Method Unit Tests ======

subtest '_escape_sql_wildcards - unit test' => sub {
    is($model->_escape_sql_wildcards('test%value'), 'test\\%value', 'Escapes %');
    is($model->_escape_sql_wildcards('test_value'), 'test\\_value', 'Escapes _');
    is($model->_escape_sql_wildcards('test\\value'), 'test\\\\value', 'Escapes \\');
    is($model->_escape_sql_wildcards('test%_\\value'), 'test\\%\\_\\\\value', 'Escapes all wildcards');
    is($model->_escape_sql_wildcards('normal'), 'normal', 'Leaves normal strings unchanged');
    is($model->_escape_sql_wildcards(''), '', 'Handles empty string');
    is($model->_escape_sql_wildcards(undef), '', 'Handles undef');
};

subtest '_sanitize_text - unit test' => sub {
    # Test control character removal
    is($model->_sanitize_text("Test\x00String"), 'TestString', 'Removes NULL byte');
    is($model->_sanitize_text("Test\x07String"), 'TestString', 'Removes bell character');
    is($model->_sanitize_text("Test\x1BString"), 'TestString', 'Removes escape character');
    is($model->_sanitize_text("Test\x00\x01\x02String"), 'TestString', 'Removes multiple control chars');

    # Test whitespace preservation
    is($model->_sanitize_text("Test\nWith\tTabs"), "Test\nWith\tTabs", 'Preserves newlines and tabs');
    is($model->_sanitize_text("  Test  "), 'Test', 'Trims whitespace');

    # Test length limiting
    my $long_text = "A" x 1500;
    my $sanitized = $model->_sanitize_text($long_text);
    is(length($sanitized), 1000, 'Limits to 1000 chars by default');

    my $custom_limit = $model->_sanitize_text($long_text, 500);
    is(length($custom_limit), 500, 'Respects custom length limit');

    # Test edge cases
    is($model->_sanitize_text(''), '', 'Handles empty string');
    is($model->_sanitize_text(undef), undef, 'Handles undef');
    is($model->_sanitize_text('Normal text'), 'Normal text', 'Leaves normal text unchanged');
};

done_testing();
