"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CompletePackingResultSchema = exports.PackagingRecordSchema = exports.CompletePackingRequestSchema = exports.CreateCartonRequestSchema = exports.RegisterInventoryResultSchema = exports.RegisterInventoryRequestSchema = exports.DualScanVerificationResultSchema = exports.VerificationStatusSchema = exports.DualScanVerificationRequestSchema = exports.BoxScanPayloadSchema = exports.DeviceScanPayloadSchema = exports.PackagingCartonSchema = exports.InventoryItemSchema = exports.PackingErrorCodeSchema = exports.CartonStatusSchema = exports.InventoryStatusSchema = void 0;
exports.isValidInventoryStateTransition = isValidInventoryStateTransition;
exports.evaluateDualScan = evaluateDualScan;
const zod_1 = require("zod");
const common_1 = require("../common");
const qr_1 = require("../qr");
const provisioning_1 = require("../provisioning");
const product_1 = require("../product");
const generator_1 = require("../qr/generator");
// ── 1. Manufacturing Inventory State & Lifecycle ───────────────────────
exports.InventoryStatusSchema = zod_1.z.enum([
    'PROVISIONED',
    'VERIFIED',
    'PACKING',
    'PACKED',
    'QUARANTINED'
]);
exports.CartonStatusSchema = zod_1.z.enum([
    'OPEN',
    'FULL',
    'SEALED',
    'CANCELLED'
]);
exports.PackingErrorCodeSchema = zod_1.z.enum([
    'SERIAL_ALREADY_REGISTERED',
    'DEVICE_NOT_FOUND',
    'DEVICE_ALREADY_PACKED',
    'DEVICE_NOT_VERIFIED',
    'DUAL_SCAN_REQUIRED',
    'DUAL_SCAN_NOT_FOUND',
    'CARTON_REQUIRED',
    'INVALID_QR',
    'QR_DEVICE_MISMATCH',
    'PRODUCT_MISMATCH',
    'VARIANT_MISMATCH',
    'HARDWARE_REVISION_MISMATCH',
    'FIRMWARE_FAMILY_MISMATCH',
    'CARTON_NOT_FOUND',
    'CARTON_ALREADY_ASSIGNED',
    'CARTON_FULL',
    'DUPLICATE_SCAN',
    'INVALID_STATE_TRANSITION',
    'PACKING_VALIDATION_FAILED',
    'PROVISIONING_NOT_PASSED',
    'SECRET_DATA_DETECTED'
]);
// ── 2. Inventory Domain Models ─────────────────────────────────────────
exports.InventoryItemSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    traceId: zod_1.z.string().uuid(),
    status: exports.InventoryStatusSchema.default('PROVISIONED'),
    cartonId: zod_1.z.string().nullable().optional(),
    qrToken: qr_1.OpaqueQrTokenSchema.nullable().optional(),
    qrUri: qr_1.QrUriSchema.nullable().optional(),
    qcStatus: zod_1.z.enum(['PASS', 'FAIL']).default('PASS'),
    registeredAt: zod_1.z.string().datetime(),
    verifiedAt: zod_1.z.string().datetime().nullable().optional(),
    packedAt: zod_1.z.string().datetime().nullable().optional()
});
exports.PackagingCartonSchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    cartonCode: zod_1.z.string().regex(/^CARTON-[A-Z0-9-]+$/, {
        message: 'Must be a valid carton code (e.g. CARTON-2026-SW3X-001)'
    }),
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    targetCapacity: zod_1.z.number().int().positive().default(1),
    packedCount: zod_1.z.number().int().nonnegative().default(0),
    status: exports.CartonStatusSchema.default('OPEN'),
    sealedAt: zod_1.z.string().datetime().nullable().optional(),
    operatorUserId: zod_1.z.string().optional(),
    createdAt: zod_1.z.string().datetime(),
    updatedAt: zod_1.z.string().datetime()
});
// ── 3. Scan & Verification Requests / Payloads ─────────────────────────
exports.DeviceScanPayloadSchema = zod_1.z.object({
    serialNumber: common_1.SerialNumberSchema,
    stationId: zod_1.z.string().min(1),
    scannedAt: zod_1.z.string().datetime()
});
exports.BoxScanPayloadSchema = zod_1.z.object({
    boxToken: qr_1.OpaqueQrTokenSchema,
    stationId: zod_1.z.string().min(1),
    scannedAt: zod_1.z.string().datetime()
});
exports.DualScanVerificationRequestSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    stationId: zod_1.z.string().min(1),
    operatorUserId: zod_1.z.string().optional(),
    deviceSerial: zod_1.z.union([common_1.SerialNumberSchema, zod_1.z.string().regex(/^E1[A-Z]\dH\dF\d-\d{5}$/)]),
    boxTokenOrUri: zod_1.z.string().min(16),
    cartonId: zod_1.z.string().optional(),
    requestedAt: zod_1.z.string().datetime()
});
exports.VerificationStatusSchema = zod_1.z.enum([
    'MATCH_APPROVED',
    'MISMATCH_REJECTED',
    'DEVICE_NOT_FOUND',
    'BOX_NOT_FOUND',
    'ALREADY_PACKED',
    'QC_NOT_PASSED'
]);
exports.DualScanVerificationResultSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    verificationId: zod_1.z.string().uuid().optional(),
    success: zod_1.z.boolean(),
    isMatch: zod_1.z.boolean(),
    status: exports.VerificationStatusSchema,
    deviceSerial: zod_1.z.union([common_1.SerialNumberSchema, zod_1.z.string().regex(/^E1[A-Z]\dH\dF\d-\d{5}$/)]),
    deviceId: zod_1.z.string().uuid().optional(),
    boxToken: qr_1.OpaqueQrTokenSchema.optional(),
    productVariantId: zod_1.z.string().optional(),
    hardwareRevision: common_1.HardwareRevisionCodeSchema.optional(),
    firmwareFamily: zod_1.z.string().optional(),
    cartonId: zod_1.z.string().optional(),
    rejectionReason: zod_1.z.string().optional(),
    errorCode: exports.PackingErrorCodeSchema.optional(),
    verifiedAt: zod_1.z.string().datetime()
}).refine((data) => {
    if (data.success && data.isMatch) {
        return data.status === 'MATCH_APPROVED';
    }
    return data.status !== 'MATCH_APPROVED';
}, {
    message: 'Consistency violation: success and isMatch must correlate with status MATCH_APPROVED'
});
// ── 4. Registration & Packing Operations ───────────────────────────────
exports.RegisterInventoryRequestSchema = zod_1.z.object({
    traceabilityRecord: provisioning_1.BenchProvisioningTraceabilityRecordSchema,
    stationId: zod_1.z.string().min(1),
    qrToken: qr_1.OpaqueQrTokenSchema.optional()
});
exports.RegisterInventoryResultSchema = zod_1.z.object({
    success: zod_1.z.boolean(),
    inventoryItem: exports.InventoryItemSchema.optional(),
    errorCode: exports.PackingErrorCodeSchema.optional(),
    errorMessage: zod_1.z.string().optional(),
    registeredAt: zod_1.z.string().datetime()
});
exports.CreateCartonRequestSchema = zod_1.z.object({
    cartonCode: zod_1.z.string().min(1),
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    targetCapacity: zod_1.z.number().int().positive().default(1),
    operatorUserId: zod_1.z.string().optional()
});
exports.CompletePackingRequestSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    cartonId: zod_1.z.string().min(1),
    verificationId: zod_1.z.string().uuid(),
    stationId: zod_1.z.string().min(1),
    operatorUserId: zod_1.z.string().optional(),
    notes: zod_1.z.string().optional()
});
exports.PackagingRecordSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    traceId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    cartonId: zod_1.z.string().min(1),
    verificationId: zod_1.z.string().uuid(),
    stationId: zod_1.z.string().min(1),
    operatorUserId: zod_1.z.string().nullable().optional(),
    packedAt: zod_1.z.string().datetime(),
    notes: zod_1.z.string().nullable().optional()
});
exports.CompletePackingResultSchema = zod_1.z.object({
    success: zod_1.z.boolean(),
    packagingRecord: exports.PackagingRecordSchema.optional(),
    inventoryItem: exports.InventoryItemSchema.optional(),
    carton: exports.PackagingCartonSchema.optional(),
    errorCode: exports.PackingErrorCodeSchema.optional(),
    errorMessage: zod_1.z.string().optional(),
    packedAt: zod_1.z.string().datetime()
});
const ALLOWED_STATE_TRANSITIONS = {
    PROVISIONED: ['VERIFIED', 'PACKING', 'QUARANTINED'],
    VERIFIED: ['PACKING', 'PACKED', 'QUARANTINED'],
    PACKING: ['PACKED', 'VERIFIED', 'QUARANTINED'],
    PACKED: [], // Terminal packed state
    QUARANTINED: ['PROVISIONED', 'VERIFIED'] // Can only be re-bench tested
};
/**
 * Validates whether an inventory state transition is permitted.
 */
function isValidInventoryStateTransition(from, to) {
    if (from === to)
        return true; // Idempotent same-state is valid
    const allowed = ALLOWED_STATE_TRANSITIONS[from];
    return !!allowed && allowed.includes(to);
}
/**
 * Executes server-side Dual-Scan matching logic against canonical product, firmware,
 * hardware, and carton rules.
 */
function evaluateDualScan(params) {
    const { item, scannedTokenOrUri, carton } = params;
    (0, generator_1.assertNoSecretsInRecord)(item);
    const now = new Date().toISOString();
    // 1. Device must not already be packed
    if (item.status === 'PACKED') {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'ALREADY_PACKED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Device ${item.serialNumber} is already marked PACKED.`,
            errorCode: 'DEVICE_ALREADY_PACKED',
            verifiedAt: now
        });
    }
    // 2. Provisioning / QC must have passed
    if (item.qcStatus !== 'PASS') {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'QC_NOT_PASSED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Device ${item.serialNumber} QC status is ${item.qcStatus}.`,
            errorCode: 'PROVISIONING_NOT_PASSED',
            verifiedAt: now
        });
    }
    // 3. Parse and extract token from scanned URI or raw token
    let token = scannedTokenOrUri.trim();
    if (token.startsWith('eh://p/v1?t=')) {
        token = token.replace('eh://p/v1?t=', '').split('&')[0] || '';
    }
    const tokenParse = qr_1.OpaqueQrTokenSchema.safeParse(token);
    if (!tokenParse.success) {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'MISMATCH_REJECTED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Scanned token '${token}' is not a valid canonical opaque QR token (16-64 chars).`,
            errorCode: 'INVALID_QR',
            verifiedAt: now
        });
    }
    // 4. Token match against registered device QR token (if assigned)
    if (item.qrToken && item.qrToken !== token) {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'MISMATCH_REJECTED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            boxToken: token,
            productVariantId: item.productVariantId,
            hardwareRevision: item.hardwareRevision,
            rejectionReason: `Scanned QR token '${token}' does not match registered device token '${item.qrToken}'.`,
            errorCode: 'QR_DEVICE_MISMATCH',
            verifiedAt: now
        });
    }
    // 5. Canonical Product Definition & HW Revision compatibility
    if (!product_1.CANONICAL_APPROVED_VARIANTS.has(item.productVariantId)) {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'MISMATCH_REJECTED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Product variant '${item.productVariantId}' is not in the canonical catalog.`,
            errorCode: 'PRODUCT_MISMATCH',
            verifiedAt: now
        });
    }
    if (!(0, product_1.isCanonicalProductHardwareSupported)(item.productVariantId, item.hardwareRevision)) {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'MISMATCH_REJECTED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Hardware revision '${item.hardwareRevision}' is incompatible with variant '${item.productVariantId}'.`,
            errorCode: 'HARDWARE_REVISION_MISMATCH',
            verifiedAt: now
        });
    }
    // 6. Firmware Family Check
    const prodDef = (0, product_1.getCanonicalProductDefinition)(item.productVariantId);
    if (!prodDef || prodDef.firmwareFamily !== item.firmwareFamily) {
        return exports.DualScanVerificationResultSchema.parse({
            success: false,
            isMatch: false,
            status: 'MISMATCH_REJECTED',
            deviceSerial: item.serialNumber,
            deviceId: item.deviceId,
            rejectionReason: `Firmware family '${item.firmwareFamily}' does not match canonical family '${prodDef?.firmwareFamily}'.`,
            errorCode: 'FIRMWARE_FAMILY_MISMATCH',
            verifiedAt: now
        });
    }
    // 7. Carton compatibility check (if carton is targeted)
    if (carton) {
        if (carton.status !== 'OPEN') {
            return exports.DualScanVerificationResultSchema.parse({
                success: false,
                isMatch: false,
                status: 'MISMATCH_REJECTED',
                deviceSerial: item.serialNumber,
                deviceId: item.deviceId,
                cartonId: carton.id,
                rejectionReason: `Carton '${carton.cartonCode}' is status '${carton.status}' (not OPEN).`,
                errorCode: 'CARTON_FULL',
                verifiedAt: now
            });
        }
        if (carton.productVariantId !== item.productVariantId) {
            return exports.DualScanVerificationResultSchema.parse({
                success: false,
                isMatch: false,
                status: 'MISMATCH_REJECTED',
                deviceSerial: item.serialNumber,
                deviceId: item.deviceId,
                cartonId: carton.id,
                rejectionReason: `Carton variant '${carton.productVariantId}' does not match device variant '${item.productVariantId}'.`,
                errorCode: 'VARIANT_MISMATCH',
                verifiedAt: now
            });
        }
        if (carton.hardwareRevision !== item.hardwareRevision) {
            return exports.DualScanVerificationResultSchema.parse({
                success: false,
                isMatch: false,
                status: 'MISMATCH_REJECTED',
                deviceSerial: item.serialNumber,
                deviceId: item.deviceId,
                cartonId: carton.id,
                rejectionReason: `Carton hardware revision '${carton.hardwareRevision}' does not match device revision '${item.hardwareRevision}'.`,
                errorCode: 'HARDWARE_REVISION_MISMATCH',
                verifiedAt: now
            });
        }
        if (carton.packedCount >= carton.targetCapacity) {
            return exports.DualScanVerificationResultSchema.parse({
                success: false,
                isMatch: false,
                status: 'MISMATCH_REJECTED',
                deviceSerial: item.serialNumber,
                deviceId: item.deviceId,
                cartonId: carton.id,
                rejectionReason: `Carton '${carton.cartonCode}' capacity reached (${carton.packedCount}/${carton.targetCapacity}).`,
                errorCode: 'CARTON_FULL',
                verifiedAt: now
            });
        }
    }
    // 8. Verification Success
    const result = {
        schemaVersion: 1,
        success: true,
        isMatch: true,
        status: 'MATCH_APPROVED',
        deviceSerial: item.serialNumber,
        deviceId: item.deviceId,
        boxToken: token,
        productVariantId: item.productVariantId,
        hardwareRevision: item.hardwareRevision,
        firmwareFamily: item.firmwareFamily,
        cartonId: carton?.id,
        verifiedAt: now
    };
    (0, generator_1.assertNoSecretsInRecord)(result);
    return exports.DualScanVerificationResultSchema.parse(result);
}
//# sourceMappingURL=index.js.map