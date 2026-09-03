-- Migration 019: Multi-Protocol Device Connectivity & Interoperability (Phase 26)
-- Managed Tables: device_transports, device_connection_states,
--                 commissioning_sessions, transport_health_snapshots

-- 1. Device Transports (configuration and capability mappings per device)
CREATE TABLE IF NOT EXISTS device_transports (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  transport_type    TEXT NOT NULL CHECK(transport_type IN ('WIFI_MQTT','BLE','THREAD','MATTER')),
  is_active         INTEGER NOT NULL DEFAULT 0,
  is_supported      INTEGER NOT NULL DEFAULT 1,
  priority_rank     INTEGER NOT NULL DEFAULT 1,
  config            TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at        TEXT
);

CREATE INDEX IF NOT EXISTS idx_device_transports_home_device
  ON device_transports(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_device_transports_type
  ON device_transports(transport_type);
CREATE INDEX IF NOT EXISTS idx_device_transports_active
  ON device_transports(device_id, is_active);

-- 2. Device Connection States (deterministic lifecycle tracking)
CREATE TABLE IF NOT EXISTS device_connection_states (
  id                    TEXT PRIMARY KEY,
  home_id               TEXT NOT NULL,
  device_id             TEXT NOT NULL UNIQUE,
  active_transport      TEXT NOT NULL CHECK(active_transport IN ('WIFI_MQTT','BLE','THREAD','MATTER')),
  connection_state      TEXT NOT NULL DEFAULT 'DISCONNECTED' CHECK(connection_state IN (
                          'DISCOVERING','COMMISSIONING','CONNECTING','CONNECTED',
                          'DEGRADED','RECONNECTING','DISCONNECTED','FAILED','DECOMMISSIONED')),
  last_connected_at     TEXT,
  last_disconnected_at  TEXT,
  reconnect_count       INTEGER NOT NULL DEFAULT 0,
  last_error            TEXT,
  updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_device_conn_state_home
  ON device_connection_states(home_id);
CREATE INDEX IF NOT EXISTS idx_device_conn_state_status
  ON device_connection_states(connection_state);

-- 3. Commissioning Sessions (protocol-neutral onboarding lifecycle)
CREATE TABLE IF NOT EXISTS commissioning_sessions (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  transport_type    TEXT NOT NULL CHECK(transport_type IN ('WIFI_MQTT','BLE','THREAD','MATTER')),
  stage             TEXT NOT NULL DEFAULT 'DISCOVERED' CHECK(stage IN (
                      'DISCOVERED','READY','STARTED','AUTHENTICATING',
                      'NETWORK_JOINING','VERIFYING','COMPLETED','FAILED','CANCELLED')),
  auth_method       TEXT,
  error_details     TEXT,
  started_at        TEXT NOT NULL,
  completed_at      TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at        TEXT
);

CREATE INDEX IF NOT EXISTS idx_commissioning_sessions_home_device
  ON commissioning_sessions(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_commissioning_sessions_stage
  ON commissioning_sessions(stage);

-- 4. Transport Health Snapshots (normalized connectivity health metrics)
CREATE TABLE IF NOT EXISTS transport_health_snapshots (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  transport_type    TEXT NOT NULL CHECK(transport_type IN ('WIFI_MQTT','BLE','THREAD','MATTER')),
  latency_ms        REAL NOT NULL DEFAULT 0.0,
  error_rate        REAL NOT NULL DEFAULT 0.0,
  availability      TEXT NOT NULL DEFAULT 'ONLINE' CHECK(availability IN ('ONLINE','DEGRADED','UNREACHABLE','UNCONFIGURED')),
  metrics           TEXT,
  snapshotted_at    TEXT NOT NULL,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_transport_health_home_device
  ON transport_health_snapshots(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_transport_health_type
  ON transport_health_snapshots(transport_type);
