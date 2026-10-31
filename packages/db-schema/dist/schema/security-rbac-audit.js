"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.securityAuditEvents = exports.userSecurityPrincipals = void 0;
/**
 * EH Home Schema — security-rbac-audit
 * Source: PostgreSQL Migration 035 (Part 14)
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- user_security_principals (035_security_rbac_audit.sql) ---
exports.userSecurityPrincipals = (0, pg_core_1.pgTable)('user_security_principals', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    email: (0, pg_core_1.varchar)('email', { length: 255 }).notNull().unique(),
    role: (0, pg_core_1.varchar)('role', { length: 32 }).notNull().default('USER'),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('ACTIVE'),
    mfaEnabled: (0, pg_core_1.boolean)('mfa_enabled').notNull().default(false),
    failedLoginAttempts: (0, pg_core_1.integer)('failed_login_attempts').notNull().default(0),
    lastLoginAt: (0, pg_core_1.timestamp)('last_login_at', { withTimezone: true }),
    lastPasswordChangeAt: (0, pg_core_1.timestamp)('last_password_change_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- security_audit_events (035_security_rbac_audit.sql) ---
exports.securityAuditEvents = (0, pg_core_1.pgTable)('security_audit_events', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    sequenceNumber: (0, pg_core_1.bigserial)('sequence_number', { mode: 'number' }).unique(),
    actorId: (0, pg_core_1.varchar)('actor_id', { length: 128 }).notNull(),
    actorEmail: (0, pg_core_1.varchar)('actor_email', { length: 255 }),
    actorRole: (0, pg_core_1.varchar)('actor_role', { length: 32 }),
    action: (0, pg_core_1.varchar)('action', { length: 64 }).notNull(),
    resourceType: (0, pg_core_1.varchar)('resource_type', { length: 64 }).notNull(),
    resourceId: (0, pg_core_1.varchar)('resource_id', { length: 128 }),
    outcome: (0, pg_core_1.varchar)('outcome', { length: 32 }).notNull().default('SUCCESS'),
    severity: (0, pg_core_1.varchar)('severity', { length: 16 }).notNull().default('INFO'),
    failureReason: (0, pg_core_1.text)('failure_reason'),
    errorCode: (0, pg_core_1.varchar)('error_code', { length: 64 }),
    correlationId: (0, pg_core_1.varchar)('correlation_id', { length: 64 }),
    clientIp: (0, pg_core_1.varchar)('client_ip', { length: 45 }),
    userAgent: (0, pg_core_1.text)('user_agent'),
    metadata: (0, pg_core_1.jsonb)('metadata').notNull().default({}),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
//# sourceMappingURL=security-rbac-audit.js.map