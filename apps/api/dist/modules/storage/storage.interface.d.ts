import { StorageBucket, StorageObjectMetadata, ObjectClassification } from '@eh-home/contracts';
export interface PutObjectOptions {
    contentType?: string;
    classification?: ObjectClassification;
    customMetadata?: Record<string, string>;
}
export interface ListObjectsResult {
    bucket: StorageBucket;
    objects: StorageObjectMetadata[];
    continuationToken?: string;
    isTruncated: boolean;
}
export interface SignedUrlResult {
    url: string;
    expiresAt: string;
    bucket: StorageBucket;
    key: string;
}
export interface StorageHealthResult {
    healthy: boolean;
    provider: string;
    endpoint?: string;
    bucketsAvailable?: string[];
    error?: string;
}
export interface IStorageProvider {
    /**
     * Initializes the storage provider (e.g. verifying connectivity or creating buckets)
     */
    init(): Promise<void>;
    /**
     * Uploads/Puts an object into the specified bucket
     */
    putObject(bucket: StorageBucket, key: string, content: Buffer | Uint8Array | string, options?: PutObjectOptions): Promise<StorageObjectMetadata>;
    /**
     * Retrieves an object's binary content and metadata
     */
    getObject(bucket: StorageBucket, key: string): Promise<{
        content: Buffer;
        metadata: StorageObjectMetadata;
    }>;
    /**
     * Retrieves object metadata without downloading content
     */
    headObject(bucket: StorageBucket, key: string): Promise<StorageObjectMetadata>;
    /**
     * Deletes an object from the specified bucket
     */
    deleteObject(bucket: StorageBucket, key: string): Promise<boolean>;
    /**
     * Lists objects under a bucket matching an optional prefix
     */
    listObjects(bucket: StorageBucket, prefix?: string, limit?: number, continuationToken?: string): Promise<ListObjectsResult>;
    /**
     * Generates a presigned URL for secure direct upload or download
     */
    getSignedUrl(bucket: StorageBucket, key: string, expiresInSeconds?: number, action?: 'GET' | 'PUT'): Promise<SignedUrlResult>;
    /**
     * Checks whether an object exists in the specified bucket
     */
    hasObject(bucket: StorageBucket, key: string): Promise<boolean>;
    /**
     * Probes health and connectivity to the storage backend
     */
    isHealthy(): Promise<StorageHealthResult>;
}
//# sourceMappingURL=storage.interface.d.ts.map