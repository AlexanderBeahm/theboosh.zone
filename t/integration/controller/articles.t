#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'get articles endpoint exists' => sub {
    $t->get_ok('/api/articles')
      ->status_is(200, 'Articles endpoint returns 200');
};

subtest 'get articles returns JSON array' => sub {
    $t->get_ok('/api/articles')
      ->status_is(200)
      ->header_is('Content-Type' => 'application/json;charset=UTF-8')
      ->json_has('/articles', 'Response has articles array')
      ->json_has('/pagination', 'Response has pagination object');

    my $json = $t->tx->res->json;
    is(ref $json->{articles}, 'ARRAY', 'Articles is an array');
    ok(exists $json->{pagination}, 'Pagination exists');
};

subtest 'articles pagination metadata' => sub {
    $t->get_ok('/api/articles')
      ->status_is(200)
      ->json_has('/pagination/current_page', 'Has current_page')
      ->json_has('/pagination/per_page', 'Has per_page')
      ->json_has('/pagination/total_count', 'Has total_count')
      ->json_has('/pagination/total_pages', 'Has total_pages');
};

subtest 'articles pagination with custom limit' => sub {
    $t->get_ok('/api/articles?limit=5')
      ->status_is(200)
      ->json_is('/pagination/per_page' => 5, 'Custom limit applied');
};

subtest 'articles pagination limit validation' => sub {
    # Test max limit (should return error when exceeding 100)
    $t->get_ok('/api/articles?limit=200')
      ->status_is(400, 'Excessive limit returns 400')
      ->json_has('/error', 'Error message included');
};

subtest 'articles pagination with page parameter' => sub {
    $t->get_ok('/api/articles?page=2&limit=10')
      ->status_is(200)
      ->json_is('/pagination/current_page' => 2, 'Page parameter accepted');
};

subtest 'articles tag filtering' => sub {
    $t->get_ok('/api/articles?tag=nonexistent-tag')
      ->status_is(200)
      ->json_is('/articles' => [], 'No articles for nonexistent tag');
};

subtest 'get article by slug - nonexistent' => sub {
    $t->get_ok('/api/articles/nonexistent-article-slug')
      ->status_is(404, 'Nonexistent article returns 404')
      ->json_has('/error', 'Error message included');
};

subtest 'admin articles endpoint without auth' => sub {
    $t->get_ok('/api/admin/articles')
      ->status_is(401, 'Admin endpoint requires authentication');

    $t->post_ok('/api/admin/articles' => json => {
        title => 'Test Article',
        content => 'Test content'
    })
      ->status_is(401, 'Creating article requires authentication');
};

subtest 'admin article CRUD - with authentication' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for admin article tests';
        return;
    }

    # Login first
    $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })->status_is(200, 'Login successful');

    # Create a test article
    my $test_title = 'Test Article ' . time();
    my $article_id;

    $t->post_ok('/api/admin/articles' => json => {
        title => $test_title,
        content => 'This is test content with **markdown**.',
        excerpt => 'Test excerpt',
        is_published => 0,  # Draft
        tags => ['test', 'automated']
    })
      ->status_is(201, 'Article created successfully')
      ->json_has('/article/id', 'Response includes article ID')
      ->json_is('/article/title' => $test_title, 'Title matches')
      ->json_has('/article/slug', 'Slug was auto-generated')
      ->json_is('/article/is_published' => 0, 'Article is draft');

    $article_id = $t->tx->res->json->{article}->{id};
    ok($article_id, 'Got article ID');

    # Get the article by ID (admin-only)
    $t->get_ok("/api/admin/articles/$article_id")
      ->status_is(200, 'Can retrieve article by ID')
      ->json_is('/article/id' => $article_id, 'ID matches')
      ->json_is('/article/title' => $test_title, 'Title matches');

    # Update the article
    $t->put_ok("/api/admin/articles/$article_id" => json => {
        title => "$test_title Updated",
        is_published => 1
    })
      ->status_is(200, 'Article updated successfully')
      ->json_is('/article/title' => "$test_title Updated", 'Title was updated')
      ->json_is('/article/is_published' => 1, 'Article now published');

    # Get the article's slug
    my $slug = $t->tx->res->json->{article}->{slug};

    # Verify article is now visible via public endpoint
    $t->get_ok("/api/articles/$slug")
      ->status_is(200, 'Published article visible via public endpoint')
      ->json_is('/article/title' => "$test_title Updated", 'Title matches');

    # Delete the article
    $t->delete_ok("/api/admin/articles/$article_id")
      ->status_is(200, 'Article deleted successfully')
      ->json_has('/message', 'Delete confirmation message');

    # Verify article is gone
    $t->get_ok("/api/admin/articles/$article_id")
      ->status_is(404, 'Deleted article not found');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'article creation with auto-slug generation' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Create article without explicit slug
    my $unique_title = "Auto Slug Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $unique_title,
        content => 'Content here',
        is_published => 0
    })
      ->status_is(201)
      ->json_has('/article/slug', 'Slug auto-generated');

    my $slug = $t->tx->res->json->{article}->{slug};
    like($slug, qr/^auto-slug-test-\d+$/, 'Slug follows expected pattern');

    # Clean up
    my $id = $t->tx->res->json->{article}->{id};
    $t->delete_ok("/api/admin/articles/$id")->status_is(200);

    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'draft articles not visible to public' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login as admin
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Create a draft article
    my $draft_title = "Draft Article " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $draft_title,
        content => 'Draft content',
        is_published => 0
    })
      ->status_is(201);

    my $draft_slug = $t->tx->res->json->{article}->{slug};
    my $draft_id = $t->tx->res->json->{article}->{id};

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);

    # Try to access draft as public user
    $t->get_ok("/api/articles/$draft_slug")
      ->status_is(404, 'Draft article not accessible to public');

    # Login again to clean up
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    $t->delete_ok("/api/admin/articles/$draft_id")->status_is(200);
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'admin can retrieve all articles regardless of published status' => sub {
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set';
        return;
    }

    # Login as admin
    $t->post_ok('/api/auth/login' => json => {
        username => $ENV{ADMIN_USERNAME} || 'admin',
        password => $admin_pass
    })->status_is(200);

    # Create a published article
    my $published_title = "Published for All Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $published_title,
        content => 'Published content',
        is_published => 1
    })->status_is(201);
    my $published_id = $t->tx->res->json->{article}->{id};

    # Create a draft article
    my $draft_title = "Draft for All Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $draft_title,
        content => 'Draft content',
        is_published => 0
    })->status_is(201);
    my $draft_id = $t->tx->res->json->{article}->{id};

    # Get all articles without published filter (admin default behavior)
    $t->get_ok('/api/admin/articles')
      ->status_is(200, 'Admin can retrieve articles without filter');

    my $json = $t->tx->res->json;
    my @articles = @{$json->{articles}};

    # Check that we have both published and draft articles
    my @test_articles = grep {
        $_->{id} == $published_id || $_->{id} == $draft_id
    } @articles;

    is(scalar @test_articles, 2, 'Admin gets both published and draft articles by default');

    # Verify we can filter to just published
    $t->get_ok('/api/admin/articles?published=1')
      ->status_is(200, 'Admin can filter to published articles');

    my $published_json = $t->tx->res->json;
    my @published_articles = @{$published_json->{articles}};
    my @published_test = grep { $_->{id} == $published_id } @published_articles;
    my @draft_test_in_published = grep { $_->{id} == $draft_id } @published_articles;

    ok(scalar @published_test > 0, 'Published article found when filtering published=1');
    is(scalar @draft_test_in_published, 0, 'Draft article not found when filtering published=1');

    # Verify we can filter to just drafts
    $t->get_ok('/api/admin/articles?published=0')
      ->status_is(200, 'Admin can filter to draft articles');

    my $draft_json = $t->tx->res->json;
    my @draft_articles = @{$draft_json->{articles}};
    my @draft_test = grep { $_->{id} == $draft_id } @draft_articles;
    my @published_test_in_drafts = grep { $_->{id} == $published_id } @draft_articles;

    ok(scalar @draft_test > 0, 'Draft article found when filtering published=0');
    is(scalar @published_test_in_drafts, 0, 'Published article not found when filtering published=0');

    # Clean up
    $t->delete_ok("/api/admin/articles/$published_id")->status_is(200);
    $t->delete_ok("/api/admin/articles/$draft_id")->status_is(200);
    $t->post_ok('/api/auth/logout')->status_is(200);
};

done_testing();
