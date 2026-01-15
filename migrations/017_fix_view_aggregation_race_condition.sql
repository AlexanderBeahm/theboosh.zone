-- Migration: Fix race condition in view count aggregation
-- Replaces function with row-locking version to prevent double-counting or view loss
-- when multiple cron jobs run simultaneously

CREATE OR REPLACE FUNCTION aggregate_article_view_counts()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
BEGIN
    -- Use a single atomic operation with row-level locking
    -- FOR UPDATE SKIP LOCKED prevents concurrent executions from processing same rows
    -- This ensures:
    -- 1. Each view is only counted once (rows are locked during processing)
    -- 2. Concurrent executions skip already-locked rows instead of waiting
    -- 3. No views are lost between counting and marking as indexed
    WITH views_to_process AS (
        SELECT id, article_id
        FROM article_views
        WHERE view_indexed = FALSE
        FOR UPDATE SKIP LOCKED
    ),
    view_counts AS (
        SELECT article_id, COUNT(*) as new_views
        FROM views_to_process
        GROUP BY article_id
    ),
    updated_articles AS (
        UPDATE articles a
        SET view_count = a.view_count + vc.new_views
        FROM view_counts vc
        WHERE a.id = vc.article_id
        RETURNING a.id
    )
    UPDATE article_views av
    SET view_indexed = TRUE
    FROM views_to_process vtp
    WHERE av.id = vtp.id;

    GET DIAGNOSTICS processed_count = ROW_COUNT;

    IF processed_count > 0 THEN
        RAISE NOTICE 'Article view count aggregation complete. Processed % new views.', processed_count;
    END IF;

    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Update function comment
COMMENT ON FUNCTION aggregate_article_view_counts() IS
    'Incrementally aggregates new view counts from article_views into articles.view_count. '
    'Uses FOR UPDATE SKIP LOCKED to prevent race conditions when multiple aggregation jobs run. '
    'Only processes views where view_indexed = FALSE, then marks them as indexed. '
    'Called periodically via Docker cron container to maintain permanent view statistics.';
