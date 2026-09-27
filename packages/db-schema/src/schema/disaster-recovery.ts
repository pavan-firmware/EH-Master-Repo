/**
 * EH Home Schema — disaster-recovery
 * Source: PostgreSQL Migrations 001–029
 */
import { bigint, boolean, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- backup_records (026_disaster_recovery_state_resilience.sql) ---
export const backupRecords = pgTable('backup_records', {
  backupId: varchar('backup_id', { length: 64 }).primaryKey(),
  status: varchar('status', { length: 32 }).notNull().default('CREATED'),
  scope: varchar('scope', { length: 32 }).notNull().default('FULL'),
  homeId: varchar('home_id', { length: 64 }),
  provider: varchar('provider', { length: 64 }).notNull().default('LocalBackupProvider'),
  location: text('location').notNull(),
  schemaVersionRecorded: integer('schema_version_recorded').notNull().default(1),
  migrationVersionRecorded: integer('migration_version_recorded').notNull().default(26),
  objectCount: integer('object_count').notNull().default(0),
  totalBytes: bigint('total_bytes', { mode: 'number' }).notNull().default(0),
  manifestChecksum: varchar('manifest_checksum', { length: 128 }),
  errorMessage: text('error_message'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp('completed_at', { withTimezone: true }),
  expiresAt: timestamp('expires_at', { withTimezone: true }),
});

export type BackupRecords = typeof backupRecords.$inferSelect;
export type NewBackupRecords = typeof backupRecords.$inferInsert;

// --- backup_objects (026_disaster_recovery_state_resilience.sql) ---
export const backupObjects = pgTable('backup_objects', {
  id: varchar('id', { length: 64 }).primaryKey(),
  backupId: varchar('backup_id', { length: 64 }).notNull(),
  objectKey: varchar('object_key', { length: 128 }).notNull(),
  entityType: varchar('entity_type', { length: 64 }).notNull(),
  recordCount: integer('record_count').notNull().default(0),
  byteSize: bigint('byte_size', { mode: 'number' }).notNull().default(0),
  sha256Checksum: varchar('sha256_checksum', { length: 128 }).notNull(),
  dataClassification: varchar('data_classification', { length: 32 }).notNull().default('CRITICAL_STATE'),
  secretHandling: varchar('secret_handling', { length: 32 }).notNull().default('NONE'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type BackupObjects = typeof backupObjects.$inferSelect;
export type NewBackupObjects = typeof backupObjects.$inferInsert;

// --- restore_operations (026_disaster_recovery_state_resilience.sql) ---
export const restoreOperations = pgTable('restore_operations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  backupId: varchar('backup_id', { length: 64 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('PENDING'),
  stage: varchar('stage', { length: 32 }).notNull().default('VALIDATE'),
  targetScope: varchar('target_scope', { length: 32 }).notNull().default('FULL'),
  homeId: varchar('home_id', { length: 64 }),
  initiatedBy: varchar('initiated_by', { length: 64 }).notNull(),
  dryRun: boolean('dry_run').notNull().default(false),
  planJson: jsonb('plan_json').notNull().default({}),
  reconciliationJson: jsonb('reconciliation_json').notNull().default({}),
  errorMessage: text('error_message'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp('completed_at', { withTimezone: true }),
});

export type RestoreOperations = typeof restoreOperations.$inferSelect;
export type NewRestoreOperations = typeof restoreOperations.$inferInsert;

// --- recovery_checkpoints (026_disaster_recovery_state_resilience.sql) ---
export const recoveryCheckpoints = pgTable('recovery_checkpoints', {
  id: varchar('id', { length: 64 }).primaryKey(),
  name: varchar('name', { length: 128 }).notNull(),
  checkpointType: varchar('checkpoint_type', { length: 32 }).notNull().default('MANUAL'),
  appVersion: varchar('app_version', { length: 32 }),
  schemaVersionRecorded: integer('schema_version_recorded').notNull().default(1),
  migrationVersionRecorded: integer('migration_version_recorded').notNull().default(26),
  activeOperationId: varchar('active_operation_id', { length: 64 }),
  stateSummaryJson: jsonb('state_summary_json').notNull().default({}),
  metadataJson: jsonb('metadata_json').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type RecoveryCheckpoints = typeof recoveryCheckpoints.$inferSelect;
export type NewRecoveryCheckpoints = typeof recoveryCheckpoints.$inferInsert;

// --- recovery_integrity_results (026_disaster_recovery_state_resilience.sql) ---
export const recoveryIntegrityResults = pgTable('recovery_integrity_results', {
  id: varchar('id', { length: 64 }).primaryKey(),
  backupId: varchar('backup_id', { length: 64 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('UNKNOWN'),
  manifestValid: boolean('manifest_valid').notNull().default(false),
  checksumsValid: boolean('checksums_valid').notNull().default(false),
  schemaCompatible: boolean('schema_compatible').notNull().default(false),
  migrationCompatible: boolean('migration_compatible').notNull().default(false),
  verifiedObjectsCount: integer('verified_objects_count').notNull().default(0),
  failedObjectsCount: integer('failed_objects_count').notNull().default(0),
  detailsJson: jsonb('details_json').notNull().default({}),
  verifiedBy: varchar('verified_by', { length: 64 }).notNull(),
  verifiedAt: timestamp('verified_at', { withTimezone: true }).notNull().defaultNow(),
});

export type RecoveryIntegrityResults = typeof recoveryIntegrityResults.$inferSelect;
export type NewRecoveryIntegrityResults = typeof recoveryIntegrityResults.$inferInsert;
