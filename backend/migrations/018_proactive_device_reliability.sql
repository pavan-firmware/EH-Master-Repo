-- Migration 018: Proactive Device Reliability + Self-Healing Home (Phase 25)
-- Managed Tables: reliability_incidents, reliability_diagnostics,
--                 reliability_recovery_attempts, reliability_health_snapshots,
--                 maintenance_recommendations

-- 1. Reliability Incidents
CREATE TABLE IF NOT EXISTS reliability_incidents (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  incident_type     TEXT NOT NULL CHECK(incident_type IN (
                      'DEVICE_OFFLINE','TELEMETRY_STALE','COMMAND_FAILURE',
                      'COMMAND_LATENCY','MQTT_INSTABILITY','OTA_FAILURE',
                      'REPEATED_RECONNECT','RELIABILITY_DEGRADATION')),
  severity          TEXT NOT NULL CHECK(severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  status            TEXT NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','INVESTIGATING','RESOLVED','AUTO_RESOLVED')),
  title             TEXT NOT NULL,
  description       TEXT,
  evidence          TEXT,
  signal_count      INTEGER NOT NULL DEFAULT 1,
  first_observed_at TEXT NOT NULL,
  last_observed_at  TEXT NOT NULL,
  resolved_at       TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at        TEXT
);

CREATE INDEX IF NOT EXISTS idx_reliability_incidents_home_device
  ON reliability_incidents(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_reliability_incidents_home_status
  ON reliability_incidents(home_id, status);
CREATE INDEX IF NOT EXISTS idx_reliability_incidents_device_type
  ON reliability_incidents(device_id, incident_type);

-- 2. Reliability Diagnostics
CREATE TABLE IF NOT EXISTS reliability_diagnostics (
  id                TEXT PRIMARY KEY,
  incident_id       TEXT NOT NULL,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  diagnosis_type    TEXT NOT NULL CHECK(diagnosis_type IN (
                      'NETWORK_INSTABILITY','DEVICE_UNREACHABLE',
                      'TELEMETRY_PIPELINE_ISSUE','COMMAND_EXECUTION_ISSUE',
                      'FIRMWARE_ISSUE','OTA_ISSUE','UNKNOWN')),
  confidence        REAL NOT NULL DEFAULT 0.0,
  root_cause        TEXT NOT NULL,
  evidence          TEXT,
  recommended_actions TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_reliability_diagnostics_incident
  ON reliability_diagnostics(incident_id);
CREATE INDEX IF NOT EXISTS idx_reliability_diagnostics_home_device
  ON reliability_diagnostics(home_id, device_id);

-- 3. Reliability Recovery Attempts
CREATE TABLE IF NOT EXISTS reliability_recovery_attempts (
  id                    TEXT PRIMARY KEY,
  incident_id           TEXT NOT NULL,
  home_id               TEXT NOT NULL,
  device_id             TEXT NOT NULL,
  action_type           TEXT NOT NULL CHECK(action_type IN (
                          'RETRY_COMMAND','REFRESH_STATE','REQUEST_TELEMETRY_REFRESH',
                          'RETRY_FAILED_OPERATION','RE_EVALUATE_OTA_ELIGIBILITY',
                          'MARK_DEGRADED','CREATE_MAINTENANCE_RECOMMENDATION')),
  status                TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN (
                          'PENDING','EXECUTING','VERIFYING','RECOVERED',
                          'PARTIALLY_RECOVERED','FAILED')),
  command_accepted      INTEGER NOT NULL DEFAULT 0,
  pre_action_state      TEXT,
  post_action_state     TEXT,
  verification_evidence TEXT,
  failure_reason        TEXT,
  initiated_at          TEXT NOT NULL,
  command_accepted_at   TEXT,
  verification_started_at TEXT,
  completed_at          TEXT,
  created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at            TEXT
);

CREATE INDEX IF NOT EXISTS idx_reliability_recovery_incident
  ON reliability_recovery_attempts(incident_id);
CREATE INDEX IF NOT EXISTS idx_reliability_recovery_home_device
  ON reliability_recovery_attempts(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_reliability_recovery_status
  ON reliability_recovery_attempts(status);

-- 4. Reliability Health Snapshots
CREATE TABLE IF NOT EXISTS reliability_health_snapshots (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  health_state      TEXT NOT NULL CHECK(health_state IN (
                      'HEALTHY','DEGRADED','UNSTABLE','UNAVAILABLE','UNKNOWN')),
  health_score      REAL NOT NULL DEFAULT 100.0,
  connectivity_score REAL,
  telemetry_score   REAL,
  command_score     REAL,
  uptime_score      REAL,
  factors           TEXT,
  active_incidents  INTEGER NOT NULL DEFAULT 0,
  snapshotted_at    TEXT NOT NULL,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_reliability_snapshots_home_device
  ON reliability_health_snapshots(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_reliability_snapshots_state
  ON reliability_health_snapshots(health_state);

-- 5. Maintenance Recommendations
CREATE TABLE IF NOT EXISTS maintenance_recommendations (
  id                TEXT PRIMARY KEY,
  home_id           TEXT NOT NULL,
  device_id         TEXT NOT NULL,
  incident_id       TEXT,
  recommendation_type TEXT NOT NULL CHECK(recommendation_type IN (
                      'FIRMWARE_UPDATE_REQUIRED','DEVICE_REPLACEMENT_ADVISED',
                      'NETWORK_CHECK_REQUIRED','POWER_CYCLE_ADVISED',
                      'PROFESSIONAL_SERVICE_REQUIRED','MONITOR_CLOSELY','OTHER')),
  priority          TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  title             TEXT NOT NULL,
  description       TEXT NOT NULL,
  action_steps      TEXT,
  status            TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN (
                      'PENDING','APPROVED','REJECTED','IN_PROGRESS','COMPLETED')),
  approved_by       TEXT,
  approved_at       TEXT,
  completed_at      TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at        TEXT
);

CREATE INDEX IF NOT EXISTS idx_maintenance_recommendations_home_device
  ON maintenance_recommendations(home_id, device_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_recommendations_status
  ON maintenance_recommendations(status);
