-- Phase 28: Local-First Home Control & Edge Execution Platform Migration

CREATE TABLE IF NOT EXISTS local_route_cache (
  id VARCHAR(64) PRIMARY KEY,
  device_id VARCHAR(64) NOT NULL,
  home_id VARCHAR(64) NOT NULL,
  transport_type VARCHAR(32) NOT NULL,
  local_endpoint VARCHAR(255) NOT NULL,
  local_ip VARCHAR(64),
  local_port INTEGER,
  reachability VARCHAR(32) NOT NULL DEFAULT 'REACHABLE',
  identity_fingerprint VARCHAR(128),
  is_tls_secured BOOLEAN DEFAULT 1,
  latency_ms REAL DEFAULT 0.0,
  expires_at TIMESTAMP NOT NULL,
  last_contact_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lrc_device_home ON local_route_cache(device_id, home_id);
CREATE INDEX IF NOT EXISTS idx_lrc_reachability ON local_route_cache(reachability);
CREATE INDEX IF NOT EXISTS idx_lrc_expires_at ON local_route_cache(expires_at);

CREATE TABLE IF NOT EXISTS edge_execution_records (
  id VARCHAR(64) PRIMARY KEY,
  command_id VARCHAR(64) NOT NULL,
  device_id VARCHAR(64) NOT NULL,
  home_id VARCHAR(64) NOT NULL,
  channel_index INTEGER,
  action VARCHAR(64) NOT NULL,
  route_mode VARCHAR(32) NOT NULL,
  transport_used VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL,
  is_confirmed_by_device BOOLEAN NOT NULL DEFAULT 0,
  confirmed_state TEXT,
  latency_ms REAL DEFAULT 0.0,
  error_message TEXT,
  idempotency_key VARCHAR(128),
  actor_user_id VARCHAR(64),
  actor_source VARCHAR(32),
  queued_for_cloud_sync BOOLEAN DEFAULT 0,
  executed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_eer_device_time ON edge_execution_records(device_id, executed_at);
CREATE INDEX IF NOT EXISTS idx_eer_home_time ON edge_execution_records(home_id, executed_at);
CREATE INDEX IF NOT EXISTS idx_eer_command_id ON edge_execution_records(command_id);
CREATE INDEX IF NOT EXISTS idx_eer_idempotency ON edge_execution_records(idempotency_key);

CREATE TABLE IF NOT EXISTS local_discovery_nodes (
  id VARCHAR(64) PRIMARY KEY,
  discovery_id VARCHAR(64) NOT NULL UNIQUE,
  device_id VARCHAR(64) NOT NULL,
  home_id VARCHAR(64) NOT NULL,
  product_variant_id VARCHAR(64),
  mac_address VARCHAR(64) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  port INTEGER NOT NULL,
  transport_type VARCHAR(32) NOT NULL,
  protocol_version VARCHAR(32),
  firmware_version VARCHAR(32),
  identity_fingerprint VARCHAR(128) NOT NULL,
  is_trusted BOOLEAN NOT NULL DEFAULT 1,
  ttl_seconds INTEGER DEFAULT 300,
  discovered_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ldn_device_home ON local_discovery_nodes(device_id, home_id);
CREATE INDEX IF NOT EXISTS idx_ldn_trusted ON local_discovery_nodes(is_trusted);
