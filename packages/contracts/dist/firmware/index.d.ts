import { z } from 'zod';
export declare const ReleaseStatusSchema: z.ZodEnum<["ALPHA", "BETA", "RELEASE_CANDIDATE", "PRODUCTION_READY", "REVOKED"]>;
export type ReleaseStatus = z.infer<typeof ReleaseStatusSchema>;
export declare const FirmwareArtifactMetadataSchema: z.ZodObject<{
    fileName: z.ZodString;
    artifactType: z.ZodEnum<["APP_BIN", "BOOTLOADER", "PARTITION_TABLE", "ELF", "MAP", "FACTORY_NVS"]>;
    fileSizeBytes: z.ZodNumber;
    sha256: z.ZodString;
    s3Key: z.ZodString;
    downloadUrl: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    fileName: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileSizeBytes: number;
    sha256: string;
    s3Key: string;
    downloadUrl?: string | undefined;
}, {
    fileName: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileSizeBytes: number;
    sha256: string;
    s3Key: string;
    downloadUrl?: string | undefined;
}>;
export type FirmwareArtifactMetadata = z.infer<typeof FirmwareArtifactMetadataSchema>;
export declare const OtaManifestSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    releaseId: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevision: z.ZodString;
    version: z.ZodString;
    minFirmwareVersion: z.ZodString;
    binarySizeBytes: z.ZodNumber;
    sha256: z.ZodString;
    ed25519Signature: z.ZodString;
    downloadUrl: z.ZodString;
    releaseNotes: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    version: string;
    createdAt: string;
    productVariantId: string;
    minFirmwareVersion: string;
    sha256: string;
    downloadUrl: string;
    releaseId: string;
    hardwareRevision: string;
    binarySizeBytes: number;
    ed25519Signature: string;
    releaseNotes?: string | undefined;
}, {
    version: string;
    createdAt: string;
    productVariantId: string;
    minFirmwareVersion: string;
    sha256: string;
    downloadUrl: string;
    releaseId: string;
    hardwareRevision: string;
    binarySizeBytes: number;
    ed25519Signature: string;
    schemaVersion?: number | undefined;
    releaseNotes?: string | undefined;
}>;
export type OtaManifest = z.infer<typeof OtaManifestSchema>;
export declare const FirmwareReleaseSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    releaseId: z.ZodString;
    firmwareFamily: z.ZodString;
    version: z.ZodString;
    gitCommitSha: z.ZodString;
    gitBranch: z.ZodDefault<z.ZodString>;
    artifacts: z.ZodArray<z.ZodObject<{
        fileName: z.ZodString;
        artifactType: z.ZodEnum<["APP_BIN", "BOOTLOADER", "PARTITION_TABLE", "ELF", "MAP", "FACTORY_NVS"]>;
        fileSizeBytes: z.ZodNumber;
        sha256: z.ZodString;
        s3Key: z.ZodString;
        downloadUrl: z.ZodOptional<z.ZodString>;
    }, "strip", z.ZodTypeAny, {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        s3Key: string;
        downloadUrl?: string | undefined;
    }, {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        s3Key: string;
        downloadUrl?: string | undefined;
    }>, "many">;
    manifest: z.ZodObject<{
        schemaVersion: z.ZodDefault<z.ZodNumber>;
        releaseId: z.ZodString;
        productVariantId: z.ZodString;
        hardwareRevision: z.ZodString;
        version: z.ZodString;
        minFirmwareVersion: z.ZodString;
        binarySizeBytes: z.ZodNumber;
        sha256: z.ZodString;
        ed25519Signature: z.ZodString;
        downloadUrl: z.ZodString;
        releaseNotes: z.ZodOptional<z.ZodString>;
        createdAt: z.ZodString;
    }, "strip", z.ZodTypeAny, {
        schemaVersion: number;
        version: string;
        createdAt: string;
        productVariantId: string;
        minFirmwareVersion: string;
        sha256: string;
        downloadUrl: string;
        releaseId: string;
        hardwareRevision: string;
        binarySizeBytes: number;
        ed25519Signature: string;
        releaseNotes?: string | undefined;
    }, {
        version: string;
        createdAt: string;
        productVariantId: string;
        minFirmwareVersion: string;
        sha256: string;
        downloadUrl: string;
        releaseId: string;
        hardwareRevision: string;
        binarySizeBytes: number;
        ed25519Signature: string;
        schemaVersion?: number | undefined;
        releaseNotes?: string | undefined;
    }>;
    status: z.ZodDefault<z.ZodEnum<["ALPHA", "BETA", "RELEASE_CANDIDATE", "PRODUCTION_READY", "REVOKED"]>>;
    approvedByUserId: z.ZodOptional<z.ZodString>;
    approvedAt: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "ALPHA" | "BETA" | "RELEASE_CANDIDATE" | "PRODUCTION_READY" | "REVOKED";
    schemaVersion: number;
    firmwareFamily: string;
    version: string;
    createdAt: string;
    releaseId: string;
    gitCommitSha: string;
    gitBranch: string;
    artifacts: {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        s3Key: string;
        downloadUrl?: string | undefined;
    }[];
    manifest: {
        schemaVersion: number;
        version: string;
        createdAt: string;
        productVariantId: string;
        minFirmwareVersion: string;
        sha256: string;
        downloadUrl: string;
        releaseId: string;
        hardwareRevision: string;
        binarySizeBytes: number;
        ed25519Signature: string;
        releaseNotes?: string | undefined;
    };
    approvedByUserId?: string | undefined;
    approvedAt?: string | undefined;
}, {
    firmwareFamily: string;
    version: string;
    createdAt: string;
    releaseId: string;
    gitCommitSha: string;
    artifacts: {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        s3Key: string;
        downloadUrl?: string | undefined;
    }[];
    manifest: {
        version: string;
        createdAt: string;
        productVariantId: string;
        minFirmwareVersion: string;
        sha256: string;
        downloadUrl: string;
        releaseId: string;
        hardwareRevision: string;
        binarySizeBytes: number;
        ed25519Signature: string;
        schemaVersion?: number | undefined;
        releaseNotes?: string | undefined;
    };
    status?: "ALPHA" | "BETA" | "RELEASE_CANDIDATE" | "PRODUCTION_READY" | "REVOKED" | undefined;
    schemaVersion?: number | undefined;
    gitBranch?: string | undefined;
    approvedByUserId?: string | undefined;
    approvedAt?: string | undefined;
}>;
export type FirmwareRelease = z.infer<typeof FirmwareReleaseSchema>;
export declare const FirmwareCompatibilityMatrixSchema: z.ZodObject<{
    firmwareFamily: z.ZodString;
    version: z.ZodString;
    compatibleHardwareRevisions: z.ZodArray<z.ZodString, "many">;
    breakingChanges: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    updatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    firmwareFamily: string;
    version: string;
    compatibleHardwareRevisions: string[];
    breakingChanges: string[];
    updatedAt: string;
}, {
    firmwareFamily: string;
    version: string;
    compatibleHardwareRevisions: string[];
    updatedAt: string;
    breakingChanges?: string[] | undefined;
}>;
export type FirmwareCompatibilityMatrix = z.infer<typeof FirmwareCompatibilityMatrixSchema>;
export declare const FirmwareReleaseLifecycleStatusSchema: z.ZodEnum<["DRAFT", "BUILDING", "VALIDATION", "APPROVED", "RELEASED", "DEPRECATED", "RETIRED", "REVOKED"]>;
export type FirmwareReleaseLifecycleStatus = z.infer<typeof FirmwareReleaseLifecycleStatusSchema>;
/**
 * Historical fleet / storage status compatibility mapping (Migration 011 / Phase 18 / Phase 41 <-> Part 07).
 * 'RELEASED' in the engineering release domain represents 'PUBLISHED' in historical fleet distribution.
 */
export declare const DOMAIN_TO_LEGACY_STATUS_MAP: Record<string, string>;
export declare const LEGACY_TO_DOMAIN_STATUS_MAP: Record<string, string>;
export declare function toLegacyReleaseStatus(domainStatus: string): string;
export declare function toDomainReleaseStatus(legacyStatus: string): string;
export declare const FirmwareFamilySchema: z.ZodObject<{
    id: z.ZodString;
    displayName: z.ZodString;
    targetMcu: z.ZodDefault<z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>>;
    defaultIdfVersion: z.ZodDefault<z.ZodString>;
    repositoryUrl: z.ZodOptional<z.ZodString>;
    description: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    displayName: string;
    id: string;
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    defaultIdfVersion: string;
    description?: string | undefined;
    repositoryUrl?: string | undefined;
}, {
    displayName: string;
    id: string;
    description?: string | undefined;
    targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
    defaultIdfVersion?: string | undefined;
    repositoryUrl?: string | undefined;
}>;
export type FirmwareFamily = z.infer<typeof FirmwareFamilySchema>;
export declare const FirmwareBuildMetadataSchema: z.ZodObject<{
    buildId: z.ZodString;
    firmwareFamilyId: z.ZodString;
    gitCommitSha: z.ZodString;
    gitBranch: z.ZodDefault<z.ZodString>;
    gitTag: z.ZodOptional<z.ZodString>;
    idfVersion: z.ZodDefault<z.ZodString>;
    buildProfile: z.ZodDefault<z.ZodEnum<["release", "debug", "profiling"]>>;
    toolchainInfo: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    builtBy: z.ZodOptional<z.ZodString>;
    builtAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    gitCommitSha: string;
    gitBranch: string;
    buildId: string;
    firmwareFamilyId: string;
    idfVersion: string;
    buildProfile: "release" | "debug" | "profiling";
    toolchainInfo: Record<string, unknown>;
    builtAt: string;
    gitTag?: string | undefined;
    builtBy?: string | undefined;
}, {
    gitCommitSha: string;
    buildId: string;
    firmwareFamilyId: string;
    builtAt: string;
    gitBranch?: string | undefined;
    gitTag?: string | undefined;
    idfVersion?: string | undefined;
    buildProfile?: "release" | "debug" | "profiling" | undefined;
    toolchainInfo?: Record<string, unknown> | undefined;
    builtBy?: string | undefined;
}>;
export type FirmwareBuildMetadata = z.infer<typeof FirmwareBuildMetadataSchema>;
export declare const FirmwareHardwareCompatibilitySchema: z.ZodObject<{
    firmwareReleaseId: z.ZodString;
    hardwareRevisionId: z.ZodString;
    minHardwareRevision: z.ZodOptional<z.ZodString>;
    maxHardwareRevision: z.ZodOptional<z.ZodString>;
    isVerified: z.ZodDefault<z.ZodBoolean>;
    verificationNotes: z.ZodOptional<z.ZodString>;
    verifiedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    verifiedAt: string;
    firmwareReleaseId: string;
    hardwareRevisionId: string;
    isVerified: boolean;
    minHardwareRevision?: string | undefined;
    maxHardwareRevision?: string | undefined;
    verificationNotes?: string | undefined;
}, {
    verifiedAt: string;
    firmwareReleaseId: string;
    hardwareRevisionId: string;
    minHardwareRevision?: string | undefined;
    maxHardwareRevision?: string | undefined;
    isVerified?: boolean | undefined;
    verificationNotes?: string | undefined;
}>;
export type FirmwareHardwareCompatibility = z.infer<typeof FirmwareHardwareCompatibilitySchema>;
export declare const TargetMcuSchema: z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>;
export type TargetMcu = z.infer<typeof TargetMcuSchema>;
export declare const CanonicalProductionMcuSchema: z.ZodEnum<["esp32-c6", "esp32-s3"]>;
export type CanonicalProductionMcu = z.infer<typeof CanonicalProductionMcuSchema>;
export declare const CANONICAL_PRODUCTION_MCUS: readonly ["esp32-c6", "esp32-s3"];
export declare const IdfTargetSchema: z.ZodEnum<["esp32c6", "esp32s3", "esp32", "esp32c3"]>;
export type IdfTarget = z.infer<typeof IdfTargetSchema>;
export declare const ToolchainSchema: z.ZodEnum<["riscv32-esp-elf", "xtensa-esp-elf"]>;
export type Toolchain = z.infer<typeof ToolchainSchema>;
export declare const MCU_TO_IDF_TARGET_MAP: Record<TargetMcu, IdfTarget>;
export declare const MCU_TO_TOOLCHAIN_MAP: Record<TargetMcu, Toolchain>;
export declare const DiscoveredArtifactSchema: z.ZodObject<{
    artifactType: z.ZodEnum<["APP_BIN", "BOOTLOADER", "PARTITION_TABLE", "ELF", "MAP", "FACTORY_NVS"]>;
    fileName: z.ZodString;
    fileSizeBytes: z.ZodNumber;
    sha256: z.ZodString;
    storagePath: z.ZodString;
    role: z.ZodOptional<z.ZodString>;
    targetMcu: z.ZodOptional<z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>>;
    idfTarget: z.ZodOptional<z.ZodEnum<["esp32c6", "esp32s3", "esp32", "esp32c3"]>>;
}, "strip", z.ZodTypeAny, {
    fileName: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileSizeBytes: number;
    sha256: string;
    storagePath: string;
    targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
    role?: string | undefined;
    idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
}, {
    fileName: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileSizeBytes: number;
    sha256: string;
    storagePath: string;
    targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
    role?: string | undefined;
    idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
}>;
export type DiscoveredArtifact = z.infer<typeof DiscoveredArtifactSchema>;
export declare const FirmwareBuildManifestSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodDefault<z.ZodNumber>>;
    buildId: z.ZodString;
    firmwareFamily: z.ZodString;
    productVariants: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    version: z.ZodString;
    gitCommitSha: z.ZodString;
    gitBranch: z.ZodDefault<z.ZodString>;
    gitTag: z.ZodOptional<z.ZodString>;
    targetMcu: z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>;
    idfTarget: z.ZodEnum<["esp32c6", "esp32s3", "esp32", "esp32c3"]>;
    toolchain: z.ZodEnum<["riscv32-esp-elf", "xtensa-esp-elf"]>;
    idfVersion: z.ZodDefault<z.ZodString>;
    buildProfile: z.ZodDefault<z.ZodEnum<["release", "debug", "profiling"]>>;
    lifecycleStatus: z.ZodEnum<["DRAFT", "BUILDING", "VALIDATION", "APPROVED", "RELEASED", "DEPRECATED", "RETIRED", "REVOKED"]>;
    compatibleHardwareRevisions: z.ZodArray<z.ZodString, "many">;
    artifacts: z.ZodArray<z.ZodObject<{
        artifactType: z.ZodEnum<["APP_BIN", "BOOTLOADER", "PARTITION_TABLE", "ELF", "MAP", "FACTORY_NVS"]>;
        fileName: z.ZodString;
        fileSizeBytes: z.ZodNumber;
        sha256: z.ZodString;
        storagePath: z.ZodString;
        role: z.ZodOptional<z.ZodString>;
        targetMcu: z.ZodOptional<z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>>;
        idfTarget: z.ZodOptional<z.ZodEnum<["esp32c6", "esp32s3", "esp32", "esp32c3"]>>;
    }, "strip", z.ZodTypeAny, {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        storagePath: string;
        targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
        role?: string | undefined;
        idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
    }, {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        storagePath: string;
        targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
        role?: string | undefined;
        idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
    }>, "many">;
    generatedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    firmwareFamily: string;
    version: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "RETIRED" | "VALIDATION" | "APPROVED" | "REVOKED" | "BUILDING" | "RELEASED";
    gitCommitSha: string;
    gitBranch: string;
    artifacts: {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        storagePath: string;
        targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
        role?: string | undefined;
        idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
    }[];
    compatibleHardwareRevisions: string[];
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    buildId: string;
    idfVersion: string;
    buildProfile: "release" | "debug" | "profiling";
    idfTarget: "esp32" | "esp32c6" | "esp32s3" | "esp32c3";
    productVariants: string[];
    toolchain: "riscv32-esp-elf" | "xtensa-esp-elf";
    generatedAt: string;
    gitTag?: string | undefined;
}, {
    firmwareFamily: string;
    version: string;
    lifecycleStatus: "DRAFT" | "DEPRECATED" | "RETIRED" | "VALIDATION" | "APPROVED" | "REVOKED" | "BUILDING" | "RELEASED";
    gitCommitSha: string;
    artifacts: {
        fileName: string;
        artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
        fileSizeBytes: number;
        sha256: string;
        storagePath: string;
        targetMcu?: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3" | undefined;
        role?: string | undefined;
        idfTarget?: "esp32" | "esp32c6" | "esp32s3" | "esp32c3" | undefined;
    }[];
    compatibleHardwareRevisions: string[];
    targetMcu: "esp32" | "esp32-c3" | "esp32-c6" | "esp32-s3";
    buildId: string;
    idfTarget: "esp32" | "esp32c6" | "esp32s3" | "esp32c3";
    toolchain: "riscv32-esp-elf" | "xtensa-esp-elf";
    generatedAt: string;
    schemaVersion?: number | undefined;
    gitBranch?: string | undefined;
    gitTag?: string | undefined;
    idfVersion?: string | undefined;
    buildProfile?: "release" | "debug" | "profiling" | undefined;
    productVariants?: string[] | undefined;
}>;
export type FirmwareBuildManifest = z.infer<typeof FirmwareBuildManifestSchema>;
/**
 * Canonical product variant mapping derived from authoritative product-definitions/
 */
export declare const FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP: Record<string, string[]>;
export type FirmwareImplementationStatus = 'IMPLEMENTED' | 'PLANNED';
export type FirmwareReleaseEligibility = 'PRODUCTION' | 'PROTOTYPE_ONLY' | 'NOT_ELIGIBLE';
export interface FirmwareFamilyMetadata {
    id: string;
    displayName: string;
    targetMcu: TargetMcu;
    idfTarget: IdfTarget;
    toolchain: Toolchain;
    implementationStatus: FirmwareImplementationStatus;
    releaseEligibility: FirmwareReleaseEligibility;
    projectPath?: string;
    productVariants: string[];
}
export declare const CANONICAL_FIRMWARE_FAMILIES: Record<string, FirmwareFamilyMetadata>;
export declare const PRODUCTION_RELEASE_ELIGIBLE_FAMILIES: string[];
/**
 * Validates whether a firmware family is currently eligible for an official production release.
 * Returns valid: false with an explicit error message if the family is unknown, planned, or prototype-only.
 */
export declare function validateProductionReleaseFamily(family: string): {
    valid: boolean;
    error?: string;
    metadata?: FirmwareFamilyMetadata;
};
/** Bench-only family names for dev kits and generic bring-up firmware. */
export declare function isBenchTestFirmwareFamily(family: string): boolean;
/**
 * Parses release git tags into firmware family and semantic version.
 * Supports:
 *  - Family-scoped tags: <family>@v<version> (e.g. 'esp32c6-switch-platform@v1.0.0')
 *  - Generic tags: v<version> (e.g. 'v1.0.0', defaults to primary production family 'esp32c6-switch-platform')
 */
export declare function parseReleaseTag(tag: string, defaultFamily?: string): {
    firmwareFamily: string;
    version: string;
    isFamilyScoped: boolean;
};
export declare const ReleaseReadinessGateSchema: z.ZodObject<{
    releaseId: z.ZodString;
    isReadyForApproval: z.ZodBoolean;
    evaluatedAt: z.ZodString;
    checks: z.ZodArray<z.ZodObject<{
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
    }>, "many">;
}, "strip", z.ZodTypeAny, {
    releaseId: string;
    isReadyForApproval: boolean;
    evaluatedAt: string;
    checks: {
        gate: string;
        passed: boolean;
        detail: string;
    }[];
}, {
    releaseId: string;
    isReadyForApproval: boolean;
    evaluatedAt: string;
    checks: {
        gate: string;
        passed: boolean;
        detail: string;
    }[];
}>;
export type ReleaseReadinessGate = z.infer<typeof ReleaseReadinessGateSchema>;
//# sourceMappingURL=index.d.ts.map