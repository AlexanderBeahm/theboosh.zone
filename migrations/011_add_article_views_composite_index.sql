-- Add composite index for IP-based queries with article slug and time
-- This optimizes queries that filter by IP address and need slug/time data
CREATE INDEX IF NOT EXISTS idx_article_views_ip_slug_time
ON article_views(ip_address, article_slug, viewed_at);
