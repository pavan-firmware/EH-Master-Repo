-- =============================================================================
-- Migration 029: Production Observability, Monitoring & Incident Response
-- Phase 43 Database Schema
-- Managed Tables: platform_incidents, platform_alerts
-- =============================================================================

-- 1. Platform Incidents Table
-- Canonical platform-wide incident lifecycle tracking.
CREATE TABLE IF NOT EXISTS platform_incidents (
    id VARCHAR(64) PRIMARY KEY,
    incident_type VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status VARCHAR(32) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING', 'MITIGATING', 'RESOLVED', 'CLOSED')),
    component VARCHAR(64) NOT NULL,
    summary VARCHAR(255) NOT NULL,
    description TEXT,
    affected_entities_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    correlation_ids_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    first_observed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_observed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    acknowledged_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    investigating_at TIMESTAMP WITH TIME ZONE,
    investigating_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    mitigating_at TIMESTAMP WITH TIME ZONE,
    mitigating_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_platform_incidents_status ON platform_incidents(status);
CREATE INDEX IF NOT EXISTS idx_platform_incidents_severity ON platform_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_platform_incidents_component ON platform_incidents(component);
CREATE INDEX IF NOT EXISTS idx_platform_incidents_time ON platform_incidents(first_observed_at DESC);

-- 2. Platform Alerts Table
-- Deterministic, fingerprinted alert records.
CREATE TABLE IF NOT EXISTS platform_alerts (
    id VARCHAR(64) PRIMARY KEY,
    alert_type VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    component VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ACKNOWLEDGED', 'RESOLVED', 'SUPPRESSED')),
    incident_id VARCHAR(64) REFERENCES platform_incidents(id) ON DELETE SET NULL,
    summary VARCHAR(255) NOT NULL,
    fingerprint VARCHAR(128) NOT NULL,
    occurrence_count INTEGER NOT NULL DEFAULT 1,
    first_seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    correlation_id VARCHAR(64),
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_platform_alerts_fingerprint ON platform_alerts(fingerprint, status);
CREATE INDEX IF NOT EXISTS idx_platform_alerts_incident ON platform_alerts(incident_id);
CREATE INDEX IF NOT EXISTS idx_platform_alerts_status ON platform_alerts(status);
CREATE INDEX IF NOT EXISTS idx_platform_alerts_seen ON platform_alerts(last_seen_at DESC);
