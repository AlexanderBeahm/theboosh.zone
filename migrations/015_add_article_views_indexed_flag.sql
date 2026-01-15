-- Migration: Add view_indexed flag to article_views table
-- This tracks which views have been aggregated into articles.view_count

ALTER TABLE article_views ADD COLUMN IF NOT EXISTS view_indexed BOOLEAN DEFAULT FALSE NOT NULL;

-- Partial index for efficient querying of unindexed views
-- Only indexes rows where view_indexed = FALSE (the ones we need to process)
CREATE INDEX IF NOT EXISTS idx_article_views_unindexed
ON article_views(article_slug) WHERE view_indexed = FALSE;

-- Comment for documentation
COMMENT ON COLUMN article_views.view_indexed IS 'TRUE if this view has been counted in articles.view_count';
