/**
 * EH Home Schema — device-reliability
 * Source: PostgreSQL Migrations 001–029
 */
import { integer, pgTable, real, text, timestamp } from 'drizzle-orm/pg-core';

// --- reliability_incidents (018_proactive_device_reliability.sql) ---
export const reliabilityIncidents = pgTable('reliability_incidents', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  incidentType: text('incident_type').notNull(),
  severity: text('severity').notNull(),
  status: text('status').notNull().default('OPEN'),
  title: text('title').notNull(),
  description: text('description'),
  evidence: text('evidence'),
  signalCount: integer('signal_count').notNull().default(1),
  firstObservedAt: text('first_observed_at').notNull(),
  lastObservedAt: text('last_observed_at').notNull(),
  resolvedAt: text('resolved_at'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: text('updated_at'),
});

export type ReliabilityIncidents = typeof reliabilityIncidents.$inferSelect;
export type NewReliabilityIncidents = typeof reliabilityIncidents.$inferInsert;

// --- reliability_diagnostics (018_proactive_device_reliability.sql) ---
export const reliabilityDiagnostics = pgTable('reliability_diagnostics', {
  id: text('id').primaryKey(),
  incidentId: text('incident_id').notNull(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  diagnosisType: text('diagnosis_type').notNull(),
  confidence: real('confidence').notNull().default(0.0),
  rootCause: text('root_cause').notNull(),
  evidence: text('evidence'),
  recommendedActions: text('recommended_actions'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ReliabilityDiagnostics = typeof reliabilityDiagnostics.$inferSelect;
export type NewReliabilityDiagnostics = typeof reliabilityDiagnostics.$inferInsert;

// --- reliability_recovery_attempts (018_proactive_device_reliability.sql) ---
export const reliabilityRecoveryAttempts = pgTable('reliability_recovery_attempts', {
  id: text('id').primaryKey(),
  incidentId: text('incident_id').notNull(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  actionType: text('action_type').notNull(),
  status: text('status').notNull().default('PENDING'),
  commandAccepted: integer('command_accepted').notNull().default(0),
  preActionState: text('pre_action_state'),
  postActionState: text('post_action_state'),
  verificationEvidence: text('verification_evidence'),
  failureReason: text('failure_reason'),
  initiatedAt: text('initiated_at').notNull(),
  commandAcceptedAt: text('command_accepted_at'),
  verificationStartedAt: text('verification_started_at'),
  completedAt: text('completed_at'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: text('updated_at'),
});

export type ReliabilityRecoveryAttempts = typeof reliabilityRecoveryAttempts.$inferSelect;
export type NewReliabilityRecoveryAttempts = typeof reliabilityRecoveryAttempts.$inferInsert;

// --- reliability_health_snapshots (018_proactive_device_reliability.sql) ---
export const reliabilityHealthSnapshots = pgTable('reliability_health_snapshots', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  healthState: text('health_state').notNull(),
  healthScore: real('health_score').notNull().default(100.0),
  connectivityScore: real('connectivity_score'),
  telemetryScore: real('telemetry_score'),
  commandScore: real('command_score'),
  uptimeScore: real('uptime_score'),
  factors: text('factors'),
  activeIncidents: integer('active_incidents').notNull().default(0),
  snapshottedAt: text('snapshotted_at').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type ReliabilityHealthSnapshots = typeof reliabilityHealthSnapshots.$inferSelect;
export type NewReliabilityHealthSnapshots = typeof reliabilityHealthSnapshots.$inferInsert;

// --- maintenance_recommendations (018_proactive_device_reliability.sql) ---
export const maintenanceRecommendations = pgTable('maintenance_recommendations', {
  id: text('id').primaryKey(),
  homeId: text('home_id').notNull(),
  deviceId: text('device_id').notNull(),
  incidentId: text('incident_id'),
  recommendationType: text('recommendation_type').notNull(),
  priority: text('priority').notNull(),
  title: text('title').notNull(),
  description: text('description').notNull(),
  actionSteps: text('action_steps'),
  status: text('status').notNull().default('PENDING'),
  approvedBy: text('approved_by'),
  approvedAt: text('approved_at'),
  completedAt: text('completed_at'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: text('updated_at'),
});

export type MaintenanceRecommendations = typeof maintenanceRecommendations.$inferSelect;
export type NewMaintenanceRecommendations = typeof maintenanceRecommendations.$inferInsert;
