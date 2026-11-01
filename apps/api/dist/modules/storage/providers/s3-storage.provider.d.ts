import { StorageBucket, StorageObjectMetadata } from '@eh-home/contracts';
import { IStorageProvider, PutObjectOptions, ListObjectsResult, SignedUrlResult, StorageHealthResult } from '../storage.interface';
export interface S3StorageConfig {
    endpoint: string;
    region?: string;
    accessKeyId: string;
    secretAccessKey: string;
    forcePathStyle?: boolean;
}
export declare class S3StorageProvider implements IStorageProvider {
    private endpoint;
    private region;
    private accessKeyId;
    private secretAccessKey;
    private forcePathStyle;
    constructor(config: S3StorageConfig);
    /**
     * Generates AWS SigV4 Signing Key
     */
    private getSigningKey;
    /**
     * Builds AWS SigV4 Authorization Headers
     */
    private buildAuthHeaders;
    private buildUrl;
    init(): Promise<void>;
    putObject(bucket: StorageBucket, rawKey: string, content: Buffer | Uint8Array | string, options?: PutObjectOptions): Promise<StorageObjectMetadata>;
    getObject(bucket: StorageBucket, rawKey: string): Promise<{
        content: Buffer;
        metadata: StorageObjectMetadata;
    }>;
    headObject(bucket: StorageBucket, rawKey: string): Promise<StorageObjectMetadata>;
    deleteObject(bucket: StorageBucket, rawKey: string): Promise<boolean>;
    listObjects(bucket: StorageBucket, prefix?: string, limit?: number, continuationToken?: string): Promise<ListObjectsResult>;
    getSignedUrl(bucket: StorageBucket, rawKey: string, expiresInSeconds?: number, action?: 'GET' | 'PUT'): Promise<SignedUrlResult>;
    hasObject(bucket: StorageBucket, rawKey: string): Promise<boolean>;
    isHealthy(): Promise<StorageHealthResult>;
}
//# sourceMappingURL=s3-storage.provider.d.ts.map