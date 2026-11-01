"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recoveryIntegrityResults = exports.recoveryCheckpoints = exports.restoreOperations = exports.backupObjects = exports.backupRecords = void 0;
/**
 * EH Home Schema — disaster-recovery
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- backup_records (026_disaster_recovery_state_resilience.sql) ---
exports.backupRecords = (0, pg_core_1.pgTable)('backup_records', {
    backupId: (0, pg_core_1.varchar)('backup_id', { length: 64 }).primaryKey(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('CREATED'),
    scope: (0, pg_core_1.varchar)('scope', { length: 32 }).notNull().default('FULL'),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    provider: (0, pg_core_1.varchar)('provider', { length: 64 }).notNull().default('LocalBackupProvider'),
    location: (0, pg_core_1.text)('location').notNull(),
    schemaVersionRecorded: (0, pg_core_1.integer)('schema_version_recorded').notNull().default(1),
    migrationVersionRecorded: (0, pg_core_1.integer)('migration_version_recorded').notNull().default(26),
    objectCount: (0, pg_core_1.integer)('object_count').notNull().default(0),
    totalBytes: (0, pg_core_1.bigint)('total_bytes', { mode: 'number' }).notNull().default(0),
    manifestChecksum: (0, pg_core_1.varchar)('manifest_checksum', { length: 128 }),
    errorMessage: (0, pg_core_1.text)('error_message'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }),
});
// --- backup_objects (026_disaster_recovery_state_resilience.sql) ---
exports.backupObjects = (0, pg_core_1.pgTable)('backup_objects', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    backupId: (0, pg_core_1.varchar)('backup_id', { length: 64 }).notNull(),
    objectKey: (0, pg_core_1.varchar)('object_key', { length: 128 }).notNull(),
    entityType: (0, pg_core_1.varchar)('entity_type', { length: 64 }).notNull(),
    recordCount: (0, pg_core_1.integer)('record_count').notNull().default(0),
    byteSize: (0, pg_core_1.bigint)('byte_size', { mode: 'number' }).notNull().default(0),
    sha256Checksum: (0, pg_core_1.varchar)('sha256_checksum', { length: 128 }).notNull(),
    dataClassification: (0, pg_core_1.varchar)('data_classification', { length: 32 }).notNull().default('CRITICAL_STATE'),
    secretHandling: (0, pg_core_1.varchar)('secret_handling', { length: 32 }).notNull().default('NONE'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- restore_operations (026_disaster_recovery_state_resilience.sql) ---
exports.restoreOperations = (0, pg_core_1.pgTable)('restore_operations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    backupId: (0, pg_core_1.varchar)('backup_id', { length: 64 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PENDING'),
    stage: (0, pg_core_1.varchar)('stage', { length: 32 }).notNull().default('VALIDATE'),
    targetScope: (0, pg_core_1.varchar)('target_scope', { length: 32 }).notNull().default('FULL'),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    initiatedBy: (0, pg_core_1.varchar)('initiated_by', { length: 64 }).notNull(),
    dryRun: (0, pg_core_1.boolean)('dry_run').notNull().default(false),
    planJson: (0, pg_core_1.jsonb)('plan_json').notNull().default({}),
    reconciliationJson: (0, pg_core_1.jsonb)('reconciliation_json').notNull().default({}),
    errorMessage: (0, pg_core_1.text)('error_message'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
});
// --- recovery_checkpoints (026_disaster_recovery_state_resilience.sql) ---
exports.recoveryCheckpoints = (0, pg_core_1.pgTable)('recovery_checkpoints', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    name: (0, pg_core_1.varchar)('name', { length: 128 }).notNull(),
    checkpointType: (0, pg_core_1.varchar)('checkpoint_type', { length: 32 }).notNull().default('MANUAL'),
    appVersion: (0, pg_core_1.varchar)('app_version', { length: 32 }),
    schemaVersionRecorded: (0, pg_core_1.integer)('schema_version_recorded').notNull().default(1),
    migrationVersionRecorded: (0, pg_core_1.integer)('migration_version_recorded').notNull().default(26),
    activeOperationId: (0, pg_core_1.varchar)('active_operation_id', { length: 64 }),
    stateSummaryJson: (0, pg_core_1.jsonb)('state_summary_json').notNull().default({}),
    metadataJson: (0, pg_core_1.jsonb)('metadata_json').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- recovery_integrity_results (026_disaster_recovery_state_resilience.sql) ---
exports.recoveryIntegrityResults = (0, pg_core_1.pgTable)('recovery_integrity_results', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    backupId: (0, pg_core_1.varchar)('backup_id', { length: 64 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('UNKNOWN'),
    manifestValid: (0, pg_core_1.boolean)('manifest_valid').notNull().default(false),
    checksumsValid: (0, pg_core_1.boolean)('checksums_valid').notNull().default(false),
    schemaCompatible: (0, pg_core_1.boolean)('schema_compatible').notNull().default(false),
    migrationCompatible: (0, pg_core_1.boolean)('migration_compatible').notNull().default(false),
    verifiedObjectsCount: (0, pg_core_1.integer)('verified_objects_count').notNull().default(0),
    failedObjectsCount: (0, pg_core_1.integer)('failed_objects_count').notNull().default(0),
    detailsJson: (0, pg_core_1.jsonb)('details_json').notNull().default({}),
    verifiedBy: (0, pg_core_1.varchar)('verified_by', { length: 64 }).notNull(),
    verifiedAt: (0, pg_core_1.timestamp)('verified_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=disaster-recovery.js.map