-- Migration 013: Smart Energy Automation, Execution Logs & Optimization Engine (UP)

CREATE TABLE IF NOT EXISTS energy_automation_executions (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  automation_id TEXT,
  scope_type TEXT DEFAULT 'device',
  scope_id TEXT,
  trigger_type TEXT NOT NULL,
  trigger_reason TEXT NOT NULL,
  telemetry_context TEXT,
  previous_state TEXT,
  requested_action TEXT,
  resulting_state TEXT,
  status TEXT NOT NULL, -- 'succeeded', 'failed', 'partial', 'skipped'
  skip_reason TEXT,     -- 'in_cooldown', 'hysteresis_active', 'conditions_not_met', 'loop_detected', 'disabled', 'missing_telemetry', 'stale_telemetry'
  error_message TEXT,
  duration_ms INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (automation_id) REFERENCES automations(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_energy_auto_exec_home ON energy_automation_executions(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_energy_auto_exec_auto ON energy_automation_executions(automation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS energy_optimizations (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  device_id TEXT,
  category TEXT NOT NULL, -- 'VAMPIRE_STANDBY_POWER', 'OVERNIGHT_CONSUMPTION', 'HIGH_PEAK_DEMAND', 'THRESHOLD_FREQUENT_EXCEED'
  severity TEXT NOT NULL DEFAULT 'MEDIUM', -- 'LOW', 'MEDIUM', 'HIGH'
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  estimated_daily_savings_kwh REAL NOT NULL DEFAULT 0,
  estimated_monthly_savings_kwh REAL NOT NULL DEFAULT 0,
  estimated_monthly_cost_savings REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'USD',
  calculation_basis TEXT,
  suggested_action TEXT,
  is_dismissed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_energy_opt_home ON energy_optimizations(home_id, is_dismissed, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_energy_opt_device ON energy_optimizations(device_id);
