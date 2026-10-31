import { z } from 'zod';
/**
 * EH Home Canonical Storage Contracts (Part 16)
 * Single source of truth for object storage buckets, object keys,
 * storage metadata, data classification, and backup manifests.
 */
export declare const StorageBucketSchema: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
export type StorageBucket = z.infer<typeof StorageBucketSchema>;
export declare const CANONICAL_BUCKETS: readonly ["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"];
export declare const ObjectClassificationSchema: z.ZodEnum<["PUBLIC_ASSET", "PROTECTED_FIRMWARE", "MANUFACTURING_DATA", "DATABASE_BACKUP", "AUDIT_EXPORT"]>;
export type ObjectClassification = z.infer<typeof ObjectClassificationSchema>;
export declare const StorageObjectMetadataSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    key: z.ZodString;
    sizeBytes: z.ZodNumber;
    contentType: z.ZodDefault<z.ZodString>;
    sha256: z.ZodString;
    etag: z.ZodOptional<z.ZodString>;
    lastModified: z.ZodDefault<z.ZodString>;
    classification: z.ZodDefault<z.ZodEnum<["PUBLIC_ASSET", "PROTECTED_FIRMWARE", "MANUFACTURING_DATA", "DATABASE_BACKUP", "AUDIT_EXPORT"]>>;
    customMetadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodString>>;
}, "strip", z.ZodTypeAny, {
    sha256: string;
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    sizeBytes: number;
    contentType: string;
    lastModified: string;
    classification: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT";
    customMetadata: Record<string, string>;
    etag?: string | undefined;
}, {
    sha256: string;
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    sizeBytes: number;
    contentType?: string | undefined;
    etag?: string | undefined;
    lastModified?: string | undefined;
    classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
    customMetadata?: Record<string, string> | undefined;
}>;
export type StorageObjectMetadata = z.infer<typeof StorageObjectMetadataSchema>;
export declare const PutObjectRequestSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    key: z.ZodString;
    content: z.ZodUnion<[z.ZodType<Uint8Array<ArrayBuffer>, z.ZodTypeDef, Uint8Array<ArrayBuffer>>, z.ZodString]>;
    contentType: z.ZodOptional<z.ZodString>;
    classification: z.ZodOptional<z.ZodEnum<["PUBLIC_ASSET", "PROTECTED_FIRMWARE", "MANUFACTURING_DATA", "DATABASE_BACKUP", "AUDIT_EXPORT"]>>;
    customMetadata: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodString>>;
}, "strip", z.ZodTypeAny, {
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    content: string | Uint8Array<ArrayBuffer>;
    contentType?: string | undefined;
    classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
    customMetadata?: Record<string, string> | undefined;
}, {
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    content: string | Uint8Array<ArrayBuffer>;
    contentType?: string | undefined;
    classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
    customMetadata?: Record<string, string> | undefined;
}>;
export type PutObjectRequest = z.infer<typeof PutObjectRequestSchema>;
export declare const GetObjectResultSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    key: z.ZodString;
    content: z.ZodType<Uint8Array<ArrayBuffer>, z.ZodTypeDef, Uint8Array<ArrayBuffer>>;
    metadata: z.ZodObject<{
        bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
        key: z.ZodString;
        sizeBytes: z.ZodNumber;
        contentType: z.ZodDefault<z.ZodString>;
        sha256: z.ZodString;
        etag: z.ZodOptional<z.ZodString>;
        lastModified: z.ZodDefault<z.ZodString>;
        classification: z.ZodDefault<z.ZodEnum<["PUBLIC_ASSET", "PROTECTED_FIRMWARE", "MANUFACTURING_DATA", "DATABASE_BACKUP", "AUDIT_EXPORT"]>>;
        customMetadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodString>>;
    }, "strip", z.ZodTypeAny, {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType: string;
        lastModified: string;
        classification: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT";
        customMetadata: Record<string, string>;
        etag?: string | undefined;
    }, {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType?: string | undefined;
        etag?: string | undefined;
        lastModified?: string | undefined;
        classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
        customMetadata?: Record<string, string> | undefined;
    }>;
}, "strip", z.ZodTypeAny, {
    metadata: {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType: string;
        lastModified: string;
        classification: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT";
        customMetadata: Record<string, string>;
        etag?: string | undefined;
    };
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    content: Uint8Array<ArrayBuffer>;
}, {
    metadata: {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType?: string | undefined;
        etag?: string | undefined;
        lastModified?: string | undefined;
        classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
        customMetadata?: Record<string, string> | undefined;
    };
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    content: Uint8Array<ArrayBuffer>;
}>;
export type GetObjectResult = z.infer<typeof GetObjectResultSchema>;
export declare const SignedUrlRequestSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    key: z.ZodString;
    expiresInSeconds: z.ZodDefault<z.ZodNumber>;
    action: z.ZodDefault<z.ZodEnum<["GET", "PUT"]>>;
}, "strip", z.ZodTypeAny, {
    key: string;
    action: "GET" | "PUT";
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    expiresInSeconds: number;
}, {
    key: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    action?: "GET" | "PUT" | undefined;
    expiresInSeconds?: number | undefined;
}>;
export type SignedUrlRequest = z.infer<typeof SignedUrlRequestSchema>;
export declare const SignedUrlResponseSchema: z.ZodObject<{
    url: z.ZodString;
    expiresAt: z.ZodString;
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    key: z.ZodString;
}, "strip", z.ZodTypeAny, {
    key: string;
    expiresAt: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    url: string;
}, {
    key: string;
    expiresAt: string;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    url: string;
}>;
export type SignedUrlResponse = z.infer<typeof SignedUrlResponseSchema>;
export declare const ListObjectsRequestSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    prefix: z.ZodOptional<z.ZodString>;
    limit: z.ZodDefault<z.ZodNumber>;
    continuationToken: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    limit: number;
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    prefix?: string | undefined;
    continuationToken?: string | undefined;
}, {
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    limit?: number | undefined;
    prefix?: string | undefined;
    continuationToken?: string | undefined;
}>;
export type ListObjectsRequest = z.infer<typeof ListObjectsRequestSchema>;
export declare const ListObjectsResponseSchema: z.ZodObject<{
    bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
    objects: z.ZodArray<z.ZodObject<{
        bucket: z.ZodEnum<["eh-product-assets", "eh-firmware-artifacts", "eh-manufacturing-labels", "eh-database-backups"]>;
        key: z.ZodString;
        sizeBytes: z.ZodNumber;
        contentType: z.ZodDefault<z.ZodString>;
        sha256: z.ZodString;
        etag: z.ZodOptional<z.ZodString>;
        lastModified: z.ZodDefault<z.ZodString>;
        classification: z.ZodDefault<z.ZodEnum<["PUBLIC_ASSET", "PROTECTED_FIRMWARE", "MANUFACTURING_DATA", "DATABASE_BACKUP", "AUDIT_EXPORT"]>>;
        customMetadata: z.ZodDefault<z.ZodRecord<z.ZodString, z.ZodString>>;
    }, "strip", z.ZodTypeAny, {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType: string;
        lastModified: string;
        classification: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT";
        customMetadata: Record<string, string>;
        etag?: string | undefined;
    }, {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType?: string | undefined;
        etag?: string | undefined;
        lastModified?: string | undefined;
        classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
        customMetadata?: Record<string, string> | undefined;
    }>, "many">;
    continuationToken: z.ZodOptional<z.ZodString>;
    isTruncated: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    objects: {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType: string;
        lastModified: string;
        classification: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT";
        customMetadata: Record<string, string>;
        etag?: string | undefined;
    }[];
    isTruncated: boolean;
    continuationToken?: string | undefined;
}, {
    bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
    objects: {
        sha256: string;
        key: string;
        bucket: "eh-product-assets" | "eh-firmware-artifacts" | "eh-manufacturing-labels" | "eh-database-backups";
        sizeBytes: number;
        contentType?: string | undefined;
        etag?: string | undefined;
        lastModified?: string | undefined;
        classification?: "PUBLIC_ASSET" | "PROTECTED_FIRMWARE" | "MANUFACTURING_DATA" | "DATABASE_BACKUP" | "AUDIT_EXPORT" | undefined;
        customMetadata?: Record<string, string> | undefined;
    }[];
    continuationToken?: string | undefined;
    isTruncated?: boolean | undefined;
}>;
export type ListObjectsResponse = z.infer<typeof ListObjectsResponseSchema>;
export declare const BackupManifestSchema: z.ZodObject<{
    backupId: z.ZodString;
    timestamp: z.ZodString;
    schemaVersion: z.ZodString;
    migrationVersion: z.ZodString;
    pgVersion: z.ZodDefault<z.ZodString>;
    backupTool: z.ZodDefault<z.ZodEnum<["pg_dump", "postgres_engine", "psql"]>>;
    commandArgs: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    sourceDatabase: z.ZodString;
    tableCount: z.ZodNumber;
    rowCount: z.ZodNumber;
    sha256: z.ZodString;
    sizeBytes: z.ZodNumber;
    format: z.ZodDefault<z.ZodEnum<["POSTGRES_CUSTOM_ARCHIVE", "POSTGRES_SQL_DUMP", "SQL_DUMP", "JSON_SNAPSHOT"]>>;
    checksumVerified: z.ZodDefault<z.ZodBoolean>;
    tablesIncluded: z.ZodDefault<z.ZodArray<z.ZodString, "many">>;
    retentionExpiresAt: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    schemaVersion: string;
    timestamp: string;
    sha256: string;
    sizeBytes: number;
    backupId: string;
    migrationVersion: string;
    pgVersion: string;
    backupTool: "pg_dump" | "postgres_engine" | "psql";
    commandArgs: string[];
    sourceDatabase: string;
    tableCount: number;
    rowCount: number;
    format: "POSTGRES_CUSTOM_ARCHIVE" | "POSTGRES_SQL_DUMP" | "SQL_DUMP" | "JSON_SNAPSHOT";
    checksumVerified: boolean;
    tablesIncluded: string[];
    retentionExpiresAt?: string | undefined;
}, {
    schemaVersion: string;
    timestamp: string;
    sha256: string;
    sizeBytes: number;
    backupId: string;
    migrationVersion: string;
    sourceDatabase: string;
    tableCount: number;
    rowCount: number;
    pgVersion?: string | undefined;
    backupTool?: "pg_dump" | "postgres_engine" | "psql" | undefined;
    commandArgs?: string[] | undefined;
    format?: "POSTGRES_CUSTOM_ARCHIVE" | "POSTGRES_SQL_DUMP" | "SQL_DUMP" | "JSON_SNAPSHOT" | undefined;
    checksumVerified?: boolean | undefined;
    tablesIncluded?: string[] | undefined;
    retentionExpiresAt?: string | undefined;
}>;
export type BackupManifest = z.infer<typeof BackupManifestSchema>;
export declare const BackupRetentionPolicySchema: z.ZodObject<{
    maxBackupsCount: z.ZodDefault<z.ZodNumber>;
    retentionDays: z.ZodDefault<z.ZodNumber>;
    keepMonthlyForMonths: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    maxBackupsCount: number;
    retentionDays: number;
    keepMonthlyForMonths: number;
}, {
    maxBackupsCount?: number | undefined;
    retentionDays?: number | undefined;
    keepMonthlyForMonths?: number | undefined;
}>;
export type BackupRetentionPolicy = z.infer<typeof BackupRetentionPolicySchema>;
export declare class CanonicalObjectKeyBuilder {
    /**
     * Sanitizes object key components by rejecting path traversal and illegal characters.
     */
    static sanitizeSegment(segment: string): string;
    /**
     * Normalizes a full object key path.
     */
    static normalizeKey(rawKey: string): string;
    /**
     * Canonical path for Product Imagery and Design Assets:
     * `products/{productId}/variants/{variantId}/images/{assetId}_{filename}`
     */
    static buildProductAssetKey(productId: string, variantId: string, assetId: string, filename: string): string;
    /**
     * Canonical path for Firmware Artifacts:
     * `firmware/{firmwareFamily}/{version}/{targetMcu}/{sha256}.bin`
     */
    static buildFirmwareKey(family: string, version: string, targetMcu: string, sha256: string): string;
    /**
     * Canonical path for Manufacturing QR / Label Artifacts:
     * `labels/{deviceId}/{qrToken}.pdf`
     */
    static buildLabelKey(deviceId: string, qrToken: string): string;
    /**
     * Canonical path for Database Backup Snapshots:
     * `backups/{timestamp}_{schemaVersion}_{shortSha256}.json`
     */
    static buildBackupKey(timestamp: Date | string, schemaVersion: string, identifierOrSha: string, ext?: string): string;
}
//# sourceMappingURL=index.d.ts.map