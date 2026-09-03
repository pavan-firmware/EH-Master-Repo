-- Migration 015: Energy Forecasting, Predictive Intelligence, Baselines, Anomalies & Efficiency Scores (UP)

CREATE TABLE IF NOT EXISTS energy_forecasts (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL,
    scope_type VARCHAR(16) NOT NULL DEFAULT 'home',
    scope_id VARCHAR(64) NOT NULL,
    horizon VARCHAR(32) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    predicted_kwh NUMERIC(12, 4) NOT NULL DEFAULT 0,
    predicted_cost NUMERIC(12, 4) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    confidence_score NUMERIC(5, 4) NOT NULL DEFAULT 0.5,
    methodology VARCHAR(64) NOT NULL DEFAULT 'HISTORICAL_HOURLY_PROFILE',
    data_coverage VARCHAR(16) DEFAULT 'FULL',
    is_estimate BOOLEAN NOT NULL DEFAULT TRUE,
    points_json JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_energy_forecasts_home ON energy_forecasts(home_id, horizon);
CREATE INDEX IF NOT EXISTS idx_energy_forecasts_scope ON energy_forecasts(scope_type, scope_id);

CREATE TABLE IF NOT EXISTS energy_anomalies (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL,
    scope_type VARCHAR(16) NOT NULL DEFAULT 'device',
    scope_id VARCHAR(64) NOT NULL,
    anomaly_type VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL DEFAULT 'LOW',
    observed_value NUMERIC(12, 4) NOT NULL,
    baseline_value NUMERIC(12, 4) NOT NULL,
    deviation_percentage NUMERIC(10, 2) NOT NULL,
    is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    confirmation_count INTEGER NOT NULL DEFAULT 1,
    evidence_json JSONB DEFAULT '{}',
    detected_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_energy_anomalies_home ON energy_anomalies(home_id, severity);
CREATE INDEX IF NOT EXISTS idx_energy_anomalies_scope ON energy_anomalies(scope_type, scope_id);

CREATE TABLE IF NOT EXISTS energy_baselines (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL,
    scope_type VARCHAR(16) NOT NULL DEFAULT 'device',
    scope_id VARCHAR(64) NOT NULL,
    typical_power_w NUMERIC(10, 2) NOT NULL DEFAULT 0,
    typical_daily_kwh NUMERIC(10, 4) NOT NULL DEFAULT 0,
    typical_overnight_wh NUMERIC(10, 2) NOT NULL DEFAULT 0,
    typical_operating_hours JSONB DEFAULT '[]',
    sample_count INTEGER NOT NULL DEFAULT 0,
    confidence NUMERIC(5, 4) NOT NULL DEFAULT 0.5,
    calculated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_energy_baselines_scope ON energy_baselines(home_id, scope_type, scope_id);

CREATE TABLE IF NOT EXISTS forecast_accuracy_records (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL,
    forecast_id VARCHAR(64),
    horizon VARCHAR(32) NOT NULL,
    predicted_value NUMERIC(12, 4) NOT NULL,
    actual_value NUMERIC(12, 4) NOT NULL,
    absolute_error NUMERIC(12, 4) NOT NULL,
    percentage_error NUMERIC(10, 2) NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_forecast_accuracy_home ON forecast_accuracy_records(home_id, horizon);

CREATE TABLE IF NOT EXISTS energy_efficiency_scores (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL,
    score NUMERIC(5, 2) NOT NULL,
    grade VARCHAR(4) NOT NULL,
    factors_json JSONB NOT NULL DEFAULT '{}',
    evidence_json JSONB DEFAULT '{}',
    calculated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_energy_efficiency_home ON energy_efficiency_scores(home_id, calculated_at);
