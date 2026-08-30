-- =============================================================================
-- Migration 007: Device Management, Health Metrics, Activity & Observability
-- Phase 11 Database Schema
-- =============================================================================

CREATE TABLE IF NOT EXISTS device_activity_logs (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    device_id VARCHAR(64) REFERENCES devices(id) ON DELETE CASCADE,
    event_type VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL DEFAULT 'info',
    message TEXT NOT NULL,
    correlation_id VARCHAR(128),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_activity_logs_device_id ON device_activity_logs(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_activity_logs_home_id ON device_activity_logs(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_activity_logs_correlation_id ON device_activity_logs(correlation_id);

CREATE TABLE IF NOT EXISTS device_health_metrics (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL UNIQUE REFERENCES devices(id) ON DELETE CASCADE,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    health_status VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN',
    last_seen_at TIMESTAMP WITH TIME ZONE,
    uptime_seconds INTEGER DEFAULT 0,
    rssi INTEGER,
    ip_address VARCHAR(45),
    command_success_count INTEGER NOT NULL DEFAULT 0,
    command_failure_count INTEGER NOT NULL DEFAULT 0,
    last_error_message TEXT,
    last_error_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_health_metrics_home_id ON device_health_metrics(home_id);
CREATE INDEX IF NOT EXISTS idx_device_health_metrics_health_status ON device_health_metrics(health_status);
