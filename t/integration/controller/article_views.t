#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

use HelloPerld::Model::ArticleView;

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

# Helper to create ArticleView model with proper config
sub create_view_model {
    return HelloPerld::Model::ArticleView->new(
        logger => $t->app->logger_instance,
        db_config => $t->app->config->{database} || {}
    );
}

# Create a test article first
my $test_article_slug;
my $test_article_id;
my $csrf_token;

subtest 'setup: create test article' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};
    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for article view tests';
        return;
    }

    # Login as admin first and get CSRF token
    my $login_response = $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200)->tx->res->json;

    $csrf_token = $login_response->{csrf_token};
    ok($csrf_token, 'Got CSRF token from login response');

    # Create a test article with unique title
    my $unique_title = 'Test Article for Views ' . time();
    my $article_data = {
        title => $unique_title,
        content => 'This is test content for view tracking',
        excerpt => 'Test excerpt',
        is_published => 1,
        tags => ['test']
    };

    $t->post_ok('/api/admin/articles' => {'X-CSRF-Token' => $csrf_token} => json => $article_data)
      ->status_is(201)
      ->json_has('/article/slug', 'Article created with slug');

    $test_article_slug = $t->tx->res->json->{article}->{slug};
    $test_article_id = $t->tx->res->json->{article}->{id};
    ok($test_article_slug, "Test article slug: $test_article_slug");
    ok($test_article_id, "Test article ID: $test_article_id");
};

SKIP: {
    skip 'No test article created', 5 unless $test_article_slug;

    subtest 'article view tracking on GET request' => sub {
        # Make a GET request to the article endpoint
        $t->get_ok("/api/articles/$test_article_slug")
          ->status_is(200, 'Article endpoint returns 200');

        # Wait a moment for async database insert
        sleep(1);

        # Verify view was tracked in database
        my $view_model = create_view_model();

        my $views = $view_model->get_views_by_slug($test_article_slug, 10, 0);
        ok(defined $views, 'Views query succeeded');
        is(ref $views, 'ARRAY', 'Views is an array');
        cmp_ok(scalar @$views, '>=', 1, 'At least one view recorded');

        if (@$views > 0) {
            my $view = $views->[0];
            is($view->{article_slug}, $test_article_slug, 'View has correct slug');
            ok($view->{ip_address}, 'View has IP address');
            ok($view->{viewed_at}, 'View has timestamp');
        }
    };

    subtest 'multiple views tracked correctly' => sub {
        # Make multiple requests
        for my $i (1..3) {
            $t->get_ok("/api/articles/$test_article_slug")
              ->status_is(200);
        }

        # Wait for async inserts
        sleep(1);

        my $view_model = create_view_model();

        my $total_views = $view_model->get_total_views_by_slug($test_article_slug);
        ok(defined $total_views, 'Total views query succeeded');
        cmp_ok($total_views, '>=', 4, 'Multiple views tracked (at least 4 including previous test)');
    };

    subtest 'unique IPs counted correctly' => sub {
        my $view_model = create_view_model();

        my $unique_ips = $view_model->get_unique_ips_by_slug($test_article_slug);
        ok(defined $unique_ips, 'Unique IPs query succeeded');
        cmp_ok($unique_ips, '>=', 1, 'At least one unique IP recorded');
    };

    subtest 'views by IP address' => sub {
        my $view_model = create_view_model();

        # Get views to find an IP
        my $views = $view_model->get_views_by_slug($test_article_slug, 1, 0);
        skip 'No views to test IP lookup', 2 unless $views && @$views > 0;

        my $test_ip = $views->[0]->{ip_address};
        my $ip_views = $view_model->get_views_by_ip($test_ip, 10, 0);

        ok(defined $ip_views, 'Views by IP query succeeded');
        is(ref $ip_views, 'ARRAY', 'IP views is an array');
        cmp_ok(scalar @$ip_views, '>=', 1, 'At least one view for IP');
    };

    subtest 'non-article endpoints not tracked' => sub {
        my $initial_count = 0;
        my $view_model = create_view_model();
        $initial_count = $view_model->get_total_views_by_slug($test_article_slug) || 0;

        # Make request to non-article endpoint
        $t->get_ok('/api/tags')
          ->status_is(200);

        sleep(1);

        # View count should not have increased
        my $new_count = $view_model->get_total_views_by_slug($test_article_slug) || 0;
        is($new_count, $initial_count, 'Non-article endpoint does not create views');
    };
}

subtest 'cleanup: delete test article' => sub {
    if ($test_article_id && $csrf_token) {
        $t->delete_ok("/api/admin/articles/$test_article_id" => {'X-CSRF-Token' => $csrf_token})
          ->status_is(200, 'Test article deleted');

        # Logout
        $t->post_ok('/api/auth/logout' => {'X-CSRF-Token' => $csrf_token})->status_is(200);
    }
};

done_testing();
