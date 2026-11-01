"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditQueryFilterSchema = exports.AuditRecordSchema = exports.AuditSeveritySchema = exports.AuditOutcomeSchema = exports.AuditResourceTypeSchema = exports.AuditActionSchema = void 0;
exports.assertNoSecretsInAuditPayload = assertNoSecretsInAuditPayload;
const zod_1 = require("zod");
const common_1 = require("../common");
const security_1 = require("../security");
/**
 * EH Home Canonical Audit Logging Contracts (Part 14)
 * Single source of truth for security audit events, query filters,
 * append-only guarantees, and zero-secret data policies.
 */
// 1. Security & Operational Audit Actions
exports.AuditActionSchema = zod_1.z.enum([
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
// 2. Resource Types
exports.AuditResourceTypeSchema = zod_1.z.enum([
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
// 3. Outcome & Severity
exports.AuditOutcomeSchema = zod_1.z.enum(['SUCCESS', 'DENIED', 'FAILED', 'WARNING']);
exports.AuditSeveritySchema = zod_1.z.enum(['INFO', 'WARNING', 'CRITICAL']);
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
function assertNoSecretsInAuditPayload(payload, depth = 0) {
    if (!payload || typeof payload !== 'object' || depth > 10)
        return;
    if (Array.isArray(payload)) {
        for (const item of payload) {
            assertNoSecretsInAuditPayload(item, depth + 1);
        }
        return;
    }
    for (const [key, value] of Object.entries(payload)) {
        const cleanKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (FORBIDDEN_SECRET_KEYS.has(cleanKey) ||
            cleanKey.includes('password') ||
            cleanKey.includes('privatekey') ||
            cleanKey.includes('wifipass') ||
            cleanKey.endsWith('token')) {
            throw new Error(`Security Violation: Audit record contains forbidden secret key '${key}'`);
        }
        if (typeof value === 'string') {
            // Reject raw PEM private keys
            if (value.includes('BEGIN PRIVATE KEY') || value.includes('BEGIN RSA PRIVATE KEY') || value.includes('BEGIN EC PRIVATE KEY')) {
                throw new Error(`Security Violation: Audit record contains raw private key material in field '${key}'`);
            }
        }
        else if (typeof value === 'object' && value !== null) {
            assertNoSecretsInAuditPayload(value, depth + 1);
        }
    }
}
// 5. Canonical Audit Record Schema
exports.AuditRecordSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    sequenceNumber: zod_1.z.number().int().nonnegative().optional(),
    timestamp: common_1.IsoDateTimeSchema,
    actorId: zod_1.z.string().min(1),
    actorEmail: zod_1.z.string().optional(),
    actorRole: security_1.UserRoleSchema.optional(),
    action: exports.AuditActionSchema,
    resourceType: exports.AuditResourceTypeSchema,
    resourceId: zod_1.z.string().optional(),
    outcome: exports.AuditOutcomeSchema,
    severity: exports.AuditSeveritySchema.default('INFO'),
    failureReason: zod_1.z.string().optional(),
    errorCode: zod_1.z.string().optional(),
    correlationId: zod_1.z.string().optional(),
    clientIp: zod_1.z.string().optional(),
    userAgent: zod_1.z.string().optional(),
    metadata: zod_1.z.record(zod_1.z.unknown()).default({})
}).refine((record) => {
    try {
        assertNoSecretsInAuditPayload(record.metadata);
        return true;
    }
    catch {
        return false;
    }
}, { message: 'Audit record metadata contains forbidden sensitive secrets' });
// 6. Audit Query Filter Schema
exports.AuditQueryFilterSchema = zod_1.z.object({
    actorId: zod_1.z.string().optional(),
    action: exports.AuditActionSchema.optional(),
    resourceType: exports.AuditResourceTypeSchema.optional(),
    resourceId: zod_1.z.string().optional(),
    outcome: exports.AuditOutcomeSchema.optional(),
    severity: exports.AuditSeveritySchema.optional(),
    correlationId: zod_1.z.string().optional(),
    startDate: common_1.IsoDateTimeSchema.optional(),
    endDate: common_1.IsoDateTimeSchema.optional(),
    limit: zod_1.z.number().int().min(1).max(200).default(50),
    offset: zod_1.z.number().int().min(0).default(0)
});
//# sourceMappingURL=index.js.map