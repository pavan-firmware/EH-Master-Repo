/**
 * EH Home Firmware Domain Request & Response Schemas
 */

import { z } from 'zod';

// Query schemas
export const ListFirmwareFamiliesQuerySchema = z.object({
  targetMcu: z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});
export type ListFirmwareFamiliesQuery = z.infer<typeof ListFirmwareFamiliesQuerySchema>;

export const ListFirmwareReleasesQuerySchema = z.object({
  firmwareFamily: z.string().optional(),
  productVariantId: z.string().optional(),
  hardwareRevisionId: z.string().optional(),
  status: z.string().optional(),
  version: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});
export type ListFirmwareReleasesQuery = z.infer<typeof ListFirmwareReleasesQuerySchema>;

// Params schemas
export const FirmwareReleaseParamsSchema = z.object({
  releaseId: z.string().min(1),
});
export type FirmwareReleaseParams = z.infer<typeof FirmwareReleaseParamsSchema>;

export const FirmwareFamilyParamsSchema = z.object({
  familyId: z.string().min(1),
});
export type FirmwareFamilyParams = z.infer<typeof FirmwareFamilyParamsSchema>;

// Request bodies
export const CreateFirmwareReleaseBodySchema = z.object({
  id: z.string().optional(),
  firmwareFamily: z.string().min(1),
  productVariantId: z.string().regex(/^eh-[a-z0-9-]+$/),
  version: z.string().regex(/^\d+\.\d+\.\d+.*$/, { message: 'Must be semantic version' }),
  hardwareRevision: z.string().optional(),
  minFirmwareVersion: z.string().optional(),
  releaseChannel: z.enum(['development', 'beta', 'production', 'staging', 'canary']).default('production'),
  gitCommitSha: z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
  gitBranch: z.string().default('main'),
  gitTag: z.string().optional(),
  idfVersion: z.string().default('v5.4.1'),
  binarySizeBytes: z.number().int().positive().default(1024),
  sha256: z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
  ed25519Signature: z.string().optional(),
  downloadUrl: z.string().default(''),
  releaseNotes: z.string().optional(),
  status: z.literal('DRAFT').optional().default('DRAFT'),
});
export type CreateFirmwareReleaseBody = z.infer<typeof CreateFirmwareReleaseBodySchema>;

export const UpdateReleaseStatusBodySchema = z.object({
  status: z.enum(['DRAFT', 'BUILDING', 'VALIDATION', 'APPROVED', 'RELEASED', 'DEPRECATED', 'RETIRED', 'REVOKED']),
  reason: z.string().optional(),
  approvedByUserId: z.string().optional(),
});
export type UpdateReleaseStatusBody = z.infer<typeof UpdateReleaseStatusBodySchema>;

export const RegisterBuildBodySchema = z.object({
  id: z.string().optional(),
  firmwareReleaseId: z.string().optional(),
  firmwareFamilyId: z.string().min(1),
  gitCommitSha: z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
  gitBranch: z.string().default('main'),
  gitTag: z.string().optional(),
  idfVersion: z.string().default('v5.4.1'),
  buildProfile: z.enum(['release', 'debug', 'profiling']).default('release'),
  toolchainInfo: z.record(z.unknown()).default({}),
  builtBy: z.string().optional(),
});
export type RegisterBuildBody = z.infer<typeof RegisterBuildBodySchema>;

export const RegisterArtifactBodySchema = z.object({
  id: z.string().optional(),
  buildId: z.string().min(1),
  artifactType: z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
  fileName: z.string().min(1),
  fileSizeBytes: z.number().int().positive(),
  sha256: z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
  storagePath: z.string().min(1),
  downloadUrl: z.string().optional(),
  signature: z.string().optional(),
});
export type RegisterArtifactBody = z.infer<typeof RegisterArtifactBodySchema>;

export const DefineCompatibilityBodySchema = z.object({
  hardwareRevisionId: z.string().min(1),
  minHardwareRevision: z.string().optional(),
  maxHardwareRevision: z.string().optional(),
  verificationNotes: z.string().optional(),
});
export type DefineCompatibilityBody = z.infer<typeof DefineCompatibilityBodySchema>;

// Detailed output types
export interface FirmwareFamilyDetail {
  id: string;
  displayName: string;
  targetMcu: string;
  defaultIdfVersion: string;
  repositoryUrl: string | null;
  description: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface FirmwareArtifactDetail {
  id: string;
  buildId: string;
  artifactType: string;
  fileName: string;
  fileSizeBytes: number;
  sha256: string;
  storagePath: string;
  downloadUrl: string | null;
  signature: string | null;
  createdAt: string;
}

export interface FirmwareBuildDetail {
  id: string;
  firmwareReleaseId: string | null;
  firmwareFamilyId: string;
  gitCommitSha: string;
  gitBranch: string;
  gitTag: string | null;
  idfVersion: string;
  buildProfile: string;
  toolchainInfo: Record<string, unknown>;
  builtBy: string | null;
  builtAt: string;
  createdAt: string;
  artifacts?: FirmwareArtifactDetail[];
}

export interface FirmwareCompatibilityItem {
  id: string;
  firmwareReleaseId: string;
  hardwareRevisionId: string;
  minHardwareRevision: string | null;
  maxHardwareRevision: string | null;
  isVerified: boolean;
  verificationNotes: string | null;
  verifiedAt: string;
  createdAt: string;
}

export interface FirmwareReleaseDetail {
  id: string;
  productVariantId: string;
  hardwareRevision: string | null;
  firmwareFamily: string;
  version: string;
  minFirmwareVersion: string | null;
  releaseChannel: string;
  binarySizeBytes: number;
  sha256: string;
  ed25519Signature: string;
  downloadUrl: string;
  releaseNotes: string | null;
  status: string;
  gitCommitSha?: string;
  gitBranch?: string;
  idfVersion?: string;
  createdAt: string;
  releasedAt: string | null;
  builds?: FirmwareBuildDetail[];
  compatibilities?: FirmwareCompatibilityItem[];
}
