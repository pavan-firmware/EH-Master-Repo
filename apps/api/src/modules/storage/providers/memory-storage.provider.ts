import * as crypto from 'crypto';
import {
  StorageBucket,
  StorageObjectMetadata,
  CANONICAL_BUCKETS,
  CanonicalObjectKeyBuilder
} from '@eh-home/contracts';
import {
  IStorageProvider,
  PutObjectOptions,
  ListObjectsResult,
  SignedUrlResult,
  StorageHealthResult
} from '../storage.interface';

interface StoredItem {
  content: Buffer;
  metadata: StorageObjectMetadata;
}

export class MemoryStorageProvider implements IStorageProvider {
  private buckets: Map<string, Map<string, StoredItem>> = new Map();
  private healthy = true;

  constructor() {
    for (const b of CANONICAL_BUCKETS) {
      this.buckets.set(b, new Map());
    }
  }

  public async init(): Promise<void> {
    for (const b of CANONICAL_BUCKETS) {
      if (!this.buckets.has(b)) {
        this.buckets.set(b, new Map());
      }
    }
  }

  public setHealthy(healthy: boolean): void {
    this.healthy = healthy;
  }

  public async putObject(
    bucket: StorageBucket,
    rawKey: string,
    content: Buffer | Uint8Array | string,
    options?: PutObjectOptions
  ): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const bucketStore = this.buckets.get(bucket);
    if (!bucketStore) {
      throw new Error(`BucketNotFound: Bucket '${bucket}' does not exist`);
    }

    const buf = Buffer.isBuffer(content)
      ? content
      : typeof content === 'string'
      ? Buffer.from(content, 'utf8')
      : Buffer.from(content);

    const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
    const etag = `"${sha256.substring(0, 32)}"`;

    const metadata: StorageObjectMetadata = {
      bucket,
      key,
      sizeBytes: buf.byteLength,
      contentType: options?.contentType || 'application/octet-stream',
      sha256,
      etag,
      lastModified: new Date().toISOString(),
      classification: options?.classification || 'PUBLIC_ASSET',
      customMetadata: options?.customMetadata || {}
    };

    bucketStore.set(key, { content: buf, metadata });
    return metadata;
  }

  public async getObject(
    bucket: StorageBucket,
    rawKey: string
  ): Promise<{ content: Buffer; metadata: StorageObjectMetadata }> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const bucketStore = this.buckets.get(bucket);
    if (!bucketStore) {
      throw new Error(`BucketNotFound: Bucket '${bucket}' does not exist`);
    }

    const item = bucketStore.get(key);
    if (!item) {
      const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
      (err as any).statusCode = 404;
      throw err;
    }

    return {
      content: Buffer.from(item.content),
      metadata: { ...item.metadata }
    };
  }

  public async headObject(bucket: StorageBucket, rawKey: string): Promise<StorageObjectMetadata> {
    const { metadata } = await this.getObject(bucket, rawKey);
    return metadata;
  }

  public async deleteObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const bucketStore = this.buckets.get(bucket);
    if (!bucketStore) return false;
    return bucketStore.delete(key);
  }

  public async listObjects(
    bucket: StorageBucket,
    prefix?: string,
    limit: number = 100,
    continuationToken?: string
  ): Promise<ListObjectsResult> {
    const bucketStore = this.buckets.get(bucket);
    if (!bucketStore) {
      throw new Error(`BucketNotFound: Bucket '${bucket}' does not exist`);
    }

    let items = Array.from(bucketStore.values()).map((i) => i.metadata);

    if (prefix) {
      items = items.filter((m) => m.key.startsWith(prefix));
    }

    // Sort deterministically by key
    items.sort((a, b) => a.key.localeCompare(b.key));

    const startIndex = continuationToken ? parseInt(continuationToken, 10) || 0 : 0;
    const paged = items.slice(startIndex, startIndex + limit);
    const hasMore = startIndex + limit < items.length;

    return {
      bucket,
      objects: paged,
      continuationToken: hasMore ? String(startIndex + limit) : undefined,
      isTruncated: hasMore
    };
  }

  public async getSignedUrl(
    bucket: StorageBucket,
    rawKey: string,
    expiresInSeconds: number = 900,
    action: 'GET' | 'PUT' = 'GET'
  ): Promise<SignedUrlResult> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();
    const token = crypto.randomBytes(16).toString('hex');
    const url = `https://storage.local/${bucket}/${key}?action=${action}&token=${token}&expires=${Math.floor(
      Date.now() / 1000 + expiresInSeconds
    )}`;

    return {
      url,
      expiresAt,
      bucket,
      key
    };
  }

  public async hasObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const bucketStore = this.buckets.get(bucket);
    if (!bucketStore) return false;
    return bucketStore.has(key);
  }

  public async isHealthy(): Promise<StorageHealthResult> {
    if (!this.healthy) {
      return {
        healthy: false,
        provider: 'MemoryStorageProvider',
        error: 'Storage provider simulated failure'
      };
    }

    return {
      healthy: true,
      provider: 'MemoryStorageProvider',
      bucketsAvailable: Array.from(this.buckets.keys())
    };
  }

  public clear(): void {
    for (const store of this.buckets.values()) {
      store.clear();
    }
  }
}
