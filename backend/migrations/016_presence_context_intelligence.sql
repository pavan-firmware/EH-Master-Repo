-- Migration 016: Presence, Context Intelligence + Context-Aware Automation (Phase 23)

CREATE TABLE IF NOT EXISTS presence_signals (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  home_id VARCHAR(64) NOT NULL,
  source VARCHAR(32) NOT NULL,
  state VARCHAR(16) NOT NULL,
  confidence REAL NOT NULL,
  evidence_json TEXT,
  observed_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_presence_signals_home_obs ON presence_signals(home_id, observed_at);
CREATE INDEX IF NOT EXISTS idx_presence_signals_user_home ON presence_signals(user_id, home_id);

CREATE TABLE IF NOT EXISTS presence_states (
  id VARCHAR(128) PRIMARY KEY,
  home_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  state VARCHAR(16) NOT NULL,
  confidence REAL NOT NULL,
  source VARCHAR(32) NOT NULL,
  is_stale INTEGER DEFAULT 0,
  last_observed_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_presence_states_home ON presence_states(home_id);

CREATE TABLE IF NOT EXISTS home_contexts (
  home_id VARCHAR(64) PRIMARY KEY,
  mode VARCHAR(32) NOT NULL,
  previous_mode VARCHAR(32),
  precedence_tier VARCHAR(32) NOT NULL,
  active_override_id VARCHAR(64),
  is_vacation INTEGER DEFAULT 0,
  is_occupied INTEGER DEFAULT 1,
  confidence REAL NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS context_overrides (
  id VARCHAR(64) PRIMARY KEY,
  home_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  state VARCHAR(16),
  reason TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_context_overrides_home ON context_overrides(home_id, is_active);

CREATE TABLE IF NOT EXISTS context_transitions (
  id VARCHAR(64) PRIMARY KEY,
  home_id VARCHAR(64) NOT NULL,
  from_mode VARCHAR(32) NOT NULL,
  to_mode VARCHAR(32) NOT NULL,
  trigger_source VARCHAR(64) NOT NULL,
  reason TEXT,
  evidence_json TEXT,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (home_id) REFERENCES homes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_context_transitions_home ON context_transitions(home_id, created_at);
