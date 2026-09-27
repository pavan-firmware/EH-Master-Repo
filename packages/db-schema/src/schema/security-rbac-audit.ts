/**
 * EH Home Schema — security-rbac-audit
 * Source: PostgreSQL Migration 035 (Part 14)
 */
import { boolean, integer, jsonb, pgTable, text, timestamp, varchar, bigserial } from 'drizzle-orm/pg-core';

// --- user_security_principals (035_security_rbac_audit.sql) ---
export const userSecurityPrincipals = pgTable('user_security_principals', {
  id: varchar('id', { length: 128 }).primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  role: varchar('role', { length: 32 }).notNull().default('USER'),
  status: varchar('status', { length: 32 }).notNull().default('ACTIVE'),
  mfaEnabled: boolean('mfa_enabled').notNull().default(false),
  failedLoginAttempts: integer('failed_login_attempts').notNull().default(0),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  lastPasswordChangeAt: timestamp('last_password_change_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type UserSecurityPrincipals = typeof userSecurityPrincipals.$inferSelect;
export type NewUserSecurityPrincipals = typeof userSecurityPrincipals.$inferInsert;

// --- security_audit_events (035_security_rbac_audit.sql) ---
export const securityAuditEvents = pgTable('security_audit_events', {
  id: varchar('id', { length: 64 }).primaryKey(),
  sequenceNumber: bigserial('sequence_number', { mode: 'number' }).unique(),
  actorId: varchar('actor_id', { length: 128 }).notNull(),
  actorEmail: varchar('actor_email', { length: 255 }),
  actorRole: varchar('actor_role', { length: 32 }),
  action: varchar('action', { length: 64 }).notNull(),
  resourceType: varchar('resource_type', { length: 64 }).notNull(),
  resourceId: varchar('resource_id', { length: 128 }),
  outcome: varchar('outcome', { length: 32 }).notNull().default('SUCCESS'),
  severity: varchar('severity', { length: 16 }).notNull().default('INFO'),
  failureReason: text('failure_reason'),
  errorCode: varchar('error_code', { length: 64 }),
  correlationId: varchar('correlation_id', { length: 64 }),
  clientIp: varchar('client_ip', { length: 45 }),
  userAgent: text('user_agent'),
  metadata: jsonb('metadata').notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type SecurityAuditEvents = typeof securityAuditEvents.$inferSelect;
export type NewSecurityAuditEvents = typeof securityAuditEvents.$inferInsert;
