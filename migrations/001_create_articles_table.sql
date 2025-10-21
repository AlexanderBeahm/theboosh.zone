-- Create articles table for blog posts
CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT NOT NULL,
    excerpt TEXT,
    author VARCHAR(100) NOT NULL DEFAULT 'Alex Beahm',
    published_at TIMESTAMP,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_published BOOLEAN DEFAULT FALSE,
    meta_description TEXT,
    featured_image VARCHAR(255)
);

-- Create index on slug for fast lookups
CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug);

-- Create index on published_at for sorting published articles
CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles(published_at);

-- Create index on is_published for filtering
CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(is_published);
