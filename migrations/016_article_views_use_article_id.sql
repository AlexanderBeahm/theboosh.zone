-- Migration: Change article_views to use article_id instead of article_slug
-- This provides referential integrity and handles slug changes

-- Step 1: Add article_id column
ALTER TABLE article_views ADD COLUMN IF NOT EXISTS article_id INTEGER;

-- Step 2: Populate article_id from existing slug data (if any)
UPDATE article_views av
SET article_id = a.id
FROM articles a
WHERE av.article_slug = a.slug
  AND av.article_id IS NULL;

-- Step 3: Delete orphaned views (views for articles that no longer exist)
DELETE FROM article_views WHERE article_id IS NULL;

-- Step 4: Make article_id NOT NULL
ALTER TABLE article_views ALTER COLUMN article_id SET NOT NULL;

-- Step 5: Add foreign key constraint with CASCADE delete
-- When an article is deleted, its view records are also deleted
ALTER TABLE article_views
ADD CONSTRAINT fk_article_views_article_id
FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;

-- Step 6: Create index on article_id for efficient lookups
CREATE INDEX IF NOT EXISTS idx_article_views_article_id ON article_views(article_id);

-- Step 7: Drop the old article_slug column and its index
DROP INDEX IF EXISTS idx_article_views_slug_time;
ALTER TABLE article_views DROP COLUMN IF EXISTS article_slug;

-- Step 8: Update the unindexed partial index to use article_id
DROP INDEX IF EXISTS idx_article_views_unindexed;
CREATE INDEX IF NOT EXISTS idx_article_views_unindexed
ON article_views(article_id) WHERE view_indexed = FALSE;
