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

export interface S3StorageConfig {
  endpoint: string; // e.g. http://127.0.0.1:9000 or https://s3.amazonaws.com
  region?: string;  // default 'us-east-1'
  accessKeyId: string;
  secretAccessKey: string;
  forcePathStyle?: boolean; // default true for MinIO
}

export class S3StorageProvider implements IStorageProvider {
  private endpoint: string;
  private region: string;
  private accessKeyId: string;
  private secretAccessKey: string;
  private forcePathStyle: boolean;

  constructor(config: S3StorageConfig) {
    this.endpoint = config.endpoint.replace(/\/+$/, '');
    this.region = config.region || 'us-east-1';
    this.accessKeyId = config.accessKeyId;
    this.secretAccessKey = config.secretAccessKey;
    this.forcePathStyle = config.forcePathStyle ?? true;
  }

  /**
   * Generates AWS SigV4 Signing Key
   */
  private getSigningKey(dateStamp: string): Buffer {
    const kDate = crypto.createHmac('sha256', 'AWS4' + this.secretAccessKey).update(dateStamp).digest();
    const kRegion = crypto.createHmac('sha256', kDate).update(this.region).digest();
    const kService = crypto.createHmac('sha256', kRegion).update('s3').digest();
    return crypto.createHmac('sha256', kService).update('aws4_request').digest();
  }

  /**
   * Builds AWS SigV4 Authorization Headers
   */
  private buildAuthHeaders(
    method: string,
    canonicalUri: string,
    queryParams: Record<string, string>,
    headers: Record<string, string>,
    payloadHash: string
  ): Record<string, string> {
    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);

    const allHeaders: Record<string, string> = {
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

  private buildUrl(bucket: string, key?: string): { url: string; uri: string } {
    const sanitizedKey = key ? CanonicalObjectKeyBuilder.normalizeKey(key) : '';
    let uri: string;
    let url: string;

    if (this.forcePathStyle) {
      uri = `/${bucket}${sanitizedKey ? '/' + encodeURI(sanitizedKey) : ''}`;
      url = `${this.endpoint}${uri}`;
    } else {
      uri = sanitizedKey ? `/${encodeURI(sanitizedKey)}` : '/';
      const endpointUrl = new URL(this.endpoint);
      url = `${endpointUrl.protocol}//${bucket}.${endpointUrl.host}${uri}`;
    }

    return { url, uri };
  }

  public async init(): Promise<void> {
    // Check and create canonical buckets if missing
    for (const bucket of CANONICAL_BUCKETS) {
      try {
        const { url, uri } = this.buildUrl(bucket);
        const headers = this.buildAuthHeaders(
          'HEAD',
          uri,
          {},
          {},
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        );
        const res = await fetch(url, { method: 'HEAD', headers });
        if (res.status === 404) {
          // Create bucket
          const putHeaders = this.buildAuthHeaders(
            'PUT',
            uri,
            {},
            {},
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
          );
          await fetch(url, { method: 'PUT', headers: putHeaders });
        }
      } catch {
        // In local environments where MinIO is not running, fail gracefully on init
      }
    }
  }

  public async putObject(
    bucket: StorageBucket,
    rawKey: string,
    content: Buffer | Uint8Array | string,
    options?: PutObjectOptions
  ): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const buf = Buffer.isBuffer(content)
      ? content
      : typeof content === 'string'
      ? Buffer.from(content, 'utf8')
      : Buffer.from(content);

    const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
    const { url, uri } = this.buildUrl(bucket, key);

    const reqHeaders: Record<string, string> = {
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

  public async getObject(
    bucket: StorageBucket,
    rawKey: string
  ): Promise<{ content: Buffer; metadata: StorageObjectMetadata }> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const { url, uri } = this.buildUrl(bucket, key);
    const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    const authHeaders = this.buildAuthHeaders('GET', uri, {}, {}, emptyHash);

    const response = await fetch(url, {
      method: 'GET',
      headers: authHeaders
    });

    if (response.status === 404) {
      const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
      (err as any).statusCode = 404;
      throw err;
    }

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`S3 GetObject failed [${response.status}]: ${errText}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    const content = Buffer.from(arrayBuffer);
    const sha256 = crypto.createHash('sha256').update(content).digest('hex');

    const metadata: StorageObjectMetadata = {
      bucket,
      key,
      sizeBytes: content.byteLength,
      contentType: response.headers.get('content-type') || 'application/octet-stream',
      sha256,
      etag: response.headers.get('etag') || `"${sha256.substring(0, 32)}"`,
      lastModified: response.headers.get('last-modified') || new Date().toISOString(),
      classification: (response.headers.get('x-amz-meta-classification') as any) || 'PUBLIC_ASSET',
      customMetadata: {}
    };

    return { content, metadata };
  }

  public async headObject(bucket: StorageBucket, rawKey: string): Promise<StorageObjectMetadata> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const { url, uri } = this.buildUrl(bucket, key);
    const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    const authHeaders = this.buildAuthHeaders('HEAD', uri, {}, {}, emptyHash);

    const response = await fetch(url, {
      method: 'HEAD',
      headers: authHeaders
    });

    if (response.status === 404) {
      const err = new Error(`NoSuchKey: Object '${key}' not found in bucket '${bucket}'`);
      (err as any).statusCode = 404;
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
      classification: (response.headers.get('x-amz-meta-classification') as any) || 'PUBLIC_ASSET',
      customMetadata: {}
    };
  }

  public async deleteObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const { url, uri } = this.buildUrl(bucket, key);
    const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    const authHeaders = this.buildAuthHeaders('DELETE', uri, {}, {}, emptyHash);

    const response = await fetch(url, {
      method: 'DELETE',
      headers: authHeaders
    });

    return response.ok || response.status === 204 || response.status === 404;
  }

  public async listObjects(
    bucket: StorageBucket,
    prefix?: string,
    limit: number = 100,
    continuationToken?: string
  ): Promise<ListObjectsResult> {
    const { url, uri } = this.buildUrl(bucket);
    const queryParams: Record<string, string> = {
      'list-type': '2',
      'max-keys': String(limit)
    };
    if (prefix) queryParams['prefix'] = prefix;
    if (continuationToken) queryParams['continuation-token'] = continuationToken;

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
    const objects: StorageObjectMetadata[] = [];
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

  public async getSignedUrl(
    bucket: StorageBucket,
    rawKey: string,
    expiresInSeconds: number = 900,
    action: 'GET' | 'PUT' = 'GET'
  ): Promise<SignedUrlResult> {
    const key = CanonicalObjectKeyBuilder.normalizeKey(rawKey);
    const { url, uri } = this.buildUrl(bucket, key);
    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);
    const credentialScope = `${dateStamp}/${this.region}/s3/aws4_request`;

    const host = new URL(this.endpoint).host;
    const queryParams: Record<string, string> = {
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

  public async hasObject(bucket: StorageBucket, rawKey: string): Promise<boolean> {
    try {
      await this.headObject(bucket, rawKey);
      return true;
    } catch {
      return false;
    }
  }

  public async isHealthy(): Promise<StorageHealthResult> {
    try {
      const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      const authHeaders = this.buildAuthHeaders('GET', '/', {}, {}, emptyHash);
      const res = await fetch(`${this.endpoint}/`, { method: 'GET', headers: authHeaders });
      
      return {
        healthy: res.ok || res.status === 200 || res.status === 403,
        provider: 'S3StorageProvider',
        endpoint: this.endpoint,
        bucketsAvailable: [...CANONICAL_BUCKETS]
      };
    } catch (err: any) {
      return {
        healthy: false,
        provider: 'S3StorageProvider',
        endpoint: this.endpoint,
        error: err?.message || 'Storage connection refused'
      };
    }
  }
}
