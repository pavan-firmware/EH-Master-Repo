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
exports.DiskStorageProvider = void 0;
const crypto = __importStar(require("crypto"));
const fs = __importStar(require("node:fs/promises"));
const path = __importStar(require("node:path"));
const contracts_1 = require("@eh-home/contracts");
/** Free, persistent local storage for a single desktop/API installation. */
class DiskStorageProvider {
    rootDir;
    constructor(rootDir) {
        this.rootDir = rootDir;
    }
    contentPath(bucket, key) {
        const normalized = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(key);
        const root = path.resolve(this.rootDir, bucket);
        const resolved = path.resolve(root, normalized);
        if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`))
            throw new Error('Invalid storage key');
        return resolved;
    }
    metadataPath(contentPath) {
        return `${contentPath}.meta.json`;
    }
    async init() {
        await Promise.all(contracts_1.CANONICAL_BUCKETS.map((bucket) => fs.mkdir(path.join(this.rootDir, bucket), { recursive: true })));
    }
    async putObject(bucket, rawKey, content, options) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const target = this.contentPath(bucket, key);
        const buffer = Buffer.isBuffer(content) ? content : typeof content === 'string' ? Buffer.from(content) : Buffer.from(content);
        const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
        const metadata = {
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
    async getObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const target = this.contentPath(bucket, key);
        try {
            const [content, metadataRaw] = await Promise.all([fs.readFile(target), fs.readFile(this.metadataPath(target), 'utf8')]);
            return { content, metadata: JSON.parse(metadataRaw) };
        }
        catch (error) {
            const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
            err.cause = error;
            err.statusCode = 404;
            throw err;
        }
    }
    async headObject(bucket, key) { return (await this.getObject(bucket, key)).metadata; }
    async deleteObject(bucket, rawKey) {
        const target = this.contentPath(bucket, rawKey);
        try {
            await fs.rm(target);
            await fs.rm(this.metadataPath(target), { force: true });
            return true;
        }
        catch {
            return false;
        }
    }
    async collect(dir, bucket, prefix, result) {
        for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory())
                await this.collect(full, bucket, prefix, result);
            else if (!entry.name.endsWith('.meta.json')) {
                try {
                    const raw = await fs.readFile(this.metadataPath(full), 'utf8');
                    const metadata = JSON.parse(raw);
                    if (!prefix || metadata.key.startsWith(prefix))
                        result.push(metadata);
                }
                catch { /* ignore incomplete files */ }
            }
        }
    }
    async listObjects(bucket, prefix = '', limit = 100, continuationToken) {
        const result = [];
        await this.collect(path.resolve(this.rootDir, bucket), bucket, prefix, result);
        result.sort((a, b) => a.key.localeCompare(b.key));
        const start = continuationToken ? Number.parseInt(continuationToken, 10) || 0 : 0;
        return { bucket, objects: result.slice(start, start + limit), continuationToken: start + limit < result.length ? String(start + limit) : undefined, isTruncated: start + limit < result.length };
    }
    async getSignedUrl(bucket, rawKey, expiresInSeconds = 900, action = 'GET') {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        return { url: `https://storage.local/${bucket}/${key}?action=${action}`, expiresAt: new Date(Date.now() + expiresInSeconds * 1000).toISOString(), bucket, key };
    }
    async hasObject(bucket, key) {
        try {
            await fs.access(this.contentPath(bucket, key));
            return true;
        }
        catch {
            return false;
        }
    }
    async isHealthy() {
        try {
            await this.init();
            return { healthy: true, provider: 'DiskStorageProvider', endpoint: this.rootDir, bucketsAvailable: [...contracts_1.CANONICAL_BUCKETS] };
        }
        catch (error) {
            return { healthy: false, provider: 'DiskStorageProvider', error: error.message };
        }
    }
}
exports.DiskStorageProvider = DiskStorageProvider;
//# sourceMappingURL=disk-storage.provider.js.map