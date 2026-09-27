import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, SemanticVersionSchema } from '../common';

export const ReleaseStatusSchema = z.enum([
  'ALPHA',
  'BETA',
  'RELEASE_CANDIDATE',
  'PRODUCTION_READY',
  'REVOKED'
]);
export type ReleaseStatus = z.infer<typeof ReleaseStatusSchema>;

export const FirmwareArtifactMetadataSchema = z.object({
  fileName: z.string().min(1),
  artifactType: z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
  fileSizeBytes: z.number().int().positive(),
  sha256: z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be a 64-char hex SHA-256' }),
  s3Key: z.string().min(1),
  downloadUrl: z.string().url().optional()
});
export type FirmwareArtifactMetadata = z.infer<typeof FirmwareArtifactMetadataSchema>;

export const OtaManifestSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  releaseId: z.string().uuid(),
  productVariantId: z.string().regex(/^eh-[a-z0-9-]+$/),
  hardwareRevision: HardwareRevisionCodeSchema,
  version: SemanticVersionSchema,
  minFirmwareVersion: SemanticVersionSchema,
  binarySizeBytes: z.number().int().min(1024),
  sha256: z.string().regex(/^[0-9a-fA-F]{64}$/),
  ed25519Signature: z.string().regex(/^[0-9a-fA-F]{128}$/),
  downloadUrl: z.string().url(),
  releaseNotes: z.string().optional(),
  createdAt: z.string().datetime()
});
export type OtaManifest = z.infer<typeof OtaManifestSchema>;

export const FirmwareReleaseSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  releaseId: z.string().uuid(),
  firmwareFamily: z.string().min(1),
  version: SemanticVersionSchema,
  gitCommitSha: z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be a 40-char git commit SHA' }),
  gitBranch: z.string().default('main'),
  artifacts: z.array(FirmwareArtifactMetadataSchema).min(1),
  manifest: OtaManifestSchema,
  status: ReleaseStatusSchema.default('RELEASE_CANDIDATE'),
  approvedByUserId: z.string().uuid().optional(),
  approvedAt: z.string().datetime().optional(),
  createdAt: z.string().datetime()
});
export type FirmwareRelease = z.infer<typeof FirmwareReleaseSchema>;

export const FirmwareCompatibilityMatrixSchema = z.object({
  firmwareFamily: z.string().min(1),
  version: SemanticVersionSchema,
  compatibleHardwareRevisions: z.array(HardwareRevisionCodeSchema).min(1),
  breakingChanges: z.array(z.string()).default([]),
  updatedAt: z.string().datetime()
});
export type FirmwareCompatibilityMatrix = z.infer<typeof FirmwareCompatibilityMatrixSchema>;

export const FirmwareReleaseLifecycleStatusSchema = z.enum([
  'DRAFT',
  'BUILDING',
  'VALIDATION',
  'APPROVED',
  'RELEASED',
  'DEPRECATED',
  'RETIRED',
  'REVOKED'
]);
export type FirmwareReleaseLifecycleStatus = z.infer<typeof FirmwareReleaseLifecycleStatusSchema>;

/**
 * Historical fleet / storage status compatibility mapping (Migration 011 / Phase 18 / Phase 41 <-> Part 07).
 * 'RELEASED' in the engineering release domain represents 'PUBLISHED' in historical fleet distribution.
 */
export const DOMAIN_TO_LEGACY_STATUS_MAP: Record<string, string> = {
  RELEASED: 'PUBLISHED',
  DRAFT: 'DRAFT',
  DEPRECATED: 'DEPRECATED',
  RETIRED: 'DEPRECATED',
  REVOKED: 'REVOKED',
};

export const LEGACY_TO_DOMAIN_STATUS_MAP: Record<string, string> = {
  PUBLISHED: 'RELEASED',
  DRAFT: 'DRAFT',
  DEPRECATED: 'DEPRECATED',
  REVOKED: 'REVOKED',
};

export function toLegacyReleaseStatus(domainStatus: string): string {
  return DOMAIN_TO_LEGACY_STATUS_MAP[domainStatus] || domainStatus;
}

export function toDomainReleaseStatus(legacyStatus: string): string {
  return LEGACY_TO_DOMAIN_STATUS_MAP[legacyStatus] || legacyStatus;
}

export const FirmwareFamilySchema = z.object({
  id: z.string().min(1),
  displayName: z.string().min(1),
  targetMcu: z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']).default('esp32-c6'),
  defaultIdfVersion: z.string().default('v5.4.1'),
  repositoryUrl: z.string().optional(),
  description: z.string().optional()
});
export type FirmwareFamily = z.infer<typeof FirmwareFamilySchema>;

export const FirmwareBuildMetadataSchema = z.object({
  buildId: z.string(),
  firmwareFamilyId: z.string(),
  gitCommitSha: z.string().regex(/^[0-9a-fA-F]{40}$/),
  gitBranch: z.string().default('main'),
  gitTag: z.string().optional(),
  idfVersion: z.string().default('v5.4.1'),
  buildProfile: z.enum(['release', 'debug', 'profiling']).default('release'),
  toolchainInfo: z.record(z.unknown()).default({}),
  builtBy: z.string().optional(),
  builtAt: z.string().datetime()
});
export type FirmwareBuildMetadata = z.infer<typeof FirmwareBuildMetadataSchema>;

export const FirmwareHardwareCompatibilitySchema = z.object({
  firmwareReleaseId: z.string(),
  hardwareRevisionId: z.string(),
  minHardwareRevision: z.string().optional(),
  maxHardwareRevision: z.string().optional(),
  isVerified: z.boolean().default(true),
  verificationNotes: z.string().optional(),
  verifiedAt: z.string().datetime()
});
export type FirmwareHardwareCompatibility = z.infer<typeof FirmwareHardwareCompatibilitySchema>;

export const TargetMcuSchema = z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']);
export type TargetMcu = z.infer<typeof TargetMcuSchema>;

export const CanonicalProductionMcuSchema = z.enum(['esp32-c6', 'esp32-s3']);
export type CanonicalProductionMcu = z.infer<typeof CanonicalProductionMcuSchema>;
export const CANONICAL_PRODUCTION_MCUS = ['esp32-c6', 'esp32-s3'] as const;

export const IdfTargetSchema = z.enum(['esp32c6', 'esp32s3', 'esp32', 'esp32c3']);
export type IdfTarget = z.infer<typeof IdfTargetSchema>;

export const ToolchainSchema = z.enum(['riscv32-esp-elf', 'xtensa-esp-elf']);
export type Toolchain = z.infer<typeof ToolchainSchema>;

export const MCU_TO_IDF_TARGET_MAP: Record<TargetMcu, IdfTarget> = {
  'esp32-c6': 'esp32c6',
  'esp32-s3': 'esp32s3',
  'esp32': 'esp32',
  'esp32-c3': 'esp32c3',
};

export const MCU_TO_TOOLCHAIN_MAP: Record<TargetMcu, Toolchain> = {
  'esp32-c6': 'riscv32-esp-elf',
  'esp32-s3': 'xtensa-esp-elf',
  'esp32': 'xtensa-esp-elf',
  'esp32-c3': 'riscv32-esp-elf',
};

export const DiscoveredArtifactSchema = z.object({
  artifactType: z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
  fileName: z.string().min(1),
  fileSizeBytes: z.number().int().positive(),
  sha256: z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
  storagePath: z.string().min(1),
  role: z.string().optional(),
  targetMcu: TargetMcuSchema.optional(),
  idfTarget: IdfTargetSchema.optional(),
});
export type DiscoveredArtifact = z.infer<typeof DiscoveredArtifactSchema>;

export const FirmwareBuildManifestSchema = z.object({
  schemaVersion: SchemaVersionSchema.default(1),
  buildId: z.string().uuid({ message: 'buildId must be an authoritative UUID' }),
  firmwareFamily: z.string().min(1),
  productVariants: z.array(z.string().min(1)).default([]),
  version: SemanticVersionSchema,
  gitCommitSha: z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
  gitBranch: z.string().default('main'),
  gitTag: z.string().optional(),
  targetMcu: TargetMcuSchema,
  idfTarget: IdfTargetSchema,
  toolchain: ToolchainSchema,
  idfVersion: z.string().default('v5.4.1'),
  buildProfile: z.enum(['release', 'debug', 'profiling']).default('release'),
  lifecycleStatus: FirmwareReleaseLifecycleStatusSchema,
  compatibleHardwareRevisions: z.array(z.string().min(1)).min(1),
  artifacts: z.array(DiscoveredArtifactSchema).min(1),
  generatedAt: z.string().datetime(),
});
export type FirmwareBuildManifest = z.infer<typeof FirmwareBuildManifestSchema>;

/**
 * Canonical product variant mapping derived from authoritative product-definitions/
 */
export const FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP: Record<string, string[]> = {
  'esp32c6-switch-platform': ['eh-smart-switch-1x', 'eh-smart-switch-2x', 'eh-smart-switch-3x', 'eh-smart-switch-4x'],
  'esp32c6-socket-platform': ['eh-smart-socket-1x', 'eh-smart-socket-2x', 'eh-smart-socket-3x'],
  'esp32c6-fan-platform': ['eh-smart-fan-1x'],
  'esp32c6-light-platform': ['eh-smart-light-cct'],
  'esp32s3-hub-platform': ['eh-smart-hub-v1'],
  'esp32c6-sensor-platform': ['eh-sensor-node-v1'],
  'esp32-dev-platform': ['eh-smart-switch-dev', 'eh-smart-socket-dev'],
};

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

export const CANONICAL_FIRMWARE_FAMILIES: Record<string, FirmwareFamilyMetadata> = {
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

export const PRODUCTION_RELEASE_ELIGIBLE_FAMILIES: string[] = Object.values(CANONICAL_FIRMWARE_FAMILIES)
  .filter((f) => f.releaseEligibility === 'PRODUCTION')
  .map((f) => f.id);

/**
 * Validates whether a firmware family is currently eligible for an official production release.
 * Returns valid: false with an explicit error message if the family is unknown, planned, or prototype-only.
 */
export function validateProductionReleaseFamily(family: string): {
  valid: boolean;
  error?: string;
  metadata?: FirmwareFamilyMetadata;
} {
  const meta = CANONICAL_FIRMWARE_FAMILIES[family];
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

/**
 * Parses release git tags into firmware family and semantic version.
 * Supports:
 *  - Family-scoped tags: <family>@v<version> (e.g. 'esp32c6-switch-platform@v1.0.0')
 *  - Generic tags: v<version> (e.g. 'v1.0.0', defaults to primary production family 'esp32c6-switch-platform')
 */
export function parseReleaseTag(
  tag: string,
  defaultFamily = 'esp32c6-switch-platform'
): { firmwareFamily: string; version: string; isFamilyScoped: boolean } {
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

export const ReleaseReadinessGateSchema = z.object({
  releaseId: z.string().min(1),
  isReadyForApproval: z.boolean(),
  evaluatedAt: z.string().datetime(),
  checks: z.array(
    z.object({
      gate: z.string(),
      passed: z.boolean(),
      detail: z.string(),
    })
  ),
});
export type ReleaseReadinessGate = z.infer<typeof ReleaseReadinessGateSchema>;


