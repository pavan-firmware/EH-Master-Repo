import { z } from 'zod';
import { IsoDateTimeSchema } from '../common';

/**
 * EH Home Canonical Storage Contracts (Part 16)
 * Single source of truth for object storage buckets, object keys,
 * storage metadata, data classification, and backup manifests.
 */

// 1. Canonical Storage Buckets
export const StorageBucketSchema = z.enum([
  'eh-product-assets',        // Product catalog imagery and design assets
  'eh-firmware-artifacts',     // Firmware binary releases and manifest signatures
  'eh-manufacturing-labels',   // Generated QR codes, pack labels, compliance PDFs
  'eh-database-backups'        // Periodic and manual PostgreSQL dumps with manifest
]);
export type StorageBucket = z.infer<typeof StorageBucketSchema>;

export const CANONICAL_BUCKETS = [
  'eh-product-assets',
  'eh-firmware-artifacts',
  'eh-manufacturing-labels',
  'eh-database-backups'
] as const;

// 2. Data Classification
export const ObjectClassificationSchema = z.enum([
  'PUBLIC_ASSET',              // Non-sensitive product images
  'PROTECTED_FIRMWARE',        // Release-gated firmware binaries and signatures
  'MANUFACTURING_DATA',        // Factory provisioning, QR tokens, compliance labels
  'DATABASE_BACKUP',           // Privileged DB snapshots and manifests
  'AUDIT_EXPORT'               // Privileged audit trail exports
]);
export type ObjectClassification = z.infer<typeof ObjectClassificationSchema>;

// 3. Storage Object Metadata
export const StorageObjectMetadataSchema = z.object({
  bucket: StorageBucketSchema,
  key: z.string().min(1),
  sizeBytes: z.number().int().nonnegative(),
  contentType: z.string().default('application/octet-stream'),
  sha256: z.string().regex(/^[a-f0-9]{64}$/i, 'Must be a 64-char hexadecimal SHA-256 hash'),
  etag: z.string().optional(),
  lastModified: IsoDateTimeSchema.default(() => new Date().toISOString()),
  classification: ObjectClassificationSchema.default('PUBLIC_ASSET'),
  customMetadata: z.record(z.string()).default({})
});
export type StorageObjectMetadata = z.infer<typeof StorageObjectMetadataSchema>;

// 4. Object Storage Operations Schemas
export const PutObjectRequestSchema = z.object({
  bucket: StorageBucketSchema,
  key: z.string().min(1),
  content: z.union([z.instanceof(Uint8Array), z.string()]),
  contentType: z.string().optional(),
  classification: ObjectClassificationSchema.optional(),
  customMetadata: z.record(z.string()).optional()
});
export type PutObjectRequest = z.infer<typeof PutObjectRequestSchema>;

export const GetObjectResultSchema = z.object({
  bucket: StorageBucketSchema,
  key: z.string(),
  content: z.instanceof(Uint8Array),
  metadata: StorageObjectMetadataSchema
});
export type GetObjectResult = z.infer<typeof GetObjectResultSchema>;

export const SignedUrlRequestSchema = z.object({
  bucket: StorageBucketSchema,
  key: z.string().min(1),
  expiresInSeconds: z.number().int().min(1).max(86400).default(900), // Default 15 minutes
  action: z.enum(['GET', 'PUT']).default('GET')
});
export type SignedUrlRequest = z.infer<typeof SignedUrlRequestSchema>;

export const SignedUrlResponseSchema = z.object({
  url: z.string().url(),
  expiresAt: IsoDateTimeSchema,
  bucket: StorageBucketSchema,
  key: z.string()
});
export type SignedUrlResponse = z.infer<typeof SignedUrlResponseSchema>;

export const ListObjectsRequestSchema = z.object({
  bucket: StorageBucketSchema,
  prefix: z.string().optional(),
  limit: z.number().int().min(1).max(1000).default(100),
  continuationToken: z.string().optional()
});
export type ListObjectsRequest = z.infer<typeof ListObjectsRequestSchema>;

export const ListObjectsResponseSchema = z.object({
  bucket: StorageBucketSchema,
  objects: z.array(StorageObjectMetadataSchema),
  continuationToken: z.string().optional(),
  isTruncated: z.boolean().default(false)
});
export type ListObjectsResponse = z.infer<typeof ListObjectsResponseSchema>;

// 5. Database Backup Manifest Schema
export const BackupManifestSchema = z.object({
  backupId: z.string().min(1),
  timestamp: IsoDateTimeSchema,
  schemaVersion: z.string().min(1),
  migrationVersion: z.string().min(1),
  pgVersion: z.string().default('16.0'),
  backupTool: z.enum(['pg_dump', 'postgres_engine', 'psql']).default('pg_dump'),
  commandArgs: z.array(z.string()).default(['-Fc', '--no-owner', '--no-privileges']),
  sourceDatabase: z.string().min(1),
  tableCount: z.number().int().nonnegative(),
  rowCount: z.number().int().nonnegative(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/i),
  sizeBytes: z.number().int().nonnegative(),
  format: z.enum(['POSTGRES_CUSTOM_ARCHIVE', 'POSTGRES_SQL_DUMP', 'SQL_DUMP', 'JSON_SNAPSHOT']).default('POSTGRES_CUSTOM_ARCHIVE'),
  checksumVerified: z.boolean().default(true),
  tablesIncluded: z.array(z.string()).default([]),
  retentionExpiresAt: IsoDateTimeSchema.optional()
});
export type BackupManifest = z.infer<typeof BackupManifestSchema>;


export const BackupRetentionPolicySchema = z.object({
  maxBackupsCount: z.number().int().min(1).default(30),
  retentionDays: z.number().int().min(1).default(30),
  keepMonthlyForMonths: z.number().int().min(0).default(12)
});
export type BackupRetentionPolicy = z.infer<typeof BackupRetentionPolicySchema>;

// 6. Canonical Object Key Builders & Sanitizers
export class CanonicalObjectKeyBuilder {
  /**
   * Sanitizes object key components by rejecting path traversal and illegal characters.
   */
  public static sanitizeSegment(segment: string): string {
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
  public static normalizeKey(rawKey: string): string {
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
  public static buildProductAssetKey(
    productId: string,
    variantId: string,
    assetId: string,
    filename: string
  ): string {
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
  public static buildFirmwareKey(
    family: string,
    version: string,
    targetMcu: string,
    sha256: string
  ): string {
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
  public static buildLabelKey(deviceId: string, qrToken: string): string {
    const sDevice = this.sanitizeSegment(deviceId);
    const sToken = this.sanitizeSegment(qrToken);
    return `labels/${sDevice}/${sToken}.pdf`;
  }

  /**
   * Canonical path for Database Backup Snapshots:
   * `backups/{timestamp}_{schemaVersion}_{shortSha256}.json`
   */
  public static buildBackupKey(
    timestamp: Date | string,
    schemaVersion: string,
    identifierOrSha: string,
    ext: string = 'json'
  ): string {
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
