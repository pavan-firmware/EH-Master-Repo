/**
 * EH Home Schema — device-trust
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, doublePrecision, integer, jsonb, pgTable, text, timestamp, varchar } from 'drizzle-orm/pg-core';

// --- device_trust_states (025_device_trust_security.sql) ---
export const deviceTrustStates = pgTable('device_trust_states', {
  deviceId: varchar('device_id', { length: 64 }).primaryKey(),
  trustState: varchar('trust_state', { length: 32 }).notNull().default('PROVISIONED'),
  trustScore: doublePrecision('trust_score').notNull().default(100.0),
  reasoningJson: jsonb('reasoning_json').notNull().default({}),
  quarantinedAt: timestamp('quarantined_at', { withTimezone: true }),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  lastEvaluatedAt: timestamp('last_evaluated_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceTrustStates = typeof deviceTrustStates.$inferSelect;
export type NewDeviceTrustStates = typeof deviceTrustStates.$inferInsert;

// --- device_credential_lifecycle (025_device_trust_security.sql) ---
export const deviceCredentialLifecycle = pgTable('device_credential_lifecycle', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  credentialType: varchar('credential_type', { length: 32 }).notNull(),
  keyIdentifier: varchar('key_identifier', { length: 128 }).notNull(),
  fingerprint: varchar('fingerprint', { length: 128 }),
  status: varchar('status', { length: 32 }).notNull().default('ROTATION_PENDING'),
  rotationGeneration: integer('rotation_generation').notNull().default(1),
  issuedAt: timestamp('issued_at', { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp('expires_at', { withTimezone: true }),
  rotatedAt: timestamp('rotated_at', { withTimezone: true }),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  metadata: jsonb('metadata').notNull().default({}),
});

export type DeviceCredentialLifecycle = typeof deviceCredentialLifecycle.$inferSelect;
export type NewDeviceCredentialLifecycle = typeof deviceCredentialLifecycle.$inferInsert;

// --- device_revocations (025_device_trust_security.sql) ---
export const deviceRevocations = pgTable('device_revocations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  revocationType: varchar('revocation_type', { length: 32 }).notNull(),
  reason: text('reason').notNull(),
  actorUserId: varchar('actor_user_id', { length: 64 }),
  evidenceJson: jsonb('evidence_json').notNull().default({}),
  remediationAllowed: boolean('remediation_allowed').notNull().default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceRevocations = typeof deviceRevocations.$inferSelect;
export type NewDeviceRevocations = typeof deviceRevocations.$inferInsert;

// --- device_provisioning_records (025_device_trust_security.sql) ---
export const deviceProvisioningRecords = pgTable('device_provisioning_records', {
  id: varchar('id', { length: 64 }).primaryKey(),
  deviceId: varchar('device_id', { length: 64 }).notNull(),
  stage: varchar('stage', { length: 32 }).notNull(),
  authority: varchar('authority', { length: 64 }).notNull(),
  evidenceJson: jsonb('evidence_json').notNull().default({}),
  completedAt: timestamp('completed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type DeviceProvisioningRecords = typeof deviceProvisioningRecords.$inferSelect;
export type NewDeviceProvisioningRecords = typeof deviceProvisioningRecords.$inferInsert;
