-- Create article_views table for tracking article viewership with IP addresses
CREATE TABLE IF NOT EXISTS article_views (
    id SERIAL PRIMARY KEY,
    article_slug VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast queries by article slug and time
CREATE INDEX IF NOT EXISTS idx_article_views_slug_time ON article_views(article_slug, viewed_at);

-- Index for IP-based analysis
CREATE INDEX IF NOT EXISTS idx_article_views_ip ON article_views(ip_address);

-- Index for time-based queries
CREATE INDEX IF NOT EXISTS idx_article_views_time ON article_views(viewed_at);
