-- =============================================================================
-- Migration: 034_telemetry_mqtt_ota.sql
-- Description: EMQX MQTT ACL rules, device availability history & OTA execution jobs
-- Explicit Non-Destructive Delete Policy (ON DELETE RESTRICT)
-- =============================================================================

-- 1. MQTT Client ACL Authorization Rules
CREATE TABLE IF NOT EXISTS mqtt_acl_rules (
    id VARCHAR(128) PRIMARY KEY,
    client_id VARCHAR(128) NOT NULL,
    username VARCHAR(128),
    permission VARCHAR(16) NOT NULL DEFAULT 'allow',
    action VARCHAR(16) NOT NULL DEFAULT 'all', -- 'publish', 'subscribe', 'all'
    topic VARCHAR(255) NOT NULL,
    qos SMALLINT DEFAULT 1,
    retain SMALLINT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mqtt_acl_client ON mqtt_acl_rules(client_id);
CREATE INDEX IF NOT EXISTS idx_mqtt_acl_username ON mqtt_acl_rules(username);
CREATE INDEX IF NOT EXISTS idx_mqtt_acl_topic ON mqtt_acl_rules(topic);

-- 2. Device Availability History
CREATE TABLE IF NOT EXISTS device_availability_history (
    id VARCHAR(128) PRIMARY KEY,
    device_id VARCHAR(128) NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
    status VARCHAR(32) NOT NULL, -- 'ONLINE', 'OFFLINE', 'STALE'
    source VARCHAR(32) NOT NULL DEFAULT 'MQTT_LWT', -- 'MQTT_CONNECT', 'MQTT_LWT', 'HEARTBEAT_TIMEOUT', 'DISCONNECT'
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_avail_history_device ON device_availability_history(device_id);
CREATE INDEX IF NOT EXISTS idx_avail_history_recorded_at ON device_availability_history(recorded_at);

-- 3. OTA Execution Jobs
CREATE TABLE IF NOT EXISTS ota_execution_jobs (
    id VARCHAR(128) PRIMARY KEY,
    device_id VARCHAR(128) NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
    release_id VARCHAR(128) NOT NULL,
    rollout_id VARCHAR(128),
    firmware_family VARCHAR(64) NOT NULL,
    target_version VARCHAR(32) NOT NULL,
    from_version VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'REQUESTED', -- 'REQUESTED', 'DOWNLOADING', 'VERIFYING', 'INSTALLED', 'BOOT_VERIFIED', 'HEALTH_VERIFIED', 'FAILED', 'ROLLED_BACK'
    progress_percent INTEGER DEFAULT 0,
    error_code VARCHAR(64),
    error_message TEXT,
    sha256 VARCHAR(64) NOT NULL,
    ed25519_signature VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_ota_jobs_device ON ota_execution_jobs(device_id);
CREATE INDEX IF NOT EXISTS idx_ota_jobs_status ON ota_execution_jobs(status);
CREATE INDEX IF NOT EXISTS idx_ota_jobs_release ON ota_execution_jobs(release_id);
