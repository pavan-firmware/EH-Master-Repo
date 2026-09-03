-- Migration 014: Energy Cost Intelligence, Tariffs, Time-Of-Use, Budgets & Cost Optimization (UP)

CREATE TABLE IF NOT EXISTS energy_tariffs (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  name TEXT NOT NULL,
  tariff_type TEXT NOT NULL, -- 'FLAT', 'TIME_OF_USE', 'DYNAMIC'
  currency TEXT NOT NULL DEFAULT 'USD',
  flat_rate_per_kwh REAL,
  fixed_daily_charge REAL DEFAULT 0,
  effective_from TEXT NOT NULL,
  effective_to TEXT,
  carbon_intensity_g_per_kwh REAL,
  is_active INTEGER NOT NULL DEFAULT 1,
  metadata TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_energy_tariffs_home_active ON energy_tariffs(home_id, is_active, effective_from);

CREATE TABLE IF NOT EXISTS tariff_periods (
  id TEXT PRIMARY KEY,
  tariff_id TEXT NOT NULL,
  home_id TEXT NOT NULL,
  period_type TEXT NOT NULL, -- 'OFF_PEAK', 'STANDARD', 'PEAK', 'CRITICAL_PEAK'
  start_time TEXT NOT NULL, -- 'HH:MM'
  end_time TEXT NOT NULL,   -- 'HH:MM'
  applicable_weekdays TEXT NOT NULL, -- JSON array '[1,2,3,4,5,6,7]'
  price_per_kwh REAL NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (tariff_id) REFERENCES energy_tariffs(id) ON DELETE CASCADE,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tariff_periods_tariff ON tariff_periods(tariff_id);
CREATE INDEX IF NOT EXISTS idx_tariff_periods_home ON tariff_periods(home_id);

CREATE TABLE IF NOT EXISTS energy_budgets (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  period_type TEXT NOT NULL, -- 'daily', 'weekly', 'monthly'
  budget_amount REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  alert_threshold_percent REAL NOT NULL DEFAULT 80,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_energy_budgets_home_period ON energy_budgets(home_id, period_type);

CREATE TABLE IF NOT EXISTS cost_optimizations (
  id TEXT PRIMARY KEY,
  home_id TEXT NOT NULL,
  device_id TEXT,
  category TEXT NOT NULL, -- 'LOAD_SHIFTING', 'AVOID_PEAK_TARIFF', 'CHEAPEST_WINDOW_SCHEDULE', 'OFF_PEAK_PREHEAT'
  priority TEXT NOT NULL DEFAULT 'MEDIUM', -- 'LOW', 'MEDIUM', 'HIGH'
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  evidence TEXT,
  estimated_savings TEXT,
  recommended_window TEXT,
  is_dismissed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cost_optimizations_home ON cost_optimizations(home_id, is_dismissed, created_at DESC);
