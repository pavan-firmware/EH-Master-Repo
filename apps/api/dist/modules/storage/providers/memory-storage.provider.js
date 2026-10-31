"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.MemoryStorageProvider = void 0;
const crypto = __importStar(require("crypto"));
const contracts_1 = require("@eh-home/contracts");
class MemoryStorageProvider {
    buckets = new Map();
    healthy = true;
    constructor() {
        for (const b of contracts_1.CANONICAL_BUCKETS) {
            this.buckets.set(b, new Map());
        }
    }
    async init() {
        for (const b of contracts_1.CANONICAL_BUCKETS) {
            if (!this.buckets.has(b)) {
                this.buckets.set(b, new Map());
            }
        }
    }
    setHealthy(healthy) {
        this.healthy = healthy;
    }
    async putObject(bucket, rawKey, content, options) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
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
        const metadata = {
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
    async getObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const bucketStore = this.buckets.get(bucket);
        if (!bucketStore) {
            throw new Error(`BucketNotFound: Bucket '${bucket}' does not exist`);
        }
        const item = bucketStore.get(key);
        if (!item) {
            const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
            err.statusCode = 404;
            throw err;
        }
        return {
            content: Buffer.from(item.content),
            metadata: { ...item.metadata }
        };
    }
    async headObject(bucket, rawKey) {
        const { metadata } = await this.getObject(bucket, rawKey);
        return metadata;
    }
    async deleteObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const bucketStore = this.buckets.get(bucket);
        if (!bucketStore)
            return false;
        return bucketStore.delete(key);
    }
    async listObjects(bucket, prefix, limit = 100, continuationToken) {
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
    async getSignedUrl(bucket, rawKey, expiresInSeconds = 900, action = 'GET') {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();
        const token = crypto.randomBytes(16).toString('hex');
        const url = `https://storage.local/${bucket}/${key}?action=${action}&token=${token}&expires=${Math.floor(Date.now() / 1000 + expiresInSeconds)}`;
        return {
            url,
            expiresAt,
            bucket,
            key
        };
    }
    async hasObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const bucketStore = this.buckets.get(bucket);
        if (!bucketStore)
            return false;
        return bucketStore.has(key);
    }
    async isHealthy() {
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
    clear() {
        for (const store of this.buckets.values()) {
            store.clear();
        }
    }
}
exports.MemoryStorageProvider = MemoryStorageProvider;
//# sourceMappingURL=memory-storage.provider.js.map