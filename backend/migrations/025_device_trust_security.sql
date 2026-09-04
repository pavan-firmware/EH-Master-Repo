-- =============================================================================
-- Migration 025: Secure Device Identity, Trust & Credential Lifecycle
-- Phase 32 Database Schema
-- =============================================================================

-- 1. Device Trust State Engine
CREATE TABLE IF NOT EXISTS device_trust_states (
    device_id VARCHAR(64) PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    trust_state VARCHAR(32) NOT NULL DEFAULT 'PROVISIONED',
    trust_score DOUBLE PRECISION NOT NULL DEFAULT 100.0,
    reasoning_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    quarantined_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    last_evaluated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_trust_state ON device_trust_states(trust_state);
CREATE INDEX IF NOT EXISTS idx_device_trust_score ON device_trust_states(trust_score);

-- 2. Device Credential Lifecycle Ledger (Historical ledger only; device_credentials is authoritative)
-- NOTE: metadata JSONB strictly prohibited from storing raw secrets, passwords, or keys.
CREATE TABLE IF NOT EXISTS device_credential_lifecycle (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    credential_type VARCHAR(32) NOT NULL,
    key_identifier VARCHAR(128) NOT NULL,
    fingerprint VARCHAR(128),
    status VARCHAR(32) NOT NULL DEFAULT 'ROTATION_PENDING',
    rotation_generation INT NOT NULL DEFAULT 1,
    issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    rotated_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_cred_lifecycle_device_type ON device_credential_lifecycle(device_id, credential_type);
CREATE INDEX IF NOT EXISTS idx_cred_lifecycle_status ON device_credential_lifecycle(status);
CREATE INDEX IF NOT EXISTS idx_cred_lifecycle_generation ON device_credential_lifecycle(rotation_generation);

-- 3. Explicit Device Revocation & Quarantine Records
CREATE TABLE IF NOT EXISTS device_revocations (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    revocation_type VARCHAR(32) NOT NULL,
    reason TEXT NOT NULL,
    actor_user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    evidence_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    remediation_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_revocations_device ON device_revocations(device_id);
CREATE INDEX IF NOT EXISTS idx_device_revocations_type ON device_revocations(revocation_type);
CREATE INDEX IF NOT EXISTS idx_device_revocations_time ON device_revocations(created_at DESC);

-- 4. Device Provisioning Records
CREATE TABLE IF NOT EXISTS device_provisioning_records (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    stage VARCHAR(32) NOT NULL,
    authority VARCHAR(64) NOT NULL,
    evidence_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dev_prov_records_device ON device_provisioning_records(device_id);
CREATE INDEX IF NOT EXISTS idx_dev_prov_records_stage ON device_provisioning_records(stage);
CREATE INDEX IF NOT EXISTS idx_dev_prov_records_time ON device_provisioning_records(created_at DESC);
