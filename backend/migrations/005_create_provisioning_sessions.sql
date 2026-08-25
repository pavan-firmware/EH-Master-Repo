-- Migration 005: Create Provisioning Sessions Table (Phase 5)

CREATE TABLE IF NOT EXISTS provisioning_sessions (
    id VARCHAR(128) PRIMARY KEY,
    device_id VARCHAR(128) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    app_challenge VARCHAR(256),
    device_challenge VARCHAR(256),
    ssid VARCHAR(128),
    status VARCHAR(32) NOT NULL DEFAULT 'CREATED',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_prov_sessions_dev_status ON provisioning_sessions(device_id, status);
