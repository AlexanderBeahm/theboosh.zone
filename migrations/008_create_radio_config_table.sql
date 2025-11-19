-- Migration: Create radio_config table
-- Description: Store configuration for the radio streaming feature
-- Author: System
-- Date: 2025-11-18

-- Create radio_config table to store playlist configuration
CREATE TABLE IF NOT EXISTS radio_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(255) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    description TEXT,
    updated_by INTEGER REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on config_key for faster lookups
CREATE INDEX IF NOT EXISTS idx_radio_config_key ON radio_config(config_key);

-- Insert default configuration for playlist URL
INSERT INTO radio_config (config_key, config_value, description)
VALUES
    ('playlist_url', '', 'URL to the .m3u playlist file (local or remote)')
ON CONFLICT (config_key) DO NOTHING;

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_radio_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER radio_config_updated_at
    BEFORE UPDATE ON radio_config
    FOR EACH ROW
    EXECUTE FUNCTION update_radio_config_updated_at();

-- Add comment to table
COMMENT ON TABLE radio_config IS 'Configuration storage for radio streaming feature';
COMMENT ON COLUMN radio_config.config_key IS 'Unique configuration key identifier';
COMMENT ON COLUMN radio_config.config_value IS 'Configuration value (can store URLs, JSON, etc.)';
COMMENT ON COLUMN radio_config.updated_by IS 'User ID of admin who last updated this config';
