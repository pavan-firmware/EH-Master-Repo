-- =============================================================================
-- Migration 028: Production Device Fleet Management & Safe OTA Rollout (UP)
-- =============================================================================

CREATE TABLE IF NOT EXISTS fleet_device_firmware_state (
  device_id TEXT PRIMARY KEY,
  product_variant_id TEXT NOT NULL,
  current_firmware_version TEXT NOT NULL,
  target_firmware_version TEXT,
  rollout_id TEXT,
  rollout_state TEXT,
  last_ota_result TEXT,
  last_attempt_at TEXT,
  failure_reason TEXT,
  health_verification_state TEXT NOT NULL DEFAULT 'PENDING',
  updated_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (product_variant_id) REFERENCES product_variants(id)
);

CREATE INDEX IF NOT EXISTS idx_fleet_device_firmware_state_rollout ON fleet_device_firmware_state(rollout_id);
CREATE INDEX IF NOT EXISTS idx_fleet_device_firmware_state_health ON fleet_device_firmware_state(health_verification_state);
CREATE INDEX IF NOT EXISTS idx_fleet_device_firmware_state_version ON fleet_device_firmware_state(current_firmware_version);

CREATE TABLE IF NOT EXISTS ota_attempts (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  rollout_id TEXT NOT NULL,
  requested_version TEXT NOT NULL,
  outcome TEXT NOT NULL,
  reason TEXT,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  audit_metadata_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (rollout_id) REFERENCES ota_rollouts(id)
);

CREATE INDEX IF NOT EXISTS idx_ota_attempts_device ON ota_attempts(device_id);
CREATE INDEX IF NOT EXISTS idx_ota_attempts_rollout ON ota_attempts(rollout_id);
CREATE INDEX IF NOT EXISTS idx_ota_attempts_outcome ON ota_attempts(outcome);
