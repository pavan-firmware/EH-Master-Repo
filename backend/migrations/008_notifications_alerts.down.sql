-- =============================================================================
-- Migration 008 DOWN: Revert Notifications, Alerts & Push Delivery Platform
-- =============================================================================

DROP TABLE IF EXISTS notification_delivery_queue;
DROP TABLE IF EXISTS user_notification_preferences;
DROP TABLE IF EXISTS push_device_tokens;
DROP TABLE IF EXISTS notifications;
