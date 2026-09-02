-- Migration 012: Energy Intelligence, Device Telemetry & Usage Analytics (UP)

CREATE TABLE IF NOT EXISTS device_telemetry_measurements (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  channel_index INTEGER NOT NULL DEFAULT 1,
  v_mv INTEGER NOT NULL,
  i_ma INTEGER NOT NULL,
  p_mw INTEGER NOT NULL,
  e_tot_wh INTEGER NOT NULL,
  e_int_mwh INTEGER NOT NULL,
  freq_mhz INTEGER NOT NULL,
  pf_x1000 INTEGER NOT NULL,
  flags INTEGER NOT NULL DEFAULT 0,
  sequence_number INTEGER NOT NULL DEFAULT 0,
  device_timestamp TEXT NOT NULL,
  ingested_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_telemetry_dev_ts ON device_telemetry_measurements(device_id, device_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_dev_ch_ts ON device_telemetry_measurements(device_id, channel_index, device_timestamp DESC);

CREATE TABLE IF NOT EXISTS telemetry_aggregates (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  channel_index INTEGER NOT NULL DEFAULT 1,
  bucket_type TEXT NOT NULL, -- 'MINUTE', 'HOUR', 'DAY'
  bucket_start TEXT NOT NULL,
  bucket_end TEXT NOT NULL,
  total_energy_wh REAL NOT NULL,
  avg_power_w REAL NOT NULL,
  peak_power_w REAL NOT NULL,
  min_power_w REAL NOT NULL,
  sample_count INTEGER NOT NULL DEFAULT 0,
  data_quality TEXT NOT NULL DEFAULT 'GOOD', -- 'GOOD', 'PARTIAL', 'INTERPOLATED'
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_telemetry_agg_dev_bucket ON telemetry_aggregates(device_id, bucket_type, bucket_start);

CREATE TABLE IF NOT EXISTS energy_threshold_configs (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  device_id TEXT,
  high_power_w REAL,
  daily_energy_kwh REAL,
  monthly_energy_kwh REAL,
  cost_per_kwh REAL DEFAULT 0.15,
  currency TEXT DEFAULT 'USD',
  is_enabled INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_energy_thresholds_home ON energy_threshold_configs(home_id);

CREATE TABLE IF NOT EXISTS energy_events (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  device_id TEXT,
  event_type TEXT NOT NULL, -- 'HIGH_POWER_EXCEEDED', 'DAILY_ENERGY_EXCEEDED', 'REVERSE_POWER_FLOW', 'COUNTER_RESET'
  severity TEXT NOT NULL DEFAULT 'WARN', -- 'INFO', 'WARN', 'CRITICAL'
  value_recorded REAL NOT NULL,
  threshold_value REAL NOT NULL,
  message TEXT NOT NULL,
  details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_energy_events_home_ts ON energy_events(home_id, created_at DESC);
