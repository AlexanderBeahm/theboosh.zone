-- Create media table for uploaded images and files
CREATE TABLE IF NOT EXISTS media (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    filepath VARCHAR(512) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size INTEGER NOT NULL,
    width INTEGER,
    height INTEGER,
    uploaded_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    alt_text TEXT,
    caption TEXT
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_media_filename ON media(filename);
CREATE INDEX IF NOT EXISTS idx_media_mime_type ON media(mime_type);
CREATE INDEX IF NOT EXISTS idx_media_uploaded_by ON media(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_media_created_at ON media(created_at DESC);

-- Comments for documentation
COMMENT ON TABLE media IS 'Stores metadata for uploaded media files (images, etc.)';
COMMENT ON COLUMN media.filename IS 'Generated unique filename stored on disk';
COMMENT ON COLUMN media.original_filename IS 'Original filename from upload';
COMMENT ON COLUMN media.filepath IS 'Relative path from uploads directory';
COMMENT ON COLUMN media.file_size IS 'File size in bytes';
COMMENT ON COLUMN media.width IS 'Image width in pixels (null for non-images)';
COMMENT ON COLUMN media.height IS 'Image height in pixels (null for non-images)';
