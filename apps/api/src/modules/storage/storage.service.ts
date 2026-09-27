import {
  StorageBucket,
  StorageBucketSchema,
  StorageObjectMetadata,
  CanonicalObjectKeyBuilder,
  SecurityContext
} from '@eh-home/contracts';

import {
  IStorageProvider,
  PutObjectOptions,
  ListObjectsResult,
  SignedUrlResult,
  StorageHealthResult
} from './storage.interface';
import { AuditService } from '../audit/audit.service';
import { AuditRepository } from '../audit/audit.repository';

export class StorageService {
  private provider: IStorageProvider;
  private auditService?: AuditService;

  constructor(provider: IStorageProvider, auditService?: AuditService) {
    this.provider = provider;
    this.auditService = auditService;
  }

  public getProvider(): IStorageProvider {
    return this.provider;
  }

  public setAuditService(auditService: AuditService): void {
    this.auditService = auditService;
  }

  private async audit(
    action: any,
    actorId: string,
    actorRole: any,
    resourceType: any,
    resourceId: string,
    outcome: 'SUCCESS' | 'DENIED' | 'FAILED',
    metadata?: Record<string, unknown>,
    failureReason?: string,
    correlationId?: string
  ): Promise<void> {
    const service = this.auditService || new AuditService(new AuditRepository());
    await service.logSecurityEvent({
      actorId,
      actorRole,
      action,
      resourceType,
      resourceId,
      outcome,
      failureReason,
      correlationId,
      metadata
    });
  }

  /**
   * Universal PutObject with bucket validation, key sanitization, and classification
   */
  public async putObject(
    bucket: StorageBucket,
    rawKey: string,
    content: Buffer | Uint8Array | string,
    options?: PutObjectOptions,
    callerContext?: SecurityContext
  ): Promise<StorageObjectMetadata> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);

    const metadata = await this.provider.putObject(bucket, key, content, options);

    if (callerContext && bucket !== 'eh-product-assets') {
      await this.audit(
        'OBJECT_STORED',
        callerContext.principal.id,
        callerContext.principal.role,
        'STORAGE',
        `${bucket}/${key}`,
        'SUCCESS',
        {
          bucket,
          key,
          sizeBytes: metadata.sizeBytes,
          sha256: metadata.sha256,
          classification: metadata.classification
        },
        undefined,
        callerContext.correlationId
      );
    }

    return metadata;
  }

  /**
   * Retrieves an object's binary content and metadata
   */
  public async getObject(
    bucket: StorageBucket,
    rawKey: string
  ): Promise<{ content: Buffer; metadata: StorageObjectMetadata }> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    return this.provider.getObject(bucket, key);
  }

  /**
   * Retrieves object metadata
   */
  public async headObject(bucket: StorageBucket, rawKey: string): Promise<StorageObjectMetadata> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    return this.provider.headObject(bucket, key);
  }

  /**
   * Deletes an object
   */
  public async deleteObject(
    bucket: StorageBucket,
    rawKey: string,
    callerContext?: SecurityContext
  ): Promise<boolean> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const deleted = await this.provider.deleteObject(bucket, key);

    if (callerContext && deleted) {
      await this.audit(
        'OBJECT_DELETED',
        callerContext.principal.id,
        callerContext.principal.role,
        'STORAGE',
        `${bucket}/${key}`,
        'SUCCESS',
        { bucket, key },
        undefined,
        callerContext.correlationId
      );
    }

    return deleted;
  }

  /**
   * Lists objects
   */
  public async listObjects(
    bucket: StorageBucket,
    prefix?: string,
    limit?: number,
    continuationToken?: string
  ): Promise<ListObjectsResult> {
    StorageBucketSchema.parse(bucket);
    return this.provider.listObjects(bucket, prefix, limit, continuationToken);
  }

  /**
   * Generates a signed URL
   */
  public async getSignedUrl(
    bucket: StorageBucket,
    rawKey: string,
    expiresInSeconds: number = 900,
    action: 'GET' | 'PUT' = 'GET'
  ): Promise<SignedUrlResult> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    return this.provider.getSignedUrl(bucket, key, expiresInSeconds, action);
  }

  /**
   * Checks existence of an object
   */
  public async hasObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    StorageBucketSchema.parse(bucket);
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    return this.provider.hasObject(bucket, key);
  }

  /**
   * Storage health check
   */
  public async isHealthy(): Promise<StorageHealthResult> {
    return this.provider.isHealthy();
  }

  // ── High-Level Domain Asset Helpers ─────────────────────────────────────

  /**
   * Uploads a Product catalog image/asset
   */
  public async uploadProductAsset(
    productId: string,
    variantId: string,
    assetId: string,
    filename: string,
    content: Buffer | Uint8Array | string,
    contentType: string = 'image/png',
    callerContext?: SecurityContext
  ): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.buildProductAssetKey(productId, variantId, assetId, filename);
    return this.putObject(
      'eh-product-assets',
      key,
      content,
      {
        contentType,
        classification: 'PUBLIC_ASSET',
        customMetadata: { productId, variantId, assetId }
      },
      callerContext
    );
  }

  /**
   * Uploads a signed Firmware binary artifact
   */
  public async uploadFirmwareBinary(
    family: string,
    version: string,
    targetMcu: string,
    sha256: string,
    content: Buffer | Uint8Array | string,
    callerContext?: SecurityContext
  ): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.buildFirmwareKey(family, version, targetMcu, sha256);
    return this.putObject(
      'eh-firmware-artifacts',
      key,
      content,
      {
        contentType: 'application/octet-stream',
        classification: 'PROTECTED_FIRMWARE',
        customMetadata: { family, version, targetMcu, sha256 }
      },
      callerContext
    );
  }

  /**
   * Uploads a Manufacturing QR / Label document
   */
  public async uploadManufacturingLabel(
    deviceId: string,
    qrToken: string,
    content: Buffer | Uint8Array | string,
    callerContext?: SecurityContext
  ): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.buildLabelKey(deviceId, qrToken);
    return this.putObject(
      'eh-manufacturing-labels',
      key,
      content,
      {
        contentType: 'application/pdf',
        classification: 'MANUFACTURING_DATA',
        customMetadata: { deviceId, qrToken }
      },
      callerContext
    );
  }
}
