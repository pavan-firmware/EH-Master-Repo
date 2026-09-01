-- EH Home — Migration 010: Cloud Sync, Backup, Restore, Offline Reconciliation & Data Lifecycle (UP)

CREATE TABLE IF NOT EXISTS sync_checkpoints (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    client_device_id VARCHAR(128) NOT NULL,
    last_sync_seq BIGINT NOT NULL DEFAULT 0,
    schema_version INTEGER NOT NULL DEFAULT 1,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sync_checkpoints_user_home_client UNIQUE (user_id, home_id, client_device_id)
);

CREATE INDEX IF NOT EXISTS idx_sync_checkpoints_user_home ON sync_checkpoints(user_id, home_id);

CREATE TABLE IF NOT EXISTS pending_change_audits (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    entity_type VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64),
    mutation_type VARCHAR(64) NOT NULL,
    payload JSONB,
    status VARCHAR(32) NOT NULL DEFAULT 'ACCEPTED',
    rejection_reason TEXT,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pending_change_audits_mutation UNIQUE (home_id, client_mutation_id)
);

CREATE INDEX IF NOT EXISTS idx_pending_change_audits_home ON pending_change_audits(home_id, applied_at);

CREATE TABLE IF NOT EXISTS data_export_records (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE SET NULL,
    export_scope VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'COMPLETED',
    sanitized_summary JSONB,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_data_export_records_user ON data_export_records(user_id, created_at);
