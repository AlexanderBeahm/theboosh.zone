-- Add retention policy for article_views table
-- Retention period: 2 years (730 days)
-- This function can be called periodically to clean up old records

-- Create function to delete old article views
CREATE OR REPLACE FUNCTION cleanup_old_article_views(retention_days INTEGER DEFAULT 730)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM article_views
    WHERE viewed_at < CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Add comment documenting the retention policy
COMMENT ON FUNCTION cleanup_old_article_views(INTEGER) IS
'Deletes article_views records older than the specified retention period (default: 730 days / 2 years).
Call periodically via cron job or scheduled task.
Example: SELECT cleanup_old_article_views(730); -- Delete records older than 2 years
Returns the number of deleted records.';

-- Add comment on the table for documentation
COMMENT ON TABLE article_views IS
'Tracks individual article views for analytics. Retention policy: 2 years.
Use cleanup_old_article_views() function periodically to remove old records.
Expected growth: ~1000 views/day = ~365K rows/year.';
