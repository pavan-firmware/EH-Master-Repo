/**
 * EH Home Schema — notifications-alerts
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- notifications (008_notifications_alerts.sql) ---
export const notifications = pgTable('notifications', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }),
  homeId: varchar('home_id', { length: 64 }),
  type: varchar('type', { length: 64 }).notNull(),
  category: varchar('category', { length: 32 }).notNull().default('alert'),
  priority: varchar('priority', { length: 16 }).notNull().default('NORMAL'),
  title: varchar('title', { length: 255 }).notNull(),
  body: text('body').notNull(),
  entityType: varchar('entity_type', { length: 64 }),
  entityId: varchar('entity_id', { length: 64 }),
  dataJson: jsonb('data_json').notNull().default({}),
  readAt: timestamp('read_at', { withTimezone: true }),
  deliveryStatus: varchar('delivery_status', { length: 32 }).notNull().default('PENDING'),
  idempotencyKey: varchar('idempotency_key', { length: 128 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Notifications = typeof notifications.$inferSelect;
export type NewNotifications = typeof notifications.$inferInsert;

// --- push_device_tokens (008_notifications_alerts.sql) ---
export const pushDeviceTokens = pgTable('push_device_tokens', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  pushToken: text('push_token').notNull(),
  platform: varchar('platform', { length: 32 }).notNull().default('android'),
  deviceName: varchar('device_name', { length: 128 }),
  isActive: boolean('is_active').notNull().default(true),
  lastUsedAt: timestamp('last_used_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type PushDeviceTokens = typeof pushDeviceTokens.$inferSelect;
export type NewPushDeviceTokens = typeof pushDeviceTokens.$inferInsert;

// --- user_notification_preferences (008_notifications_alerts.sql) ---
export const userNotificationPreferences = pgTable('user_notification_preferences', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull().unique(),
  pushEnabled: boolean('push_enabled').notNull().default(true),
  criticalAlerts: boolean('critical_alerts').notNull().default(true),
  deviceOffline: boolean('device_offline').notNull().default(true),
  automationFailure: boolean('automation_failure').notNull().default(true),
  firmwareUpdates: boolean('firmware_updates').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type UserNotificationPreferences = typeof userNotificationPreferences.$inferSelect;
export type NewUserNotificationPreferences = typeof userNotificationPreferences.$inferInsert;

// --- notification_delivery_queue (008_notifications_alerts.sql) ---
export const notificationDeliveryQueue = pgTable('notification_delivery_queue', {
  id: varchar('id', { length: 64 }).primaryKey(),
  notificationId: varchar('notification_id', { length: 64 }).notNull(),
  tokenId: varchar('token_id', { length: 64 }),
  status: varchar('status', { length: 32 }).notNull().default('PENDING'),
  attempts: integer('attempts').notNull().default(0),
  maxAttempts: integer('max_attempts').notNull().default(5),
  nextAttemptAt: timestamp('next_attempt_at', { withTimezone: true }).notNull().defaultNow(),
  lastError: text('last_error'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type NotificationDeliveryQueue = typeof notificationDeliveryQueue.$inferSelect;
export type NewNotificationDeliveryQueue = typeof notificationDeliveryQueue.$inferInsert;

// --- platform_events (023_intelligent_notifications.sql) ---
export const platformEvents = pgTable('platform_events', {
  id: varchar('id', { length: 64 }).primaryKey(),
  eventType: varchar('event_type', { length: 64 }).notNull(),
  source: varchar('source', { length: 32 }).notNull(),
  homeId: varchar('home_id', { length: 64 }),
  deviceId: varchar('device_id', { length: 64 }),
  userId: varchar('user_id', { length: 64 }),
  severity: varchar('severity', { length: 16 }).notNull().default('INFO'),
  title: varchar('title', { length: 255 }).notNull(),
  message: text('message'),
  dataJson: jsonb('data_json').notNull().default({}),
  occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type PlatformEvents = typeof platformEvents.$inferSelect;
export type NewPlatformEvents = typeof platformEvents.$inferInsert;

// --- notification_aggregations (023_intelligent_notifications.sql) ---
export const notificationAggregations = pgTable('notification_aggregations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  aggregationKey: varchar('aggregation_key', { length: 128 }).notNull(),
  homeId: varchar('home_id', { length: 64 }),
  roomId: varchar('room_id', { length: 64 }),
  eventType: varchar('event_type', { length: 64 }).notNull(),
  severity: varchar('severity', { length: 16 }).notNull().default('INFO'),
  eventCount: integer('event_count').notNull().default(1),
  aggregatedIds: jsonb('aggregated_ids').notNull().default([]),
  summaryTitle: varchar('summary_title', { length: 255 }).notNull(),
  summaryBody: text('summary_body').notNull(),
  windowSeconds: integer('window_seconds').notNull().default(60),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type NotificationAggregations = typeof notificationAggregations.$inferSelect;
export type NewNotificationAggregations = typeof notificationAggregations.$inferInsert;

// --- notification_actions (023_intelligent_notifications.sql) ---
export const notificationActions = pgTable('notification_actions', {
  id: varchar('id', { length: 64 }).primaryKey(),
  notificationId: varchar('notification_id', { length: 64 }).notNull(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  actionType: varchar('action_type', { length: 64 }).notNull(),
  actionTarget: varchar('action_target', { length: 128 }),
  actionState: varchar('action_state', { length: 32 }).notNull().default('ACTIONED'),
  payload: jsonb('payload').notNull().default({}),
  executedAt: timestamp('executed_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type NotificationActions = typeof notificationActions.$inferSelect;
export type NewNotificationActions = typeof notificationActions.$inferInsert;

// --- platform_alerts (029_production_observability_and_incidents.sql) ---
export const platformAlerts = pgTable('platform_alerts', {
  id: varchar('id', { length: 64 }).primaryKey(),
  alertType: varchar('alert_type', { length: 64 }).notNull(),
  severity: varchar('severity', { length: 16 }).notNull(),
  component: varchar('component', { length: 64 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('ACTIVE'),
  incidentId: varchar('incident_id', { length: 64 }),
  summary: varchar('summary', { length: 255 }).notNull(),
  fingerprint: varchar('fingerprint', { length: 128 }).notNull(),
  occurrenceCount: integer('occurrence_count').notNull().default(1),
  firstSeenAt: timestamp('first_seen_at', { withTimezone: true }).notNull().defaultNow(),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  correlationId: varchar('correlation_id', { length: 64 }),
  metadataJson: jsonb('metadata_json').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type PlatformAlerts = typeof platformAlerts.$inferSelect;
export type NewPlatformAlerts = typeof platformAlerts.$inferInsert;
