"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.provisioningSessions = exports.networkIdentity = exports.deviceEvents = exports.deviceCommands = exports.channelState = exports.deviceState = exports.deviceAuthorizations = exports.deviceCredentials = exports.devices = void 0;
/**
 * EH Home Schema — device-identity-state
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- devices (001_initial_schema.sql) ---
exports.devices = (0, pg_core_1.pgTable)('devices', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    serialNumber: (0, pg_core_1.varchar)('serial_number', { length: 128 }).notNull().unique(),
    productVariantId: (0, pg_core_1.varchar)('product_variant_id', { length: 128 }).notNull(),
    hardwareRevision: (0, pg_core_1.varchar)('hardware_revision', { length: 32 }).notNull(),
    firmwareVersion: (0, pg_core_1.varchar)('firmware_version', { length: 32 }).notNull().default('1.0.0'),
    firmwareFamily: (0, pg_core_1.varchar)('firmware_family', { length: 64 }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_credentials (001_initial_schema.sql) ---
exports.deviceCredentials = (0, pg_core_1.pgTable)('device_credentials', {
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).primaryKey(),
    mqttUsername: (0, pg_core_1.varchar)('mqtt_username', { length: 128 }).notNull().unique(),
    mqttPasswordHash: (0, pg_core_1.varchar)('mqtt_password_hash', { length: 255 }).notNull(),
    tlsClientCertFingerprint: (0, pg_core_1.varchar)('tls_client_cert_fingerprint', { length: 64 }),
    localSessionKeyHash: (0, pg_core_1.varchar)('local_session_key_hash', { length: 255 }).notNull(),
    credentialState: (0, pg_core_1.varchar)('credential_state', { length: 32 }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    rotatedAt: (0, pg_core_1.timestamp)('rotated_at', { withTimezone: true }),
});
// --- device_authorizations (001_initial_schema.sql) ---
exports.deviceAuthorizations = (0, pg_core_1.pgTable)('device_authorizations', {
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 128 }).notNull(),
    roomId: (0, pg_core_1.varchar)('room_id', { length: 128 }),
    customName: (0, pg_core_1.varchar)('custom_name', { length: 128 }).notNull(),
    channelLabels: (0, pg_core_1.jsonb)('channel_labels').default({}),
    claimedAt: (0, pg_core_1.timestamp)('claimed_at', { withTimezone: true }).notNull().defaultNow(),
    claimedByUserId: (0, pg_core_1.varchar)('claimed_by_user_id', { length: 128 }).notNull(),
});
// --- device_state (001_initial_schema.sql) ---
exports.deviceState = (0, pg_core_1.pgTable)('device_state', {
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).primaryKey(),
    connectionState: (0, pg_core_1.varchar)('connection_state', { length: 32 }).notNull().default('OFFLINE'),
    lastSeenAt: (0, pg_core_1.timestamp)('last_seen_at', { withTimezone: true }),
    lastCommandId: (0, pg_core_1.varchar)('last_command_id', { length: 128 }),
    lastEventId: (0, pg_core_1.varchar)('last_event_id', { length: 128 }),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- channel_state (001_initial_schema.sql) ---
exports.channelState = (0, pg_core_1.pgTable)('channel_state', {
    id: (0, pg_core_1.varchar)('id', { length: 255 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull(),
    desiredState: (0, pg_core_1.jsonb)('desired_state').default({}),
    reportedState: (0, pg_core_1.jsonb)('reported_state').default({}),
    confidence: (0, pg_core_1.varchar)('confidence', { length: 32 }).notNull().default('UNKNOWN'),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.deviceId, t.channelIndex),
]);
// --- device_commands (001_initial_schema.sql) ---
exports.deviceCommands = (0, pg_core_1.pgTable)('device_commands', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull(),
    action: (0, pg_core_1.varchar)('action', { length: 64 }).notNull(),
    params: (0, pg_core_1.jsonb)('params').notNull().default({}),
    idempotencyKey: (0, pg_core_1.varchar)('idempotency_key', { length: 128 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('CREATED'),
    failureReason: (0, pg_core_1.text)('failure_reason'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }).notNull(),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
});
// --- device_events (001_initial_schema.sql) ---
exports.deviceEvents = (0, pg_core_1.pgTable)('device_events', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull(),
    channelIndex: (0, pg_core_1.integer)('channel_index').notNull(),
    eventType: (0, pg_core_1.varchar)('event_type', { length: 64 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull(),
    payload: (0, pg_core_1.jsonb)('payload').notNull().default({}),
    sequenceNumber: (0, pg_core_1.bigint)('sequence_number', { mode: 'number' }).notNull(),
    timestamp: (0, pg_core_1.timestamp)('timestamp', { withTimezone: true }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- network_identity (002_capabilities_network_audit_outbox.sql) ---
exports.networkIdentity = (0, pg_core_1.pgTable)('network_identity', {
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).primaryKey(),
    wifiMacAddress: (0, pg_core_1.varchar)('wifi_mac_address', { length: 32 }),
    threadExtendedAddress: (0, pg_core_1.varchar)('thread_extended_address', { length: 32 }),
    currentIpv4Address: (0, pg_core_1.varchar)('current_ipv4_address', { length: 45 }),
    currentIpv6Address: (0, pg_core_1.varchar)('current_ipv6_address', { length: 45 }),
    bleMacAddress: (0, pg_core_1.varchar)('ble_mac_address', { length: 32 }),
    lastSeenAt: (0, pg_core_1.timestamp)('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- provisioning_sessions (005_create_provisioning_sessions.sql) ---
exports.provisioningSessions = (0, pg_core_1.pgTable)('provisioning_sessions', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull(),
    appChallenge: (0, pg_core_1.varchar)('app_challenge', { length: 256 }),
    deviceChallenge: (0, pg_core_1.varchar)('device_challenge', { length: 256 }),
    ssid: (0, pg_core_1.varchar)('ssid', { length: 128 }),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('CREATED'),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }),
    endedAt: (0, pg_core_1.timestamp)('ended_at', { withTimezone: true }),
});
//# sourceMappingURL=device-identity-state.js.map