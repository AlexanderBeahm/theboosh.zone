#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

# Initialize the Mojolicious app
my $t = Test::Mojo->new('HelloPerld');

subtest 'get tags endpoint exists' => sub {
    $t->get_ok('/api/tags')
      ->status_is(200, 'Tags endpoint returns 200');
};

subtest 'get tags returns JSON array' => sub {
    $t->get_ok('/api/tags')
      ->status_is(200)
      ->header_is('Content-Type' => 'application/json;charset=UTF-8')
      ->json_has('/tags', 'Response has tags array')
      ->json_has('/pagination', 'Response has pagination object');

    my $json = $t->tx->res->json;
    is(ref $json->{tags}, 'ARRAY', 'Tags is an array');
};

subtest 'tags pagination metadata' => sub {
    $t->get_ok('/api/tags')
      ->status_is(200)
      ->json_has('/pagination/page', 'Has page')
      ->json_has('/pagination/limit', 'Has limit')
      ->json_has('/pagination/total', 'Has total');
};

subtest 'tags with order_by parameter' => sub {
    $t->get_ok('/api/tags?order_by=name')
      ->status_is(200, 'order_by=name accepted');

    $t->get_ok('/api/tags?order_by=usage')
      ->status_is(200, 'order_by=usage accepted');
};

subtest 'popular tags endpoint' => sub {
    $t->get_ok('/api/tags/popular')
      ->status_is(200, 'Popular tags endpoint exists')
      ->json_has('/tags', 'Response has tags array');

    my $tags = $t->tx->res->json->{tags};
    is(ref $tags, 'ARRAY', 'Tags is an array');

    # Verify tags have usage_count field
    if (scalar @$tags > 0) {
        ok(exists $tags->[0]->{usage_count}, 'Tags include usage_count');
    } else {
        pass('No tags to verify (empty database)');
    }
};

subtest 'search tags endpoint' => sub {
    $t->get_ok('/api/tags/search?q=test')
      ->status_is(200, 'Search endpoint accepts query')
      ->json_has('/tags', 'Response has tags array')
      ->json_has('/query', 'Response includes query param');
};

subtest 'search tags - empty query' => sub {
    $t->get_ok('/api/tags/search')
      ->status_is(400, 'Search without query returns 400')
      ->json_has('/error', 'Error message included');
};

subtest 'get tag by slug - nonexistent' => sub {
    $t->get_ok('/api/tags/nonexistent-tag-slug')
      ->status_is(404, 'Nonexistent tag returns 404');
};

subtest 'admin tag operations require authentication' => sub {
    $t->post_ok('/api/admin/tags' => json => {
        name => 'Test Tag'
    })
      ->status_is(401, 'Creating tag requires authentication');
};

subtest 'admin tag CRUD - with authentication' => sub {
    my $admin_user = $ENV{ADMIN_USERNAME} || 'admin';
    my $admin_pass = $ENV{ADMIN_PASSWORD};

    unless ($admin_pass) {
        plan skip_all => 'ADMIN_PASSWORD not set for admin tag tests';
        return;
    }

    # Login
    $t->post_ok('/api/auth/login' => json => {
        username => $admin_user,
        password => $admin_pass
    })->status_is(200, 'Login successful');

    # Create a test tag
    my $test_name = 'TestTag' . time();
    my $tag_id;

    $t->post_ok('/api/admin/tags' => json => {
        name => $test_name
    })
      ->status_is(201, 'Tag created successfully')
      ->json_has('/id', 'Response includes tag ID')
      ->json_is('/name' => $test_name, 'Name matches')
      ->json_has('/slug', 'Slug was auto-generated');

    $tag_id = $t->tx->res->json->{id};
    my $slug = $t->tx->res->json->{slug};
    ok($tag_id, 'Got tag ID');

    # Get the tag by ID
    $t->get_ok("/api/tags/$tag_id")
      ->status_is(200, 'Can retrieve tag by ID')
      ->json_is('/id' => $tag_id, 'ID matches')
      ->json_is('/name' => $test_name, 'Name matches');

    # Get the tag by slug
    $t->get_ok("/api/tags/$slug")
      ->status_is(200, 'Can retrieve tag by slug')
      ->json_is('/slug' => $slug, 'Slug matches');

    # Update the tag
    $t->put_ok("/api/admin/tags/$tag_id" => json => {
        name => "$test_name Updated"
    })
      ->status_is(200, 'Tag updated successfully')
      ->json_is('/name' => "$test_name Updated", 'Name was updated');

    # Delete the tag
    $t->delete_ok("/api/admin/tags/$tag_id")
      ->status_is(200, 'Tag deleted successfully')
      ->json_has('/message', 'Delete confirmation message');

    # Verify tag is gone
    $t->get_ok("/api/tags/$tag_id")
      ->status_is(404, 'Deleted tag not found');

    # Logout
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'tag usage count reflects article associations' => sub {
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

    # Create a unique tag
    my $tag_name = 'UsageTest' . time();
    $t->post_ok('/api/admin/tags' => json => {
        name => $tag_name
    })->status_is(201);

    my $tag_id = $t->tx->res->json->{id};

    # Create an article with this tag
    $t->post_ok('/api/admin/articles' => json => {
        title => "Article with $tag_name",
        content => 'Content',
        is_published => 1,
        tags => [$tag_name]
    })->status_is(201);

    my $article_id = $t->tx->res->json->{id};

    # Get the tag and verify usage_count
    $t->get_ok("/api/tags/$tag_id")
      ->status_is(200)
      ->json_is('/usage_count' => 1, 'Usage count is 1 after associating with article');

    # Clean up
    $t->delete_ok("/api/admin/articles/$article_id")->status_is(200);
    $t->delete_ok("/api/admin/tags/$tag_id")->status_is(200);

    $t->post_ok('/api/auth/logout')->status_is(200);
};

done_testing();
