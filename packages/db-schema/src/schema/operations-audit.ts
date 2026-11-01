/**
 * EH Home Schema — operations-audit
 * Source: PostgreSQL Migrations 001–029
 */
import { bigint, doublePrecision, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- audit_logs (002_capabilities_network_audit_outbox.sql) ---
export const auditLogs = pgTable('audit_logs', {
  id: varchar('id', { length: 255 }).primaryKey(),
  actorUserId: varchar('actor_user_id', { length: 128 }),
  deviceId: varchar('device_id', { length: 128 }),
  homeId: varchar('home_id', { length: 128 }),
  action: varchar('action', { length: 128 }).notNull(),
  payload: jsonb('payload').notNull().default({}),
  ipAddress: varchar('ip_address', { length: 45 }),
  correlationId: varchar('correlation_id', { length: 128 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type AuditLogs = typeof auditLogs.$inferSelect;
export type NewAuditLogs = typeof auditLogs.$inferInsert;

// --- outbox (002_capabilities_network_audit_outbox.sql) ---
export const outbox = pgTable('outbox', {
  id: varchar('id', { length: 255 }).primaryKey(),
  eventType: varchar('event_type', { length: 128 }).notNull(),
  aggregateType: varchar('aggregate_type', { length: 64 }).notNull(),
  aggregateId: varchar('aggregate_id', { length: 128 }).notNull(),
  payload: jsonb('payload').notNull(),
  status: varchar('status', { length: 32 }).notNull().default('PENDING'),
  attemptCount: integer('attempt_count').notNull().default(0),
  lastError: text('last_error'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  processedAt: timestamp('processed_at', { withTimezone: true }),
});

export type Outbox = typeof outbox.$inferSelect;
export type NewOutbox = typeof outbox.$inferInsert;

// --- operational_events (024_secure_operations_observability.sql) ---
export const operationalEvents = pgTable('operational_events', {
  id: varchar('id', { length: 64 }).primaryKey(),
  correlationId: varchar('correlation_id', { length: 64 }).notNull(),
  causationId: varchar('causation_id', { length: 64 }),
  homeId: varchar('home_id', { length: 64 }),
  deviceId: varchar('device_id', { length: 64 }),
  roomId: varchar('room_id', { length: 64 }),
  userId: varchar('user_id', { length: 64 }),
  subsystem: varchar('subsystem', { length: 32 }).notNull(),
  operation: varchar('operation', { length: 128 }).notNull(),
  action: varchar('action', { length: 128 }).notNull(),
  source: varchar('source', { length: 64 }).notNull(),
  executionPath: varchar('execution_path', { length: 32 }).notNull().default('CLOUD'),
  severity: varchar('severity', { length: 16 }).notNull().default('INFO'),
  authorizationResult: varchar('authorization_result', { length: 32 }).notNull().default('AUTHORIZED'),
  outcome: varchar('outcome', { length: 32 }).notNull().default('SUCCESS'),
  failureCode: varchar('failure_code', { length: 64 }),
  durationMs: doublePrecision('duration_ms'),
  metadata: jsonb('metadata').notNull().default({}),
  redactionMarkers: jsonb('redaction_markers').notNull().default([]),
  traceLifecycle: varchar('trace_lifecycle', { length: 32 }),
  occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type OperationalEvents = typeof operationalEvents.$inferSelect;
export type NewOperationalEvents = typeof operationalEvents.$inferInsert;

// --- security_audit_records (024_secure_operations_observability.sql) ---
export const securityAuditRecords = pgTable('security_audit_records', {
  id: varchar('id', { length: 64 }).primaryKey(),
  sequenceNumber: bigint('sequence_number', { mode: 'number' }).notNull().unique(),
  recordHash: varchar('record_hash', { length: 64 }).notNull(),
  prevRecordHash: varchar('prev_record_hash', { length: 64 }).notNull(),
  actorUserId: varchar('actor_user_id', { length: 64 }),
  homeId: varchar('home_id', { length: 64 }),
  deviceId: varchar('device_id', { length: 64 }),
  action: varchar('action', { length: 128 }).notNull(),
  resourceType: varchar('resource_type', { length: 64 }).notNull(),
  resourceId: varchar('resource_id', { length: 128 }),
  outcome: varchar('outcome', { length: 32 }).notNull().default('SUCCESS'),
  ipAddress: varchar('ip_address', { length: 45 }),
  correlationId: varchar('correlation_id', { length: 64 }),
  canonicalPayload: jsonb('canonical_payload').notNull().default({}),
  metadata: jsonb('metadata').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type SecurityAuditRecords = typeof securityAuditRecords.$inferSelect;
export type NewSecurityAuditRecords = typeof securityAuditRecords.$inferInsert;

// --- system_health_snapshots (024_secure_operations_observability.sql) ---
export const systemHealthSnapshots = pgTable('system_health_snapshots', {
  id: varchar('id', { length: 64 }).primaryKey(),
  status: varchar('status', { length: 32 }).notNull().default('HEALTHY'),
  subsystemsJson: jsonb('subsystems_json').notNull().default({}),
  metadataJson: jsonb('metadata_json').notNull().default({}),
  recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type SystemHealthSnapshots = typeof systemHealthSnapshots.$inferSelect;
export type NewSystemHealthSnapshots = typeof systemHealthSnapshots.$inferInsert;

// --- platform_incidents (029_production_observability_and_incidents.sql) ---
export const platformIncidents = pgTable('platform_incidents', {
  id: varchar('id', { length: 64 }).primaryKey(),
  incidentType: varchar('incident_type', { length: 64 }).notNull(),
  severity: varchar('severity', { length: 16 }).notNull(),
  status: varchar('status', { length: 32 }).notNull().default('OPEN'),
  component: varchar('component', { length: 64 }).notNull(),
  summary: varchar('summary', { length: 255 }).notNull(),
  description: text('description'),
  affectedEntitiesJson: jsonb('affected_entities_json').notNull().default({}),
  correlationIdsJson: jsonb('correlation_ids_json').notNull().default([]),
  firstObservedAt: timestamp('first_observed_at', { withTimezone: true }).notNull().defaultNow(),
  lastObservedAt: timestamp('last_observed_at', { withTimezone: true }).notNull().defaultNow(),
  acknowledgedAt: timestamp('acknowledged_at', { withTimezone: true }),
  acknowledgedBy: varchar('acknowledged_by', { length: 64 }),
  investigatingAt: timestamp('investigating_at', { withTimezone: true }),
  investigatingBy: varchar('investigating_by', { length: 64 }),
  mitigatingAt: timestamp('mitigating_at', { withTimezone: true }),
  mitigatingBy: varchar('mitigating_by', { length: 64 }),
  resolvedAt: timestamp('resolved_at', { withTimezone: true }),
  resolvedBy: varchar('resolved_by', { length: 64 }),
  resolutionNotes: text('resolution_notes'),
  metadataJson: jsonb('metadata_json').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type PlatformIncidents = typeof platformIncidents.$inferSelect;
export type NewPlatformIncidents = typeof platformIncidents.$inferInsert;
