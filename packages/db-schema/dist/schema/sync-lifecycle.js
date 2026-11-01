"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.dataExportRecords = exports.pendingChangeAudits = exports.syncCheckpoints = void 0;
/**
 * EH Home Schema — sync-lifecycle
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- sync_checkpoints (010_cloud_sync_data_lifecycle.sql) ---
exports.syncCheckpoints = (0, pg_core_1.pgTable)('sync_checkpoints', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    clientDeviceId: (0, pg_core_1.varchar)('client_device_id', { length: 128 }).notNull(),
    lastSyncSeq: (0, pg_core_1.bigint)('last_sync_seq', { mode: 'number' }).notNull().default(0),
    schemaVersion: (0, pg_core_1.integer)('schema_version').notNull().default(1),
    syncedAt: (0, pg_core_1.timestamp)('synced_at', { withTimezone: true }).defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.userId, t.homeId, t.clientDeviceId),
]);
// --- pending_change_audits (010_cloud_sync_data_lifecycle.sql) ---
exports.pendingChangeAudits = (0, pg_core_1.pgTable)('pending_change_audits', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    clientMutationId: (0, pg_core_1.varchar)('client_mutation_id', { length: 128 }).notNull(),
    entityType: (0, pg_core_1.varchar)('entity_type', { length: 64 }).notNull(),
    entityId: (0, pg_core_1.varchar)('entity_id', { length: 64 }),
    mutationType: (0, pg_core_1.varchar)('mutation_type', { length: 64 }).notNull(),
    payload: (0, pg_core_1.jsonb)('payload'),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('ACCEPTED'),
    rejectionReason: (0, pg_core_1.text)('rejection_reason'),
    appliedAt: (0, pg_core_1.timestamp)('applied_at', { withTimezone: true }).defaultNow(),
}, (t) => [
    (0, pg_core_1.unique)().on(t.homeId, t.clientMutationId),
]);
// --- data_export_records (010_cloud_sync_data_lifecycle.sql) ---
exports.dataExportRecords = (0, pg_core_1.pgTable)('data_export_records', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }).notNull(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    exportScope: (0, pg_core_1.varchar)('export_scope', { length: 32 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('COMPLETED'),
    sanitizedSummary: (0, pg_core_1.jsonb)('sanitized_summary'),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).defaultNow(),
});
//# sourceMappingURL=sync-lifecycle.js.map