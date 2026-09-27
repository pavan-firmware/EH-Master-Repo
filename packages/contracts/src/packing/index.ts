import { z } from 'zod';
import { SchemaVersionSchema, SerialNumberSchema, HardwareRevisionCodeSchema } from '../common';
import { OpaqueQrTokenSchema, QrUriSchema } from '../qr';
import { BenchProvisioningTraceabilityRecordSchema } from '../provisioning';
import { CANONICAL_APPROVED_VARIANTS, isCanonicalProductHardwareSupported, getCanonicalProductDefinition } from '../product';
import { assertNoSecretsInRecord } from '../qr/generator';

// ── 1. Manufacturing Inventory State & Lifecycle ───────────────────────

export const InventoryStatusSchema = z.enum([
  'PROVISIONED',
  'VERIFIED',
  'PACKING',
  'PACKED',
  'QUARANTINED'
]);
export type InventoryStatus = z.infer<typeof InventoryStatusSchema>;

export const CartonStatusSchema = z.enum([
  'OPEN',
  'FULL',
  'SEALED',
  'CANCELLED'
]);
export type CartonStatus = z.infer<typeof CartonStatusSchema>;

export const PackingErrorCodeSchema = z.enum([
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
export type PackingErrorCode = z.infer<typeof PackingErrorCodeSchema>;

// ── 2. Inventory Domain Models ─────────────────────────────────────────

export const InventoryItemSchema = z.object({
  id: z.string().uuid(),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareVersion: z.string().min(1),
  traceId: z.string().uuid(),
  status: InventoryStatusSchema.default('PROVISIONED'),
  cartonId: z.string().nullable().optional(),
  qrToken: OpaqueQrTokenSchema.nullable().optional(),
  qrUri: QrUriSchema.nullable().optional(),
  qcStatus: z.enum(['PASS', 'FAIL']).default('PASS'),
  registeredAt: z.string().datetime(),
  verifiedAt: z.string().datetime().nullable().optional(),
  packedAt: z.string().datetime().nullable().optional()
});
export type InventoryItem = z.infer<typeof InventoryItemSchema>;

export const PackagingCartonSchema = z.object({
  id: z.string().min(1),
  cartonCode: z.string().regex(/^CARTON-[A-Z0-9-]+$/, {
    message: 'Must be a valid carton code (e.g. CARTON-2026-SW3X-001)'
  }),
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  targetCapacity: z.number().int().positive().default(1),
  packedCount: z.number().int().nonnegative().default(0),
  status: CartonStatusSchema.default('OPEN'),
  sealedAt: z.string().datetime().nullable().optional(),
  operatorUserId: z.string().optional(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime()
});
export type PackagingCarton = z.infer<typeof PackagingCartonSchema>;

// ── 3. Scan & Verification Requests / Payloads ─────────────────────────

export const DeviceScanPayloadSchema = z.object({
  serialNumber: SerialNumberSchema,
  stationId: z.string().min(1),
  scannedAt: z.string().datetime()
});
export type DeviceScanPayload = z.infer<typeof DeviceScanPayloadSchema>;

export const BoxScanPayloadSchema = z.object({
  boxToken: OpaqueQrTokenSchema,
  stationId: z.string().min(1),
  scannedAt: z.string().datetime()
});
export type BoxScanPayload = z.infer<typeof BoxScanPayloadSchema>;

export const DualScanVerificationRequestSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  stationId: z.string().min(1),
  operatorUserId: z.string().optional(),
  deviceSerial: SerialNumberSchema,
  boxTokenOrUri: z.string().min(16),
  cartonId: z.string().optional(),
  requestedAt: z.string().datetime()
});
export type DualScanVerificationRequest = z.infer<typeof DualScanVerificationRequestSchema>;

export const VerificationStatusSchema = z.enum([
  'MATCH_APPROVED',
  'MISMATCH_REJECTED',
  'DEVICE_NOT_FOUND',
  'BOX_NOT_FOUND',
  'ALREADY_PACKED',
  'QC_NOT_PASSED'
]);
export type VerificationStatus = z.infer<typeof VerificationStatusSchema>;

export const DualScanVerificationResultSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  verificationId: z.string().uuid().optional(),
  success: z.boolean(),
  isMatch: z.boolean(),
  status: VerificationStatusSchema,
  deviceSerial: SerialNumberSchema,
  deviceId: z.string().uuid().optional(),
  boxToken: OpaqueQrTokenSchema.optional(),
  productVariantId: z.string().optional(),
  hardwareRevision: HardwareRevisionCodeSchema.optional(),
  firmwareFamily: z.string().optional(),
  cartonId: z.string().optional(),
  rejectionReason: z.string().optional(),
  errorCode: PackingErrorCodeSchema.optional(),
  verifiedAt: z.string().datetime()
}).refine(
  (data) => {
    if (data.success && data.isMatch) {
      return data.status === 'MATCH_APPROVED';
    }
    return data.status !== 'MATCH_APPROVED';
  },
  {
    message: 'Consistency violation: success and isMatch must correlate with status MATCH_APPROVED'
  }
);
export type DualScanVerificationResult = z.infer<typeof DualScanVerificationResultSchema>;

// ── 4. Registration & Packing Operations ───────────────────────────────

export const RegisterInventoryRequestSchema = z.object({
  traceabilityRecord: BenchProvisioningTraceabilityRecordSchema,
  stationId: z.string().min(1),
  qrToken: OpaqueQrTokenSchema.optional()
});
export type RegisterInventoryRequest = z.infer<typeof RegisterInventoryRequestSchema>;

export const RegisterInventoryResultSchema = z.object({
  success: z.boolean(),
  inventoryItem: InventoryItemSchema.optional(),
  errorCode: PackingErrorCodeSchema.optional(),
  errorMessage: z.string().optional(),
  registeredAt: z.string().datetime()
});
export type RegisterInventoryResult = z.infer<typeof RegisterInventoryResultSchema>;

export const CreateCartonRequestSchema = z.object({
  cartonCode: z.string().min(1),
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  targetCapacity: z.number().int().positive().default(1),
  operatorUserId: z.string().optional()
});
export type CreateCartonRequest = z.infer<typeof CreateCartonRequestSchema>;

export const CompletePackingRequestSchema = z.object({
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  cartonId: z.string().min(1),
  verificationId: z.string().uuid(),
  stationId: z.string().min(1),
  operatorUserId: z.string().optional(),
  notes: z.string().optional()
});
export type CompletePackingRequest = z.infer<typeof CompletePackingRequestSchema>;

export const PackagingRecordSchema = z.object({
  id: z.string().uuid(),
  traceId: z.string().uuid(),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareVersion: z.string().min(1),
  cartonId: z.string().min(1),
  verificationId: z.string().uuid(),
  stationId: z.string().min(1),
  operatorUserId: z.string().nullable().optional(),
  packedAt: z.string().datetime(),
  notes: z.string().nullable().optional()
});
export type PackagingRecord = z.infer<typeof PackagingRecordSchema>;

export const CompletePackingResultSchema = z.object({
  success: z.boolean(),
  packagingRecord: PackagingRecordSchema.optional(),
  inventoryItem: InventoryItemSchema.optional(),
  carton: PackagingCartonSchema.optional(),
  errorCode: PackingErrorCodeSchema.optional(),
  errorMessage: z.string().optional(),
  packedAt: z.string().datetime()
});
export type CompletePackingResult = z.infer<typeof CompletePackingResultSchema>;

const ALLOWED_STATE_TRANSITIONS: Record<InventoryStatus, readonly InventoryStatus[]> = {
  PROVISIONED: ['VERIFIED', 'PACKING', 'QUARANTINED'],
  VERIFIED: ['PACKING', 'PACKED', 'QUARANTINED'],
  PACKING: ['PACKED', 'VERIFIED', 'QUARANTINED'],
  PACKED: [], // Terminal packed state
  QUARANTINED: ['PROVISIONED', 'VERIFIED'] // Can only be re-bench tested
};

/**
 * Validates whether an inventory state transition is permitted.
 */
export function isValidInventoryStateTransition(from: InventoryStatus, to: InventoryStatus): boolean {
  if (from === to) return true; // Idempotent same-state is valid
  const allowed = ALLOWED_STATE_TRANSITIONS[from];
  return !!allowed && allowed.includes(to);
}

// ── 6. Domain Dual-Scan Comparison Validator ───────────────────────────

export interface EvaluateDualScanParams {
  item: InventoryItem;
  scannedTokenOrUri: string;
  carton?: PackagingCarton | null;
  stationId: string;
  operatorUserId?: string;
}

/**
 * Executes server-side Dual-Scan matching logic against canonical product, firmware,
 * hardware, and carton rules.
 */
export function evaluateDualScan(params: EvaluateDualScanParams): DualScanVerificationResult {
  const { item, scannedTokenOrUri, carton } = params;
  assertNoSecretsInRecord(item);

  const now = new Date().toISOString();


  // 1. Device must not already be packed
  if (item.status === 'PACKED') {
    return DualScanVerificationResultSchema.parse({
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
    return DualScanVerificationResultSchema.parse({
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

  const tokenParse = OpaqueQrTokenSchema.safeParse(token);
  if (!tokenParse.success) {
    return DualScanVerificationResultSchema.parse({
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
    return DualScanVerificationResultSchema.parse({
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
  if (!CANONICAL_APPROVED_VARIANTS.has(item.productVariantId)) {
    return DualScanVerificationResultSchema.parse({
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

  if (!isCanonicalProductHardwareSupported(item.productVariantId, item.hardwareRevision)) {
    return DualScanVerificationResultSchema.parse({
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
  const prodDef = getCanonicalProductDefinition(item.productVariantId);
  if (!prodDef || prodDef.firmwareFamily !== item.firmwareFamily) {
    return DualScanVerificationResultSchema.parse({
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
      return DualScanVerificationResultSchema.parse({
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
      return DualScanVerificationResultSchema.parse({
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
      return DualScanVerificationResultSchema.parse({
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
      return DualScanVerificationResultSchema.parse({
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
  const result: DualScanVerificationResult = {
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

  assertNoSecretsInRecord(result);
  return DualScanVerificationResultSchema.parse(result);
}
