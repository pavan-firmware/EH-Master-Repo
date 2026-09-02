-- =============================================================================
-- Migration 011: Device Fleet Management, Firmware Inventory & OTA Lifecycle (DOWN)
-- =============================================================================

DROP TABLE IF EXISTS device_maintenance_logs;
DROP TABLE IF EXISTS ota_operations;
DROP TABLE IF EXISTS ota_rollouts;
DROP TABLE IF EXISTS firmware_releases;
