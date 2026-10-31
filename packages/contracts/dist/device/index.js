"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeviceStateSchema = exports.ConnectionStateSchema = exports.DeviceCredentialSchema = exports.CredentialStateSchema = exports.DeviceHardwareRecordSchema = exports.DeviceIdentitySchema = exports.DeviceLifecycleStateSchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.DeviceLifecycleStateSchema = zod_1.z.enum([
    'CREATED',
    'PROGRAMMED',
    'TESTING',
    'TEST_PASSED',
    'TEST_FAILED',
    'QC_APPROVED',
    'QR_ASSIGNED',
    'LABEL_PRINTED',
    'PACKING_SCANNED',
    'PACKED',
    'INVENTORY_STOCKED',
    'SHIPPED',
    'ACTIVATED',
    'DECOMMISSIONED'
]);
exports.DeviceIdentitySchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    productVariantId: zod_1.z.string().regex(/^eh-[a-z0-9-]+$/),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().regex(/^[a-z0-9-]+$/)
});
exports.DeviceHardwareRecordSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    macAddress: common_1.MacAddressSchema,
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    batchId: zod_1.z.string().uuid().optional(),
    lifecycleState: exports.DeviceLifecycleStateSchema.default('CREATED'),
    manufacturedAt: zod_1.z.string().datetime().optional(),
    createdAt: zod_1.z.string().datetime()
});
exports.CredentialStateSchema = zod_1.z.enum([
    'FACTORY',
    'PROVISIONED',
    'CLAIMED',
    'ACTIVE',
    'ROTATED',
    'REVOKED',
    'RESET'
]);
exports.DeviceCredentialSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    deviceId: zod_1.z.string().uuid(),
    mqttUsername: zod_1.z.string().min(1),
    mqttPasswordHash: zod_1.z.string().min(1),
    tlsClientCertFingerprint: zod_1.z.string().nullable().optional(),
    localSessionKeyHash: zod_1.z.string().min(1),
    credentialState: exports.CredentialStateSchema,
    createdAt: zod_1.z.string().datetime(),
    rotatedAt: zod_1.z.string().datetime().nullable().optional()
});
exports.ConnectionStateSchema = zod_1.z.enum(['ONLINE', 'STALE', 'OFFLINE']);
exports.DeviceStateSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    deviceId: zod_1.z.string().uuid(),
    connectionState: exports.ConnectionStateSchema.default('OFFLINE'),
    lastSeenAt: zod_1.z.string().datetime().nullable().optional(),
    lastCommandId: zod_1.z.string().nullable().optional(),
    lastEventId: zod_1.z.string().nullable().optional(),
    updatedAt: zod_1.z.string().datetime()
});
//# sourceMappingURL=index.js.map