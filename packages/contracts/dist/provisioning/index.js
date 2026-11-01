"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.BenchProvisioningTraceabilityRecordSchema = exports.BenchProvisioningRequestSchema = exports.BenchArtifactValidationResultSchema = exports.BenchArtifactValidationRequestSchema = exports.Esp32IdentificationSchema = exports.SerialDeviceInfoSchema = exports.SerialPortStatusSchema = exports.BenchDeviceStateSchema = exports.ProvisioningErrorCodeSchema = void 0;
exports.validateBenchArtifact = validateBenchArtifact;
const zod_1 = require("zod");
const common_1 = require("../common");
const firmware_1 = require("../firmware");
// ── 1. Typed Error Codes ─────────────────────────────────────────────
exports.ProvisioningErrorCodeSchema = zod_1.z.enum([
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
// ── 2. Bench Device Lifecycle States ───────────────────────────────────
exports.BenchDeviceStateSchema = zod_1.z.enum([
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
// ── 3. Serial Port Metadata ──────────────────────────────────────────
exports.SerialPortStatusSchema = zod_1.z.enum([
    'AVAILABLE',
    'BUSY',
    'DISCONNECTED',
    'INACCESSIBLE'
]);
exports.SerialDeviceInfoSchema = zod_1.z.object({
    portName: zod_1.z.string().min(1),
    vendorId: zod_1.z.string().optional(),
    productId: zod_1.z.string().optional(),
    description: zod_1.z.string().optional(),
    status: exports.SerialPortStatusSchema.default('AVAILABLE'),
    isEspCandidate: zod_1.z.boolean().default(false),
    manufacturer: zod_1.z.string().optional(),
    chipFamily: zod_1.z.string().optional(),
});
// ── 4. ESP32 Device Identification ────────────────────────────────────
exports.Esp32IdentificationSchema = zod_1.z.object({
    port: zod_1.z.string().min(1),
    chipName: zod_1.z.string().min(1),
    chipFamily: zod_1.z.string().min(1),
    macAddress: zod_1.z.string().optional(),
    detectedTarget: zod_1.z.string().optional(),
    connectionStatus: zod_1.z.enum(['CONNECTED', 'DISCONNECTED', 'BOOTLOADER', 'UNKNOWN']),
    flashSizeBytes: zod_1.z.number().int().positive().optional(),
    features: zod_1.z.array(zod_1.z.string()).default([]),
    currentFirmware: zod_1.z.object({
        version: zod_1.z.string().optional(),
        productVariantId: zod_1.z.string().optional()
    }).optional()
});
// ── 5. Firmware Artifact Validation Gates ─────────────────────────────
exports.BenchArtifactValidationRequestSchema = zod_1.z.object({
    benchTestMode: zod_1.z.boolean().default(false),
    firmwareFamily: zod_1.z.string().min(1),
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    targetMcu: firmware_1.TargetMcuSchema,
    manifest: zod_1.z.any(), // FirmwareBuildManifest
    computedSha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
});
exports.BenchArtifactValidationResultSchema = zod_1.z.object({
    valid: zod_1.z.boolean(),
    errorCode: exports.ProvisioningErrorCodeSchema.optional(),
    message: zod_1.z.string(),
    firmwareFamily: zod_1.z.string().optional(),
    targetMcu: zod_1.z.string().optional(),
    idfTarget: zod_1.z.string().optional(),
    hardwareCompatible: zod_1.z.boolean().optional(),
    releaseEligible: zod_1.z.boolean().optional(),
    sha256Verified: zod_1.z.boolean().optional(),
    gateDetails: zod_1.z.array(zod_1.z.object({
        gate: zod_1.z.string(),
        passed: zod_1.z.boolean(),
        detail: zod_1.z.string()
    })).default([])
});
/**
 * Validates a firmware artifact against all production gating requirements.
 * Rejects mismatched SHA-256, invalid families, incompatible hardware, or unreleased status.
 */
function validateBenchArtifact(params) {
    const gates = [];
    const manifest = params.manifest;
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
    const appArtifact = manifest.artifacts?.find((a) => a.artifactType === 'APP_BIN');
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
    const isBenchTestBuild = manifest.buildProfile === 'debug' || manifest.buildProfile === 'profiling';
    const eligibility = (0, firmware_1.validateProductionReleaseFamily)(manifest.firmwareFamily);
    const benchFamilyAllowed = isBenchTestBuild && (0, firmware_1.isBenchTestFirmwareFamily)(manifest.firmwareFamily);
    if (!eligibility.valid && !benchFamilyAllowed && (manifest.buildProfile === 'release' || !manifest.buildProfile)) {
        gates.push({ gate: 'RELEASE_ELIGIBLE', passed: false, detail: eligibility.error || 'Family not eligible for production release' });
        return {
            valid: false,
            errorCode: 'ARTIFACT_NOT_RELEASE_ELIGIBLE',
            message: eligibility.error || 'Artifact firmware family is not eligible for release.',
            gateDetails: gates
        };
    }
    gates.push({
        gate: 'RELEASE_ELIGIBLE',
        passed: true,
        detail: benchFamilyAllowed
            ? `Bench-test family '${manifest.firmwareFamily}' permitted for debug/profiling validation only.`
            : `Family '${manifest.firmwareFamily}' is eligible.`
    });
    // Gate 4: Artifact Release Lifecycle State (Fail-Closed)
    const rawStatus = manifest.lifecycleStatus || manifest.status;
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
    const isReleased = rawStatus === 'RELEASED' || rawStatus === 'PUBLISHED';
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
    const allowedVariants = firmware_1.FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP[manifest.firmwareFamily]
        || (benchFamilyAllowed ? [params.productVariantId] : []);
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
    // Gate 7: Target MCU Architecture Match (Allows generic ESP32 / development prototype boards)
    const isTargetMatch = manifest.targetMcu === params.targetMcu;
    // Only the literal generic ESP32 target is a dev-board wildcard. Concrete
    // families such as esp32-c3 and esp32-s3 must still match exactly.
    const isPrototypeBoard = params.targetMcu === 'esp32' && (benchFamilyAllowed || params.benchTestMode);
    if (!isTargetMatch && !isPrototypeBoard) {
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
    gates.push({
        gate: 'TARGET_MCU_MATCH',
        passed: true,
        detail: isTargetMatch
            ? `Target MCU '${manifest.targetMcu}' matches.`
            : `Prototype/Dev board '${params.targetMcu}' permitted for bench testing (target: ${manifest.targetMcu})`
    });
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
exports.BenchProvisioningRequestSchema = zod_1.z.object({
    port: zod_1.z.string().min(1),
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareReleaseId: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    targetMcu: firmware_1.TargetMcuSchema,
    appBinPath: zod_1.z.string().min(1),
    computedSha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/),
    bootloaderPath: zod_1.z.string().optional(),
    partitionTablePath: zod_1.z.string().optional(),
    partitionsCsvPath: zod_1.z.string().optional(),
    manifestPath: zod_1.z.string().optional(),
    baudRate: zod_1.z.number().int().positive().default(115200),
    operatorUserId: zod_1.z.string().optional(),
    benchTestMode: zod_1.z.boolean().default(false)
});
/**
 * Structured Traceability Record.
 * MUST NEVER contain private keys, Wi-Fi credentials, or commissioning secrets!
 */
exports.BenchProvisioningTraceabilityRecordSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    traceId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    productVariantId: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareReleaseId: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    targetMcu: firmware_1.TargetMcuSchema,
    idfTarget: firmware_1.IdfTargetSchema,
    artifactSha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/),
    tlsCertFingerprint: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/),
    port: zod_1.z.string().min(1),
    flashStatus: zod_1.z.enum(['PASS', 'FAIL']),
    verificationStatus: zod_1.z.enum(['PASS', 'FAIL']),
    provisioningStatus: zod_1.z.enum(['PASS', 'FAIL']),
    provisionedAt: zod_1.z.string().datetime(),
    durationMs: zod_1.z.number().int().nonnegative(),
    operatorUserId: zod_1.z.string().optional(),
    benchTestMode: zod_1.z.boolean().default(false),
    notes: zod_1.z.string().optional()
});
//# sourceMappingURL=index.js.map