-- Migration: Create view count aggregation function
-- This incrementally aggregates article_views counts into the permanent view_count column
-- Scheduling is handled by Docker cron container (not pg_cron due to managed DB limitations)

-- Function to incrementally aggregate view counts from article_views to articles.view_count
-- This function:
-- 1. Counts only NEW views (view_indexed = FALSE) per article
-- 2. Increments the view_count column on each article (does not replace)
-- 3. Marks processed views as view_indexed = TRUE
-- 4. Returns the number of new views processed
--
-- This incremental approach ensures:
-- - Each view is only counted once
-- - Counts persist after old article_views records are cleaned up
-- - Aggregation is efficient (only processes new views)
CREATE OR REPLACE FUNCTION aggregate_article_view_counts()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
BEGIN
    -- Step 1: Count unindexed views per article and increment view_count
    WITH new_view_counts AS (
        SELECT
            article_id,
            COUNT(*) as new_views
        FROM article_views
        WHERE view_indexed = FALSE
        GROUP BY article_id
    )
    UPDATE articles a
    SET view_count = a.view_count + nvc.new_views
    FROM new_view_counts nvc
    WHERE a.id = nvc.article_id;

    -- Step 2: Mark all unindexed views as indexed
    UPDATE article_views
    SET view_indexed = TRUE
    WHERE view_indexed = FALSE;

    GET DIAGNOSTICS processed_count = ROW_COUNT;

    -- Log the aggregation (visible in PostgreSQL logs)
    IF processed_count > 0 THEN
        RAISE NOTICE 'Article view count aggregation complete. Processed % new views.', processed_count;
    END IF;

    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Comment for documentation
COMMENT ON FUNCTION aggregate_article_view_counts() IS
    'Incrementally aggregates new view counts from article_views into articles.view_count. '
    'Only processes views where view_indexed = FALSE, then marks them as indexed. '
    'Called periodically via Docker cron container to maintain permanent view statistics.';
