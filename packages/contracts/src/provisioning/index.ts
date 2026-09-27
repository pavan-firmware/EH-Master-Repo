/**
 * EH Home Bench Provisioning & Device Flashing Contracts
 * 
 * Defines runtime Zod validation schemas and TypeScript types for:
 * - Serial device discovery and status
 * - ESP32 device identification
 * - Firmware artifact validation gates
 * - Controlled flasher parameters and progress
 * - Bench provisioning workflow states and typed error codes
 * - Traceability records (strictly excluding secret material)
 */

import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, SerialNumberSchema } from '../common';
import { TargetMcuSchema, IdfTargetSchema, FirmwareBuildManifest, FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP, validateProductionReleaseFamily } from '../firmware';

// ── 1. Typed Error Codes ─────────────────────────────────────────────

export const ProvisioningErrorCodeSchema = z.enum([
  'DEVICE_NOT_FOUND',
  'DEVICE_BUSY',
  'DEVICE_DISCONNECTED',
  'DEVICE_IDENTIFICATION_FAILED',
  'ARTIFACT_NOT_FOUND',
  'ARTIFACT_HASH_MISMATCH',
  'FAMILY_MISMATCH',
  'TARGET_MISMATCH',
  'HARDWARE_INCOMPATIBLE',
  'ARTIFACT_NOT_RELEASE_ELIGIBLE',
  'ARTIFACT_LIFECYCLE_NOT_RELEASED',
  'FLASH_FAILED',
  'FLASH_VERIFY_FAILED',
  'PROVISIONING_FAILED',
  'SECURITY_VALIDATION_FAILED'
]);
export type ProvisioningErrorCode = z.infer<typeof ProvisioningErrorCodeSchema>;

// ── 2. Bench Device Lifecycle States ───────────────────────────────────

export const BenchDeviceStateSchema = z.enum([
  'NO_DEVICE_DETECTED',
  'DEVICE_DETECTED',
  'DEVICE_IDENTIFIED',
  'DEVICE_READY_FOR_FLASHING',
  'FLASHING',
  'VERIFICATION',
  'PROVISIONING',
  'COMPLETED',
  'FAILED'
]);
export type BenchDeviceState = z.infer<typeof BenchDeviceStateSchema>;

// ── 3. Serial Port Metadata ──────────────────────────────────────────

export const SerialPortStatusSchema = z.enum([
  'AVAILABLE',
  'BUSY',
  'DISCONNECTED',
  'INACCESSIBLE'
]);
export type SerialPortStatus = z.infer<typeof SerialPortStatusSchema>;

export const SerialDeviceInfoSchema = z.object({
  portName: z.string().min(1),
  vendorId: z.string().optional(),
  productId: z.string().optional(),
  description: z.string().optional(),
  status: SerialPortStatusSchema.default('AVAILABLE'),
  isEspCandidate: z.boolean().default(false),
  manufacturer: z.string().optional(),
  chipFamily: z.string().optional(),
});
export type SerialDeviceInfo = z.infer<typeof SerialDeviceInfoSchema>;

// ── 4. ESP32 Device Identification ────────────────────────────────────

export const Esp32IdentificationSchema = z.object({
  port: z.string().min(1),
  chipName: z.string().min(1),
  chipFamily: z.string().min(1),
  macAddress: z.string().optional(),
  detectedTarget: z.string().optional(),
  connectionStatus: z.enum(['CONNECTED', 'DISCONNECTED', 'BOOTLOADER', 'UNKNOWN']),
  flashSizeBytes: z.number().int().positive().optional(),
  features: z.array(z.string()).default([]),
  currentFirmware: z.object({
    version: z.string().optional(),
    productVariantId: z.string().optional()
  }).optional()
});
export type Esp32Identification = z.infer<typeof Esp32IdentificationSchema>;

// ── 5. Firmware Artifact Validation Gates ─────────────────────────────

export const BenchArtifactValidationRequestSchema = z.object({
  firmwareFamily: z.string().min(1),
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  targetMcu: TargetMcuSchema,
  manifest: z.any(), // FirmwareBuildManifest
  computedSha256: z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
});
export type BenchArtifactValidationRequest = z.infer<typeof BenchArtifactValidationRequestSchema>;

export const BenchArtifactValidationResultSchema = z.object({
  valid: z.boolean(),
  errorCode: ProvisioningErrorCodeSchema.optional(),
  message: z.string(),
  firmwareFamily: z.string().optional(),
  targetMcu: z.string().optional(),
  idfTarget: z.string().optional(),
  hardwareCompatible: z.boolean().optional(),
  releaseEligible: z.boolean().optional(),
  sha256Verified: z.boolean().optional(),
  gateDetails: z.array(z.object({
    gate: z.string(),
    passed: z.boolean(),
    detail: z.string()
  })).default([])
});
export type BenchArtifactValidationResult = z.infer<typeof BenchArtifactValidationResultSchema>;

/**
 * Validates a firmware artifact against all production gating requirements.
 * Rejects mismatched SHA-256, invalid families, incompatible hardware, or unreleased status.
 */
export function validateBenchArtifact(
  params: BenchArtifactValidationRequest
): BenchArtifactValidationResult {
  const gates: { gate: string; passed: boolean; detail: string }[] = [];
  const manifest = params.manifest as FirmwareBuildManifest;

  if (!manifest || typeof manifest !== 'object') {
    return {
      valid: false,
      errorCode: 'ARTIFACT_NOT_FOUND',
      message: 'Firmware build manifest is missing or invalid.',
      gateDetails: [{ gate: 'MANIFEST_EXISTS', passed: false, detail: 'Manifest object is null or undefined' }]
    };
  }

  // Gate 1: Manifest Presence & Well-Formedness
  if (!manifest || typeof manifest !== 'object') {
    return {
      valid: false,
      errorCode: 'ARTIFACT_NOT_FOUND',
      message: 'Firmware build manifest is missing or invalid.',
      gateDetails: [{ gate: 'MANIFEST_EXISTS', passed: false, detail: 'Manifest object is null or undefined' }]
    };
  }
  gates.push({ gate: 'MANIFEST_EXISTS', passed: true, detail: 'Manifest loaded and parsed.' });

  // Gate 2: SHA-256 Checksum Verification
  const appArtifact = manifest.artifacts?.find((a: any) => a.artifactType === 'APP_BIN');
  const expectedSha256 = appArtifact?.sha256?.toLowerCase();
  const computedSha = params.computedSha256.toLowerCase();

  if (!expectedSha256 || expectedSha256 !== computedSha) {
    gates.push({
      gate: 'SHA256_VERIFICATION',
      passed: false,
      detail: `Checksum mismatch: expected ${expectedSha256 || 'none'}, computed ${computedSha}`
    });
    return {
      valid: false,
      errorCode: 'ARTIFACT_HASH_MISMATCH',
      message: `Artifact SHA-256 checksum verification failed. File integrity cannot be guaranteed.`,
      sha256Verified: false,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'SHA256_VERIFICATION', passed: true, detail: `SHA-256 verified (${computedSha.slice(0, 16)}...)` });

  // Gate 3: Firmware Family Release Eligibility
  const eligibility = validateProductionReleaseFamily(manifest.firmwareFamily);
  if (!eligibility.valid && (manifest.buildProfile === 'release' || !manifest.buildProfile)) {
    gates.push({ gate: 'RELEASE_ELIGIBLE', passed: false, detail: eligibility.error || 'Family not eligible for production release' });
    return {
      valid: false,
      errorCode: 'ARTIFACT_NOT_RELEASE_ELIGIBLE',
      message: eligibility.error || 'Artifact firmware family is not eligible for release.',
      gateDetails: gates
    };
  }
  gates.push({ gate: 'RELEASE_ELIGIBLE', passed: true, detail: `Family '${manifest.firmwareFamily}' is eligible.` });

  // Gate 4: Artifact Release Lifecycle State (Fail-Closed)
  const rawStatus = manifest.lifecycleStatus || (manifest as any).status;
  if (!rawStatus || typeof rawStatus !== 'string' || !rawStatus.trim()) {
    gates.push({
      gate: 'ARTIFACT_RELEASE_LIFECYCLE',
      passed: false,
      detail: 'Manifest is missing explicit lifecycleStatus; unreleased artifacts cannot be flashed to production hardware.'
    });
    return {
      valid: false,
      errorCode: 'ARTIFACT_LIFECYCLE_NOT_RELEASED',
      message: 'Firmware artifact release lifecycle status is missing or empty in manifest; explicit release authorization required.',
      gateDetails: gates
    };
  }

  const isReleased = rawStatus === 'RELEASED' || (rawStatus as string) === 'PUBLISHED';
  if (!isReleased) {
    gates.push({
      gate: 'ARTIFACT_RELEASE_LIFECYCLE',
      passed: false,
      detail: `Artifact release status '${rawStatus}' is not authorized for production flashing.`
    });
    return {
      valid: false,
      errorCode: 'ARTIFACT_LIFECYCLE_NOT_RELEASED',
      message: `Firmware artifact lifecycle state '${rawStatus}' is not authorized for production flashing (must be RELEASED).`,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'ARTIFACT_RELEASE_LIFECYCLE', passed: true, detail: `Artifact status '${rawStatus}' authorized for production.` });

  // Gate 5: Firmware Family Identity Match
  if (manifest.firmwareFamily !== params.firmwareFamily) {
    gates.push({
      gate: 'FAMILY_MATCH',
      passed: false,
      detail: `Family mismatch: manifest=${manifest.firmwareFamily}, requested=${params.firmwareFamily}`
    });
    return {
      valid: false,
      errorCode: 'FAMILY_MISMATCH',
      message: `Selected firmware family '${params.firmwareFamily}' does not match manifest family '${manifest.firmwareFamily}'.`,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'FAMILY_MATCH', passed: true, detail: `Family matches '${manifest.firmwareFamily}'` });

  // Gate 6: Product Variant Compatibility
  const allowedVariants = FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP[manifest.firmwareFamily] || [];
  if (!allowedVariants.includes(params.productVariantId)) {
    gates.push({
      gate: 'PRODUCT_VARIANT_COMPATIBILITY',
      passed: false,
      detail: `Variant '${params.productVariantId}' not supported by family '${manifest.firmwareFamily}'`
    });
    return {
      valid: false,
      errorCode: 'FAMILY_MISMATCH',
      message: `Product variant '${params.productVariantId}' is incompatible with firmware family '${manifest.firmwareFamily}'.`,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'PRODUCT_VARIANT_COMPATIBILITY', passed: true, detail: `Variant '${params.productVariantId}' supported.` });

  // Gate 7: Target MCU Architecture Match
  if (manifest.targetMcu !== params.targetMcu) {
    gates.push({
      gate: 'TARGET_MCU_MATCH',
      passed: false,
      detail: `Target mismatch: manifest=${manifest.targetMcu}, detected=${params.targetMcu}`
    });
    return {
      valid: false,
      errorCode: 'TARGET_MISMATCH',
      message: `Detected device MCU '${params.targetMcu}' does not match manifest target '${manifest.targetMcu}'.`,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'TARGET_MCU_MATCH', passed: true, detail: `Target MCU '${manifest.targetMcu}' matches.` });

  // Gate 8: Hardware Revision Compatibility
  const isHwCompatible = manifest.compatibleHardwareRevisions?.includes(params.hardwareRevision);
  if (!isHwCompatible) {
    gates.push({
      gate: 'HARDWARE_COMPATIBILITY',
      passed: false,
      detail: `Revision '${params.hardwareRevision}' not in [${manifest.compatibleHardwareRevisions?.join(', ')}]`
    });
    return {
      valid: false,
      errorCode: 'HARDWARE_INCOMPATIBLE',
      message: `Hardware revision '${params.hardwareRevision}' is not certified compatible with this firmware build.`,
      hardwareCompatible: false,
      gateDetails: gates
    };
  }
  gates.push({ gate: 'HARDWARE_COMPATIBILITY', passed: true, detail: `Hardware revision '${params.hardwareRevision}' certified compatible.` });

  return {
    valid: true,
    message: 'All firmware artifact validation gates passed successfully.',
    firmwareFamily: manifest.firmwareFamily,
    targetMcu: manifest.targetMcu,
    idfTarget: manifest.idfTarget,
    hardwareCompatible: true,
    releaseEligible: true,
    sha256Verified: true,
    gateDetails: gates
  };
}

// ── 6. Bench Provisioning Request & Traceability Record ────────────────

export const BenchProvisioningRequestSchema = z.object({
  port: z.string().min(1),
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareReleaseId: z.string().min(1),
  firmwareVersion: z.string().min(1),
  targetMcu: TargetMcuSchema,
  appBinPath: z.string().min(1),
  computedSha256: z.string().regex(/^[0-9a-fA-F]{64}$/),
  bootloaderPath: z.string().optional(),
  partitionTablePath: z.string().optional(),
  partitionsCsvPath: z.string().optional(),
  manifestPath: z.string().optional(),
  baudRate: z.number().int().positive().default(115200),
  operatorUserId: z.string().optional()
});
export type BenchProvisioningRequest = z.infer<typeof BenchProvisioningRequestSchema>;

/**
 * Structured Traceability Record.
 * MUST NEVER contain private keys, Wi-Fi credentials, or commissioning secrets!
 */
export const BenchProvisioningTraceabilityRecordSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  traceId: z.string().uuid(),
  deviceId: z.string().uuid(),
  serialNumber: SerialNumberSchema,
  productVariantId: z.string().min(1),
  hardwareRevision: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  firmwareReleaseId: z.string().min(1),
  firmwareVersion: z.string().min(1),
  targetMcu: TargetMcuSchema,
  idfTarget: IdfTargetSchema,
  artifactSha256: z.string().regex(/^[0-9a-fA-F]{64}$/),
  tlsCertFingerprint: z.string().regex(/^[0-9a-fA-F]{64}$/),
  port: z.string().min(1),
  flashStatus: z.enum(['PASS', 'FAIL']),
  verificationStatus: z.enum(['PASS', 'FAIL']),
  provisioningStatus: z.enum(['PASS', 'FAIL']),
  provisionedAt: z.string().datetime(),
  durationMs: z.number().int().nonnegative(),
  operatorUserId: z.string().optional(),
  notes: z.string().optional()
});
export type BenchProvisioningTraceabilityRecord = z.infer<typeof BenchProvisioningTraceabilityRecordSchema>;
