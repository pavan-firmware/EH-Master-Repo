-- =============================================================================
-- Migration 031: Automation Edge Execution Ownership & Sync
-- =============================================================================

ALTER TABLE automations
ADD COLUMN IF NOT EXISTS execution_target VARCHAR(16) DEFAULT 'CLOUD',
ADD COLUMN IF NOT EXISTS edge_sync_status VARCHAR(16) DEFAULT 'N/A',
ADD COLUMN IF NOT EXISTS edge_device_id VARCHAR(64),
ADD COLUMN IF NOT EXISTS edge_slot_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_automations_execution_target ON automations(execution_target);
CREATE INDEX IF NOT EXISTS idx_automations_edge_sync ON automations(edge_sync_status);
