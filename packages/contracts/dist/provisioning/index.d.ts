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
export declare const ProvisioningErrorCodeSchema: z.ZodEnum<["DEVICE_NOT_FOUND", "DEVICE_BUSY", "DEVICE_DISCONNECTED", "DEVICE_IDENTIFICATION_FAILED", "ARTIFACT_NOT_FOUND", "ARTIFACT_HASH_MISMATCH", "FAMILY_MISMATCH", "TARGET_MISMATCH", "HARDWARE_INCOMPATIBLE", "ARTIFACT_NOT_RELEASE_ELIGIBLE", "ARTIFACT_LIFECYCLE_NOT_RELEASED", "FLASH_FAILED", "FLASH_VERIFY_FAILED", "PROVISIONING_FAILED", "SECURITY_VALIDATION_FAILED"]>;
export type ProvisioningErrorCode = z.infer<typeof ProvisioningErrorCodeSchema>;
export declare const BenchDeviceStateSchema: z.ZodEnum<["NO_DEVICE_DETECTED", "DEVICE_DETECTED", "DEVICE_IDENTIFIED", "DEVICE_READY_FOR_FLASHING", "FLASHING", "VERIFICATION", "PROVISIONING", "COMPLETED", "FAILED"]>;
export type BenchDeviceState = z.infer<typeof BenchDeviceStateSchema>;
export declare const SerialPortStatusSchema: z.ZodEnum<["AVAILABLE", "BUSY", "DISCONNECTED", "INACCESSIBLE"]>;
export type SerialPortStatus = z.infer<typeof SerialPortStatusSchema>;
export declare const SerialDeviceInfoSchema: z.ZodObject<{
    portName: z.ZodString;
    vendorId: z.ZodOptional<z.ZodString>;
    productId: z.ZodOptional<z.ZodString>;
    description: z.ZodOptional<z.ZodString>;
    status: z.ZodDefault<z.ZodEnum<["AVAILABLE", "BUSY", "DISCONNECTED", "INACCESSIBLE"]>>;
    isEspCandidate: z.ZodDefault<z.ZodBoolean>;
    manufacturer: z.ZodOptional<z.ZodString>;
    chipFamily: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "AVAILABLE" | "BUSY" | "DISCONNECTED" | "INACCESSIBLE";
    portName: string;
    isEspCandidate: boolean;
    productId?: string | undefined;
    description?: string | undefined;
    manufacturer?: string | undefined;
    vendorId?: string | undefined;
    chipFamily?: string | undefined;
}, {
    portName: string;
    status?: "AVAILABLE" | "BUSY" | "DISCONNECTED" | "INACCESSIBLE" | undefined;
    productId?: string | undefined;
    description?: string | undefined;
    manufacturer?: string | undefined;
    vendorId?: string | undefined;
    isEspCandidate?: boolean | undefined;
    chipFamily?: string | undefined;
}>;
export type SerialDeviceInfo = z.infer<typeof SerialDeviceInfoSchema>;
export declare const Esp32IdentificationSchema: z.ZodObject<{
    port: z.ZodString;
    chipName: z.ZodString;
    chipFamily: z.ZodString;
    macAddress: z.ZodOptional<z.ZodString>;
    detectedTarget: z.ZodOptional<z.ZodString>;
    connectionStatus: z.ZodEnum<["CONNECTED", "DISCONNECTED", "BOOTLOADER", "UNKNOWN"]>;
    flashSizeBytes: z.ZodOptional<z.ZodNumber>;
    features: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    currentFirmware: z.ZodOptional<z.ZodObject<{
        version: z.ZodOptional<z.ZodString>;
        productVariantId: z.ZodOptional<z.ZodString>;
    }, "strip", z.ZodTypeAny, {
        version?: string | undefined;
        productVariantId?: string | undefined;
    }, {
        version?: string | undefined;
        productVariantId?: string | undefined;
    }>>;
}, "strip", z.ZodTypeAny, {
    chipFamily: string;
    port: string;
    chipName: string;
    connectionStatus: "BOOTLOADER" | "DISCONNECTED" | "CONNECTED" | "UNKNOWN";
    features: string[];
    flashSizeBytes?: number | undefined;
    macAddress?: string | undefined;
    detectedTarget?: string | undefined;
    currentFirmware?: {
        version?: string | undefined;
        productVariantId?: string | undefined;
    } | undefined;
}, {
    chipFamily: string;
    port: string;
    chipName: string;
    connectionStatus: "BOOTLOADER" | "DISCONNECTED" | "CONNECTED" | "UNKNOWN";
    flashSizeBytes?: number | undefined;
    macAddress?: string | undefined;
    detectedTarget?: string | undefined;
    features?: string[] | undefined;
    currentFirmware?: {
        version?: string | undefined;
        productVariantId?: string | undefined;
    } | undefined;
}>;
export type Esp32Identification = z.infer<typeof Esp32IdentificationSchema>;
export declare const BenchArtifactValidationRequestSchema: z.ZodObject<{
    benchTestMode: z.ZodDefault<z.ZodBoolean>;
    firmwareFamily: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    targetMcu: z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>;
    manifest: z.ZodAny;
    computedSha256: z.ZodString;
}, "strip", z.ZodTypeAny, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    benchTestMode: boolean;
    computedSha256: string;
    manifest?: any;
}, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    computedSha256: string;
    manifest?: any;
    benchTestMode?: boolean | undefined;
}>;
export type BenchArtifactValidationRequest = z.infer<typeof BenchArtifactValidationRequestSchema>;
export declare const BenchArtifactValidationResultSchema: z.ZodObject<{
    valid: z.ZodBoolean;
    errorCode: z.ZodOptional<z.ZodEnum<["DEVICE_NOT_FOUND", "DEVICE_BUSY", "DEVICE_DISCONNECTED", "DEVICE_IDENTIFICATION_FAILED", "ARTIFACT_NOT_FOUND", "ARTIFACT_HASH_MISMATCH", "FAMILY_MISMATCH", "TARGET_MISMATCH", "HARDWARE_INCOMPATIBLE", "ARTIFACT_NOT_RELEASE_ELIGIBLE", "ARTIFACT_LIFECYCLE_NOT_RELEASED", "FLASH_FAILED", "FLASH_VERIFY_FAILED", "PROVISIONING_FAILED", "SECURITY_VALIDATION_FAILED"]>>;
    message: z.ZodString;
    firmwareFamily: z.ZodOptional<z.ZodString>;
    targetMcu: z.ZodOptional<z.ZodString>;
    idfTarget: z.ZodOptional<z.ZodString>;
    hardwareCompatible: z.ZodOptional<z.ZodBoolean>;
    releaseEligible: z.ZodOptional<z.ZodBoolean>;
    sha256Verified: z.ZodOptional<z.ZodBoolean>;
    gateDetails: z.ZodDefault<z.ZodArray<z.ZodObject<{
        gate: z.ZodString;
        passed: z.ZodBoolean;
        detail: z.ZodString;
    }, "strip", z.ZodTypeAny, {
        gate: string;
        passed: boolean;
        detail: string;
    }, {
        gate: string;
        passed: boolean;
        detail: string;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    message: string;
    valid: boolean;
    gateDetails: {
        gate: string;
        passed: boolean;
        detail: string;
    }[];
    firmwareFamily?: string | undefined;
    targetMcu?: string | undefined;
    idfTarget?: string | undefined;
    errorCode?: "DEVICE_NOT_FOUND" | "DEVICE_BUSY" | "DEVICE_DISCONNECTED" | "DEVICE_IDENTIFICATION_FAILED" | "ARTIFACT_NOT_FOUND" | "ARTIFACT_HASH_MISMATCH" | "FAMILY_MISMATCH" | "TARGET_MISMATCH" | "HARDWARE_INCOMPATIBLE" | "ARTIFACT_NOT_RELEASE_ELIGIBLE" | "ARTIFACT_LIFECYCLE_NOT_RELEASED" | "FLASH_FAILED" | "FLASH_VERIFY_FAILED" | "PROVISIONING_FAILED" | "SECURITY_VALIDATION_FAILED" | undefined;
    hardwareCompatible?: boolean | undefined;
    releaseEligible?: boolean | undefined;
    sha256Verified?: boolean | undefined;
}, {
    message: string;
    valid: boolean;
    firmwareFamily?: string | undefined;
    targetMcu?: string | undefined;
    idfTarget?: string | undefined;
    errorCode?: "DEVICE_NOT_FOUND" | "DEVICE_BUSY" | "DEVICE_DISCONNECTED" | "DEVICE_IDENTIFICATION_FAILED" | "ARTIFACT_NOT_FOUND" | "ARTIFACT_HASH_MISMATCH" | "FAMILY_MISMATCH" | "TARGET_MISMATCH" | "HARDWARE_INCOMPATIBLE" | "ARTIFACT_NOT_RELEASE_ELIGIBLE" | "ARTIFACT_LIFECYCLE_NOT_RELEASED" | "FLASH_FAILED" | "FLASH_VERIFY_FAILED" | "PROVISIONING_FAILED" | "SECURITY_VALIDATION_FAILED" | undefined;
    hardwareCompatible?: boolean | undefined;
    releaseEligible?: boolean | undefined;
    sha256Verified?: boolean | undefined;
    gateDetails?: {
        gate: string;
        passed: boolean;
        detail: string;
    }[] | undefined;
}>;
export type BenchArtifactValidationResult = z.infer<typeof BenchArtifactValidationResultSchema>;
/**
 * Validates a firmware artifact against all production gating requirements.
 * Rejects mismatched SHA-256, invalid families, incompatible hardware, or unreleased status.
 */
export declare function validateBenchArtifact(params: BenchArtifactValidationRequest): BenchArtifactValidationResult;
export declare const BenchProvisioningRequestSchema: z.ZodObject<{
    port: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    firmwareFamily: z.ZodString;
    firmwareReleaseId: z.ZodString;
    firmwareVersion: z.ZodString;
    targetMcu: z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>;
    appBinPath: z.ZodString;
    computedSha256: z.ZodString;
    bootloaderPath: z.ZodOptional<z.ZodString>;
    partitionTablePath: z.ZodOptional<z.ZodString>;
    partitionsCsvPath: z.ZodOptional<z.ZodString>;
    manifestPath: z.ZodOptional<z.ZodString>;
    baudRate: z.ZodDefault<z.ZodNumber>;
    operatorUserId: z.ZodOptional<z.ZodString>;
    benchTestMode: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    firmwareReleaseId: string;
    firmwareVersion: string;
    port: string;
    benchTestMode: boolean;
    computedSha256: string;
    appBinPath: string;
    baudRate: number;
    operatorUserId?: string | undefined;
    bootloaderPath?: string | undefined;
    partitionTablePath?: string | undefined;
    partitionsCsvPath?: string | undefined;
    manifestPath?: string | undefined;
}, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    firmwareReleaseId: string;
    firmwareVersion: string;
    port: string;
    computedSha256: string;
    appBinPath: string;
    operatorUserId?: string | undefined;
    benchTestMode?: boolean | undefined;
    bootloaderPath?: string | undefined;
    partitionTablePath?: string | undefined;
    partitionsCsvPath?: string | undefined;
    manifestPath?: string | undefined;
    baudRate?: number | undefined;
}>;
export type BenchProvisioningRequest = z.infer<typeof BenchProvisioningRequestSchema>;
/**
 * Structured Traceability Record.
 * MUST NEVER contain private keys, Wi-Fi credentials, or commissioning secrets!
 */
export declare const BenchProvisioningTraceabilityRecordSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodDefault<z.ZodNumber>>;
    traceId: z.ZodString;
    deviceId: z.ZodString;
    serialNumber: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    firmwareFamily: z.ZodString;
    firmwareReleaseId: z.ZodString;
    firmwareVersion: z.ZodString;
    targetMcu: z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>;
    idfTarget: z.ZodEnum<["esp32c6", "esp32s3", "esp32", "esp32c3"]>;
    artifactSha256: z.ZodString;
    tlsCertFingerprint: z.ZodString;
    port: z.ZodString;
    flashStatus: z.ZodEnum<["PASS", "FAIL"]>;
    verificationStatus: z.ZodEnum<["PASS", "FAIL"]>;
    provisioningStatus: z.ZodEnum<["PASS", "FAIL"]>;
    provisionedAt: z.ZodString;
    durationMs: z.ZodNumber;
    operatorUserId: z.ZodOptional<z.ZodString>;
    benchTestMode: z.ZodDefault<z.ZodBoolean>;
    notes: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    firmwareReleaseId: string;
    idfTarget: "esp32" | "esp32c6" | "esp32s3" | "esp32c3";
    deviceId: string;
    serialNumber: string;
    firmwareVersion: string;
    traceId: string;
    port: string;
    benchTestMode: boolean;
    artifactSha256: string;
    tlsCertFingerprint: string;
    flashStatus: "PASS" | "FAIL";
    verificationStatus: "PASS" | "FAIL";
    provisioningStatus: "PASS" | "FAIL";
    provisionedAt: string;
    durationMs: number;
    notes?: string | undefined;
    operatorUserId?: string | undefined;
}, {
    firmwareFamily: string;
    productVariantId: string;
    hardwareRevision: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    firmwareReleaseId: string;
    idfTarget: "esp32" | "esp32c6" | "esp32s3" | "esp32c3";
    deviceId: string;
    serialNumber: string;
    firmwareVersion: string;
    traceId: string;
    port: string;
    artifactSha256: string;
    tlsCertFingerprint: string;
    flashStatus: "PASS" | "FAIL";
    verificationStatus: "PASS" | "FAIL";
    provisioningStatus: "PASS" | "FAIL";
    provisionedAt: string;
    durationMs: number;
    schemaVersion?: number | undefined;
    notes?: string | undefined;
    operatorUserId?: string | undefined;
    benchTestMode?: boolean | undefined;
}>;
export type BenchProvisioningTraceabilityRecord = z.infer<typeof BenchProvisioningTraceabilityRecordSchema>;
//# sourceMappingURL=index.d.ts.map