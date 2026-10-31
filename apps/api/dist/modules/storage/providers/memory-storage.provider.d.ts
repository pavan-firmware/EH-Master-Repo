import { StorageBucket, StorageObjectMetadata } from '@eh-home/contracts';
import { IStorageProvider, PutObjectOptions, ListObjectsResult, SignedUrlResult, StorageHealthResult } from '../storage.interface';
export declare class MemoryStorageProvider implements IStorageProvider {
    private buckets;
    private healthy;
    constructor();
    init(): Promise<void>;
    setHealthy(healthy: boolean): void;
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
    clear(): void;
}
//# sourceMappingURL=memory-storage.provider.d.ts.map