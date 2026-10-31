-- =============================================================================
-- Migration 030: Add channel_configs to device_authorizations
-- Persists channel alert preferences, notifications, and custom settings
-- =============================================================================

ALTER TABLE device_authorizations
ADD COLUMN IF NOT EXISTS channel_configs JSONB DEFAULT '{}'::jsonb;
