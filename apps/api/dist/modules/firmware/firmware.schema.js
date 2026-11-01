"use strict";
/**
 * EH Home Firmware Domain Request & Response Schemas
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.DefineCompatibilityBodySchema = exports.RegisterArtifactBodySchema = exports.RegisterBuildBodySchema = exports.UpdateReleaseStatusBodySchema = exports.CreateFirmwareReleaseBodySchema = exports.FirmwareFamilyParamsSchema = exports.FirmwareReleaseParamsSchema = exports.ListFirmwareReleasesQuerySchema = exports.ListFirmwareFamiliesQuerySchema = void 0;
const zod_1 = require("zod");
// Query schemas
exports.ListFirmwareFamiliesQuerySchema = zod_1.z.object({
    targetMcu: zod_1.z.enum(['esp32-c6', 'esp32-s3', 'esp32', 'esp32-c3']).optional(),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(20),
    offset: zod_1.z.coerce.number().int().min(0).default(0),
});
exports.ListFirmwareReleasesQuerySchema = zod_1.z.object({
    firmwareFamily: zod_1.z.string().optional(),
    productVariantId: zod_1.z.string().optional(),
    hardwareRevisionId: zod_1.z.string().optional(),
    status: zod_1.z.string().optional(),
    version: zod_1.z.string().optional(),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(20),
    offset: zod_1.z.coerce.number().int().min(0).default(0),
});
// Params schemas
exports.FirmwareReleaseParamsSchema = zod_1.z.object({
    releaseId: zod_1.z.string().min(1),
});
exports.FirmwareFamilyParamsSchema = zod_1.z.object({
    familyId: zod_1.z.string().min(1),
});
// Request bodies
exports.CreateFirmwareReleaseBodySchema = zod_1.z.object({
    id: zod_1.z.string().optional(),
    firmwareFamily: zod_1.z.string().min(1),
    productVariantId: zod_1.z.string().regex(/^eh-[a-z0-9-]+$/),
    version: zod_1.z.string().regex(/^\d+\.\d+\.\d+.*$/, { message: 'Must be semantic version' }),
    hardwareRevision: zod_1.z.string().optional(),
    minFirmwareVersion: zod_1.z.string().optional(),
    releaseChannel: zod_1.z.enum(['development', 'beta', 'production', 'staging', 'canary']).default('production'),
    gitCommitSha: zod_1.z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
    gitBranch: zod_1.z.string().default('main'),
    gitTag: zod_1.z.string().optional(),
    idfVersion: zod_1.z.string().default('v5.4.1'),
    binarySizeBytes: zod_1.z.number().int().positive().default(1024),
    sha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
    ed25519Signature: zod_1.z.string().optional(),
    downloadUrl: zod_1.z.string().default(''),
    releaseNotes: zod_1.z.string().optional(),
    status: zod_1.z.literal('DRAFT').optional().default('DRAFT'),
});
exports.UpdateReleaseStatusBodySchema = zod_1.z.object({
    status: zod_1.z.enum(['DRAFT', 'BUILDING', 'VALIDATION', 'APPROVED', 'RELEASED', 'DEPRECATED', 'RETIRED', 'REVOKED']),
    reason: zod_1.z.string().optional(),
    approvedByUserId: zod_1.z.string().optional(),
});
exports.RegisterBuildBodySchema = zod_1.z.object({
    id: zod_1.z.string().optional(),
    firmwareReleaseId: zod_1.z.string().optional(),
    firmwareFamilyId: zod_1.z.string().min(1),
    gitCommitSha: zod_1.z.string().regex(/^[0-9a-fA-F]{40}$/, { message: 'Must be 40-char git commit SHA' }),
    gitBranch: zod_1.z.string().default('main'),
    gitTag: zod_1.z.string().optional(),
    idfVersion: zod_1.z.string().default('v5.4.1'),
    buildProfile: zod_1.z.enum(['release', 'debug', 'profiling']).default('release'),
    toolchainInfo: zod_1.z.record(zod_1.z.unknown()).default({}),
    builtBy: zod_1.z.string().optional(),
});
exports.RegisterArtifactBodySchema = zod_1.z.object({
    id: zod_1.z.string().optional(),
    buildId: zod_1.z.string().min(1),
    artifactType: zod_1.z.enum(['APP_BIN', 'BOOTLOADER', 'PARTITION_TABLE', 'ELF', 'MAP', 'FACTORY_NVS']),
    fileName: zod_1.z.string().min(1),
    fileSizeBytes: zod_1.z.number().int().positive(),
    sha256: zod_1.z.string().regex(/^[0-9a-fA-F]{64}$/, { message: 'Must be 64-char hex SHA-256' }),
    storagePath: zod_1.z.string().min(1),
    downloadUrl: zod_1.z.string().optional(),
    signature: zod_1.z.string().optional(),
});
exports.DefineCompatibilityBodySchema = zod_1.z.object({
    hardwareRevisionId: zod_1.z.string().min(1),
    minHardwareRevision: zod_1.z.string().optional(),
    maxHardwareRevision: zod_1.z.string().optional(),
    verificationNotes: zod_1.z.string().optional(),
});
//# sourceMappingURL=firmware.schema.js.map