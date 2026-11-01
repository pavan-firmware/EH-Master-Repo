"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.platformAlerts = exports.notificationActions = exports.notificationAggregations = exports.platformEvents = exports.notificationDeliveryQueue = exports.userNotificationPreferences = exports.pushDeviceTokens = exports.notifications = void 0;
/**
 * EH Home Schema — notifications-alerts
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- notifications (008_notifications_alerts.sql) ---
exports.notifications = (0, pg_core_1.pgTable)('notifications', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    type: (0, pg_core_1.varchar)('type', { length: 64 }).notNull(),
    category: (0, pg_core_1.varchar)('category', { length: 32 }).notNull().default('alert'),
    priority: (0, pg_core_1.varchar)('priority', { length: 16 }).notNull().default('NORMAL'),
    title: (0, pg_core_1.varchar)('title', { length: 255 }).notNull(),
    body: (0, pg_core_1.text)('body').notNull(),
    entityType: (0, pg_core_1.varchar)('entity_type', { length: 64 }),
    entityId: (0, pg_core_1.varchar)('entity_id', { length: 64 }),
    dataJson: (0, pg_core_1.jsonb)('data_json').notNull().default({}),
    readAt: (0, pg_core_1.timestamp)('read_at', { withTimezone: true }),
    deliveryStatus: (0, pg_core_1.varchar)('delivery_status', { length: 32 }).notNull().default('PENDING'),
    idempotencyKey: (0, pg_core_1.varchar)('idempotency_key', { length: 128 }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- push_device_tokens (008_notifications_alerts.sql) ---
exports.pushDeviceTokens = (0, pg_core_1.pgTable)('push_device_tokens', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    pushToken: (0, pg_core_1.text)('push_token').notNull(),
    platform: (0, pg_core_1.varchar)('platform', { length: 32 }).notNull().default('android'),
    deviceName: (0, pg_core_1.varchar)('device_name', { length: 128 }),
    isActive: (0, pg_core_1.boolean)('is_active').notNull().default(true),
    lastUsedAt: (0, pg_core_1.timestamp)('last_used_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- user_notification_preferences (008_notifications_alerts.sql) ---
exports.userNotificationPreferences = (0, pg_core_1.pgTable)('user_notification_preferences', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull().unique(),
    pushEnabled: (0, pg_core_1.boolean)('push_enabled').notNull().default(true),
    criticalAlerts: (0, pg_core_1.boolean)('critical_alerts').notNull().default(true),
    deviceOffline: (0, pg_core_1.boolean)('device_offline').notNull().default(true),
    automationFailure: (0, pg_core_1.boolean)('automation_failure').notNull().default(true),
    firmwareUpdates: (0, pg_core_1.boolean)('firmware_updates').notNull().default(true),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- notification_delivery_queue (008_notifications_alerts.sql) ---
exports.notificationDeliveryQueue = (0, pg_core_1.pgTable)('notification_delivery_queue', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    notificationId: (0, pg_core_1.varchar)('notification_id', { length: 64 }).notNull(),
    tokenId: (0, pg_core_1.varchar)('token_id', { length: 64 }),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PENDING'),
    attempts: (0, pg_core_1.integer)('attempts').notNull().default(0),
    maxAttempts: (0, pg_core_1.integer)('max_attempts').notNull().default(5),
    nextAttemptAt: (0, pg_core_1.timestamp)('next_attempt_at', { withTimezone: true }).notNull().defaultNow(),
    lastError: (0, pg_core_1.text)('last_error'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- platform_events (023_intelligent_notifications.sql) ---
exports.platformEvents = (0, pg_core_1.pgTable)('platform_events', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    eventType: (0, pg_core_1.varchar)('event_type', { length: 64 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('INFO'),
    title: (0, pg_core_1.varchar)('title', { length: 255 }).notNull(),
    message: (0, pg_core_1.text)('message'),
    dataJson: (0, pg_core_1.jsonb)('data_json').notNull().default({}),
    occurredAt: (0, pg_core_1.timestamp)('occurred_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- notification_aggregations (023_intelligent_notifications.sql) ---
exports.notificationAggregations = (0, pg_core_1.pgTable)('notification_aggregations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    aggregationKey: (0, pg_core_1.varchar)('aggregation_key', { length: 128 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    roomId: (0, pg_core_1.varchar)('room_id', { length: 64 }),
    eventType: (0, pg_core_1.varchar)('event_type', { length: 64 }).notNull(),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('INFO'),
    eventCount: (0, pg_core_1.integer)('event_count').notNull().default(1),
    aggregatedIds: (0, pg_core_1.jsonb)('aggregated_ids').notNull().default([]),
    summaryTitle: (0, pg_core_1.varchar)('summary_title', { length: 255 }).notNull(),
    summaryBody: (0, pg_core_1.text)('summary_body').notNull(),
    windowSeconds: (0, pg_core_1.integer)('window_seconds').notNull().default(60),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- notification_actions (023_intelligent_notifications.sql) ---
exports.notificationActions = (0, pg_core_1.pgTable)('notification_actions', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    notificationId: (0, pg_core_1.varchar)('notification_id', { length: 64 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    actionType: (0, pg_core_1.varchar)('action_type', { length: 64 }).notNull(),
    actionTarget: (0, pg_core_1.varchar)('action_target', { length: 128 }),
    actionState: (0, pg_core_1.varchar)('action_state', { length: 32 }).notNull().default('ACTIONED'),
    payload: (0, pg_core_1.jsonb)('payload').notNull().default({}),
    executedAt: (0, pg_core_1.timestamp)('executed_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- platform_alerts (029_production_observability_and_incidents.sql) ---
exports.platformAlerts = (0, pg_core_1.pgTable)('platform_alerts', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    alertType: (0, pg_core_1.varchar)('alert_type', { length: 64 }).notNull(),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull(),
    component: (0, pg_core_1.varchar)('component', { length: 64 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('ACTIVE'),
    incidentId: (0, pg_core_1.varchar)('incident_id', { length: 64 }),
    summary: (0, pg_core_1.varchar)('summary', { length: 255 }).notNull(),
    fingerprint: (0, pg_core_1.varchar)('fingerprint', { length: 128 }).notNull(),
    occurrenceCount: (0, pg_core_1.integer)('occurrence_count').notNull().default(1),
    firstSeenAt: (0, pg_core_1.timestamp)('first_seen_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: (0, pg_core_1.timestamp)('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 64 }),
    metadataJson: (0, pg_core_1.jsonb)('metadata_json').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=notifications-alerts.js.map