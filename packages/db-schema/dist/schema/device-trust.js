"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deviceProvisioningRecords = exports.deviceRevocations = exports.deviceCredentialLifecycle = exports.deviceTrustStates = void 0;
/**
 * EH Home Schema — device-trust
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- device_trust_states (025_device_trust_security.sql) ---
exports.deviceTrustStates = (0, pg_core_1.pgTable)('device_trust_states', {
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).primaryKey(),
    trustState: (0, pg_core_1.varchar)('trust_state', { length: 32 }).notNull().default('PROVISIONED'),
    trustScore: (0, pg_core_1.doublePrecision)('trust_score').notNull().default(100.0),
    reasoningJson: (0, pg_core_1.jsonb)('reasoning_json').notNull().default({}),
    quarantinedAt: (0, pg_core_1.timestamp)('quarantined_at', { withTimezone: true }),
    revokedAt: (0, pg_core_1.timestamp)('revoked_at', { withTimezone: true }),
    lastEvaluatedAt: (0, pg_core_1.timestamp)('last_evaluated_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_credential_lifecycle (025_device_trust_security.sql) ---
exports.deviceCredentialLifecycle = (0, pg_core_1.pgTable)('device_credential_lifecycle', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    credentialType: (0, pg_core_1.varchar)('credential_type', { length: 32 }).notNull(),
    keyIdentifier: (0, pg_core_1.varchar)('key_identifier', { length: 128 }).notNull(),
    fingerprint: (0, pg_core_1.varchar)('fingerprint', { length: 128 }),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('ROTATION_PENDING'),
    rotationGeneration: (0, pg_core_1.integer)('rotation_generation').notNull().default(1),
    issuedAt: (0, pg_core_1.timestamp)('issued_at', { withTimezone: true }).notNull().defaultNow(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }),
    rotatedAt: (0, pg_core_1.timestamp)('rotated_at', { withTimezone: true }),
    revokedAt: (0, pg_core_1.timestamp)('revoked_at', { withTimezone: true }),
    metadata: (0, pg_core_1.jsonb)('metadata').notNull().default({}),
});
// --- device_revocations (025_device_trust_security.sql) ---
exports.deviceRevocations = (0, pg_core_1.pgTable)('device_revocations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    revocationType: (0, pg_core_1.varchar)('revocation_type', { length: 32 }).notNull(),
    reason: (0, pg_core_1.text)('reason').notNull(),
    actorUserId: (0, pg_core_1.varchar)('actor_user_id', { length: 64 }),
    evidenceJson: (0, pg_core_1.jsonb)('evidence_json').notNull().default({}),
    remediationAllowed: (0, pg_core_1.boolean)('remediation_allowed').notNull().default(false),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- device_provisioning_records (025_device_trust_security.sql) ---
exports.deviceProvisioningRecords = (0, pg_core_1.pgTable)('device_provisioning_records', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    deviceId: (0, pg_core_1.varchar)('device_id', { length: 64 }).notNull(),
    stage: (0, pg_core_1.varchar)('stage', { length: 32 }).notNull(),
    authority: (0, pg_core_1.varchar)('authority', { length: 64 }).notNull(),
    evidenceJson: (0, pg_core_1.jsonb)('evidence_json').notNull().default({}),
    completedAt: (0, pg_core_1.timestamp)('completed_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=device-trust.js.map