/**
 * EH Home Firmware Domain Request & Response Schemas
 */
import { z } from 'zod';
export declare const ListFirmwareFamiliesQuerySchema: z.ZodObject<{
    targetMcu: z.ZodOptional<z.ZodEnum<["esp32-c6", "esp32-s3", "esp32", "esp32-c3"]>>;
    limit: z.ZodDefault<z.ZodNumber>;
    offset: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    offset: number;
    targetMcu?: "esp32-c6" | "esp32-s3" | "esp32" | "esp32-c3" | undefined;
}, {
    limit?: number | undefined;
    offset?: number | undefined;
    targetMcu?: "esp32-c6" | "esp32-s3" | "esp32" | "esp32-c3" | undefined;
}>;
export type ListFirmwareFamiliesQuery = z.infer<typeof ListFirmwareFamiliesQuerySchema>;
export declare const ListFirmwareReleasesQuerySchema: z.ZodObject<{
    firmwareFamily: z.ZodOptional<z.ZodString>;
    productVariantId: z.ZodOptional<z.ZodString>;
    hardwareRevisionId: z.ZodOptional<z.ZodString>;
    status: z.ZodOptional<z.ZodString>;
    version: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
    offset: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    offset: number;
    status?: string | undefined;
    version?: string | undefined;
    productVariantId?: string | undefined;
    firmwareFamily?: string | undefined;
    hardwareRevisionId?: string | undefined;
}, {
    status?: string | undefined;
    version?: string | undefined;
    limit?: number | undefined;
    offset?: number | undefined;
    productVariantId?: string | undefined;
    firmwareFamily?: string | undefined;
    hardwareRevisionId?: string | undefined;
}>;
export type ListFirmwareReleasesQuery = z.infer<typeof ListFirmwareReleasesQuerySchema>;
export declare const FirmwareReleaseParamsSchema: z.ZodObject<{
    releaseId: z.ZodString;
}, "strip", z.ZodTypeAny, {
    releaseId: string;
}, {
    releaseId: string;
}>;
export type FirmwareReleaseParams = z.infer<typeof FirmwareReleaseParamsSchema>;
export declare const FirmwareFamilyParamsSchema: z.ZodObject<{
    familyId: z.ZodString;
}, "strip", z.ZodTypeAny, {
    familyId: string;
}, {
    familyId: string;
}>;
export type FirmwareFamilyParams = z.infer<typeof FirmwareFamilyParamsSchema>;
export declare const CreateFirmwareReleaseBodySchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    firmwareFamily: z.ZodString;
    productVariantId: z.ZodString;
    version: z.ZodString;
    hardwareRevision: z.ZodOptional<z.ZodString>;
    minFirmwareVersion: z.ZodOptional<z.ZodString>;
    releaseChannel: z.ZodDefault<z.ZodEnum<["development", "beta", "production", "staging", "canary"]>>;
    gitCommitSha: z.ZodString;
    gitBranch: z.ZodDefault<z.ZodString>;
    gitTag: z.ZodOptional<z.ZodString>;
    idfVersion: z.ZodDefault<z.ZodString>;
    binarySizeBytes: z.ZodDefault<z.ZodNumber>;
    sha256: z.ZodString;
    ed25519Signature: z.ZodOptional<z.ZodString>;
    downloadUrl: z.ZodDefault<z.ZodString>;
    releaseNotes: z.ZodOptional<z.ZodString>;
    status: z.ZodDefault<z.ZodOptional<z.ZodLiteral<"DRAFT">>>;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT";
    version: string;
    productVariantId: string;
    firmwareFamily: string;
    sha256: string;
    releaseChannel: "development" | "production" | "beta" | "staging" | "canary";
    gitCommitSha: string;
    gitBranch: string;
    idfVersion: string;
    binarySizeBytes: number;
    downloadUrl: string;
    id?: string | undefined;
    hardwareRevision?: string | undefined;
    minFirmwareVersion?: string | undefined;
    gitTag?: string | undefined;
    ed25519Signature?: string | undefined;
    releaseNotes?: string | undefined;
}, {
    version: string;
    productVariantId: string;
    firmwareFamily: string;
    sha256: string;
    gitCommitSha: string;
    status?: "DRAFT" | undefined;
    id?: string | undefined;
    hardwareRevision?: string | undefined;
    minFirmwareVersion?: string | undefined;
    releaseChannel?: "development" | "production" | "beta" | "staging" | "canary" | undefined;
    gitBranch?: string | undefined;
    gitTag?: string | undefined;
    idfVersion?: string | undefined;
    binarySizeBytes?: number | undefined;
    ed25519Signature?: string | undefined;
    downloadUrl?: string | undefined;
    releaseNotes?: string | undefined;
}>;
export type CreateFirmwareReleaseBody = z.infer<typeof CreateFirmwareReleaseBodySchema>;
export declare const UpdateReleaseStatusBodySchema: z.ZodObject<{
    status: z.ZodEnum<["DRAFT", "BUILDING", "VALIDATION", "APPROVED", "RELEASED", "DEPRECATED", "RETIRED", "REVOKED"]>;
    reason: z.ZodOptional<z.ZodString>;
    approvedByUserId: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    status: "DRAFT" | "DEPRECATED" | "RETIRED" | "VALIDATION" | "APPROVED" | "BUILDING" | "RELEASED" | "REVOKED";
    reason?: string | undefined;
    approvedByUserId?: string | undefined;
}, {
    status: "DRAFT" | "DEPRECATED" | "RETIRED" | "VALIDATION" | "APPROVED" | "BUILDING" | "RELEASED" | "REVOKED";
    reason?: string | undefined;
    approvedByUserId?: string | undefined;
}>;
export type UpdateReleaseStatusBody = z.infer<typeof UpdateReleaseStatusBodySchema>;
export declare const RegisterBuildBodySchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    firmwareReleaseId: z.ZodOptional<z.ZodString>;
    firmwareFamilyId: z.ZodString;
    gitCommitSha: z.ZodString;
    gitBranch: z.ZodDefault<z.ZodString>;
    gitTag: z.ZodOptional<z.ZodString>;
    idfVersion: z.ZodDefault<z.ZodString>;
    buildProfile: z.ZodDefault<z.ZodEnum<["release", "debug", "profiling"]>>;
    toolchainInfo: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    builtBy: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    gitCommitSha: string;
    gitBranch: string;
    idfVersion: string;
    firmwareFamilyId: string;
    buildProfile: "debug" | "release" | "profiling";
    toolchainInfo: Record<string, unknown>;
    id?: string | undefined;
    gitTag?: string | undefined;
    firmwareReleaseId?: string | undefined;
    builtBy?: string | undefined;
}, {
    gitCommitSha: string;
    firmwareFamilyId: string;
    id?: string | undefined;
    gitBranch?: string | undefined;
    gitTag?: string | undefined;
    idfVersion?: string | undefined;
    firmwareReleaseId?: string | undefined;
    buildProfile?: "debug" | "release" | "profiling" | undefined;
    toolchainInfo?: Record<string, unknown> | undefined;
    builtBy?: string | undefined;
}>;
export type RegisterBuildBody = z.infer<typeof RegisterBuildBodySchema>;
export declare const RegisterArtifactBodySchema: z.ZodObject<{
    id: z.ZodOptional<z.ZodString>;
    buildId: z.ZodString;
    artifactType: z.ZodEnum<["APP_BIN", "BOOTLOADER", "PARTITION_TABLE", "ELF", "MAP", "FACTORY_NVS"]>;
    fileName: z.ZodString;
    fileSizeBytes: z.ZodNumber;
    sha256: z.ZodString;
    storagePath: z.ZodString;
    downloadUrl: z.ZodOptional<z.ZodString>;
    signature: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    sha256: string;
    buildId: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileName: string;
    fileSizeBytes: number;
    storagePath: string;
    id?: string | undefined;
    downloadUrl?: string | undefined;
    signature?: string | undefined;
}, {
    sha256: string;
    buildId: string;
    artifactType: "APP_BIN" | "BOOTLOADER" | "PARTITION_TABLE" | "ELF" | "MAP" | "FACTORY_NVS";
    fileName: string;
    fileSizeBytes: number;
    storagePath: string;
    id?: string | undefined;
    downloadUrl?: string | undefined;
    signature?: string | undefined;
}>;
export type RegisterArtifactBody = z.infer<typeof RegisterArtifactBodySchema>;
export declare const DefineCompatibilityBodySchema: z.ZodObject<{
    hardwareRevisionId: z.ZodString;
    minHardwareRevision: z.ZodOptional<z.ZodString>;
    maxHardwareRevision: z.ZodOptional<z.ZodString>;
    verificationNotes: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    hardwareRevisionId: string;
    minHardwareRevision?: string | undefined;
    maxHardwareRevision?: string | undefined;
    verificationNotes?: string | undefined;
}, {
    hardwareRevisionId: string;
    minHardwareRevision?: string | undefined;
    maxHardwareRevision?: string | undefined;
    verificationNotes?: string | undefined;
}>;
export type DefineCompatibilityBody = z.infer<typeof DefineCompatibilityBodySchema>;
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
//# sourceMappingURL=firmware.schema.d.ts.map