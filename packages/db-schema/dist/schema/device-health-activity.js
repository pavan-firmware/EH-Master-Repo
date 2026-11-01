"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.transportHealthSnapshots = exports.commissioningSessions = exports.deviceConnectionStates = exports.deviceTransports = exports.deviceHealthMetrics = exports.deviceActivityLogs = void 0;
/**
 * EH Home Schema — device-health-activity
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- device_activity_logs (007_device_management_health_observability.sql) ---
exports.deviceActivityLogs = (0, pg_core_1.pgTable)('device_activity_logs', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }),
    eventType: (0, pg_core_1.varchar)('event_type', { length: 64 }).notNull(),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('info'),
    message: (0, pg_core_1.text)('message').notNull(),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 128 }),
    details: (0, pg_core_1.jsonb)('details').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_health_metrics (007_device_management_health_observability.sql) ---
exports.deviceHealthMetrics = (0, pg_core_1.pgTable)('device_health_metrics', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull().unique(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    healthStatus: (0, pg_core_1.varchar)('health_status', { length: 32 }).notNull().default('UNKNOWN'),
    lastSeenAt: (0, pg_core_1.timestamp)('last_seen_at', { withTimezone: true }),
    uptimeSeconds: (0, pg_core_1.integer)('uptime_seconds').default(0),
    rssi: (0, pg_core_1.integer)('rssi'),
    ipAddress: (0, pg_core_1.varchar)('ip_address', { length: 45 }),
    commandSuccessCount: (0, pg_core_1.integer)('command_success_count').notNull().default(0),
    commandFailureCount: (0, pg_core_1.integer)('command_failure_count').notNull().default(0),
    lastErrorMessage: (0, pg_core_1.text)('last_error_message'),
    lastErrorAt: (0, pg_core_1.timestamp)('last_error_at', { withTimezone: true }),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_transports (019_multi_protocol_connectivity.sql) ---
exports.deviceTransports = (0, pg_core_1.pgTable)('device_transports', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    transportType: (0, pg_core_1.text)('transport_type').notNull(),
    isActive: (0, pg_core_1.integer)('is_active').notNull().default(0),
    isSupported: (0, pg_core_1.integer)('is_supported').notNull().default(1),
    priorityRank: (0, pg_core_1.integer)('priority_rank').notNull().default(1),
    config: (0, pg_core_1.text)('config'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.text)('updated_at'),
});
// --- device_connection_states (019_multi_protocol_connectivity.sql) ---
exports.deviceConnectionStates = (0, pg_core_1.pgTable)('device_connection_states', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull().unique(),
    activeTransport: (0, pg_core_1.text)('active_transport').notNull(),
    connectionState: (0, pg_core_1.text)('connection_state').notNull().default('DISCONNECTED'),
    lastConnectedAt: (0, pg_core_1.text)('last_connected_at'),
    lastDisconnectedAt: (0, pg_core_1.text)('last_disconnected_at'),
    reconnectCount: (0, pg_core_1.integer)('reconnect_count').notNull().default(0),
    lastError: (0, pg_core_1.text)('last_error'),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- commissioning_sessions (019_multi_protocol_connectivity.sql) ---
exports.commissioningSessions = (0, pg_core_1.pgTable)('commissioning_sessions', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    transportType: (0, pg_core_1.text)('transport_type').notNull(),
    stage: (0, pg_core_1.text)('stage').notNull().default('DISCOVERED'),
    authMethod: (0, pg_core_1.text)('auth_method'),
    errorDetails: (0, pg_core_1.text)('error_details'),
    startedAt: (0, pg_core_1.text)('started_at').notNull(),
    completedAt: (0, pg_core_1.text)('completed_at'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.text)('updated_at'),
});
// --- transport_health_snapshots (019_multi_protocol_connectivity.sql) ---
exports.transportHealthSnapshots = (0, pg_core_1.pgTable)('transport_health_snapshots', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    transportType: (0, pg_core_1.text)('transport_type').notNull(),
    latencyMs: (0, pg_core_1.real)('latency_ms').notNull().default(0.0),
    errorRate: (0, pg_core_1.real)('error_rate').notNull().default(0.0),
    availability: (0, pg_core_1.text)('availability').notNull().default('ONLINE'),
    metrics: (0, pg_core_1.text)('metrics'),
    snapshottedAt: (0, pg_core_1.text)('snapshotted_at').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=device-health-activity.js.map