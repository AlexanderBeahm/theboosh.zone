#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger create_test_tag_data);
use Test::MockModule;

# =============================================================================
# DBD::Mock Issue - RESOLVED
# =============================================================================
# The DBD::Mock issue has been resolved. The problem was with SQL regex patterns
# that were too restrictive and didn't match the actual complex SQL queries.
#
# Fix: Updated SQL regex patterns to be more flexible (e.g., qr/SELECT.*tags/is)
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

use_ok('HelloPerld::Model::Tag');

# Initialize the model
my $logger = mock_logger();
my $model = HelloPerld::Model::Tag->new(logger => $logger);
isa_ok($model, 'HelloPerld::Model::Tag', 'Model instantiated correctly');

# Mock get_tag_usage_count to prevent it from trying to create a new DB connection
my $tag_mock = Test::MockModule->new('HelloPerld::Model::Tag');
$tag_mock->mock('get_tag_usage_count', sub {
    my ($self, $tag_id) = @_;
    # Return a default usage count for testing
    return 5;
});

subtest 'generate_slug' => sub {
    is($model->generate_slug('Test Tag'), 'test-tag', 'Basic slug generation');
    is($model->generate_slug('React.js'), 'reactjs', 'Period removed');
    is($model->generate_slug('C++'), 'c', 'Plus signs removed');
    is($model->generate_slug('  Vue 3  '), 'vue-3', 'Whitespace trimmed');
    is($model->generate_slug('Node.js & Express'), 'nodejs-express', 'Special chars handled');
};

# DBD::Mock issue fixed - tests now enabled

subtest 'get_all - basic query' => sub {
    $mock_dbh = mock_dbh();

    my $tag = create_test_tag_data();

    # Note: get_all returns id, name, slug, date_added (no usage_count in SELECT)
    # usage_count is added by calling get_tag_usage_count for each tag
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag->{id}, $tag->{name}, $tag->{slug}, $tag->{date_added}]
        ]
    };

    my $results = $model->get_all(limit => 10, offset => 0);

    ok(defined $results, 'get_all returns a result');
    is(ref $results, 'ARRAY', 'get_all returns an arrayref');
    is(scalar @$results, 1, 'get_all returns one tag');
    is($results->[0]->{name}, 'Test Tag', 'Tag name matches');
    is($results->[0]->{usage_count}, 5, 'Usage count included (from mocked method)');
};

subtest 'get_all - order by name' => sub {
    $mock_dbh = mock_dbh();

    my $tag1 = create_test_tag_data(id => 1, name => 'Alpha', slug => 'alpha');
    my $tag2 = create_test_tag_data(id => 2, name => 'Beta', slug => 'beta');

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*ORDER BY.*name/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag1->{id}, $tag1->{name}, $tag1->{slug}, $tag1->{date_added}],
            [$tag2->{id}, $tag2->{name}, $tag2->{slug}, $tag2->{date_added}]
        ]
    };

    my $results = $model->get_all(order_by => 'name');

    is(scalar @$results, 2, 'Returns two tags');
    is($results->[0]->{name}, 'Alpha', 'First tag is Alpha');
    is($results->[1]->{name}, 'Beta', 'Second tag is Beta');

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/ORDER BY\s+name/is, 'ORDER BY name applied');
};

subtest 'get_all - order by usage' => sub {
    $mock_dbh = mock_dbh();

    my $tag1 = create_test_tag_data(id => 1, name => 'Popular', usage_count => 10);
    my $tag2 = create_test_tag_data(id => 2, name => 'Less Popular', usage_count => 2);

    # When order_by => 'usage', the SQL includes a subquery for counting
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*ORDER BY.*SELECT COUNT/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag1->{id}, $tag1->{name}, $tag1->{slug}, $tag1->{date_added}],
            [$tag2->{id}, $tag2->{name}, $tag2->{slug}, $tag2->{date_added}]
        ]
    };

    my $results = $model->get_all(order_by => 'usage');

    is(scalar @$results, 2, 'Returns two tags');
    # Both will have usage_count = 5 from the mocked method
    is($results->[0]->{usage_count}, 5, 'First tag has usage count from mock');
    is($results->[1]->{usage_count}, 5, 'Second tag has usage count from mock');
};

subtest 'get_by_id' => sub {
    $mock_dbh = mock_dbh();

    my $tag = create_test_tag_data(id => 42);

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*id/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag->{id}, $tag->{name}, $tag->{slug}, $tag->{date_added}]
        ]
    };

    my $result = $model->get_by_id(42);

    ok(defined $result, 'get_by_id returns a result');
    is(ref $result, 'HASH', 'Returns a hashref');
    is($result->{id}, 42, 'Correct ID returned');
    is($result->{name}, 'Test Tag', 'Tag data correct');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');
};

subtest 'get_by_slug' => sub {
    $mock_dbh = mock_dbh();

    my $tag = create_test_tag_data(slug => 'my-tag');

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*slug/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag->{id}, $tag->{name}, 'my-tag', $tag->{date_added}]
        ]
    };

    my $result = $model->get_by_slug('my-tag');

    ok(defined $result, 'get_by_slug returns a result');
    is($result->{slug}, 'my-tag', 'Correct slug returned');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');
};

subtest 'get_by_name - case insensitive' => sub {
    $mock_dbh = mock_dbh();

    my $tag = create_test_tag_data(name => 'JavaScript');

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*LOWER.*name/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag->{id}, $tag->{name}, $tag->{slug}, $tag->{date_added}]
        ]
    };

    my $result = $model->get_by_name('javascript');

    ok(defined $result, 'get_by_name returns a result');
    is($result->{name}, 'JavaScript', 'Case-insensitive match works');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/LOWER/i, 'LOWER() used for case-insensitive search');
};

subtest 'get_by_name - not found' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*LOWER/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
        ]
    };

    my $result = $model->get_by_name('nonexistent');

    ok(!defined $result, 'get_by_name returns undef for nonexistent tag');
};

subtest 'create' => sub {
    $mock_dbh = mock_dbh();

    my $new_tag = create_test_tag_data(id => 99, name => 'New Tag', slug => 'new-tag');

    # Mock the INSERT
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO tags/i,
        results => [['id'], [99]]
    };

    # Mock the SELECT after insert (get_by_id is called after create)
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*id/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$new_tag->{id}, $new_tag->{name}, $new_tag->{slug}, $new_tag->{date_added}]
        ]
    };

    my $result = $model->create(name => 'New Tag');

    ok(defined $result, 'create returns a result');
    is($result->{id}, 99, 'Created tag has ID');
    is($result->{name}, 'New Tag', 'Tag name set correctly');
    is($result->{slug}, 'new-tag', 'Slug auto-generated');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');
};

subtest 'update' => sub {
    $mock_dbh = mock_dbh();

    my $updated_tag = create_test_tag_data(id => 1, name => 'Updated Tag');

    # Mock the UPDATE - update() returns rows affected, not the tag
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/UPDATE tags/i,
        results => [[]]
    };

    my $result = $model->update(1, name => 'Updated Tag');

    ok(defined $result, 'update returns a result (rows affected)');
    # update() returns rows affected (scalar), not the updated tag
    # To get the updated tag, you'd need to call get_by_id() separately
};

subtest 'delete' => sub {
    $mock_dbh = mock_dbh();

    # Mock the DELETE
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/DELETE FROM tags/i,
        results => [[]]
    };

    lives_ok { $model->delete(1) } 'delete executes without error';

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/DELETE FROM tags/i, 'DELETE statement executed');
};

subtest 'get_popular_tags' => sub {
    $mock_dbh = mock_dbh();

    my $tag1 = create_test_tag_data(id => 1, name => 'Popular', usage_count => 100);
    my $tag2 = create_test_tag_data(id => 2, name => 'Also Popular', usage_count => 50);

    # get_popular_tags uses a JOIN with COUNT and GROUP BY
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*COUNT.*article_id.*FROM tags.*LEFT JOIN/is,
        results => [
            ['id', 'name', 'slug', 'date_added', 'usage_count'],
            [$tag1->{id}, $tag1->{name}, $tag1->{slug}, $tag1->{date_added}, $tag1->{usage_count}],
            [$tag2->{id}, $tag2->{name}, $tag2->{slug}, $tag2->{date_added}, $tag2->{usage_count}]
        ]
    };

    my $results = $model->get_popular_tags(limit => 10);

    ok(defined $results, 'get_popular_tags returns result');
    is(scalar @$results, 2, 'Returns two tags');
    is($results->[0]->{usage_count}, 100, 'Most popular tag first');
    is($results->[1]->{usage_count}, 50, 'Second most popular tag second');

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/ORDER BY.*usage_count.*DESC/i, 'Ordered by usage DESC');
};

subtest 'search' => sub {
    $mock_dbh = mock_dbh();

    my $tag = create_test_tag_data(name => 'JavaScript');

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*name.*ILIKE/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$tag->{id}, $tag->{name}, $tag->{slug}, $tag->{date_added}]
        ]
    };

    my $results = $model->search('java');

    ok(defined $results, 'search returns result');
    is(scalar @$results, 1, 'Returns one matching tag');
    is($results->[0]->{name}, 'JavaScript', 'Found correct tag');
    is($results->[0]->{usage_count}, 5, 'Usage count added from mocked method');

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/ILIKE/i, 'Case-insensitive ILIKE used');
};

subtest 'find_or_create_by_name - finds existing' => sub {
    $mock_dbh = mock_dbh();

    my $existing_tag = create_test_tag_data(name => 'Existing');

    # Mock the SELECT (finds existing)
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*LOWER.*name/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$existing_tag->{id}, $existing_tag->{name}, $existing_tag->{slug}, $existing_tag->{date_added}]
        ]
    };

    my $result = $model->find_or_create_by_name('Existing');

    ok(defined $result, 'find_or_create_by_name returns result');
    is($result->{name}, 'Existing', 'Returns existing tag');
    is($result->{id}, 1, 'ID matches existing tag');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');
};

subtest 'find_or_create_by_name - creates new' => sub {
    $mock_dbh = mock_dbh();

    # Mock the first SELECT (not found)
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*LOWER.*name/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
        ]
    };

    # Mock the INSERT
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO tags/i,
        results => [['id'], [42]]
    };

    # Mock the second SELECT by name (after insert) - the model calls get_by_name instead of get_by_id
    my $new_tag = create_test_tag_data(id => 42, name => 'NewTag', slug => 'newtag');
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*id.*name.*slug.*date_added.*FROM tags.*WHERE.*LOWER.*name/is,
        results => [
            ['id', 'name', 'slug', 'date_added'],
            [$new_tag->{id}, $new_tag->{name}, $new_tag->{slug}, $new_tag->{date_added}]
        ]
    };

    my $result = $model->find_or_create_by_name('NewTag');

    ok(defined $result, 'find_or_create_by_name returns result');
    is($result->{id}, 42, 'New tag created with ID');
    is($result->{name}, 'NewTag', 'New tag has correct name');
    is($result->{usage_count}, 5, 'Usage count added from mocked method');
};

subtest 'get_count' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT COUNT/i,
        results => [['count'], [25]]
    };

    my $count = $model->get_count();

    is($count, 25, 'get_count returns correct count');
};

# DBD::Mock tests now working correctly

done_testing();
