import { z } from 'zod';
export declare const DeviceLifecycleStateSchema: z.ZodEnum<["CREATED", "PROGRAMMED", "TESTING", "TEST_PASSED", "TEST_FAILED", "QC_APPROVED", "QR_ASSIGNED", "LABEL_PRINTED", "PACKING_SCANNED", "PACKED", "INVENTORY_STOCKED", "SHIPPED", "ACTIVATED", "DECOMMISSIONED"]>;
export type DeviceLifecycleState = z.infer<typeof DeviceLifecycleStateSchema>;
export declare const DeviceIdentitySchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    deviceId: z.ZodString;
    serialNumber: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    firmwareFamily: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    deviceId: string;
    serialNumber: string;
}, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    deviceId: string;
    serialNumber: string;
    schemaVersion?: number | undefined;
}>;
export type DeviceIdentity = z.infer<typeof DeviceIdentitySchema>;
export declare const DeviceHardwareRecordSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    deviceId: z.ZodString;
    serialNumber: z.ZodString;
    macAddress: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    firmwareFamily: z.ZodString;
    firmwareVersion: z.ZodString;
    batchId: z.ZodOptional<z.ZodString>;
    lifecycleState: z.ZodDefault<z.ZodEnum<["CREATED", "PROGRAMMED", "TESTING", "TEST_PASSED", "TEST_FAILED", "QC_APPROVED", "QR_ASSIGNED", "LABEL_PRINTED", "PACKING_SCANNED", "PACKED", "INVENTORY_STOCKED", "SHIPPED", "ACTIVATED", "DECOMMISSIONED"]>>;
    manufacturedAt: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    firmwareFamily: string;
    createdAt: string;
    productVariantId: string;
    hardwareRevision: string;
    deviceId: string;
    serialNumber: string;
    macAddress: string;
    firmwareVersion: string;
    lifecycleState: "CREATED" | "PROGRAMMED" | "TESTING" | "TEST_PASSED" | "TEST_FAILED" | "QC_APPROVED" | "QR_ASSIGNED" | "LABEL_PRINTED" | "PACKING_SCANNED" | "PACKED" | "INVENTORY_STOCKED" | "SHIPPED" | "ACTIVATED" | "DECOMMISSIONED";
    batchId?: string | undefined;
    manufacturedAt?: string | undefined;
}, {
    firmwareFamily: string;
    createdAt: string;
    productVariantId: string;
    hardwareRevision: string;
    deviceId: string;
    serialNumber: string;
    macAddress: string;
    firmwareVersion: string;
    schemaVersion?: number | undefined;
    batchId?: string | undefined;
    lifecycleState?: "CREATED" | "PROGRAMMED" | "TESTING" | "TEST_PASSED" | "TEST_FAILED" | "QC_APPROVED" | "QR_ASSIGNED" | "LABEL_PRINTED" | "PACKING_SCANNED" | "PACKED" | "INVENTORY_STOCKED" | "SHIPPED" | "ACTIVATED" | "DECOMMISSIONED" | undefined;
    manufacturedAt?: string | undefined;
}>;
export type DeviceHardwareRecord = z.infer<typeof DeviceHardwareRecordSchema>;
export declare const CredentialStateSchema: z.ZodEnum<["FACTORY", "PROVISIONED", "CLAIMED", "ACTIVE", "ROTATED", "REVOKED", "RESET"]>;
export type CredentialState = z.infer<typeof CredentialStateSchema>;
export declare const DeviceCredentialSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    deviceId: z.ZodString;
    mqttUsername: z.ZodString;
    mqttPasswordHash: z.ZodString;
    tlsClientCertFingerprint: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    localSessionKeyHash: z.ZodString;
    credentialState: z.ZodEnum<["FACTORY", "PROVISIONED", "CLAIMED", "ACTIVE", "ROTATED", "REVOKED", "RESET"]>;
    createdAt: z.ZodString;
    rotatedAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    createdAt: string;
    deviceId: string;
    mqttUsername: string;
    mqttPasswordHash: string;
    localSessionKeyHash: string;
    credentialState: "ACTIVE" | "REVOKED" | "FACTORY" | "PROVISIONED" | "CLAIMED" | "ROTATED" | "RESET";
    tlsClientCertFingerprint?: string | null | undefined;
    rotatedAt?: string | null | undefined;
}, {
    createdAt: string;
    deviceId: string;
    mqttUsername: string;
    mqttPasswordHash: string;
    localSessionKeyHash: string;
    credentialState: "ACTIVE" | "REVOKED" | "FACTORY" | "PROVISIONED" | "CLAIMED" | "ROTATED" | "RESET";
    schemaVersion?: number | undefined;
    tlsClientCertFingerprint?: string | null | undefined;
    rotatedAt?: string | null | undefined;
}>;
export type DeviceCredential = z.infer<typeof DeviceCredentialSchema>;
export declare const ConnectionStateSchema: z.ZodEnum<["ONLINE", "STALE", "OFFLINE"]>;
export type ConnectionState = z.infer<typeof ConnectionStateSchema>;
export declare const DeviceStateSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    deviceId: z.ZodString;
    connectionState: z.ZodDefault<z.ZodEnum<["ONLINE", "STALE", "OFFLINE"]>>;
    lastSeenAt: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    lastCommandId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    lastEventId: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    updatedAt: string;
    deviceId: string;
    connectionState: "ONLINE" | "STALE" | "OFFLINE";
    lastSeenAt?: string | null | undefined;
    lastCommandId?: string | null | undefined;
    lastEventId?: string | null | undefined;
}, {
    updatedAt: string;
    deviceId: string;
    schemaVersion?: number | undefined;
    connectionState?: "ONLINE" | "STALE" | "OFFLINE" | undefined;
    lastSeenAt?: string | null | undefined;
    lastCommandId?: string | null | undefined;
    lastEventId?: string | null | undefined;
}>;
export type DeviceState = z.infer<typeof DeviceStateSchema>;
//# sourceMappingURL=index.d.ts.map