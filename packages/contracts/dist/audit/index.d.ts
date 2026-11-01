import { z } from 'zod';
/**
 * EH Home Canonical Audit Logging Contracts (Part 14)
 * Single source of truth for security audit events, query filters,
 * append-only guarantees, and zero-secret data policies.
 */
export declare const AuditActionSchema: z.ZodEnum<["AUTH_LOGIN_SUCCESS", "AUTH_LOGIN_FAILED", "AUTH_LOGOUT", "AUTH_TOKEN_REFRESHED", "AUTH_REVOKED_ATTEMPT", "PERMISSION_DENIED", "USER_CREATED", "USER_ROLE_CHANGED", "USER_STATUS_CHANGED", "USER_DELETED", "DEVICE_CLAIMED", "DEVICE_UNCLAIMED", "DEVICE_TRANSFERRED", "DEVICE_REVOKED", "DEVICE_QUARANTINED", "DEVICE_COMMAND_DISPATCHED", "FACTORY_PROVISIONED", "QC_TEST_RECORDED", "QC_TEST_OVERRIDDEN", "PACKING_VERIFIED", "PACKING_REJECTED", "INVENTORY_MUTATED", "LABEL_PRINTED", "FIRMWARE_RELEASE_CREATED", "FIRMWARE_RELEASE_APPROVED", "FIRMWARE_RELEASE_PUBLISHED", "FIRMWARE_RELEASE_REVOKED", "OTA_JOB_REQUESTED", "OTA_JOB_AUTHORIZED", "OTA_JOB_REJECTED", "OTA_JOB_CANCELLED", "OTA_JOB_ROLLED_BACK", "OBJECT_STORED", "OBJECT_DELETED", "BACKUP_CREATED", "BACKUP_RESTORED", "BACKUP_RESTORE_FAILED", "BACKUP_PRUNED", "SECURITY_POLICY_CHANGED", "MFA_CONFIGURED", "CREDENTIAL_ROTATED"]>;
export type AuditAction = z.infer<typeof AuditActionSchema>;
export declare const AuditResourceTypeSchema: z.ZodEnum<["USER", "HOME", "DEVICE", "DEVICE_CREDENTIAL", "FIRMWARE_RELEASE", "OTA_JOB", "BATCH", "PACKAGING_RECORD", "INVENTORY_ITEM", "PRINT_JOB", "SECURITY_POLICY", "SYSTEM", "STORAGE", "BACKUP"]>;
export type AuditResourceType = z.infer<typeof AuditResourceTypeSchema>;
export declare const AuditOutcomeSchema: z.ZodEnum<["SUCCESS", "DENIED", "FAILED", "WARNING"]>;
export type AuditOutcome = z.infer<typeof AuditOutcomeSchema>;
export declare const AuditSeveritySchema: z.ZodEnum<["INFO", "WARNING", "CRITICAL"]>;
export type AuditSeverity = z.infer<typeof AuditSeveritySchema>;
/**
 * Asserts that an audit payload contains zero passwords, private keys, or credentials.
 * Throws a Security Violation error if any forbidden key or pattern is detected.
 */
export declare function assertNoSecretsInAuditPayload(payload: unknown, depth?: number): void;
export declare const AuditRecordSchema: z.ZodEffects<z.ZodObject<{
    id: z.ZodString;
    sequenceNumber: z.ZodOptional<z.ZodNumber>;
    timestamp: z.ZodString;
    actorId: z.ZodString;
    actorEmail: z.ZodOptional<z.ZodString>;
    actorRole: z.ZodOptional<z.ZodEnum<["ADMIN", "OPERATOR", "RELEASE_ENGINEER", "AUDITOR", "USER", "SERVICE"]>>;
    action: z.ZodEnum<["AUTH_LOGIN_SUCCESS", "AUTH_LOGIN_FAILED", "AUTH_LOGOUT", "AUTH_TOKEN_REFRESHED", "AUTH_REVOKED_ATTEMPT", "PERMISSION_DENIED", "USER_CREATED", "USER_ROLE_CHANGED", "USER_STATUS_CHANGED", "USER_DELETED", "DEVICE_CLAIMED", "DEVICE_UNCLAIMED", "DEVICE_TRANSFERRED", "DEVICE_REVOKED", "DEVICE_QUARANTINED", "DEVICE_COMMAND_DISPATCHED", "FACTORY_PROVISIONED", "QC_TEST_RECORDED", "QC_TEST_OVERRIDDEN", "PACKING_VERIFIED", "PACKING_REJECTED", "INVENTORY_MUTATED", "LABEL_PRINTED", "FIRMWARE_RELEASE_CREATED", "FIRMWARE_RELEASE_APPROVED", "FIRMWARE_RELEASE_PUBLISHED", "FIRMWARE_RELEASE_REVOKED", "OTA_JOB_REQUESTED", "OTA_JOB_AUTHORIZED", "OTA_JOB_REJECTED", "OTA_JOB_CANCELLED", "OTA_JOB_ROLLED_BACK", "OBJECT_STORED", "OBJECT_DELETED", "BACKUP_CREATED", "BACKUP_RESTORED", "BACKUP_RESTORE_FAILED", "BACKUP_PRUNED", "SECURITY_POLICY_CHANGED", "MFA_CONFIGURED", "CREDENTIAL_ROTATED"]>;
    resourceType: z.ZodEnum<["USER", "HOME", "DEVICE", "DEVICE_CREDENTIAL", "FIRMWARE_RELEASE", "OTA_JOB", "BATCH", "PACKAGING_RECORD", "INVENTORY_ITEM", "PRINT_JOB", "SECURITY_POLICY", "SYSTEM", "STORAGE", "BACKUP"]>;
    resourceId: z.ZodOptional<z.ZodString>;
    outcome: z.ZodEnum<["SUCCESS", "DENIED", "FAILED", "WARNING"]>;
    severity: z.ZodDefault<z.ZodEnum<["INFO", "WARNING", "CRITICAL"]>>;
    failureReason: z.ZodOptional<z.ZodString>;
    errorCode: z.ZodOptional<z.ZodString>;
    correlationId: z.ZodOptional<z.ZodString>;
    clientIp: z.ZodOptional<z.ZodString>;
    userAgent: z.ZodOptional<z.ZodString>;
    metadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, "strip", z.ZodTypeAny, {
    timestamp: string;
    metadata: Record<string, unknown>;
    id: string;
    action: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED";
    resourceType: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP";
    actorId: string;
    outcome: "FAILED" | "SUCCESS" | "DENIED" | "WARNING";
    severity: "WARNING" | "INFO" | "CRITICAL";
    failureReason?: string | undefined;
    errorCode?: string | undefined;
    sequenceNumber?: number | undefined;
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    resourceId?: string | undefined;
    actorEmail?: string | undefined;
    actorRole?: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE" | undefined;
    userAgent?: string | undefined;
}, {
    timestamp: string;
    id: string;
    action: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED";
    resourceType: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP";
    actorId: string;
    outcome: "FAILED" | "SUCCESS" | "DENIED" | "WARNING";
    metadata?: Record<string, unknown> | undefined;
    failureReason?: string | undefined;
    errorCode?: string | undefined;
    sequenceNumber?: number | undefined;
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    resourceId?: string | undefined;
    actorEmail?: string | undefined;
    actorRole?: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE" | undefined;
    severity?: "WARNING" | "INFO" | "CRITICAL" | undefined;
    userAgent?: string | undefined;
}>, {
    timestamp: string;
    metadata: Record<string, unknown>;
    id: string;
    action: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED";
    resourceType: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP";
    actorId: string;
    outcome: "FAILED" | "SUCCESS" | "DENIED" | "WARNING";
    severity: "WARNING" | "INFO" | "CRITICAL";
    failureReason?: string | undefined;
    errorCode?: string | undefined;
    sequenceNumber?: number | undefined;
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    resourceId?: string | undefined;
    actorEmail?: string | undefined;
    actorRole?: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE" | undefined;
    userAgent?: string | undefined;
}, {
    timestamp: string;
    id: string;
    action: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED";
    resourceType: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP";
    actorId: string;
    outcome: "FAILED" | "SUCCESS" | "DENIED" | "WARNING";
    metadata?: Record<string, unknown> | undefined;
    failureReason?: string | undefined;
    errorCode?: string | undefined;
    sequenceNumber?: number | undefined;
    correlationId?: string | undefined;
    clientIp?: string | undefined;
    resourceId?: string | undefined;
    actorEmail?: string | undefined;
    actorRole?: "ADMIN" | "OPERATOR" | "RELEASE_ENGINEER" | "AUDITOR" | "USER" | "SERVICE" | undefined;
    severity?: "WARNING" | "INFO" | "CRITICAL" | undefined;
    userAgent?: string | undefined;
}>;
export type AuditRecord = z.infer<typeof AuditRecordSchema>;
export declare const AuditQueryFilterSchema: z.ZodObject<{
    actorId: z.ZodOptional<z.ZodString>;
    action: z.ZodOptional<z.ZodEnum<["AUTH_LOGIN_SUCCESS", "AUTH_LOGIN_FAILED", "AUTH_LOGOUT", "AUTH_TOKEN_REFRESHED", "AUTH_REVOKED_ATTEMPT", "PERMISSION_DENIED", "USER_CREATED", "USER_ROLE_CHANGED", "USER_STATUS_CHANGED", "USER_DELETED", "DEVICE_CLAIMED", "DEVICE_UNCLAIMED", "DEVICE_TRANSFERRED", "DEVICE_REVOKED", "DEVICE_QUARANTINED", "DEVICE_COMMAND_DISPATCHED", "FACTORY_PROVISIONED", "QC_TEST_RECORDED", "QC_TEST_OVERRIDDEN", "PACKING_VERIFIED", "PACKING_REJECTED", "INVENTORY_MUTATED", "LABEL_PRINTED", "FIRMWARE_RELEASE_CREATED", "FIRMWARE_RELEASE_APPROVED", "FIRMWARE_RELEASE_PUBLISHED", "FIRMWARE_RELEASE_REVOKED", "OTA_JOB_REQUESTED", "OTA_JOB_AUTHORIZED", "OTA_JOB_REJECTED", "OTA_JOB_CANCELLED", "OTA_JOB_ROLLED_BACK", "OBJECT_STORED", "OBJECT_DELETED", "BACKUP_CREATED", "BACKUP_RESTORED", "BACKUP_RESTORE_FAILED", "BACKUP_PRUNED", "SECURITY_POLICY_CHANGED", "MFA_CONFIGURED", "CREDENTIAL_ROTATED"]>>;
    resourceType: z.ZodOptional<z.ZodEnum<["USER", "HOME", "DEVICE", "DEVICE_CREDENTIAL", "FIRMWARE_RELEASE", "OTA_JOB", "BATCH", "PACKAGING_RECORD", "INVENTORY_ITEM", "PRINT_JOB", "SECURITY_POLICY", "SYSTEM", "STORAGE", "BACKUP"]>>;
    resourceId: z.ZodOptional<z.ZodString>;
    outcome: z.ZodOptional<z.ZodEnum<["SUCCESS", "DENIED", "FAILED", "WARNING"]>>;
    severity: z.ZodOptional<z.ZodEnum<["INFO", "WARNING", "CRITICAL"]>>;
    correlationId: z.ZodOptional<z.ZodString>;
    startDate: z.ZodOptional<z.ZodString>;
    endDate: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
    offset: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    offset: number;
    action?: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED" | undefined;
    correlationId?: string | undefined;
    resourceType?: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP" | undefined;
    resourceId?: string | undefined;
    actorId?: string | undefined;
    outcome?: "FAILED" | "SUCCESS" | "DENIED" | "WARNING" | undefined;
    severity?: "WARNING" | "INFO" | "CRITICAL" | undefined;
    startDate?: string | undefined;
    endDate?: string | undefined;
}, {
    limit?: number | undefined;
    action?: "LABEL_PRINTED" | "AUTH_LOGIN_SUCCESS" | "AUTH_LOGIN_FAILED" | "AUTH_LOGOUT" | "AUTH_TOKEN_REFRESHED" | "AUTH_REVOKED_ATTEMPT" | "PERMISSION_DENIED" | "USER_CREATED" | "USER_ROLE_CHANGED" | "USER_STATUS_CHANGED" | "USER_DELETED" | "DEVICE_CLAIMED" | "DEVICE_UNCLAIMED" | "DEVICE_TRANSFERRED" | "DEVICE_REVOKED" | "DEVICE_QUARANTINED" | "DEVICE_COMMAND_DISPATCHED" | "FACTORY_PROVISIONED" | "QC_TEST_RECORDED" | "QC_TEST_OVERRIDDEN" | "PACKING_VERIFIED" | "PACKING_REJECTED" | "INVENTORY_MUTATED" | "FIRMWARE_RELEASE_CREATED" | "FIRMWARE_RELEASE_APPROVED" | "FIRMWARE_RELEASE_PUBLISHED" | "FIRMWARE_RELEASE_REVOKED" | "OTA_JOB_REQUESTED" | "OTA_JOB_AUTHORIZED" | "OTA_JOB_REJECTED" | "OTA_JOB_CANCELLED" | "OTA_JOB_ROLLED_BACK" | "OBJECT_STORED" | "OBJECT_DELETED" | "BACKUP_CREATED" | "BACKUP_RESTORED" | "BACKUP_RESTORE_FAILED" | "BACKUP_PRUNED" | "SECURITY_POLICY_CHANGED" | "MFA_CONFIGURED" | "CREDENTIAL_ROTATED" | undefined;
    correlationId?: string | undefined;
    resourceType?: "USER" | "HOME" | "DEVICE" | "DEVICE_CREDENTIAL" | "FIRMWARE_RELEASE" | "OTA_JOB" | "BATCH" | "PACKAGING_RECORD" | "INVENTORY_ITEM" | "PRINT_JOB" | "SECURITY_POLICY" | "SYSTEM" | "STORAGE" | "BACKUP" | undefined;
    resourceId?: string | undefined;
    actorId?: string | undefined;
    outcome?: "FAILED" | "SUCCESS" | "DENIED" | "WARNING" | undefined;
    severity?: "WARNING" | "INFO" | "CRITICAL" | undefined;
    startDate?: string | undefined;
    endDate?: string | undefined;
    offset?: number | undefined;
}>;
export type AuditQueryFilter = z.infer<typeof AuditQueryFilterSchema>;
//# sourceMappingURL=index.d.ts.map