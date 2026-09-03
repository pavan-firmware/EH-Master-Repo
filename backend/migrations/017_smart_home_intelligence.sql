-- EH Home — Migration 017: Smart Home Intelligence + Unified Decision Engine (UP)

CREATE TABLE IF NOT EXISTS intelligence_decisions (
  id VARCHAR(64) PRIMARY KEY,
  home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
  decision_type VARCHAR(64) NOT NULL,
  priority VARCHAR(32) NOT NULL,
  priority_rank INT NOT NULL DEFAULT 7,
  confidence VARCHAR(16) NOT NULL DEFAULT 'MEDIUM',
  confidence_score NUMERIC(5, 4) DEFAULT 0.5000,
  risk VARCHAR(16) NOT NULL DEFAULT 'LOW',
  evidence JSONB DEFAULT '{}'::jsonb,
  proposed_action JSONB DEFAULT '{}'::jsonb,
  expected_effect TEXT,
  is_auto_executable BOOLEAN DEFAULT FALSE,
  safety_result JSONB DEFAULT '{}'::jsonb,
  status VARCHAR(32) NOT NULL DEFAULT 'GENERATED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_intel_decisions_home_created ON intelligence_decisions(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_intel_decisions_status ON intelligence_decisions(home_id, status);

CREATE TABLE IF NOT EXISTS intelligence_recommendations (
  id VARCHAR(64) PRIMARY KEY,
  home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
  recommendation_type VARCHAR(64) NOT NULL,
  priority VARCHAR(32) NOT NULL,
  priority_rank INT NOT NULL DEFAULT 7,
  confidence VARCHAR(16) NOT NULL DEFAULT 'MEDIUM',
  risk VARCHAR(16) NOT NULL DEFAULT 'LOW',
  title VARCHAR(255) NOT NULL,
  description TEXT,
  evidence JSONB DEFAULT '{}'::jsonb,
  proposed_action JSONB DEFAULT '{}'::jsonb,
  expected_benefit TEXT,
  is_auto_executable BOOLEAN DEFAULT FALSE,
  status VARCHAR(32) NOT NULL DEFAULT 'GENERATED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_intel_recs_home_created ON intelligence_recommendations(home_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_intel_recs_status ON intelligence_recommendations(home_id, status);

CREATE TABLE IF NOT EXISTS intelligence_decision_outcomes (
  id VARCHAR(64) PRIMARY KEY,
  decision_id VARCHAR(64) NOT NULL,
  home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
  status VARCHAR(32) NOT NULL,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  previous_state JSONB DEFAULT '{}'::jsonb,
  new_state JSONB DEFAULT '{}'::jsonb,
  expected_benefit TEXT,
  actual_benefit TEXT,
  feedback TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_intel_outcomes_home_exec ON intelligence_decision_outcomes(home_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_intel_outcomes_decision ON intelligence_decision_outcomes(decision_id);
