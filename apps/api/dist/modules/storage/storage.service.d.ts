import { StorageBucket, StorageObjectMetadata, SecurityContext } from '@eh-home/contracts';
import { IStorageProvider, PutObjectOptions, ListObjectsResult, SignedUrlResult, StorageHealthResult } from './storage.interface';
import { AuditService } from '../audit/audit.service';
export declare class StorageService {
    private provider;
    private auditService?;
    constructor(provider: IStorageProvider, auditService?: AuditService);
    getProvider(): IStorageProvider;
    setAuditService(auditService: AuditService): void;
    private audit;
    /**
     * Universal PutObject with bucket validation, key sanitization, and classification
     */
    putObject(bucket: StorageBucket, rawKey: string, content: Buffer | Uint8Array | string, options?: PutObjectOptions, callerContext?: SecurityContext): Promise<StorageObjectMetadata>;
    /**
     * Retrieves an object's binary content and metadata
     */
    getObject(bucket: StorageBucket, rawKey: string): Promise<{
        content: Buffer;
        metadata: StorageObjectMetadata;
    }>;
    /**
     * Retrieves object metadata
     */
    headObject(bucket: StorageBucket, rawKey: string): Promise<StorageObjectMetadata>;
    /**
     * Deletes an object
     */
    deleteObject(bucket: StorageBucket, rawKey: string, callerContext?: SecurityContext): Promise<boolean>;
    /**
     * Lists objects
     */
    listObjects(bucket: StorageBucket, prefix?: string, limit?: number, continuationToken?: string): Promise<ListObjectsResult>;
    /**
     * Generates a signed URL
     */
    getSignedUrl(bucket: StorageBucket, rawKey: string, expiresInSeconds?: number, action?: 'GET' | 'PUT'): Promise<SignedUrlResult>;
    /**
     * Checks existence of an object
     */
    hasObject(bucket: StorageBucket, rawKey: string): Promise<boolean>;
    /**
     * Storage health check
     */
    isHealthy(): Promise<StorageHealthResult>;
    /**
     * Uploads a Product catalog image/asset
     */
    uploadProductAsset(productId: string, variantId: string, assetId: string, filename: string, content: Buffer | Uint8Array | string, contentType?: string, callerContext?: SecurityContext): Promise<StorageObjectMetadata>;
    /**
     * Uploads a signed Firmware binary artifact
     */
    uploadFirmwareBinary(family: string, version: string, targetMcu: string, sha256: string, content: Buffer | Uint8Array | string, callerContext?: SecurityContext): Promise<StorageObjectMetadata>;
    /**
     * Uploads a Manufacturing QR / Label document
     */
    uploadManufacturingLabel(deviceId: string, qrToken: string, content: Buffer | Uint8Array | string, callerContext?: SecurityContext): Promise<StorageObjectMetadata>;
}
//# sourceMappingURL=storage.service.d.ts.map