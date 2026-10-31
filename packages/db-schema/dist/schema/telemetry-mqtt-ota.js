"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.otaExecutionJobs = exports.deviceAvailabilityHistory = exports.mqttAclRules = void 0;
/**
 * EH Home Schema — telemetry-mqtt-ota
 * Source: PostgreSQL Migration 034_telemetry_mqtt_ota.sql
 */
const pg_core_1 = require("drizzle-orm/pg-core");
const device_identity_state_1 = require("./device-identity-state");
// --- mqtt_acl_rules (034_telemetry_mqtt_ota.sql) ---
exports.mqttAclRules = (0, pg_core_1.pgTable)('mqtt_acl_rules', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    clientId: (0, pg_core_1.varchar)('client_id', { length: 128 }).notNull(),
    username: (0, pg_core_1.varchar)('username', { length: 128 }),
    permission: (0, pg_core_1.varchar)('permission', { length: 16 }).notNull().default('allow'),
    action: (0, pg_core_1.varchar)('action', { length: 16 }).notNull().default('all'),
    topic: (0, pg_core_1.varchar)('topic', { length: 255 }).notNull(),
    qos: (0, pg_core_1.smallint)('qos').default(1),
    retain: (0, pg_core_1.smallint)('retain').default(0),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_availability_history (034_telemetry_mqtt_ota.sql) ---
exports.deviceAvailabilityHistory = (0, pg_core_1.pgTable)('device_availability_history', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull().references(() => device_identity_state_1.devices.id, { onDelete: 'restrict' }),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 32 }).notNull().default('MQTT_LWT'),
    recordedAt: (0, pg_core_1.timestamp)('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    metadata: (0, pg_core_1.jsonb)('metadata').default({}),
});
// --- ota_execution_jobs (034_telemetry_mqtt_ota.sql) ---
exports.otaExecutionJobs = (0, pg_core_1.pgTable)('ota_execution_jobs', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }).notNull().references(() => device_identity_state_1.devices.id, { onDelete: 'restrict' }),
    releaseId: (0, pg_core_1.varchar)('release_id', { length: 128 }).notNull(),
    rolloutId: (0, pg_core_1.varchar)('rollout_id', { length: 128 }),
    firmwareFamily: (0, pg_core_1.varchar)('firmware_family', { length: 64 }).notNull(),
    targetVersion: (0, pg_core_1.varchar)('target_version', { length: 32 }).notNull(),
    fromVersion: (0, pg_core_1.varchar)('from_version', { length: 32 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('REQUESTED'),
    progressPercent: (0, pg_core_1.integer)('progress_percent').default(0),
    errorCode: (0, pg_core_1.varchar)('error_code', { length: 64 }),
    errorMessage: (0, pg_core_1.text)('error_message'),
    sha256: (0, pg_core_1.varchar)('sha256', { length: 64 }).notNull(),
    ed25519Signature: (0, pg_core_1.varchar)('ed25519_signature', { length: 128 }).notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
});
//# sourceMappingURL=telemetry-mqtt-ota.js.map