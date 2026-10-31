ALTER TABLE automations
DROP COLUMN IF EXISTS execution_target,
DROP COLUMN IF EXISTS edge_sync_status,
DROP COLUMN IF EXISTS edge_device_id,
DROP COLUMN IF EXISTS edge_slot_id;
