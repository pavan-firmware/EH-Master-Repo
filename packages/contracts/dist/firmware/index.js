"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReleaseReadinessGateSchema = exports.PRODUCTION_RELEASE_ELIGIBLE_FAMILIES = exports.CANONICAL_FIRMWARE_FAMILIES = exports.FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP = exports.FirmwareBuildManifestSchema = exports.DiscoveredArtifactSchema = exports.MCU_TO_TOOLCHAIN_MAP = exports.MCU_TO_IDF_TARGET_MAP = exports.ToolchainSchema = exports.IdfTargetSchema = exports.CANONICAL_PRODUCTION_MCUS = exports.CanonicalProductionMcuSchema = exports.TargetMcuSchema = exports.FirmwareHardwareCompatibilitySchema = exports.FirmwareBuildMetadataSchema = exports.FirmwareFamilySchema = exports.LEGACY_TO_DOMAIN_STATUS_MAP = exports.DOMAIN_TO_LEGACY_STATUS_MAP = exports.FirmwareReleaseLifecycleStatusSchema = exports.FirmwareCompatibilityMatrixSchema = exports.FirmwareReleaseSchema = exports.OtaManifestSchema = exports.FirmwareArtifactMetadataSchema = exports.ReleaseStatusSchema = void 0;
exports.toLegacyReleaseStatus = toLegacyReleaseStatus;
exports.toDomainReleaseStatus = toDomainReleaseStatus;
exports.validateProductionReleaseFamily = validateProductionReleaseFamily;
exports.isBenchTestFirmwareFamily = isBenchTestFirmwareFamily;
exports.parseReleaseTag = parseReleaseTag;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.ReleaseStatusSchema = zod_1.z.enum([
    'ALPHA',
    'BETA',
    'RELEASE_CANDIDATE',
    'PRODUCTION_READY',
    'REVOKED'
]);
exports.FirmwareArtifactMetadataSchema = zod_1.z.object({
    fileName: zod_1.z.string().min(1),
    artifactType: zod_1.z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
    fileSizeBytes: zod_1.z.number().int().positive(),
    sha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be a 64-char hex SHA-256' }),
    s3Key: zod_1.z.string().min(1),
    downloadUrl: zod_1.z.string().url().optional()
});
exports.OtaManifestSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    releaseId: zod_1.z.string().uuid(),
    productVariantId: zod_1.z.string().regex(/^eh-[a-z0-9-]+$/),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    version: common_1.SemanticVersionSchema,
    minFirmwareVersion: common_1.SemanticVersionSchema,
    binarySizeBytes: zod_1.z.number().int().min(1024),
    sha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/),
    ed25519Signature: zod_1.z.string().regex(/^[0-9a-fA-F]{128}$/),
    downloadUrl: zod_1.z.string().url(),
    releaseNotes: zod_1.z.string().optional(),
    createdAt: zod_1.z.string().datetime()
});
exports.FirmwareReleaseSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    releaseId: zod_1.z.string().uuid(),
    firmwareFamily: zod_1.z.string().min(1),
    version: common_1.SemanticVersionSchema,
    gitCommitSha: zod_1.z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be a 40-char git commit SHA' }),
    gitBranch: zod_1.z.string().default('main'),
    artifacts: zod_1.z.array(exports.FirmwareArtifactMetadataSchema).min(1),
    manifest: exports.OtaManifestSchema,
    status: exports.ReleaseStatusSchema.default('RELEASE_CANDIDATE'),
    approvedByUserId: zod_1.z.string().uuid().optional(),
    approvedAt: zod_1.z.string().datetime().optional(),
    createdAt: zod_1.z.string().datetime()
});
exports.FirmwareCompatibilityMatrixSchema = zod_1.z.object({
    firmwareFamily: zod_1.z.string().min(1),
    version: common_1.SemanticVersionSchema,
    compatibleHardwareRevisions: zod_1.z.array(common_1.HardwareRevisionCodeSchema).min(1),
    breakingChanges: zod_1.z.array(zod_1.z.string()).default([]),
    updatedAt: zod_1.z.string().datetime()
});
exports.FirmwareReleaseLifecycleStatusSchema = zod_1.z.enum([
    'DRAFT',
    'BUILDING',
    'VALIDATION',
    'APPROVED',
    'RELEASED',
    'DEPRECATED',
    'RETIRED',
    'REVOKED'
]);
/**
 * Historical fleet / storage status compatibility mapping (Migration 011 / Phase 18 / Phase 41 <-> Part 07).
 * 'RELEASED' in the engineering release domain represents 'PUBLISHED' in historical fleet distribution.
 */
exports.DOMAIN_TO_LEGACY_STATUS_MAP = {
    RELEASED: 'PUBLISHED',
    DRAFT: 'DRAFT',
    DEPRECATED: 'DEPRECATED',
    RETIRED: 'DEPRECATED',
    REVOKED: 'REVOKED',
};
exports.LEGACY_TO_DOMAIN_STATUS_MAP = {
    PUBLISHED: 'RELEASED',
    DRAFT: 'DRAFT',
    DEPRECATED: 'DEPRECATED',
    REVOKED: 'REVOKED',
};
function toLegacyReleaseStatus(domainStatus) {
    return exports.DOMAIN_TO_LEGACY_STATUS_MAP[domainStatus] || domainStatus;
}
function toDomainReleaseStatus(legacyStatus) {
    return exports.LEGACY_TO_DOMAIN_STATUS_MAP[legacyStatus] || legacyStatus;
}
exports.FirmwareFamilySchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    displayName: zod_1.z.string().min(1),
    targetMcu: zod_1.z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']).default('esp32-c6'),
    defaultIdfVersion: zod_1.z.string().default('v5.4.1'),
    repositoryUrl: zod_1.z.string().optional(),
    description: zod_1.z.string().optional()
});
exports.FirmwareBuildMetadataSchema = zod_1.z.object({
    buildId: zod_1.z.string(),
    firmwareFamilyId: zod_1.z.string(),
    gitCommitSha: zod_1.z.string().regex(/^[0-9a-fA-F]{40}$/),
    gitBranch: zod_1.z.string().default('main'),
    gitTag: zod_1.z.string().optional(),
    idfVersion: zod_1.z.string().default('v5.4.1'),
    buildProfile: zod_1.z.enum(['release', 'debug', 'profiling']).default('release'),
    toolchainInfo: zod_1.z.record(zod_1.z.unknown()).default({}),
    builtBy: zod_1.z.string().optional(),
    builtAt: zod_1.z.string().datetime()
});
exports.FirmwareHardwareCompatibilitySchema = zod_1.z.object({
    firmwareReleaseId: zod_1.z.string(),
    hardwareRevisionId: zod_1.z.string(),
    minHardwareRevision: zod_1.z.string().optional(),
    maxHardwareRevision: zod_1.z.string().optional(),
    isVerified: zod_1.z.boolean().default(true),
    verificationNotes: zod_1.z.string().optional(),
    verifiedAt: zod_1.z.string().datetime()
});
exports.TargetMcuSchema = zod_1.z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']);
exports.CanonicalProductionMcuSchema = zod_1.z.enum(['esp32-c6', 'esp32-s3']);
exports.CANONICAL_PRODUCTION_MCUS = ['esp32-c6', 'esp32-s3'];
exports.IdfTargetSchema = zod_1.z.enum(['esp32c6', 'esp32s3', 'esp32', 'esp32c3']);
exports.ToolchainSchema = zod_1.z.enum(['riscv32-esp-elf', 'xtensa-esp-elf']);
exports.MCU_TO_IDF_TARGET_MAP = {
    'esp32-c6': 'esp32c6',
    'esp32-s3': 'esp32s3',
    'esp32': 'esp32',
    'esp32-c3': 'esp32c3',
};
exports.MCU_TO_TOOLCHAIN_MAP = {
    'esp32-c6': 'riscv32-esp-elf',
    'esp32-s3': 'xtensa-esp-elf',
    'esp32': 'xtensa-esp-elf',
    'esp32-c3': 'riscv32-esp-elf',
};
exports.DiscoveredArtifactSchema = zod_1.z.object({
    artifactType: zod_1.z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
    fileName: zod_1.z.string().min(1),
    fileSizeBytes: zod_1.z.number().int().positive(),
    sha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
    storagePath: zod_1.z.string().min(1),
    role: zod_1.z.string().optional(),
    targetMcu: exports.TargetMcuSchema.optional(),
    idfTarget: exports.IdfTargetSchema.optional(),
});
exports.FirmwareBuildManifestSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    buildId: zod_1.z.string().uuid({ message: 'buildId must be an authoritative UUID' }),
    firmwareFamily: zod_1.z.string().min(1),
    productVariants: zod_1.z.array(zod_1.z.string().min(1)).default([]),
    version: common_1.SemanticVersionSchema,
    gitCommitSha: zod_1.z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
    gitBranch: zod_1.z.string().default('main'),
    gitTag: zod_1.z.string().optional(),
    targetMcu: exports.TargetMcuSchema,
    idfTarget: exports.IdfTargetSchema,
    toolchain: exports.ToolchainSchema,
    idfVersion: zod_1.z.string().default('v5.4.1'),
    buildProfile: zod_1.z.enum(['release', 'debug', 'profiling']).default('release'),
    lifecycleStatus: exports.FirmwareReleaseLifecycleStatusSchema,
    compatibleHardwareRevisions: zod_1.z.array(zod_1.z.string().min(1)).min(1),
    artifacts: zod_1.z.array(exports.DiscoveredArtifactSchema).min(1),
    generatedAt: zod_1.z.string().datetime(),
});
/**
 * Canonical product variant mapping derived from authoritative product-definitions/
 */
exports.FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP = {
    'esp32c6-switch-platform': ['eh-smart-switch-1x', 'eh-smart-switch-2x', 'eh-smart-switch-3x', 'eh-smart-switch-4x'],
    'esp32c6-socket-platform': ['eh-smart-socket-1x', 'eh-smart-socket-2x', 'eh-smart-socket-3x'],
    'esp32c6-fan-platform': ['eh-smart-fan-1x'],
    'esp32c6-light-platform': ['eh-smart-light-cct'],
    'esp32s3-hub-platform': ['eh-smart-hub-v1'],
    'esp32c6-sensor-platform': ['eh-sensor-node-v1'],
    'esp32-dev-platform': ['eh-smart-switch-dev', 'eh-smart-socket-dev'],
};
exports.CANONICAL_FIRMWARE_FAMILIES = {
    'esp32c6-switch-platform': {
        id: 'esp32c6-switch-platform',
        displayName: 'ESP32-C6 Smart Switch Platform',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        implementationStatus: 'IMPLEMENTED',
        releaseEligibility: 'PRODUCTION',
        projectPath: 'firmware/platforms/esp32/smart-switch-app',
        productVariants: ['eh-smart-switch-1x', 'eh-smart-switch-2x', 'eh-smart-switch-3x', 'eh-smart-switch-4x'],
    },
    'esp32c6-socket-platform': {
        id: 'esp32c6-socket-platform',
        displayName: 'ESP32-C6 Smart Socket Platform',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        implementationStatus: 'IMPLEMENTED',
        releaseEligibility: 'PRODUCTION',
        projectPath: 'firmware/platforms/esp32/smart-switch-app',
        productVariants: ['eh-smart-socket-1x', 'eh-smart-socket-2x', 'eh-smart-socket-3x'],
    },
    'esp32-dev-platform': {
        id: 'esp32-dev-platform',
        displayName: 'ESP32 DevKit WROOM Prototype Platform',
        targetMcu: 'esp32',
        idfTarget: 'esp32',
        toolchain: 'xtensa-esp-elf',
        implementationStatus: 'IMPLEMENTED',
        releaseEligibility: 'PROTOTYPE_ONLY',
        projectPath: 'firmware/platforms/esp32/smart-switch-app',
        productVariants: ['eh-smart-switch-dev', 'eh-smart-socket-dev'],
    },
    'esp32c6-fan-platform': {
        id: 'esp32c6-fan-platform',
        displayName: 'ESP32-C6 Smart Fan Platform',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        implementationStatus: 'PLANNED',
        releaseEligibility: 'NOT_ELIGIBLE',
        productVariants: ['eh-smart-fan-1x'],
    },
    'esp32c6-light-platform': {
        id: 'esp32c6-light-platform',
        displayName: 'ESP32-C6 Smart Light Platform',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        implementationStatus: 'PLANNED',
        releaseEligibility: 'NOT_ELIGIBLE',
        productVariants: ['eh-smart-light-cct'],
    },
    'esp32s3-hub-platform': {
        id: 'esp32s3-hub-platform',
        displayName: 'ESP32-S3 Smart Hub Gateway',
        targetMcu: 'esp32-s3',
        idfTarget: 'esp32s3',
        toolchain: 'xtensa-esp-elf',
        implementationStatus: 'PLANNED',
        releaseEligibility: 'NOT_ELIGIBLE',
        productVariants: ['eh-smart-hub-v1'],
    },
    'esp32c6-sensor-platform': {
        id: 'esp32c6-sensor-platform',
        displayName: 'ESP32-C6 Environmental Sensor Node',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        implementationStatus: 'PLANNED',
        releaseEligibility: 'NOT_ELIGIBLE',
        productVariants: ['eh-sensor-node-v1'],
    },
};
exports.PRODUCTION_RELEASE_ELIGIBLE_FAMILIES = Object.values(exports.CANONICAL_FIRMWARE_FAMILIES)
    .filter((f) => f.releaseEligibility === 'PRODUCTION')
    .map((f) => f.id);
/**
 * Validates whether a firmware family is currently eligible for an official production release.
 * Returns valid: false with an explicit error message if the family is unknown, planned, or prototype-only.
 */
function validateProductionReleaseFamily(family) {
    const meta = exports.CANONICAL_FIRMWARE_FAMILIES[family];
    if (!meta) {
        return {
            valid: false,
            error: `Firmware family '${family}' is not currently eligible for production release. Unknown firmware family.`,
        };
    }
    if (meta.implementationStatus !== 'IMPLEMENTED') {
        return {
            valid: false,
            error: `Firmware family '${family}' is not currently eligible for production release. Implementation status is PLANNED.`,
            metadata: meta,
        };
    }
    if (meta.releaseEligibility !== 'PRODUCTION') {
        return {
            valid: false,
            error: `Firmware family '${family}' is not currently eligible for production release. Classified as ${meta.releaseEligibility}.`,
            metadata: meta,
        };
    }
    return {
        valid: true,
        metadata: meta,
    };
}
/** Bench-only family names for dev kits and generic bring-up firmware. */
function isBenchTestFirmwareFamily(family) {
    if (!family || exports.CANONICAL_FIRMWARE_FAMILIES[family])
        return false;
    return /^[a-z0-9][a-z0-9_-]{0,63}$/.test(family);
}
/**
 * Parses release git tags into firmware family and semantic version.
 * Supports:
 *  - Family-scoped tags: <family>@v<version> (e.g. 'esp32c6-switch-platform@v1.0.0')
 *  - Generic tags: v<version> (e.g. 'v1.0.0', defaults to primary production family 'esp32c6-switch-platform')
 */
function parseReleaseTag(tag, defaultFamily = 'esp32c6-switch-platform') {
    if (tag.includes('@')) {
        const atIndex = tag.indexOf('@');
        const family = tag.substring(0, atIndex).trim();
        const rawVer = tag.substring(atIndex + 1).trim();
        const version = rawVer.startsWith('v') ? rawVer.slice(1) : rawVer;
        return { firmwareFamily: family || defaultFamily, version, isFamilyScoped: true };
    }
    const version = tag.startsWith('v') ? tag.slice(1) : tag;
    return { firmwareFamily: defaultFamily, version, isFamilyScoped: false };
}
exports.ReleaseReadinessGateSchema = zod_1.z.object({
    releaseId: zod_1.z.string().min(1),
    isReadyForApproval: zod_1.z.boolean(),
    evaluatedAt: zod_1.z.string().datetime(),
    checks: zod_1.z.array(zod_1.z.object({
        gate: zod_1.z.string(),
        passed: zod_1.z.boolean(),
        detail: zod_1.z.string(),
    })),
});
//# sourceMappingURL=index.js.map