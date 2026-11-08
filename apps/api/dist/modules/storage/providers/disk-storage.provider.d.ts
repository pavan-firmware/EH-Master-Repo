import { StorageBucket, StorageObjectMetadata } from '@eh-home/contracts';
import { IStorageProvider, PutObjectOptions, ListObjectsResult, SignedUrlResult, StorageHealthResult } from '../storage.interface';
/** Free, persistent local storage for a single desktop/API installation. */
export declare class DiskStorageProvider implements IStorageProvider {
    private readonly rootDir;
    constructor(rootDir: string);
    private contentPath;
    private metadataPath;
    init(): Promise<void>;
    putObject(bucket: StorageBucket, rawKey: string, content: Buffer | Uint8Array | string, options?: PutObjectOptions): Promise<StorageObjectMetadata>;
    getObject(bucket: StorageBucket, rawKey: string): Promise<{
        content: Buffer;
        metadata: StorageObjectMetadata;
    }>;
    headObject(bucket: StorageBucket, key: string): Promise<StorageObjectMetadata>;
    deleteObject(bucket: StorageBucket, rawKey: string): Promise<boolean>;
    private collect;
    listObjects(bucket: StorageBucket, prefix?: string, limit?: number, continuationToken?: string): Promise<ListObjectsResult>;
    getSignedUrl(bucket: StorageBucket, rawKey: string, expiresInSeconds?: number, action?: 'GET' | 'PUT'): Promise<SignedUrlResult>;
    hasObject(bucket: StorageBucket, key: string): Promise<boolean>;
    isHealthy(): Promise<StorageHealthResult>;
}
//# sourceMappingURL=disk-storage.provider.d.ts.map