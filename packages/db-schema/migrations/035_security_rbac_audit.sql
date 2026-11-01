-- ==============================================================================
-- EH Home Migration 035: Canonical RBAC, Security Principals & Immutable Audit
-- Part 14 Database Schema
-- ==============================================================================

-- 1. User Security Principals
CREATE TABLE IF NOT EXISTS user_security_principals (
    id VARCHAR(128) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'USER' CHECK (role IN ('ADMIN', 'OPERATOR', 'RELEASE_ENGINEER', 'AUDITOR', 'USER', 'SERVICE')),
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISABLED', 'REVOKED', 'PENDING_ACTIVATION')),
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    last_login_at TIMESTAMPTZ,
    last_password_change_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_sec_role ON user_security_principals(role);
CREATE INDEX IF NOT EXISTS idx_user_sec_status ON user_security_principals(status);

-- 2. Append-Only Security Audit Events
-- Dedicated high-throughput audit store with immutable guarantees
CREATE TABLE IF NOT EXISTS security_audit_events (
    id VARCHAR(64) PRIMARY KEY,
    sequence_number BIGSERIAL UNIQUE,
    actor_id VARCHAR(128) NOT NULL,
    actor_email VARCHAR(255),
    actor_role VARCHAR(32),
    action VARCHAR(64) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id VARCHAR(128),
    outcome VARCHAR(32) NOT NULL DEFAULT 'SUCCESS' CHECK (outcome IN ('SUCCESS', 'DENIED', 'FAILED', 'WARNING')),
    severity VARCHAR(16) NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    failure_reason TEXT,
    error_code VARCHAR(64),
    correlation_id VARCHAR(64),
    client_ip VARCHAR(45),
    user_agent TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sec_audit_actor ON security_audit_events(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sec_audit_action_outcome ON security_audit_events(action, outcome);
CREATE INDEX IF NOT EXISTS idx_sec_audit_resource ON security_audit_events(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_sec_audit_time ON security_audit_events(created_at DESC);
