-- Migration: Add sync fields for radio playback
-- Description: Adds total_duration field to track playlist length for synchronized playback

ALTER TABLE radio_config
ADD COLUMN IF NOT EXISTS total_duration INTEGER DEFAULT NULL;

COMMENT ON COLUMN radio_config.total_duration IS 'Total duration of playlist in seconds, NULL for live streams';
