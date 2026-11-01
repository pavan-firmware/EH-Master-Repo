"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CanonicalObjectKeyBuilder = exports.BackupRetentionPolicySchema = exports.BackupManifestSchema = exports.ListObjectsResponseSchema = exports.ListObjectsRequestSchema = exports.SignedUrlResponseSchema = exports.SignedUrlRequestSchema = exports.GetObjectResultSchema = exports.PutObjectRequestSchema = exports.StorageObjectMetadataSchema = exports.ObjectClassificationSchema = exports.CANONICAL_BUCKETS = exports.StorageBucketSchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
/**
 * EH Home Canonical Storage Contracts (Part 16)
 * Single source of truth for object storage buckets, object keys,
 * storage metadata, data classification, and backup manifests.
 */
// 1. Canonical Storage Buckets
exports.StorageBucketSchema = zod_1.z.enum([
    'eh-product-assets', // Product catalog imagery and design assets
    'eh-firmware-artifacts', // Firmware binary releases and manifest signatures
    'eh-manufacturing-labels', // Generated QR codes, pack labels, compliance PDFs
    'eh-database-backups' // Periodic and manual PostgreSQL dumps with manifest
]);
exports.CANONICAL_BUCKETS = [
    'eh-product-assets',
    'eh-firmware-artifacts',
    'eh-manufacturing-labels',
    'eh-database-backups'
];
// 2. Data Classification
exports.ObjectClassificationSchema = zod_1.z.enum([
    'PUBLIC_ASSET', // Non-sensitive product images
    'PROTECTED_FIRMWARE', // Release-gated firmware binaries and signatures
    'MANUFACTURING_DATA', // Factory provisioning, QR tokens, compliance labels
    'DATABASE_BACKUP', // Privileged DB snapshots and manifests
    'AUDIT_EXPORT' // Privileged audit trail exports
]);
// 3. Storage Object Metadata
exports.StorageObjectMetadataSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    key: zod_1.z.string().min(1),
    sizeBytes: zod_1.z.number().int().nonnegative(),
    contentType: zod_1.z.string().default('application/octet-stream'),
    sha256: zod_1.z.string().regex(/^[a-f0-9]{64}$/i, 'Must be a 64-char hexadecimal SHA-256 hash'),
    etag: zod_1.z.string().optional(),
    lastModified: common_1.IsoDateTimeSchema.default(() => new Date().toISOString()),
    classification: exports.ObjectClassificationSchema.default('PUBLIC_ASSET'),
    customMetadata: zod_1.z.record(zod_1.z.string()).default({})
});
// 4. Object Storage Operations Schemas
exports.PutObjectRequestSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    key: zod_1.z.string().min(1),
    content: zod_1.z.union([zod_1.z.instanceof(Uint8Array), zod_1.z.string()]),
    contentType: zod_1.z.string().optional(),
    classification: exports.ObjectClassificationSchema.optional(),
    customMetadata: zod_1.z.record(zod_1.z.string()).optional()
});
exports.GetObjectResultSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    key: zod_1.z.string(),
    content: zod_1.z.instanceof(Uint8Array),
    metadata: exports.StorageObjectMetadataSchema
});
exports.SignedUrlRequestSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    key: zod_1.z.string().min(1),
    expiresInSeconds: zod_1.z.number().int().min(1).max(86400).default(900), // Default 15 minutes
    action: zod_1.z.enum(['GET', 'PUT']).default('GET')
});
exports.SignedUrlResponseSchema = zod_1.z.object({
    url: zod_1.z.string().url(),
    expiresAt: common_1.IsoDateTimeSchema,
    bucket: exports.StorageBucketSchema,
    key: zod_1.z.string()
});
exports.ListObjectsRequestSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    prefix: zod_1.z.string().optional(),
    limit: zod_1.z.number().int().min(1).max(1000).default(100),
    continuationToken: zod_1.z.string().optional()
});
exports.ListObjectsResponseSchema = zod_1.z.object({
    bucket: exports.StorageBucketSchema,
    objects: zod_1.z.array(exports.StorageObjectMetadataSchema),
    continuationToken: zod_1.z.string().optional(),
    isTruncated: zod_1.z.boolean().default(false)
});
// 5. Database Backup Manifest Schema
exports.BackupManifestSchema = zod_1.z.object({
    backupId: zod_1.z.string().min(1),
    timestamp: common_1.IsoDateTimeSchema,
    schemaVersion: zod_1.z.string().min(1),
    migrationVersion: zod_1.z.string().min(1),
    pgVersion: zod_1.z.string().default('16.0'),
    backupTool: zod_1.z.enum(['pg_dump', 'postgres_engine', 'psql']).default('pg_dump'),
    commandArgs: zod_1.z.array(zod_1.z.string()).default(['-Fc', '--no-owner', '--no-privileges']),
    sourceDatabase: zod_1.z.string().min(1),
    tableCount: zod_1.z.number().int().nonnegative(),
    rowCount: zod_1.z.number().int().nonnegative(),
    sha256: zod_1.z.string().regex(/^[a-f0-9]{64}$/i),
    sizeBytes: zod_1.z.number().int().nonnegative(),
    format: zod_1.z.enum(['POSTGRES_CUSTOM_ARCHIVE', 'POSTGRES_SQL_DUMP', 'SQL_DUMP', 'JSON_SNAPSHOT']).default('POSTGRES_CUSTOM_ARCHIVE'),
    checksumVerified: zod_1.z.boolean().default(true),
    tablesIncluded: zod_1.z.array(zod_1.z.string()).default([]),
    retentionExpiresAt: common_1.IsoDateTimeSchema.optional()
});
exports.BackupRetentionPolicySchema = zod_1.z.object({
    maxBackupsCount: zod_1.z.number().int().min(1).default(30),
    retentionDays: zod_1.z.number().int().min(1).default(30),
    keepMonthlyForMonths: zod_1.z.number().int().min(0).default(12)
});
// 6. Canonical Object Key Builders & Sanitizers
class CanonicalObjectKeyBuilder {
    /**
     * Sanitizes object key components by rejecting path traversal and illegal characters.
     */
    static sanitizeSegment(segment) {
        if (!segment || typeof segment !== 'string') {
            throw new Error('Invalid segment: segment must be a non-empty string');
        }
        // Remove any path traversal tokens
        const cleaned = segment
            .replace(/\\/g, '/')
            .replace(/\.\./g, '')
            .replace(/^\/+|\/+$/g, '')
            .replace(/[^a-zA-Z0-9._-]/g, '_');
        if (!cleaned || cleaned.length === 0) {
            throw new Error(`Sanitization resulted in empty segment for: "${segment}"`);
        }
        return cleaned;
    }
    /**
     * Normalizes a full object key path.
     */
    static normalizeKey(rawKey) {
        const parts = rawKey
            .replace(/\\/g, '/')
            .split('/')
            .filter((p) => p.length > 0 && p !== '.' && p !== '..')
            .map((p) => CanonicalObjectKeyBuilder.sanitizeSegment(p));
        if (parts.length === 0) {
            throw new Error('Object key cannot be empty');
        }
        return parts.join('/');
    }
    /**
     * Canonical path for Product Imagery and Design Assets:
     * `products/{productId}/variants/{variantId}/images/{assetId}_{filename}`
     */
    static buildProductAssetKey(productId, variantId, assetId, filename) {
        const sProduct = this.sanitizeSegment(productId);
        const sVariant = this.sanitizeSegment(variantId);
        const sAsset = this.sanitizeSegment(assetId);
        const sFile = this.sanitizeSegment(filename);
        return `products/${sProduct}/variants/${sVariant}/images/${sAsset}_${sFile}`;
    }
    /**
     * Canonical path for Firmware Artifacts:
     * `firmware/{firmwareFamily}/{version}/{targetMcu}/{sha256}.bin`
     */
    static buildFirmwareKey(family, version, targetMcu, sha256) {
        const sFamily = this.sanitizeSegment(family);
        const sVersion = this.sanitizeSegment(version);
        const sMcu = this.sanitizeSegment(targetMcu);
        const sHash = this.sanitizeSegment(sha256.toLowerCase());
        return `firmware/${sFamily}/${sVersion}/${sMcu}/${sHash}.bin`;
    }
    /**
     * Canonical path for Manufacturing QR / Label Artifacts:
     * `labels/{deviceId}/{qrToken}.pdf`
     */
    static buildLabelKey(deviceId, qrToken) {
        const sDevice = this.sanitizeSegment(deviceId);
        const sToken = this.sanitizeSegment(qrToken);
        return `labels/${sDevice}/${sToken}.pdf`;
    }
    /**
     * Canonical path for Database Backup Snapshots:
     * `backups/{timestamp}_{schemaVersion}_{shortSha256}.json`
     */
    static buildBackupKey(timestamp, schemaVersion, identifierOrSha, ext = 'json') {
        const isoDate = (typeof timestamp === 'string' ? new Date(timestamp) : timestamp)
            .toISOString()
            .replace(/[:.]/g, '-');
        const sSchema = this.sanitizeSegment(schemaVersion);
        const idStr = (identifierOrSha.length === 64 && /^[0-9a-f]{64}$/i.test(identifierOrSha))
            ? identifierOrSha.substring(0, 12).toLowerCase()
            : identifierOrSha.toLowerCase();
        const sId = this.sanitizeSegment(idStr);
        const sExt = this.sanitizeSegment(ext);
        return `backups/${isoDate}_v${sSchema}_${sId}.${sExt}`;
    }
}
exports.CanonicalObjectKeyBuilder = CanonicalObjectKeyBuilder;
//# sourceMappingURL=index.js.map