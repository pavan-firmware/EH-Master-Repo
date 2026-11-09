import * as crypto from 'crypto';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import {
  StorageBucket,
  StorageObjectMetadata,
  CANONICAL_BUCKETS,
  CanonicalObjectKeyBuilder,
} from '@eh-home/contracts';
import {
  IStorageProvider,
  PutObjectOptions,
  ListObjectsResult,
  SignedUrlResult,
  StorageHealthResult,
} from '../storage.interface';

/** Free, persistent local storage for a single desktop/API installation. */
export class DiskStorageProvider implements IStorageProvider {
  constructor(private readonly rootDir: string) {}

  private contentPath(bucket: StorageBucket, key: string): string {
    const normalized = CanonicalObjectKeyBuilder.normalizeKey(key);
    const root = path.resolve(this.rootDir, bucket);
    const resolved = path.resolve(root, normalized);
    if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) throw new Error('Invalid storage key');
    return resolved;
  }

  private metadataPath(contentPath: string): string {
    return `${contentPath}.meta.json`;
  }

  async init(): Promise<void> {
    await Promise.all(CANONICAL_BUCKETS.map((bucket) => fs.mkdir(path.join(this.rootDir, bucket), { recursive: true })));
  }

  async putObject(bucket: StorageBucket, rawKey: string, content: Buffer | Uint8Array | string, options?: PutObjectOptions): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const target = this.contentPath(bucket, key);
    const buffer = Buffer.isBuffer(content) ? content : typeof content === 'string' ? Buffer.from(content) : Buffer.from(content);
    const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
    const metadata: StorageObjectMetadata = {
      bucket,
      key,
      sizeBytes: buffer.byteLength,
      contentType: options?.contentType || 'application/octet-stream',
      sha256,
      etag: `"${sha256.substring(0, 32)}"`,
      lastModified: new Date().toISOString(),
      classification: options?.classification || 'PUBLIC_ASSET',
      customMetadata: options?.customMetadata || {},
    };
    await fs.mkdir(path.dirname(target), { recursive: true });
    const temporary = `${target}.${process.pid}.tmp`;
    await fs.writeFile(temporary, buffer);
    await fs.rename(temporary, target);
    await fs.writeFile(this.metadataPath(target), JSON.stringify(metadata), 'utf8');
    return metadata;
  }

  async getObject(bucket: StorageBucket, rawKey: string): Promise<{ content: Buffer; metadata: StorageObjectMetadata }> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const target = this.contentPath(bucket, key);
    try {
      const [content, metadataRaw] = await Promise.all([fs.readFile(target), fs.readFile(this.metadataPath(target), 'utf8')]);
      return { content, metadata: JSON.parse(metadataRaw) as StorageObjectMetadata };
    } catch (error: any) {
      const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
      err.cause = error;
      (err as any).statusCode = 404;
      throw err;
    }
  }

  async headObject(bucket: StorageBucket, key: string): Promise<StorageObjectMetadata> { return (await this.getObject(bucket, key)).metadata; }

  async deleteObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    const target = this.contentPath(bucket, rawKey);
    try {
      await fs.rm(target);
      await fs.rm(this.metadataPath(target), { force: true });
      return true;
    } catch { return false; }
  }

  private async collect(dir: string, bucket: StorageBucket, prefix: string, result: StorageObjectMetadata[]): Promise<void> {
    for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) await this.collect(full, bucket, prefix, result);
      else if (!entry.name.endsWith('.meta.json')) {
        try {
          const raw = await fs.readFile(this.metadataPath(full), 'utf8');
          const metadata = JSON.parse(raw) as StorageObjectMetadata;
          if (!prefix || metadata.key.startsWith(prefix)) result.push(metadata);
        } catch { /* ignore incomplete files */ }
      }
    }
  }

  async listObjects(bucket: StorageBucket, prefix = '', limit = 100, continuationToken?: string): Promise<ListObjectsResult> {
    const result: StorageObjectMetadata[] = [];
    await this.collect(path.resolve(this.rootDir, bucket), bucket, prefix, result);
    result.sort((a, b) => a.key.localeCompare(b.key));
    const start = continuationToken ? Number.parseInt(continuationToken, 10) || 0 : 0;
    return { bucket, objects: result.slice(start, start + limit), continuationToken: start + limit < result.length ? String(start + limit) : undefined, isTruncated: start + limit < result.length };
  }

  async getSignedUrl(bucket: StorageBucket, rawKey: string, expiresInSeconds = 900, action: 'GET' | 'PUT' = 'GET'): Promise<SignedUrlResult> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    return { url: `https://storage.local/${bucket}/${key}?action=${action}`, expiresAt: new Date(Date.now() + expiresInSeconds * 1000).toISOString(), bucket, key };
  }

  async hasObject(bucket: StorageBucket, key: string): Promise<boolean> {
    try { await fs.access(this.contentPath(bucket, key)); return true; } catch { return false; }
  }

  async isHealthy(): Promise<StorageHealthResult> {
    try { await this.init(); return { healthy: true, provider: 'DiskStorageProvider', endpoint: this.rootDir, bucketsAvailable: [...CANONICAL_BUCKETS] }; }
    catch (error: any) { return { healthy: false, provider: 'DiskStorageProvider', error: error.message }; }
  }
}
