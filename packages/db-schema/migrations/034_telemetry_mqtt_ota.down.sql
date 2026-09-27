-- =============================================================================
-- Migration Down: 034_telemetry_mqtt_ota.down.sql
-- Explicit Non-Destructive Delete Policy without CASCADE in reverse order
-- =============================================================================

DROP TABLE IF EXISTS ota_execution_jobs;
DROP TABLE IF EXISTS device_availability_history;
DROP TABLE IF EXISTS mqtt_acl_rules;
