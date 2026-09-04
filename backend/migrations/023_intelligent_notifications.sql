-- =============================================================================
-- Migration 023: Intelligent Notifications, Alerts & User Event Center
-- Phase 30 Database Schema
-- =============================================================================

-- 1. Normalized Platform Event Ingestion & Audit Store
CREATE TABLE IF NOT EXISTS platform_events (
    id VARCHAR(64) PRIMARY KEY,
    event_type VARCHAR(64) NOT NULL,
    source VARCHAR(32) NOT NULL,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    device_id VARCHAR(64) REFERENCES devices(id) ON DELETE SET NULL,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    severity VARCHAR(16) NOT NULL DEFAULT 'INFO',
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_platform_events_home_id ON platform_events(home_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_events_device_id ON platform_events(device_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_events_source ON platform_events(source, event_type);
CREATE INDEX IF NOT EXISTS idx_platform_events_severity ON platform_events(severity);

-- 2. Notification Aggregations
CREATE TABLE IF NOT EXISTS notification_aggregations (
    id VARCHAR(64) PRIMARY KEY,
    aggregation_key VARCHAR(128) NOT NULL,
    home_id VARCHAR(64) REFERENCES homes(id) ON DELETE CASCADE,
    room_id VARCHAR(64) REFERENCES rooms(id) ON DELETE SET NULL,
    event_type VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL DEFAULT 'INFO',
    event_count INTEGER NOT NULL DEFAULT 1,
    aggregated_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    summary_title VARCHAR(255) NOT NULL,
    summary_body TEXT NOT NULL,
    window_seconds INTEGER NOT NULL DEFAULT 60,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_aggregations_key ON notification_aggregations(aggregation_key);
CREATE INDEX IF NOT EXISTS idx_notification_aggregations_home ON notification_aggregations(home_id, created_at DESC);

-- 3. Action Tracking for User Interactive Alerts
CREATE TABLE IF NOT EXISTS notification_actions (
    id VARCHAR(64) PRIMARY KEY,
    notification_id VARCHAR(64) NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(64) NOT NULL,
    action_target VARCHAR(128),
    action_state VARCHAR(32) NOT NULL DEFAULT 'ACTIONED',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    executed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_actions_notif ON notification_actions(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_actions_user ON notification_actions(user_id, executed_at DESC);

-- 4. Additive extensions to existing Phase 15 notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS severity VARCHAR(16) DEFAULT 'INFO';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type VARCHAR(64);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_target VARCHAR(128);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_state VARCHAR(32) DEFAULT 'NONE';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_aggregated BOOLEAN DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS aggregated_count INTEGER DEFAULT 1;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS aggregated_ids JSONB DEFAULT '[]'::jsonb;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS decision_metadata JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_notifications_severity ON notifications(severity);
CREATE INDEX IF NOT EXISTS idx_notifications_action_state ON notifications(action_state);
CREATE INDEX IF NOT EXISTS idx_notifications_expires_at ON notifications(expires_at);

-- 5. Additive extensions to existing user_notification_preferences table
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS email_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS in_app_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS device_health BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS energy_alerts BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS security_alerts BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS matter_alerts BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS member_alerts BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS quiet_hours_start VARCHAR(8) DEFAULT '22:00';
ALTER TABLE user_notification_preferences ADD COLUMN IF NOT EXISTS quiet_hours_end VARCHAR(8) DEFAULT '07:00';
