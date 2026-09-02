-- =============================================================================
-- Migration 011: Device Fleet Management, Firmware Inventory & OTA Lifecycle (UP)
-- =============================================================================

CREATE TABLE IF NOT EXISTS firmware_releases (
  id TEXT PRIMARY KEY,
  product_variant_id TEXT NOT NULL,
  hardware_revision TEXT,
  firmware_family TEXT NOT NULL,
  version TEXT NOT NULL,
  min_firmware_version TEXT,
  release_channel TEXT NOT NULL DEFAULT 'production',
  binary_size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  ed25519_signature TEXT NOT NULL,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  status TEXT NOT NULL DEFAULT 'PUBLISHED',
  created_at TEXT NOT NULL,
  released_at TEXT,
  FOREIGN KEY (product_variant_id) REFERENCES product_variants(id)
);

CREATE INDEX IF NOT EXISTS idx_firmware_releases_variant ON firmware_releases(product_variant_id, release_channel);
CREATE INDEX IF NOT EXISTS idx_firmware_releases_version ON firmware_releases(version);

CREATE TABLE IF NOT EXISTS ota_rollouts (
  id TEXT PRIMARY KEY,
  release_id TEXT NOT NULL,
  home_id TEXT,
  rollout_stage TEXT NOT NULL DEFAULT 'CANARY',
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  target_filters_json TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (release_id) REFERENCES firmware_releases(id),
  FOREIGN KEY (home_id) REFERENCES homes(id)
);

CREATE INDEX IF NOT EXISTS idx_ota_rollouts_release ON ota_rollouts(release_id);
CREATE INDEX IF NOT EXISTS idx_ota_rollouts_home ON ota_rollouts(home_id);

CREATE TABLE IF NOT EXISTS ota_operations (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  release_id TEXT NOT NULL,
  rollout_id TEXT,
  from_version TEXT NOT NULL,
  target_version TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'QUEUED',
  progress_percent INTEGER DEFAULT 0,
  error_code TEXT,
  error_message TEXT,
  initiated_by_user_id TEXT,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (home_id) REFERENCES homes(id),
  FOREIGN KEY (release_id) REFERENCES firmware_releases(id),
  FOREIGN KEY (rollout_id) REFERENCES ota_rollouts(id)
);

CREATE INDEX IF NOT EXISTS idx_ota_operations_device ON ota_operations(device_id);
CREATE INDEX IF NOT EXISTS idx_ota_operations_home ON ota_operations(home_id);
CREATE INDEX IF NOT EXISTS idx_ota_operations_status ON ota_operations(status);

CREATE TABLE IF NOT EXISTS device_maintenance_logs (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  release_id TEXT,
  from_version TEXT,
  to_version TEXT,
  status TEXT NOT NULL,
  details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id),
  FOREIGN KEY (home_id) REFERENCES homes(id)
);

CREATE INDEX IF NOT EXISTS idx_device_maintenance_device ON device_maintenance_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_device_maintenance_home ON device_maintenance_logs(home_id);
