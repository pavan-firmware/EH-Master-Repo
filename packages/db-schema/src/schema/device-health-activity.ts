/**
 * EH Home Schema — device-health-activity
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, jsonb, pgTable, real, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- device_activity_logs (007_device_management_health_observability.sql) ---
export const deviceActivityLogs = pgTable('device_activity_logs', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }),
  deviceId: varchar('device_id', { length: 64 }),
  eventType: varchar('event_type', { length: 64 }).notNull(),
  severity: varchar('severity', { length: 16 }).notNull().default('info'),
  message: text('message').notNull(),
  correlationId: varchar('correlation_id', { length: 128 }),
  details: jsonb('details').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceActivityLogs = typeof deviceActivityLogs.$inferSelect;
export type NewDeviceActivityLogs = typeof deviceActivityLogs.$inferInsert;

// --- device_health_metrics (007_device_management_health_observability.sql) ---
export const deviceHealthMetrics = pgTable('device_health_metrics', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 64 }).notNull().unique(),
  homeId: varchar('home_id', { length: 64 }),
  healthStatus: varchar('health_status', { length: 32 }).notNull().default('UNKNOWN'),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }),
  uptimeSeconds: integer('uptime_seconds').default(0),
  rssi: integer('rssi'),
  ipAddress: varchar('ip_address', { length: 45 }),
  commandSuccessCount: integer('command_success_count').notNull().default(0),
  commandFailureCount: integer('command_failure_count').notNull().default(0),
  lastErrorMessage: text('last_error_message'),
  lastErrorAt: timestamp('last_error_at', { withTimezone: true }),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceHealthMetrics = typeof deviceHealthMetrics.$inferSelect;
export type NewDeviceHealthMetrics = typeof deviceHealthMetrics.$inferInsert;

// --- device_transports (019_multi_protocol_connectivity.sql) ---
export const deviceTransports = pgTable('device_transports', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  transportType: text('transport_type').notNull(),
  isActive: integer('is_active').notNull().default(0),
  isSupported: integer('is_supported').notNull().default(1),
  priorityRank: integer('priority_rank').notNull().default(1),
  config: text('config'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: text('updated_at'),
});

export type DeviceTransports = typeof deviceTransports.$inferSelect;
export type NewDeviceTransports = typeof deviceTransports.$inferInsert;

// --- device_connection_states (019_multi_protocol_connectivity.sql) ---
export const deviceConnectionStates = pgTable('device_connection_states', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull().unique(),
  activeTransport: text('active_transport').notNull(),
  connectionState: text('connection_state').notNull().default('DISCONNECTED'),
  lastConnectedAt: text('last_connected_at'),
  lastDisconnectedAt: text('last_disconnected_at'),
  reconnectCount: integer('reconnect_count').notNull().default(0),
  lastError: text('last_error'),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceConnectionStates = typeof deviceConnectionStates.$inferSelect;
export type NewDeviceConnectionStates = typeof deviceConnectionStates.$inferInsert;

// --- commissioning_sessions (019_multi_protocol_connectivity.sql) ---
export const commissioningSessions = pgTable('commissioning_sessions', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  transportType: text('transport_type').notNull(),
  stage: text('stage').notNull().default('DISCOVERED'),
  authMethod: text('auth_method'),
  errorDetails: text('error_details'),
  startedAt: text('started_at').notNull(),
  completedAt: text('completed_at'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: text('updated_at'),
});

export type CommissioningSessions = typeof commissioningSessions.$inferSelect;
export type NewCommissioningSessions = typeof commissioningSessions.$inferInsert;

// --- transport_health_snapshots (019_multi_protocol_connectivity.sql) ---
export const transportHealthSnapshots = pgTable('transport_health_snapshots', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  transportType: text('transport_type').notNull(),
  latencyMs: real('latency_ms').notNull().default(0.0),
  errorRate: real('error_rate').notNull().default(0.0),
  availability: text('availability').notNull().default('ONLINE'),
  metrics: text('metrics'),
  snapshottedAt: text('snapshotted_at').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type TransportHealthSnapshots = typeof transportHealthSnapshots.$inferSelect;
export type NewTransportHealthSnapshots = typeof transportHealthSnapshots.$inferInsert;
