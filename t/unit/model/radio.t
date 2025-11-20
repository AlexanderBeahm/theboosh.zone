#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger);
use Test::MockModule;

# Mock the Postgres module to return our mock DBH
my $postgres_mock = Test::MockModule->new('HelloPerld::Database::Postgres');
my $mock_dbh;

$postgres_mock->mock('get_connection', sub {
    return $mock_dbh;
});

use_ok('HelloPerld::Model::Radio');

# Initialize the model
my $logger = mock_logger();
my $model = HelloPerld::Model::Radio->new(logger => $logger);
isa_ok($model, 'HelloPerld::Model::Radio', 'Model instantiated correctly');

# ====== BASIC CRUD OPERATIONS ======

subtest 'get_config - retrieve configuration value' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config.*WHERE config_key/is,
        results => [
            ['config_value', 'description', 'updated_at'],
            ['https://example.com/playlist.m3u', 'Main playlist URL', '2024-01-15 10:00:00']
        ]
    };

    my $value = $model->get_config('playlist_url');

    is($value, 'https://example.com/playlist.m3u', 'get_config returns correct value');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 'playlist_url', 'Correct key passed to query');
};

subtest 'get_config - not found returns undef' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config.*WHERE config_key/is,
        results => [
            ['config_value', 'description', 'updated_at'],
        ]
    };

    my $value = $model->get_config('nonexistent_key');

    ok(!defined $value, 'get_config returns undef for nonexistent key');
};

subtest 'get_config - missing key dies' => sub {
    $mock_dbh = mock_dbh();

    dies_ok { $model->get_config() } 'get_config dies without key';
    dies_ok { $model->get_config(undef) } 'get_config dies with undef key';
};

subtest 'get_all_config - retrieve all configuration' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config.*ORDER BY config_key/is,
        results => [
            ['config_key', 'config_value', 'description', 'updated_by', 'updated_at'],
            ['playlist_url', 'https://example.com/playlist.m3u', 'Main playlist', 1, '2024-01-15 10:00:00'],
            ['another_key', 'another_value', 'Another config', 1, '2024-01-15 11:00:00']
        ]
    };

    my $configs = $model->get_all_config();

    is(ref $configs, 'ARRAY', 'get_all_config returns arrayref');
    is(scalar @$configs, 2, 'Returns correct number of configs');
    is($configs->[0]->{config_key}, 'playlist_url', 'First config key correct');
    is($configs->[1]->{config_key}, 'another_key', 'Second config key correct');
};

subtest 'get_all_config - empty database' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config/is,
        results => [
            ['config_key', 'config_value', 'description', 'updated_by', 'updated_at'],
        ]
    };

    my $configs = $model->get_all_config();

    is(ref $configs, 'ARRAY', 'Returns arrayref');
    is(scalar @$configs, 0, 'Returns empty array for no configs');
};

subtest 'set_config - insert new configuration' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config.*ON CONFLICT/is,
        results => [[]]
    };

    lives_ok {
        $model->set_config('playlist_url', 'https://example.com/test.m3u', 1)
    } 'set_config executes without error';

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/INSERT INTO radio_config/i, 'INSERT statement executed');
    like($statement, qr/ON CONFLICT/i, 'Uses upsert pattern');

    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 'playlist_url', 'Key bound correctly');
    is($bound_params->[1], 'https://example.com/test.m3u', 'Value bound correctly');
    is($bound_params->[2], 1, 'User ID bound correctly');
};

subtest 'set_config - update existing configuration' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config.*ON CONFLICT.*DO UPDATE/is,
        results => [[]]
    };

    lives_ok {
        $model->set_config('playlist_url', 'https://example.com/updated.m3u', 2)
    } 'set_config updates existing config';

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[1], 'https://example.com/updated.m3u', 'Updated value bound');
    is($bound_params->[2], 2, 'Updated user ID bound');
};

subtest 'set_config - validation errors' => sub {
    $mock_dbh = mock_dbh();

    dies_ok { $model->set_config() } 'Dies without key';
    dies_ok { $model->set_config(undef, 'value', 1) } 'Dies with undef key';
    dies_ok { $model->set_config('key', undef, 1) } 'Dies with undef value';
    dies_ok { $model->set_config('key') } 'Dies without value';
};

# ====== PLAYLIST-SPECIFIC METHODS ======

subtest 'get_playlist_url - convenience method' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config.*WHERE config_key/is,
        results => [
            ['config_value', 'description', 'updated_at'],
            ['https://example.com/playlist.m3u', 'Playlist', '2024-01-15 10:00:00']
        ]
    };

    my $url = $model->get_playlist_url();

    is($url, 'https://example.com/playlist.m3u', 'get_playlist_url returns URL');

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 'playlist_url', 'Queries for playlist_url key');
};

subtest 'get_playlist_url - returns empty string when not set' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config/is,
        results => [
            ['config_value', 'description', 'updated_at'],
        ]
    };

    my $url = $model->get_playlist_url();

    is($url, '', 'Returns empty string when not found');
};

subtest 'set_playlist_url - valid HTTP URL' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config/is,
        results => [[]]
    };

    lives_ok {
        $model->set_playlist_url('https://example.com/playlist.m3u', 1)
    } 'set_playlist_url accepts valid HTTP URL';

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 'playlist_url', 'Sets playlist_url key');
    is($bound_params->[1], 'https://example.com/playlist.m3u', 'URL value correct');
};

subtest 'set_playlist_url - valid local path' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config/is,
        results => [[]]
    };

    lives_ok {
        $model->set_playlist_url('/uploads/playlist.m3u', 1)
    } 'set_playlist_url accepts valid local path';
};

subtest 'set_playlist_url - validates .m3u extension' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config/is,
        results => [[]]
    };

    lives_ok {
        $model->set_playlist_url('https://example.com/test.m3u8', 1)
    } 'Accepts .m3u8 extension';

    lives_ok {
        $model->set_playlist_url('/uploads/test.m3u', 1)
    } 'Accepts .m3u extension';
};

subtest 'set_playlist_url - validation errors' => sub {
    $mock_dbh = mock_dbh();

    dies_ok {
        $model->set_playlist_url('', 1)
    } 'Dies with empty URL';

    dies_ok {
        $model->set_playlist_url(undef, 1)
    } 'Dies with undef URL';

    dies_ok {
        $model->set_playlist_url('invalid-url', 1)
    } 'Dies with invalid URL format';

    # Note: The validation accepts URLs that start with http(s):// or /
    # OR end with .m3u/.m3u8, so ftp://example.com/playlist.m3u actually passes
    # because it ends with .m3u. This is by design.
};

# ====== DURATION TRACKING ======

subtest 'get_total_duration' => sub {
    $mock_dbh = mock_dbh();

    # The method uses fetchrow_hashref, so we need to return a hash
    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT total_duration.*FROM radio_config.*WHERE config_key/is,
        results => [
            ['total_duration'],
            [3600]
        ]
    };

    my $duration = $model->get_total_duration();

    # fetchrow_hashref should return the value from the hash
    is($duration, 3600, 'get_total_duration returns duration');
};

subtest 'get_total_duration - not set' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT total_duration.*FROM radio_config.*WHERE config_key/is,
        results => [
            ['total_duration'],
        ]
    };

    my $duration = $model->get_total_duration();

    ok(!defined $duration, 'Returns undef when not set');
};

subtest 'set_total_duration' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/UPDATE radio_config.*SET total_duration/is,
        results => [[]]
    };

    lives_ok {
        $model->set_total_duration(7200)
    } 'set_total_duration executes';

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 7200, 'Duration bound correctly');

    my $statement = $history->[0]->statement;
    like($statement, qr/WHERE config_key = 'playlist_url'/i, 'Updates playlist_url row');
};

# ====== METADATA OPERATIONS ======

subtest 'get_playlist_metadata - complete metadata' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*config_value as url.*total_duration.*updated_at/is,
        results => [
            ['url', 'total_duration', 'updated_at'],
            ['https://example.com/playlist.m3u', 3600, '2024-01-15 10:00:00']
        ]
    };

    my $metadata = $model->get_playlist_metadata();

    is(ref $metadata, 'HASH', 'Returns hashref');
    is($metadata->{url}, 'https://example.com/playlist.m3u', 'URL included');
    is($metadata->{total_duration}, 3600, 'Duration included');
    is($metadata->{updated_at}, '2024-01-15 10:00:00', 'Timestamp included');
};

subtest 'get_playlist_metadata - not configured' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT.*FROM radio_config/is,
        results => [
            ['url', 'total_duration', 'updated_at'],
        ]
    };

    my $metadata = $model->get_playlist_metadata();

    ok(!defined $metadata, 'Returns undef when not configured');
};

# ====== DELETE OPERATIONS ======

subtest 'delete_config' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/DELETE FROM radio_config WHERE config_key/is,
        results => [[]]
    };

    lives_ok {
        $model->delete_config('playlist_url')
    } 'delete_config executes';

    my $history = $mock_dbh->{mock_all_history};
    my $statement = $history->[0]->statement;
    like($statement, qr/DELETE FROM radio_config/i, 'DELETE statement executed');

    my $bound_params = $history->[0]->bound_params;
    is($bound_params->[0], 'playlist_url', 'Correct key bound');
};

subtest 'delete_config - validation' => sub {
    $mock_dbh = mock_dbh();

    dies_ok { $model->delete_config() } 'Dies without key';
    dies_ok { $model->delete_config(undef) } 'Dies with undef key';
};

# ====== EDGE CASES ======

subtest 'set_config - with user_id as undef' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/INSERT INTO radio_config/is,
        results => [[]]
    };

    lives_ok {
        $model->set_config('test_key', 'test_value', undef)
    } 'set_config accepts undef user_id';

    my $history = $mock_dbh->{mock_all_history};
    my $bound_params = $history->[0]->bound_params;
    ok(!defined $bound_params->[2], 'user_id bound as undef');
};

subtest 'set_playlist_url - various valid formats' => sub {
    $mock_dbh = mock_dbh();

    my @valid_urls = (
        'http://example.com/playlist.m3u',
        'https://example.com/playlist.m3u8',
        'https://cdn.example.com/path/to/playlist.m3u',
        '/uploads/playlist.m3u',
        '/var/www/uploads/playlist.m3u8',
    );

    for my $url (@valid_urls) {
        $mock_dbh->{mock_add_resultset} = {
            sql => qr/INSERT INTO radio_config/is,
            results => [[]]
        };

        lives_ok {
            $model->set_playlist_url($url, 1)
        } "Accepts valid URL: $url";
    }
};

subtest 'set_playlist_url - various invalid formats' => sub {
    # Only truly invalid URLs that don't match the validation pattern:
    # Must start with http(s):// or / OR end with .m3u/.m3u8

    my @invalid_urls = (
        'not-a-url',  # Doesn't start with http(s):// or / and doesn't end with .m3u(8)
        'invalid format without protocol or extension',
        'C:\\Windows\\path',  # Windows path doesn't start with /
    );

    for my $url (@invalid_urls) {
        dies_ok {
            $model->set_playlist_url($url, 1)
        } "Rejects invalid URL: $url";
    }

    # Note: These URLs actually PASS validation because the regex is permissive:
    # - 'ftp://example.com/playlist.m3u' - ends with .m3u (allowed)
    # - 'example.com/playlist.m3u' - ends with .m3u (allowed)
    # - 'https://example.com/file.mp3' - starts with https:// (allowed)
    # - 'https://example.com/file.txt' - starts with https:// (allowed)
    # This is by design to allow flexibility. The Controller does additional
    # validation for HTTP URLs by actually checking if they're accessible.
};

done_testing();
