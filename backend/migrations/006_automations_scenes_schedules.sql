-- =============================================================================
-- Migration 006: Automations, Scenes, Schedules, and Execution Logs (Phase 10)
-- =============================================================================

-- 1. SCENES TABLE
CREATE TABLE IF NOT EXISTS scenes (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    icon VARCHAR(64) DEFAULT 'scene_default',
    is_active BOOLEAN DEFAULT false,
    actions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scenes_home_id ON scenes(home_id);

-- 2. AUTOMATIONS TABLE
CREATE TABLE IF NOT EXISTS automations (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    is_enabled BOOLEAN DEFAULT true,
    trigger_type VARCHAR(32) NOT NULL, -- 'schedule', 'time', 'device_state'
    trigger_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    conditions JSONB NOT NULL DEFAULT '[]'::jsonb,
    actions JSONB NOT NULL DEFAULT '[]'::jsonb,
    timezone VARCHAR(64) DEFAULT 'UTC',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_automations_home_id ON automations(home_id);
CREATE INDEX IF NOT EXISTS idx_automations_trigger_type ON automations(trigger_type);
CREATE INDEX IF NOT EXISTS idx_automations_enabled ON automations(is_enabled);

-- 3. SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS schedules (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    automation_id VARCHAR(64) REFERENCES automations(id) ON DELETE CASCADE,
    scene_id VARCHAR(64) REFERENCES scenes(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    schedule_type VARCHAR(32) NOT NULL, -- 'one_time', 'daily', 'weekly', 'cron'
    cron_expression VARCHAR(64),
    time_of_day VARCHAR(8), -- 'HH:mm'
    days_of_week JSONB DEFAULT '[]'::jsonb, -- [1,2,3,4,5] (1=Mon, 7=Sun)
    timezone VARCHAR(64) DEFAULT 'UTC',
    is_enabled BOOLEAN DEFAULT true,
    next_run_at TIMESTAMP WITH TIME ZONE,
    last_run_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_schedules_home_id ON schedules(home_id);
CREATE INDEX IF NOT EXISTS idx_schedules_due ON schedules(is_enabled, next_run_at);

-- 4. AUTOMATION EXECUTION LOGS TABLE
CREATE TABLE IF NOT EXISTS automation_execution_logs (
    id VARCHAR(64) PRIMARY KEY,
    home_id VARCHAR(64) NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    automation_id VARCHAR(64) REFERENCES automations(id) ON DELETE SET NULL,
    scene_id VARCHAR(64) REFERENCES scenes(id) ON DELETE SET NULL,
    schedule_id VARCHAR(64) REFERENCES schedules(id) ON DELETE SET NULL,
    trigger_source VARCHAR(64) NOT NULL, -- 'schedule', 'manual', 'state_change'
    status VARCHAR(32) NOT NULL, -- 'succeeded', 'failed', 'partial'
    execution_identity VARCHAR(128) NOT NULL, -- Idempotency key
    target_results JSONB NOT NULL DEFAULT '[]'::jsonb,
    error_message TEXT,
    duration_ms INTEGER DEFAULT 0,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_automation_logs_home ON automation_execution_logs(home_id);
CREATE INDEX IF NOT EXISTS idx_automation_logs_automation ON automation_execution_logs(automation_id);
CREATE INDEX IF NOT EXISTS idx_automation_logs_executed_at ON automation_execution_logs(executed_at DESC);
