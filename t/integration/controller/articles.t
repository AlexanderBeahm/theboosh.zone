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

subtest 'orphaned tag cleanup - unique tag deletion' => sub {
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

    # Create unique tag name to ensure it doesn't already exist
    my $unique_tag = 'orphan-test-' . time();

    # Create article with unique tag
    my $article_title = "Orphan Tag Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $article_title,
        content => 'Test content for orphaned tag cleanup',
        is_published => 1,
        tags => [$unique_tag]
    })->status_is(201, 'Article created with unique tag');

    my $article_id = $t->tx->res->json->{article}->{id};
    ok($article_id, 'Got article ID');

    # Verify tag was created
    $t->get_ok('/api/tags')
      ->status_is(200);

    my $tags_before = $t->tx->res->json->{tags};
    my ($created_tag) = grep { $_->{slug} eq $unique_tag } @{$tags_before};
    ok($created_tag, "Tag '$unique_tag' exists after article creation");
    my $tag_id = $created_tag->{id};

    # Delete the article
    $t->delete_ok("/api/admin/articles/$article_id")
      ->status_is(200, 'Article deleted successfully');

    # Verify orphaned tag was cleaned up
    $t->get_ok('/api/tags')
      ->status_is(200);

    my $tags_after = $t->tx->res->json->{tags};
    my ($orphaned_tag) = grep { $_->{slug} eq $unique_tag } @{$tags_after};
    ok(!$orphaned_tag, "Orphaned tag '$unique_tag' was deleted");

    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'orphaned tag cleanup - shared tags preserved' => sub {
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

    # Create unique tag names
    my $shared_tag = 'shared-tag-' . time();
    my $unique_tag = 'unique-tag-' . time();

    # Create first article with shared and unique tags
    my $article1_title = "Shared Tags Test 1 " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $article1_title,
        content => 'First article content',
        is_published => 1,
        tags => [$shared_tag, $unique_tag]
    })->status_is(201);
    my $article1_id = $t->tx->res->json->{article}->{id};

    # Create second article with only shared tag
    my $article2_title = "Shared Tags Test 2 " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $article2_title,
        content => 'Second article content',
        is_published => 1,
        tags => [$shared_tag]
    })->status_is(201);
    my $article2_id = $t->tx->res->json->{article}->{id};

    # Verify both tags exist
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_before = $t->tx->res->json->{tags};
    my ($shared_before) = grep { $_->{slug} eq $shared_tag } @{$tags_before};
    my ($unique_before) = grep { $_->{slug} eq $unique_tag } @{$tags_before};
    ok($shared_before, "Shared tag exists before deletion");
    ok($unique_before, "Unique tag exists before deletion");

    # Delete first article (has unique tag and shared tag)
    $t->delete_ok("/api/admin/articles/$article1_id")
      ->status_is(200);

    # Verify shared tag still exists, unique tag deleted
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_after = $t->tx->res->json->{tags};
    my ($shared_after) = grep { $_->{slug} eq $shared_tag } @{$tags_after};
    my ($unique_after) = grep { $_->{slug} eq $unique_tag } @{$tags_after};
    ok($shared_after, "Shared tag preserved (still used by article 2)");
    ok(!$unique_after, "Unique tag deleted (not used by any articles)");

    # Clean up
    $t->delete_ok("/api/admin/articles/$article2_id")->status_is(200);
    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'orphaned tag cleanup - multiple orphaned tags' => sub {
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

    # Create article with multiple unique tags
    my $tag1 = 'multi-orphan-1-' . time();
    my $tag2 = 'multi-orphan-2-' . time();
    my $tag3 = 'multi-orphan-3-' . time();

    my $article_title = "Multiple Orphans Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $article_title,
        content => 'Test content with multiple tags',
        is_published => 1,
        tags => [$tag1, $tag2, $tag3]
    })->status_is(201);
    my $article_id = $t->tx->res->json->{article}->{id};

    # Verify all tags exist
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_before = $t->tx->res->json->{tags};
    my $tag1_before = grep { $_->{slug} eq $tag1 } @{$tags_before};
    my $tag2_before = grep { $_->{slug} eq $tag2 } @{$tags_before};
    my $tag3_before = grep { $_->{slug} eq $tag3 } @{$tags_before};
    ok($tag1_before, "Tag 1 exists before deletion");
    ok($tag2_before, "Tag 2 exists before deletion");
    ok($tag3_before, "Tag 3 exists before deletion");

    # Delete article
    $t->delete_ok("/api/admin/articles/$article_id")
      ->status_is(200);

    # Verify all orphaned tags were deleted
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_after = $t->tx->res->json->{tags};
    my $tag1_after = grep { $_->{slug} eq $tag1 } @{$tags_after};
    my $tag2_after = grep { $_->{slug} eq $tag2 } @{$tags_after};
    my $tag3_after = grep { $_->{slug} eq $tag3 } @{$tags_after};
    ok(!$tag1_after, "Tag 1 deleted");
    ok(!$tag2_after, "Tag 2 deleted");
    ok(!$tag3_after, "Tag 3 deleted");

    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'orphaned tag cleanup - article with no tags' => sub {
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

    # Create article without tags
    my $article_title = "No Tags Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $article_title,
        content => 'Article without tags',
        is_published => 1
    })->status_is(201);
    my $article_id = $t->tx->res->json->{article}->{id};

    # Delete article (should not error even though there are no tags)
    $t->delete_ok("/api/admin/articles/$article_id")
      ->status_is(200, 'Article without tags deleted successfully');

    $t->post_ok('/api/auth/logout')->status_is(200);
};

subtest 'orphaned tag cleanup - draft article deletion' => sub {
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

    # Create unique tag
    my $draft_tag = 'draft-orphan-' . time();

    # Create draft article with unique tag
    my $draft_title = "Draft Orphan Test " . time();
    $t->post_ok('/api/admin/articles' => json => {
        title => $draft_title,
        content => 'Draft article content',
        is_published => 0,
        tags => [$draft_tag]
    })->status_is(201);
    my $draft_id = $t->tx->res->json->{article}->{id};

    # Verify tag exists
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_before = $t->tx->res->json->{tags};
    my ($tag_before) = grep { $_->{slug} eq $draft_tag } @{$tags_before};
    ok($tag_before, "Draft article tag exists");

    # Delete draft article
    $t->delete_ok("/api/admin/articles/$draft_id")
      ->status_is(200);

    # Verify orphaned tag was cleaned up (even from draft)
    $t->get_ok('/api/tags')->status_is(200);
    my $tags_after = $t->tx->res->json->{tags};
    my ($tag_after) = grep { $_->{slug} eq $draft_tag } @{$tags_after};
    ok(!$tag_after, "Orphaned tag from draft article was deleted");

    $t->post_ok('/api/auth/logout')->status_is(200);
};

done_testing();
