-- Migration: Add view_count column to articles table
-- This stores the aggregated/permanent view count that survives article_views cleanup

ALTER TABLE articles ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0 NOT NULL;

-- Add index for sorting by popularity
CREATE INDEX IF NOT EXISTS idx_articles_view_count ON articles(view_count DESC);

-- Comment for documentation
COMMENT ON COLUMN articles.view_count IS 'Aggregated view count, updated periodically from article_views table';
