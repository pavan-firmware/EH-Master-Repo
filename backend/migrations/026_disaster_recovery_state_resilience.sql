-- =============================================================================
-- Migration 026: Disaster Recovery, Backup & State Resilience
-- Phase 33 Database Schema
-- =============================================================================

-- 1. Backup Records Table
CREATE TABLE IF NOT EXISTS backup_records (
    backup_id VARCHAR(64) PRIMARY KEY,
    status VARCHAR(32) NOT NULL DEFAULT 'CREATED',
    scope VARCHAR(32) NOT NULL DEFAULT 'FULL',
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE SET NULL,
    provider VARCHAR(64) NOT NULL DEFAULT 'LocalBackupProvider',
    location TEXT NOT NULL,
    schema_version_recorded INT NOT NULL DEFAULT 1,
    migration_version_recorded INT NOT NULL DEFAULT 26,
    object_count INT NOT NULL DEFAULT 0,
    total_bytes BIGINT NOT NULL DEFAULT 0,
    manifest_checksum VARCHAR(128),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_backup_records_status ON backup_records(status);
CREATE INDEX IF NOT EXISTS idx_backup_records_created ON backup_records(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_backup_records_home ON backup_records(home_id);

-- 2. Backup Objects Table
CREATE TABLE IF NOT EXISTS backup_objects (
    id VARCHAR(64) PRIMARY KEY,
    backup_id VARCHAR(64) NOT NULL REFERENCES backup_records(backup_id) ON DELETE CASCADE,
    object_key VARCHAR(128) NOT NULL,
    entity_type VARCHAR(64) NOT NULL,
    record_count INT NOT NULL DEFAULT 0,
    byte_size BIGINT NOT NULL DEFAULT 0,
    sha256_checksum VARCHAR(128) NOT NULL,
    data_classification VARCHAR(32) NOT NULL DEFAULT 'CRITICAL_STATE',
    secret_handling VARCHAR(32) NOT NULL DEFAULT 'NONE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_backup_objects_backup ON backup_objects(backup_id);
CREATE INDEX IF NOT EXISTS idx_backup_objects_entity ON backup_objects(entity_type);

-- 3. Restore Operations Table
CREATE TABLE IF NOT EXISTS restore_operations (
    id VARCHAR(64) PRIMARY KEY,
    backup_id VARCHAR(64) NOT NULL REFERENCES backup_records(backup_id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    stage VARCHAR(32) NOT NULL DEFAULT 'VALIDATE',
    target_scope VARCHAR(32) NOT NULL DEFAULT 'FULL',
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE SET NULL,
    initiated_by VARCHAR(64) NOT NULL,
    dry_run BOOLEAN NOT NULL DEFAULT FALSE,
    plan_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    reconciliation_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_restore_operations_status ON restore_operations(status);
CREATE INDEX IF NOT EXISTS idx_restore_operations_stage ON restore_operations(stage);
CREATE INDEX IF NOT EXISTS idx_restore_operations_backup ON restore_operations(backup_id);
CREATE INDEX IF NOT EXISTS idx_restore_operations_created ON restore_operations(created_at DESC);

-- 4. Recovery Checkpoints Table
CREATE TABLE IF NOT EXISTS recovery_checkpoints (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    checkpoint_type VARCHAR(32) NOT NULL DEFAULT 'MANUAL',
    app_version VARCHAR(32),
    schema_version_recorded INT NOT NULL DEFAULT 1,
    migration_version_recorded INT NOT NULL DEFAULT 26,
    active_operation_id VARCHAR(64) REFERENCES restore_operations(id) ON DELETE SET NULL,
    state_summary_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recovery_checkpoints_type ON recovery_checkpoints(checkpoint_type);
CREATE INDEX IF NOT EXISTS idx_recovery_checkpoints_created ON recovery_checkpoints(created_at DESC);

-- 5. Recovery Integrity Results Table
CREATE TABLE IF NOT EXISTS recovery_integrity_results (
    id VARCHAR(64) PRIMARY KEY,
    backup_id VARCHAR(64) NOT NULL REFERENCES backup_records(backup_id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN',
    manifest_valid BOOLEAN NOT NULL DEFAULT FALSE,
    checksums_valid BOOLEAN NOT NULL DEFAULT FALSE,
    schema_compatible BOOLEAN NOT NULL DEFAULT FALSE,
    migration_compatible BOOLEAN NOT NULL DEFAULT FALSE,
    verified_objects_count INT NOT NULL DEFAULT 0,
    failed_objects_count INT NOT NULL DEFAULT 0,
    details_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    verified_by VARCHAR(64) NOT NULL,
    verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recovery_integrity_backup ON recovery_integrity_results(backup_id);
CREATE INDEX IF NOT EXISTS idx_recovery_integrity_status ON recovery_integrity_results(status);
CREATE INDEX IF NOT EXISTS idx_recovery_integrity_time ON recovery_integrity_results(verified_at DESC);
