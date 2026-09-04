-- =============================================================================
-- Migration 024: Secure Operations, Audit & Platform Observability
-- Phase 31 Database Schema
-- =============================================================================

-- 1. Multi-Domain Operational Event Store
CREATE TABLE IF NOT EXISTS operational_events (
    id VARCHAR(64) PRIMARY KEY,
    correlation_id VARCHAR(64) NOT NULL,
    causation_id VARCHAR(64),
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    device_id VARCHAR(64) REFERENCES devices(id) ON DELETE SET NULL,
    room_id VARCHAR(64) REFERENCES rooms(id) ON DELETE SET NULL,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    subsystem VARCHAR(32) NOT NULL,
    operation VARCHAR(128) NOT NULL,
    action VARCHAR(128) NOT NULL,
    source VARCHAR(64) NOT NULL,
    execution_path VARCHAR(32) NOT NULL DEFAULT 'CLOUD',
    severity VARCHAR(16) NOT NULL DEFAULT 'INFO',
    authorization_result VARCHAR(32) NOT NULL DEFAULT 'AUTHORIZED',
    outcome VARCHAR(32) NOT NULL DEFAULT 'SUCCESS',
    failure_code VARCHAR(64),
    duration_ms DOUBLE PRECISION,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    redaction_markers JSONB NOT NULL DEFAULT '[]'::jsonb,
    trace_lifecycle VARCHAR(32),
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_operational_events_correlation ON operational_events(correlation_id);
CREATE INDEX IF NOT EXISTS idx_operational_events_causation ON operational_events(causation_id);
CREATE INDEX IF NOT EXISTS idx_operational_events_home_time ON operational_events(home_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_operational_events_subsystem ON operational_events(subsystem, outcome);
CREATE INDEX IF NOT EXISTS idx_operational_events_severity ON operational_events(severity);

-- 2. Tamper-Evident Hash-Chained Security Audit Records
-- NOTE: Distinct from general audit_logs. Restricted exclusively to security-sensitive,
-- hash-chained transitions (auth bursts, role elevation, policy change, factory reset, tamper).
CREATE TABLE IF NOT EXISTS security_audit_records (
    id VARCHAR(64) PRIMARY KEY,
    sequence_number BIGINT UNIQUE NOT NULL,
    record_hash VARCHAR(64) NOT NULL,
    prev_record_hash VARCHAR(64) NOT NULL,
    actor_user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    device_id VARCHAR(64) REFERENCES devices(id) ON DELETE SET NULL,
    action VARCHAR(128) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id VARCHAR(128),
    outcome VARCHAR(32) NOT NULL DEFAULT 'SUCCESS',
    ip_address VARCHAR(45),
    correlation_id VARCHAR(64),
    canonical_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_audit_seq ON security_audit_records(sequence_number ASC);
CREATE INDEX IF NOT EXISTS idx_security_audit_home ON security_audit_records(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_audit_action ON security_audit_records(action, outcome);

-- 3. Observational Subsystem Health Snapshots
CREATE TABLE IF NOT EXISTS system_health_snapshots (
    id VARCHAR(64) PRIMARY KEY,
    status VARCHAR(32) NOT NULL DEFAULT 'HEALTHY',
    subsystems_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_snapshots_time ON system_health_snapshots(recorded_at DESC);
