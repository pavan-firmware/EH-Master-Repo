-- =============================================================================
-- Migration 023 Rollback: Intelligent Notifications Platform
-- Phase 30 Database Schema
-- =============================================================================

DROP TABLE IF EXISTS notification_actions;
DROP TABLE IF EXISTS notification_aggregations;
DROP TABLE IF EXISTS platform_events;

-- Revert columns added to existing tables
ALTER TABLE notifications DROP COLUMN IF EXISTS decision_metadata;
ALTER TABLE notifications DROP COLUMN IF EXISTS expires_at;
ALTER TABLE notifications DROP COLUMN IF EXISTS aggregated_ids;
ALTER TABLE notifications DROP COLUMN IF EXISTS aggregated_count;
ALTER TABLE notifications DROP COLUMN IF EXISTS is_aggregated;
ALTER TABLE notifications DROP COLUMN IF EXISTS action_state;
ALTER TABLE notifications DROP COLUMN IF EXISTS action_target;
ALTER TABLE notifications DROP COLUMN IF EXISTS action_type;
ALTER TABLE notifications DROP COLUMN IF EXISTS severity;

ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS quiet_hours_end;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS quiet_hours_start;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS quiet_hours_enabled;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS member_alerts;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS matter_alerts;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS security_alerts;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS energy_alerts;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS device_health;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS in_app_enabled;
ALTER TABLE user_notification_preferences DROP COLUMN IF EXISTS email_enabled;
