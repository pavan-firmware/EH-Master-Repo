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
exports.S3StorageProvider = void 0;
const crypto = __importStar(require("crypto"));
const contracts_1 = require("@eh-home/contracts");
class S3StorageProvider {
    endpoint;
    region;
    accessKeyId;
    secretAccessKey;
    forcePathStyle;
    constructor(config) {
        this.endpoint = config.endpoint.replace(/\/+$/, '');
        this.region = config.region || 'us-east-1';
        this.accessKeyId = config.accessKeyId;
        this.secretAccessKey = config.secretAccessKey;
        this.forcePathStyle = config.forcePathStyle ?? true;
    }
    /**
     * Generates AWS SigV4 Signing Key
     */
    getSigningKey(dateStamp) {
        const kDate = crypto.createHmac('sha256', 'AWS4' + this.secretAccessKey).update(dateStamp).digest();
        const kRegion = crypto.createHmac('sha256', kDate).update(this.region).digest();
        const kService = crypto.createHmac('sha256', kRegion).update('s3').digest();
        return crypto.createHmac('sha256', kService).update('aws4_request').digest();
    }
    /**
     * Builds AWS SigV4 Authorization Headers
     */
    buildAuthHeaders(method, canonicalUri, queryParams, headers, payloadHash) {
        const now = new Date();
        const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
        const dateStamp = amzDate.substring(0, 8);
        const allHeaders = {
            ...headers,
            'x-amz-date': amzDate,
            'x-amz-content-sha256': payloadHash
        };
        const host = new URL(this.endpoint).host;
        allHeaders['host'] = host;
        // Canonical headers
        const sortedHeaderKeys = Object.keys(allHeaders).map((k) => k.toLowerCase()).sort();
        const canonicalHeaders = sortedHeaderKeys
            .map((k) => `${k}:${(allHeaders[k] ?? '').trim()}\n`)
            .join('');
        const signedHeaders = sortedHeaderKeys.join(';');
        // Canonical query string
        const canonicalQueryString = Object.keys(queryParams)
            .sort()
            .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k] ?? '')}`)
            .join('&');
        const canonicalRequest = [
            method.toUpperCase(),
            canonicalUri,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].join('\n');
        const algorithm = 'AWS4-HMAC-SHA256';
        const credentialScope = `${dateStamp}/${this.region}/s3/aws4_request`;
        const stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            crypto.createHash('sha256').update(canonicalRequest).digest('hex')
        ].join('\n');
        const signingKey = this.getSigningKey(dateStamp);
        const signature = crypto.createHmac('sha256', signingKey).update(stringToSign).digest('hex');
        const authorization = `${algorithm} Credential=${this.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;
        return {
            ...allHeaders,
            authorization
        };
    }
    buildUrl(bucket, key) {
        const sanitizedKey = key ? contracts_1.CanonicalObjectKeyBuilder.normalizeKey(key) : '';
        let uri;
        let url;
        if (this.forcePathStyle) {
            uri = `/${bucket}${sanitizedKey ? '/' + encodeURI(sanitizedKey) : ''}`;
            url = `${this.endpoint}${uri}`;
        }
        else {
            uri = sanitizedKey ? `/${encodeURI(sanitizedKey)}` : '/';
            const endpointUrl = new URL(this.endpoint);
            url = `${endpointUrl.protocol}//${bucket}.${endpointUrl.host}${uri}`;
        }
        return { url, uri };
    }
    async init() {
        // Check and create canonical buckets if missing
        for (const bucket of contracts_1.CANONICAL_BUCKETS) {
            try {
                const { url, uri } = this.buildUrl(bucket);
                const headers = this.buildAuthHeaders('HEAD', uri, {}, {}, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
                const res = await fetch(url, { method: 'HEAD', headers });
                if (res.status === 404) {
                    // Create bucket
                    const putHeaders = this.buildAuthHeaders('PUT', uri, {}, {}, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
                    await fetch(url, { method: 'PUT', headers: putHeaders });
                }
            }
            catch {
                // In local environments where MinIO is not running, fail gracefully on init
            }
        }
    }
    async putObject(bucket, rawKey, content, options) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const buf = Buffer.isBuffer(content)
            ? content
            : typeof content === 'string'
                ? Buffer.from(content, 'utf8')
                : Buffer.from(content);
        const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
        const { url, uri } = this.buildUrl(bucket, key);
        const reqHeaders = {
            'content-type': options?.contentType || 'application/octet-stream',
            'content-length': String(buf.byteLength)
        };
        if (options?.classification) {
            reqHeaders['x-amz-meta-classification'] = options.classification;
        }
        if (options?.customMetadata) {
            for (const [k, v] of Object.entries(options.customMetadata)) {
                reqHeaders[`x-amz-meta-${k.toLowerCase()}`] = String(v);
            }
        }
        const authHeaders = this.buildAuthHeaders('PUT', uri, {}, reqHeaders, sha256);
        const response = await fetch(url, {
            method: 'PUT',
            headers: authHeaders,
            body: buf
        });
        if (!response.ok) {
            const errText = await response.text();
            throw new Error(`S3 PutObject failed [${response.status}]: ${errText}`);
        }
        const etag = response.headers.get('etag') || `"${sha256.substring(0, 32)}"`;
        return {
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
    }
    async getObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const { url, uri } = this.buildUrl(bucket, key);
        const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const authHeaders = this.buildAuthHeaders('GET', uri, {}, {}, emptyHash);
        const response = await fetch(url, {
            method: 'GET',
            headers: authHeaders
        });
        if (response.status === 404) {
            const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
            err.statusCode = 404;
            throw err;
        }
        if (!response.ok) {
            const errText = await response.text();
            throw new Error(`S3 GetObject failed [${response.status}]: ${errText}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        const content = Buffer.from(arrayBuffer);
        const sha256 = crypto.createHash('sha256').update(content).digest('hex');
        const metadata = {
            bucket,
            key,
            sizeBytes: content.byteLength,
            contentType: response.headers.get('content-type') || 'application/octet-stream',
            sha256,
            etag: response.headers.get('etag') || `"${sha256.substring(0, 32)}"`,
            lastModified: response.headers.get('last-modified') || new Date().toISOString(),
            classification: response.headers.get('x-amz-meta-classification') || 'PUBLIC_ASSET',
            customMetadata: {}
        };
        return { content, metadata };
    }
    async headObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const { url, uri } = this.buildUrl(bucket, key);
        const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const authHeaders = this.buildAuthHeaders('HEAD', uri, {}, {}, emptyHash);
        const response = await fetch(url, {
            method: 'HEAD',
            headers: authHeaders
        });
        if (response.status === 404) {
            const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
            err.statusCode = 404;
            throw err;
        }
        if (!response.ok) {
            throw new Error(`S3 HeadObject failed with HTTP ${response.status}`);
        }
        const contentLength = parseInt(response.headers.get('content-length') || '0', 10);
        const etag = response.headers.get('etag') || '';
        return {
            bucket,
            key,
            sizeBytes: contentLength,
            contentType: response.headers.get('content-type') || 'application/octet-stream',
            sha256: etag.replace(/"/g, ''),
            etag,
            lastModified: response.headers.get('last-modified') || new Date().toISOString(),
            classification: response.headers.get('x-amz-meta-classification') || 'PUBLIC_ASSET',
            customMetadata: {}
        };
    }
    async deleteObject(bucket, rawKey) {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const { url, uri } = this.buildUrl(bucket, key);
        const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const authHeaders = this.buildAuthHeaders('DELETE', uri, {}, {}, emptyHash);
        const response = await fetch(url, {
            method: 'DELETE',
            headers: authHeaders
        });
        return response.ok || response.status === 204 || response.status === 404;
    }
    async listObjects(bucket, prefix, limit = 100, continuationToken) {
        const { url, uri } = this.buildUrl(bucket);
        const queryParams = {
            'list-type': '2',
            'max-keys': String(limit)
        };
        if (prefix)
            queryParams['prefix'] = prefix;
        if (continuationToken)
            queryParams['continuation-token'] = continuationToken;
        const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const authHeaders = this.buildAuthHeaders('GET', uri, queryParams, {}, emptyHash);
        const qs = Object.keys(queryParams)
            .sort()
            .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k] ?? '')}`)
            .join('&');
        const fullUrl = `${url}?${qs}`;
        const response = await fetch(fullUrl, { method: 'GET', headers: authHeaders });
        if (!response.ok) {
            const errText = await response.text();
            throw new Error(`S3 ListObjects failed [${response.status}]: ${errText}`);
        }
        const xml = await response.text();
        // Parse key contents from XML using lightweight regex
        const objects = [];
        const keyMatches = Array.from(xml.matchAll(/<Contents>[\s\S]*?<Key>(.*?)<\/Key>[\s\S]*?<Size>(\d+)<\/Size>[\s\S]*?<ETag>(.*?)<\/ETag>[\s\S]*?<\/Contents>/g));
        for (const match of keyMatches) {
            const key = match[1] || '';
            const size = parseInt(match[2] || '0', 10);
            const etag = match[3] || '';
            objects.push({
                bucket,
                key,
                sizeBytes: size,
                contentType: 'application/octet-stream',
                sha256: etag.replace(/["&quot;]/g, ''),
                etag,
                lastModified: new Date().toISOString(),
                classification: 'PUBLIC_ASSET',
                customMetadata: {}
            });
        }
        const isTruncated = xml.includes('<IsTruncated>true</IsTruncated>');
        const nextContTokenMatch = xml.match(/<NextContinuationToken>(.*?)<\/NextContinuationToken>/);
        return {
            bucket,
            objects,
            continuationToken: nextContTokenMatch ? nextContTokenMatch[1] : undefined,
            isTruncated
        };
    }
    async getSignedUrl(bucket, rawKey, expiresInSeconds = 900, action = 'GET') {
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const { url, uri } = this.buildUrl(bucket, key);
        const now = new Date();
        const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
        const dateStamp = amzDate.substring(0, 8);
        const credentialScope = `${dateStamp}/${this.region}/s3/aws4_request`;
        const host = new URL(this.endpoint).host;
        const queryParams = {
            'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
            'X-Amz-Credential': `${this.accessKeyId}/${credentialScope}`,
            'X-Amz-Date': amzDate,
            'X-Amz-Expires': String(expiresInSeconds),
            'X-Amz-SignedHeaders': 'host'
        };
        const canonicalHeaders = `host:${host}\n`;
        const signedHeaders = 'host';
        const canonicalQueryString = Object.keys(queryParams)
            .sort()
            .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k] ?? '')}`)
            .join('&');
        const canonicalRequest = [
            action.toUpperCase(),
            uri,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            'UNSIGNED-PAYLOAD'
        ].join('\n');
        const stringToSign = [
            'AWS4-HMAC-SHA256',
            amzDate,
            credentialScope,
            crypto.createHash('sha256').update(canonicalRequest).digest('hex')
        ].join('\n');
        const signingKey = this.getSigningKey(dateStamp);
        const signature = crypto.createHmac('sha256', signingKey).update(stringToSign).digest('hex');
        const presignedUrl = `${url}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
        const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();
        return {
            url: presignedUrl,
            expiresAt,
            bucket,
            key
        };
    }
    async hasObject(bucket, rawKey) {
        try {
            await this.headObject(bucket, rawKey);
            return true;
        }
        catch {
            return false;
        }
    }
    async isHealthy() {
        try {
            const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
            const authHeaders = this.buildAuthHeaders('GET', '/', {}, {}, emptyHash);
            const res = await fetch(`${this.endpoint}/`, { method: 'GET', headers: authHeaders });
            return {
                healthy: res.ok || res.status === 200 || res.status === 403,
                provider: 'S3StorageProvider',
                endpoint: this.endpoint,
                bucketsAvailable: [...contracts_1.CANONICAL_BUCKETS]
            };
        }
        catch (err) {
            return {
                healthy: false,
                provider: 'S3StorageProvider',
                endpoint: this.endpoint,
                error: err?.message || 'Storage connection refused'
            };
        }
    }
}
exports.S3StorageProvider = S3StorageProvider;
//# sourceMappingURL=s3-storage.provider.js.map