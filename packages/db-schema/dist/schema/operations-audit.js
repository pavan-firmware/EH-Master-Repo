"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.platformIncidents = exports.systemHealthSnapshots = exports.securityAuditRecords = exports.operationalEvents = exports.outbox = exports.auditLogs = void 0;
/**
 * EH Home Schema — operations-audit
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- audit_logs (002_capabilities_network_audit_outbox.sql) ---
exports.auditLogs = (0, pg_core_1.pgTable)('audit_logs', {
    id: (0, pg_core_1.varchar)('id', { length: 255 }).primaryKey(),
    actorUserId: (0, pg_core_1.varchar)('actor_user_id', { length: 128 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 128 }),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 128 }),
    action: (0, pg_core_1.varchar)('action', { length: 128 }).notNull(),
    payload: (0, pg_core_1.jsonb)('payload').notNull().default({}),
    ipAddress: (0, pg_core_1.varchar)('ip_address', { length: 45 }),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 128 }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- outbox (002_capabilities_network_audit_outbox.sql) ---
exports.outbox = (0, pg_core_1.pgTable)('outbox', {
    id: (0, pg_core_1.varchar)('id', { length: 255 }).primaryKey(),
    eventType: (0, pg_core_1.varchar)('event_type', { length: 128 }).notNull(),
    aggregateType: (0, pg_core_1.varchar)('aggregate_type', { length: 64 }).notNull(),
    aggregateId: (0, pg_core_1.varchar)('aggregate_id', { length: 128 }).notNull(),
    payload: (0, pg_core_1.jsonb)('payload').notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PENDING'),
    attemptCount: (0, pg_core_1.integer)('attempt_count').notNull().default(0),
    lastError: (0, pg_core_1.text)('last_error'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    processedAt: (0, pg_core_1.timestamp)('processed_at', { withTimezone: true }),
});
// --- operational_events (024_secure_operations_observability.sql) ---
exports.operationalEvents = (0, pg_core_1.pgTable)('operational_events', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 64 }).notNull(),
    causationId: (0, pg_core_1.varchar)('causation_id', { length: 64 }),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }),
    roomId: (0, pg_core_1.varchar)('room_id', { length: 64 }),
    userId: (0, pg_core_1.varchar)('user_id', { length: 64 }),
    subsystem: (0, pg_core_1.varchar)('subsystem', { length: 32 }).notNull(),
    operation: (0, pg_core_1.varchar)('operation', { length: 128 }).notNull(),
    action: (0, pg_core_1.varchar)('action', { length: 128 }).notNull(),
    source: (0, pg_core_1.varchar)('source', { length: 64 }).notNull(),
    executionPath: (0, pg_core_1.varchar)('execution_path', { length: 32 }).notNull().default('CLOUD'),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('INFO'),
    authorizationResult: (0, pg_core_1.varchar)('authorization_result', { length: 32 }).notNull().default('AUTHORIZED'),
    outcome: (0, pg_core_1.varchar)('outcome', { length: 32 }).notNull().default('SUCCESS'),
    failureCode: (0, pg_core_1.varchar)('failure_code', { length: 64 }),
    durationMs: (0, pg_core_1.doublePrecision)('duration_ms'),
    metadata: (0, pg_core_1.jsonb)('metadata').notNull().default({}),
    redactionMarkers: (0, pg_core_1.jsonb)('redaction_markers').notNull().default([]),
    traceLifecycle: (0, pg_core_1.varchar)('trace_lifecycle', { length: 32 }),
    occurredAt: (0, pg_core_1.timestamp)('occurred_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- security_audit_records (024_secure_operations_observability.sql) ---
exports.securityAuditRecords = (0, pg_core_1.pgTable)('security_audit_records', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    sequenceNumber: (0, pg_core_1.bigint)('sequence_number', { mode: 'number' }).notNull().unique(),
    recordHash: (0, pg_core_1.varchar)('record_hash', { length: 64 }).notNull(),
    prevRecordHash: (0, pg_core_1.varchar)('prev_record_hash', { length: 64 }).notNull(),
    actorUserId: (0, pg_core_1.varchar)('actor_user_id', { length: 64 }),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }),
    action: (0, pg_core_1.varchar)('action', { length: 128 }).notNull(),
    resourceType: (0, pg_core_1.varchar)('resource_type', { length: 64 }).notNull(),
    resourceId: (0, pg_core_1.varchar)('resource_id', { length: 128 }),
    outcome: (0, pg_core_1.varchar)('outcome', { length: 32 }).notNull().default('SUCCESS'),
    ipAddress: (0, pg_core_1.varchar)('ip_address', { length: 45 }),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 64 }),
    canonicalPayload: (0, pg_core_1.jsonb)('canonical_payload').notNull().default({}),
    metadata: (0, pg_core_1.jsonb)('metadata').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- system_health_snapshots (024_secure_operations_observability.sql) ---
exports.systemHealthSnapshots = (0, pg_core_1.pgTable)('system_health_snapshots', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('HEALTHY'),
    subsystemsJson: (0, pg_core_1.jsonb)('subsystems_json').notNull().default({}),
    metadataJson: (0, pg_core_1.jsonb)('metadata_json').notNull().default({}),
    recordedAt: (0, pg_core_1.timestamp)('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- platform_incidents (029_production_observability_and_incidents.sql) ---
exports.platformIncidents = (0, pg_core_1.pgTable)('platform_incidents', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    incidentType: (0, pg_core_1.varchar)('incident_type', { length: 64 }).notNull(),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('OPEN'),
    component: (0, pg_core_1.varchar)('component', { length: 64 }).notNull(),
    summary: (0, pg_core_1.varchar)('summary', { length: 255 }).notNull(),
    description: (0, pg_core_1.text)('description'),
    affectedEntitiesJson: (0, pg_core_1.jsonb)('affected_entities_json').notNull().default({}),
    correlationIdsJson: (0, pg_core_1.jsonb)('correlation_ids_json').notNull().default([]),
    firstObservedAt: (0, pg_core_1.timestamp)('first_observed_at', { withTimezone: true }).notNull().defaultNow(),
    lastObservedAt: (0, pg_core_1.timestamp)('last_observed_at', { withTimezone: true }).notNull().defaultNow(),
    acknowledgedAt: (0, pg_core_1.timestamp)('acknowledged_at', { withTimezone: true }),
    acknowledgedBy: (0, pg_core_1.varchar)('acknowledged_by', { length: 64 }),
    investigatingAt: (0, pg_core_1.timestamp)('investigating_at', { withTimezone: true }),
    investigatingBy: (0, pg_core_1.varchar)('investigating_by', { length: 64 }),
    mitigatingAt: (0, pg_core_1.timestamp)('mitigating_at', { withTimezone: true }),
    mitigatingBy: (0, pg_core_1.varchar)('mitigating_by', { length: 64 }),
    resolvedAt: (0, pg_core_1.timestamp)('resolved_at', { withTimezone: true }),
    resolvedBy: (0, pg_core_1.varchar)('resolved_by', { length: 64 }),
    resolutionNotes: (0, pg_core_1.text)('resolution_notes'),
    metadataJson: (0, pg_core_1.jsonb)('metadata_json').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=operations-audit.js.map