-- =============================================================================
-- Migration 028: Production Device Fleet Management & Safe OTA Rollout (DOWN)
-- =============================================================================

DROP TABLE IF EXISTS ota_attempts;
DROP TABLE IF EXISTS fleet_device_firmware_state;
