"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.maintenanceRecommendations = exports.reliabilityHealthSnapshots = exports.reliabilityRecoveryAttempts = exports.reliabilityDiagnostics = exports.reliabilityIncidents = void 0;
/**
 * EH Home Schema — device-reliability
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- reliability_incidents (018_proactive_device_reliability.sql) ---
exports.reliabilityIncidents = (0, pg_core_1.pgTable)('reliability_incidents', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    incidentType: (0, pg_core_1.text)('incident_type').notNull(),
    severity: (0, pg_core_1.text)('severity').notNull(),
    status: (0, pg_core_1.text)('status').notNull().default('OPEN'),
    title: (0, pg_core_1.text)('title').notNull(),
    description: (0, pg_core_1.text)('description'),
    evidence: (0, pg_core_1.text)('evidence'),
    signalCount: (0, pg_core_1.integer)('signal_count').notNull().default(1),
    firstObservedAt: (0, pg_core_1.text)('first_observed_at').notNull(),
    lastObservedAt: (0, pg_core_1.text)('last_observed_at').notNull(),
    resolvedAt: (0, pg_core_1.text)('resolved_at'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.text)('updated_at'),
});
// --- reliability_diagnostics (018_proactive_device_reliability.sql) ---
exports.reliabilityDiagnostics = (0, pg_core_1.pgTable)('reliability_diagnostics', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    incidentId: (0, pg_core_1.text)('incident_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    diagnosisType: (0, pg_core_1.text)('diagnosis_type').notNull(),
    confidence: (0, pg_core_1.real)('confidence').notNull().default(0.0),
    rootCause: (0, pg_core_1.text)('root_cause').notNull(),
    evidence: (0, pg_core_1.text)('evidence'),
    recommendedActions: (0, pg_core_1.text)('recommended_actions'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- reliability_recovery_attempts (018_proactive_device_reliability.sql) ---
exports.reliabilityRecoveryAttempts = (0, pg_core_1.pgTable)('reliability_recovery_attempts', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    incidentId: (0, pg_core_1.text)('incident_id').notNull(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    actionType: (0, pg_core_1.text)('action_type').notNull(),
    status: (0, pg_core_1.text)('status').notNull().default('PENDING'),
    commandAccepted: (0, pg_core_1.integer)('command_accepted').notNull().default(0),
    preActionState: (0, pg_core_1.text)('pre_action_state'),
    postActionState: (0, pg_core_1.text)('post_action_state'),
    verificationEvidence: (0, pg_core_1.text)('verification_evidence'),
    failureReason: (0, pg_core_1.text)('failure_reason'),
    initiatedAt: (0, pg_core_1.text)('initiated_at').notNull(),
    commandAcceptedAt: (0, pg_core_1.text)('command_accepted_at'),
    verificationStartedAt: (0, pg_core_1.text)('verification_started_at'),
    completedAt: (0, pg_core_1.text)('completed_at'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.text)('updated_at'),
});
// --- reliability_health_snapshots (018_proactive_device_reliability.sql) ---
exports.reliabilityHealthSnapshots = (0, pg_core_1.pgTable)('reliability_health_snapshots', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    healthState: (0, pg_core_1.text)('health_state').notNull(),
    healthScore: (0, pg_core_1.real)('health_score').notNull().default(100.0),
    connectivityScore: (0, pg_core_1.real)('connectivity_score'),
    telemetryScore: (0, pg_core_1.real)('telemetry_score'),
    commandScore: (0, pg_core_1.real)('command_score'),
    uptimeScore: (0, pg_core_1.real)('uptime_score'),
    factors: (0, pg_core_1.text)('factors'),
    activeIncidents: (0, pg_core_1.integer)('active_incidents').notNull().default(0),
    snapshottedAt: (0, pg_core_1.text)('snapshotted_at').notNull(),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- maintenance_recommendations (018_proactive_device_reliability.sql) ---
exports.maintenanceRecommendations = (0, pg_core_1.pgTable)('maintenance_recommendations', {
    id: (0, pg_core_1.text)('id').primaryKey(),
    homeId: (0, pg_core_1.text)('home_id').notNull(),
    deviceId: (0, pg_core_1.text)('device_id').notNull(),
    incidentId: (0, pg_core_1.text)('incident_id'),
    recommendationType: (0, pg_core_1.text)('recommendation_type').notNull(),
    priority: (0, pg_core_1.text)('priority').notNull(),
    title: (0, pg_core_1.text)('title').notNull(),
    description: (0, pg_core_1.text)('description').notNull(),
    actionSteps: (0, pg_core_1.text)('action_steps'),
    status: (0, pg_core_1.text)('status').notNull().default('PENDING'),
    approvedBy: (0, pg_core_1.text)('approved_by'),
    approvedAt: (0, pg_core_1.text)('approved_at'),
    completedAt: (0, pg_core_1.text)('completed_at'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.text)('updated_at'),
});
//# sourceMappingURL=device-reliability.js.map