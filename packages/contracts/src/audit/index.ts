import { z } from 'zod';
import { IsoDateTimeSchema } from '../common';
import { UserRoleSchema } from '../security';

/**
 * EH Home Canonical Audit Logging Contracts (Part 14)
 * Single source of truth for security audit events, query filters,
 * append-only guarantees, and zero-secret data policies.
 */

// 1. Security & Operational Audit Actions
export const AuditActionSchema = z.enum([
  // Authentication & Session
  'AUTH_LOGIN_SUCCESS',
  'AUTH_LOGIN_FAILED',
  'AUTH_LOGOUT',
  'AUTH_TOKEN_REFRESHED',
  'AUTH_REVOKED_ATTEMPT',
  'PERMISSION_DENIED',

  // User & Role Administration
  'USER_CREATED',
  'USER_ROLE_CHANGED',
  'USER_STATUS_CHANGED',
  'USER_DELETED',

  // Device & Ownership
  'DEVICE_CLAIMED',
  'DEVICE_UNCLAIMED',
  'DEVICE_TRANSFERRED',
  'DEVICE_REVOKED',
  'DEVICE_QUARANTINED',
  'DEVICE_COMMAND_DISPATCHED',

  // Manufacturing & Bench
  'FACTORY_PROVISIONED',
  'QC_TEST_RECORDED',
  'QC_TEST_OVERRIDDEN',
  'PACKING_VERIFIED',
  'PACKING_REJECTED',
  'INVENTORY_MUTATED',
  'LABEL_PRINTED',

  // Firmware & Release
  'FIRMWARE_RELEASE_CREATED',
  'FIRMWARE_RELEASE_APPROVED',
  'FIRMWARE_RELEASE_PUBLISHED',
  'FIRMWARE_RELEASE_REVOKED',
  'OTA_JOB_REQUESTED',
  'OTA_JOB_AUTHORIZED',
  'OTA_JOB_REJECTED',
  'OTA_JOB_CANCELLED',
  'OTA_JOB_ROLLED_BACK',

  // Storage & Backup Operations (Part 16)
  'OBJECT_STORED',
  'OBJECT_DELETED',
  'BACKUP_CREATED',
  'BACKUP_RESTORED',
  'BACKUP_RESTORE_FAILED',
  'BACKUP_PRUNED',

  // Security Policies & Keys
  'SECURITY_POLICY_CHANGED',
  'MFA_CONFIGURED',
  'CREDENTIAL_ROTATED'
]);
export type AuditAction = z.infer<typeof AuditActionSchema>;

// 2. Resource Types
export const AuditResourceTypeSchema = z.enum([
  'USER',
  'HOME',
  'DEVICE',
  'DEVICE_CREDENTIAL',
  'FIRMWARE_RELEASE',
  'OTA_JOB',
  'BATCH',
  'PACKAGING_RECORD',
  'INVENTORY_ITEM',
  'PRINT_JOB',
  'SECURITY_POLICY',
  'SYSTEM',
  'STORAGE',
  'BACKUP'
]);
export type AuditResourceType = z.infer<typeof AuditResourceTypeSchema>;


// 3. Outcome & Severity
export const AuditOutcomeSchema = z.enum(['SUCCESS', 'DENIED', 'FAILED', 'WARNING']);
export type AuditOutcome = z.infer<typeof AuditOutcomeSchema>;

export const AuditSeveritySchema = z.enum(['INFO', 'WARNING', 'CRITICAL']);
export type AuditSeverity = z.infer<typeof AuditSeveritySchema>;

const FORBIDDEN_SECRET_KEYS = new Set([
  'password',
  'passwordhash',
  'token',
  'accesstoken',
  'refreshtoken',
  'secret',
  'privatekey',
  'privkey',
  'wifipassword',
  'sessionkey',
  'devicesecret',
  'signingkey',
  'apikey',
  'authkey'
]);

/**
 * Asserts that an audit payload contains zero passwords, private keys, or credentials.
 * Throws a Security Violation error if any forbidden key or pattern is detected.
 */
export function assertNoSecretsInAuditPayload(payload: unknown, depth = 0): void {
  if (!payload || typeof payload !== 'object' || depth > 10) return;

  if (Array.isArray(payload)) {
    for (const item of payload) {
      assertNoSecretsInAuditPayload(item, depth + 1);
    }
    return;
  }

  for (const [key, value] of Object.entries(payload as Record<string, unknown>)) {
    const cleanKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (
      FORBIDDEN_SECRET_KEYS.has(cleanKey) ||
      cleanKey.includes('password') ||
      cleanKey.includes('privatekey') ||
      cleanKey.includes('wifipass') ||
      cleanKey.endsWith('token')
    ) {
      throw new Error(`Security Violation: Audit record contains forbidden secret key '${key}'`);
    }

    if (typeof value === 'string') {
      // Reject raw PEM private keys
      if (value.includes('BEGIN PRIVATE KEY') || value.includes('BEGIN RSA PRIVATE KEY') || value.includes('BEGIN EC PRIVATE KEY')) {
        throw new Error(`Security Violation: Audit record contains raw private key material in field '${key}'`);
      }
    } else if (typeof value === 'object' && value !== null) {
      assertNoSecretsInAuditPayload(value, depth + 1);
    }
  }
}

// 5. Canonical Audit Record Schema
export const AuditRecordSchema = z.object({
  id: z.string().uuid(),
  sequenceNumber: z.number().int().nonnegative().optional(),
  timestamp: IsoDateTimeSchema,
  actorId: z.string().min(1),
  actorEmail: z.string().optional(),
  actorRole: UserRoleSchema.optional(),
  action: AuditActionSchema,
  resourceType: AuditResourceTypeSchema,
  resourceId: z.string().optional(),
  outcome: AuditOutcomeSchema,
  severity: AuditSeveritySchema.default('INFO'),
  failureReason: z.string().optional(),
  errorCode: z.string().optional(),
  correlationId: z.string().optional(),
  clientIp: z.string().optional(),
  userAgent: z.string().optional(),
  metadata: z.record(z.unknown()).default({})
}).refine(
  (record) => {
    try {
      assertNoSecretsInAuditPayload(record.metadata);
      return true;
    } catch {
      return false;
    }
  },
  { message: 'Audit record metadata contains forbidden sensitive secrets' }
);
export type AuditRecord = z.infer<typeof AuditRecordSchema>;

// 6. Audit Query Filter Schema
export const AuditQueryFilterSchema = z.object({
  actorId: z.string().optional(),
  action: AuditActionSchema.optional(),
  resourceType: AuditResourceTypeSchema.optional(),
  resourceId: z.string().optional(),
  outcome: AuditOutcomeSchema.optional(),
  severity: AuditSeveritySchema.optional(),
  correlationId: z.string().optional(),
  startDate: IsoDateTimeSchema.optional(),
  endDate: IsoDateTimeSchema.optional(),
  limit: z.number().int().min(1).max(200).default(50),
  offset: z.number().int().min(0).default(0)
});
export type AuditQueryFilter = z.infer<typeof AuditQueryFilterSchema>;
