/**
 * EH Home Schema — sync-lifecycle
 * Source: PostgreSQL Migrations 001–029
 */
import { bigint, integer, jsonb, pgTable, text, timestamp, unique, varchar } from 'drizzle-orm/pg-core';

// --- sync_checkpoints (010_cloud_sync_data_lifecycle.sql) ---
export const syncCheckpoints = pgTable('sync_checkpoints', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  clientDeviceId: varchar('client_device_id', { length: 128 }).notNull(),
  lastSyncSeq: bigint('last_sync_seq', { mode: 'number' }).notNull().default(0),
  schemaVersion: integer('schema_version').notNull().default(1),
  syncedAt: timestamp('synced_at', { withTimezone: true }).defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
}, (t) => [
  unique().on(t.userId, t.homeId, t.clientDeviceId),
]);

export type SyncCheckpoints = typeof syncCheckpoints.$inferSelect;
export type NewSyncCheckpoints = typeof syncCheckpoints.$inferInsert;

// --- pending_change_audits (010_cloud_sync_data_lifecycle.sql) ---
export const pendingChangeAudits = pgTable('pending_change_audits', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  clientMutationId: varchar('client_mutation_id', { length: 128 }).notNull(),
  entityType: varchar('entity_type', { length: 64 }).notNull(),
  entityId: varchar('entity_id', { length: 64 }),
  mutationType: varchar('mutation_type', { length: 64 }).notNull(),
  payload: jsonb('payload'),
  status: varchar('status', { length: 32 }).notNull().default('ACCEPTED'),
  rejectionReason: text('rejection_reason'),
  appliedAt: timestamp('applied_at', { withTimezone: true }).defaultNow(),
}, (t) => [
  unique().on(t.homeId, t.clientMutationId),
]);

export type PendingChangeAudits = typeof pendingChangeAudits.$inferSelect;
export type NewPendingChangeAudits = typeof pendingChangeAudits.$inferInsert;

// --- data_export_records (010_cloud_sync_data_lifecycle.sql) ---
export const dataExportRecords = pgTable('data_export_records', {
  id: varchar('id', { length: 64 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull(),
  homeId: varchar('home_id', { length: 64 }),
  exportScope: varchar('export_scope', { length: 32 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('COMPLETED'),
  sanitizedSummary: jsonb('sanitized_summary'),
  expiresAt: timestamp('expires_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
});

export type DataExportRecords = typeof dataExportRecords.$inferSelect;
export type NewDataExportRecords = typeof dataExportRecords.$inferInsert;
