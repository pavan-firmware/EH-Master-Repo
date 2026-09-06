'use strict';

/**
 * Backup Provider Layer (Phase 33, Phase 38)
 *
 * Provides a provider-neutral interface for writing, reading, listing, and deleting
 * disaster recovery backup artifacts with cryptographic SHA-256 verification.
 *
 * Providers:
 * - LocalBackupProvider (Local filesystem with atomic write/rename)
 * - MemoryBackupProvider (In-memory map for fast, isolated unit tests)
 * - S3BackupProvider (Enterprise remote S3-compatible object storage with AWS SigV4)
 *
 * SECURITY & RECOVERY INVARIANTS:
 * 1. Zero secret leakage: Access keys, secret keys, and credentials are NEVER logged.
 * 2. Sanitize before upload: All backup payloads MUST pass through Phase 33 secret sanitization.
 * 3. Cryptographic integrity: Every object has a SHA-256 digest computed and verified.
 * 4. Manifest consistency: Remote backups are marked COMPLETED ONLY when all objects are verified.
 * 5. Deterministic fallbacks: Local recovery remains operational even if remote storage is down.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');
const http = require('http');
const { URL } = require('url');

/**
 * Base Abstract Backup Provider
 */
class BackupProvider {
  // Snapshot Object Operations (Phase 33 contract)
  async writeBackupObject(backupId, objectKey, data) {
    throw new Error('writeBackupObject must be implemented by concrete provider');
  }

  async readBackupObject(backupId, objectKey) {
    throw new Error('readBackupObject must be implemented by concrete provider');
  }

  async listBackupObjects(backupId) {
    throw new Error('listBackupObjects must be implemented by concrete provider');
  }

  async deleteBackup(backupId) {
    throw new Error('deleteBackup must be implemented by concrete provider');
  }

  // Direct Object Storage Operations (Phase 38 extension)
  async upload(key, data, options = {}) {
    const parts = key.split('/');
    const objectKey = parts.pop();
    const backupId = parts.join('/') || 'default';
    const res = await this.writeBackupObject(backupId, objectKey, data);
    return {
      key,
      bytesWritten: res.byteSize,
      sha256: res.sha256Checksum,
      location: res.location
    };
  }

  async download(key) {
    const parts = key.split('/');
    const objectKey = parts.pop();
    const backupId = parts.join('/') || 'default';
    const res = await this.readBackupObject(backupId, objectKey);
    return Buffer.from(res.content, 'utf8');
  }

  async list(prefix = '') {
    throw new Error('list must be implemented by concrete provider');
  }

  async delete(key) {
    throw new Error('delete must be implemented by concrete provider');
  }

  async exists(key) {
    try {
      await this.download(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  async verifyChecksum(key, expectedSha256) {
    try {
      const data = await this.download(key);
      const computed = crypto.createHash('sha256').update(data).digest('hex');
      return computed === expectedSha256;
    } catch (_) {
      return false;
    }
  }

  calculateChecksum(data) {
    const payload = typeof data === 'string' ? data : JSON.stringify(data);
    return crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
  }

  getDiagnostics() {
    return {
      provider: this.constructor.name,
      configured: true
    };
  }

  async checkHealth() {
    return {
      status: 'HEALTHY',
      check: 'PASS',
      provider: this.constructor.name
    };
  }
}

/**
 * Local Filesystem Backup Provider
 */
class LocalBackupProvider extends BackupProvider {
  /**
   * @param {Object} [opts]
   * @param {string} [opts.baseDir] - Root directory on filesystem for backup snapshots
   */
  constructor(opts = {}) {
    super();
    this.baseDir = opts.baseDir || opts.localDir || path.resolve(process.cwd(), 'var', 'backups');
    this._ensureBaseDir();
  }

  _ensureBaseDir() {
    if (!fs.existsSync(this.baseDir)) {
      try {
        fs.mkdirSync(this.baseDir, { recursive: true });
      } catch (_) {}
    }
  }

  _getBackupDir(backupId) {
    return path.join(this.baseDir, backupId);
  }

  async writeBackupObject(backupId, objectKey, data) {
    const backupDir = this._getBackupDir(backupId);
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }

    const payload = typeof data === 'string' ? data : (Buffer.isBuffer(data) ? data.toString('utf8') : JSON.stringify(data, null, 2));
    const checksum = this.calculateChecksum(payload);
    const targetPath = path.join(backupDir, objectKey);
    const tempPath = `${targetPath}.tmp.${Date.now()}`;

    // Atomic write via temp file rename
    fs.writeFileSync(tempPath, payload, 'utf8');
    fs.renameSync(tempPath, targetPath);

    return {
      objectKey,
      byteSize: Buffer.byteLength(payload, 'utf8'),
      sha256Checksum: checksum,
      path: targetPath,
      location: `local://${targetPath}`
    };
  }

  async readBackupObject(backupId, objectKey) {
    const filePath = path.join(this._getBackupDir(backupId), objectKey);
    if (!fs.existsSync(filePath)) {
      const err = new Error(`Backup object ${objectKey} for backup ${backupId} not found`);
      err.code = 'OBJECT_NOT_FOUND';
      err.statusCode = 404;
      throw err;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    const checksum = this.calculateChecksum(content);
    return {
      content,
      data: JSON.parse(content),
      byteSize: Buffer.byteLength(content, 'utf8'),
      sha256Checksum: checksum
    };
  }

  async listBackupObjects(backupId) {
    const backupDir = this._getBackupDir(backupId);
    if (!fs.existsSync(backupDir)) {
      return [];
    }
    return fs.readdirSync(backupDir).filter(f => !f.endsWith('.tmp'));
  }

  async deleteBackup(backupId) {
    const backupDir = this._getBackupDir(backupId);
    if (fs.existsSync(backupDir)) {
      fs.rmSync(backupDir, { recursive: true, force: true });
      return true;
    }
    return false;
  }

  async upload(key, data, options = {}) {
    const targetPath = path.join(this.baseDir, key);
    const dir = path.dirname(targetPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const payload = Buffer.isBuffer(data) ? data : Buffer.from(typeof data === 'string' ? data : JSON.stringify(data, null, 2), 'utf8');
    const checksum = crypto.createHash('sha256').update(payload).digest('hex');
    const tempPath = `${targetPath}.tmp.${Date.now()}`;
    fs.writeFileSync(tempPath, payload);
    fs.renameSync(tempPath, targetPath);

    return {
      key,
      bytesWritten: payload.length,
      sha256: checksum,
      location: `local://${targetPath}`
    };
  }

  async download(key) {
    const targetPath = path.join(this.baseDir, key);
    if (!fs.existsSync(targetPath)) {
      const err = new Error(`Object ${key} not found`);
      err.code = 'OBJECT_NOT_FOUND';
      err.statusCode = 404;
      throw err;
    }
    return fs.readFileSync(targetPath);
  }

  async list(prefix = '') {
    const results = [];
    const walk = (dir, currentRel = '') => {
      if (!fs.existsSync(dir)) return;
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const relPath = currentRel ? `${currentRel}/${entry.name}` : entry.name;
        if (entry.isDirectory()) {
          walk(path.join(dir, entry.name), relPath);
        } else if (!entry.name.endsWith('.tmp')) {
          if (!prefix || relPath.startsWith(prefix)) {
            const stat = fs.statSync(path.join(dir, entry.name));
            results.push({ key: relPath, size: stat.size });
          }
        }
      }
    };
    walk(this.baseDir);
    return results;
  }

  async delete(key) {
    const targetPath = path.join(this.baseDir, key);
    if (fs.existsSync(targetPath)) {
      fs.unlinkSync(targetPath);
      return { success: true };
    }
    return { success: false };
  }

  async exists(key) {
    return fs.existsSync(path.join(this.baseDir, key));
  }

  getDiagnostics() {
    return {
      provider: 'LocalBackupProvider',
      configured: true,
      baseDir: this.baseDir
    };
  }

  async checkHealth() {
    try {
      this._ensureBaseDir();
      const isWritable = fs.existsSync(this.baseDir);
      return {
        status: isWritable ? 'HEALTHY' : 'UNAVAILABLE',
        check: isWritable ? 'PASS' : 'FAIL',
        provider: 'LocalBackupProvider',
        baseDir: this.baseDir
      };
    } catch (err) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        provider: 'LocalBackupProvider',
        error: err.message
      };
    }
  }
}

/**
 * Memory Backup Provider for isolated unit tests
 */
class MemoryBackupProvider extends BackupProvider {
  constructor() {
    super();
    this.storage = new Map(); // backupId -> Map(objectKey -> { payload, checksum, byteSize })
    this._flatStorage = new Map(); // key -> { payload, checksum, byteSize }
  }

  async upload(key, data, options = {}) {
    const payload = Buffer.isBuffer(data) ? data : Buffer.from(typeof data === 'string' ? data : JSON.stringify(data, null, 2), 'utf8');
    const checksum = crypto.createHash('sha256').update(payload).digest('hex');
    const byteSize = payload.length;

    if (key.startsWith('backups/')) {
      const parts = key.split('/');
      const backupId = parts[1];
      const objectKey = parts.slice(2).join('/');
      if (!this.storage.has(backupId)) {
        this.storage.set(backupId, new Map());
      }
      this.storage.get(backupId).set(objectKey, {
        payload: payload.toString('utf8'),
        checksum,
        byteSize
      });
    } else {
      this._flatStorage.set(key, { payload, checksum, byteSize });
    }

    return {
      key,
      bytesWritten: byteSize,
      sha256: checksum,
      location: `memory://${key}`
    };
  }

  async download(key) {
    if (key.startsWith('backups/')) {
      const parts = key.split('/');
      const backupId = parts[1];
      const objectKey = parts.slice(2).join('/');
      if (this.storage.has(backupId) && this.storage.get(backupId).has(objectKey)) {
        const item = this.storage.get(backupId).get(objectKey);
        return Buffer.isBuffer(item.payload) ? item.payload : Buffer.from(item.payload, 'utf8');
      }
    }
    if (this._flatStorage.has(key)) {
      const item = this._flatStorage.get(key);
      return Buffer.isBuffer(item.payload) ? item.payload : Buffer.from(item.payload, 'utf8');
    }
    const err = new Error(`Backup object ${key} not found in memory`);
    err.code = 'OBJECT_NOT_FOUND';
    err.statusCode = 404;
    throw err;
  }

  async list(prefix = '') {
    const results = [];
    for (const [backupId, map] of this.storage.entries()) {
      if (map instanceof Map) {
        for (const [objectKey, v] of map.entries()) {
          const k = `backups/${backupId}/${objectKey}`;
          if (!prefix || k.startsWith(prefix)) {
            results.push({ key: k, size: v.byteSize, sha256: v.checksum });
          }
        }
      }
    }
    for (const [k, v] of this._flatStorage.entries()) {
      if (!prefix || k.startsWith(prefix)) {
        results.push({ key: k, size: v.byteSize, sha256: v.checksum });
      }
    }
    return results;
  }

  async delete(key) {
    let existed = false;
    if (key.startsWith('backups/')) {
      const parts = key.split('/');
      const backupId = parts[1];
      const objectKey = parts.slice(2).join('/');
      if (this.storage.has(backupId)) {
        existed = this.storage.get(backupId).delete(objectKey);
      }
    }
    if (this._flatStorage.delete(key)) {
      existed = true;
    }
    return { success: existed };
  }

  async exists(key) {
    if (key.startsWith('backups/')) {
      const parts = key.split('/');
      const backupId = parts[1];
      const objectKey = parts.slice(2).join('/');
      if (this.storage.has(backupId) && this.storage.get(backupId).has(objectKey)) {
        return true;
      }
    }
    return this._flatStorage.has(key);
  }

  async writeBackupObject(backupId, objectKey, data) {
    if (!this.storage.has(backupId)) {
      this.storage.set(backupId, new Map());
    }
    const payloadStr = typeof data === 'string' ? data : (Buffer.isBuffer(data) ? data.toString('utf8') : JSON.stringify(data, null, 2));
    const checksum = this.calculateChecksum(payloadStr);
    const byteSize = Buffer.byteLength(payloadStr, 'utf8');
    const entry = {
      payload: payloadStr,
      checksum,
      byteSize
    };
    this.storage.get(backupId).set(objectKey, entry);

    return {
      objectKey,
      byteSize,
      sha256Checksum: checksum,
      location: `memory://${backupId}/${objectKey}`
    };
  }

  async readBackupObject(backupId, objectKey) {
    const backupMap = this.storage.get(backupId);
    if (!backupMap || !backupMap.has(objectKey)) {
      const err = new Error(`Backup object ${objectKey} not found for backup ${backupId}`);
      err.code = 'OBJECT_NOT_FOUND';
      err.statusCode = 404;
      throw err;
    }
    const obj = backupMap.get(objectKey);
    const checksum = this.calculateChecksum(obj.payload);
    return {
      content: obj.payload,
      data: JSON.parse(obj.payload),
      byteSize: obj.byteSize,
      sha256Checksum: checksum
    };
  }

  async listBackupObjects(backupId) {
    const backupMap = this.storage.get(backupId);
    if (!backupMap) return [];
    return Array.from(backupMap.keys());
  }

  async deleteBackup(backupId) {
    return this.storage.delete(backupId);
  }

  getDiagnostics() {
    return {
      provider: 'MemoryBackupProvider',
      configured: true,
      activeKeysCount: this.storage.size
    };
  }

  async checkHealth() {
    return {
      status: 'STANDBY',
      check: 'PASS',
      provider: 'MemoryBackupProvider',
      activeBackupsCount: this.storage.size
    };
  }
}

/**
 * Real S3-Compatible Remote Object Storage Backup Provider
 *
 * Implements standard AWS Signature Version 4 (SigV4) for authenticated
 * object storage operations across AWS S3, MinIO, Cloudflare R2, and Ceph.
 */
class S3BackupProvider extends BackupProvider {
  /**
   * @param {Object} config
   * @param {string} config.bucket - Target S3 bucket name
   * @param {string} [config.region='us-east-1'] - AWS region
   * @param {string} [config.endpoint] - Custom S3 endpoint URL (e.g. 'https://s3.amazonaws.com' or 'http://minio:9000')
   * @param {string} [config.accessKeyId] - AWS Access Key ID
   * @param {string} [config.secretAccessKey] - AWS Secret Access Key
   * @param {string} [config.prefix='backups/'] - Key prefix in bucket
   * @param {boolean} [config.forcePathStyle=false] - Force path-style addressing (/bucket/key) for MinIO
   * @param {string} [config.serverSideEncryption] - Optional SSE header ('AES256' or 'aws:kms')
   * @param {number} [config.timeoutMs=10000] - Request timeout limit
   * @param {number} [config.maxRetries=3] - Retry limit for transient errors
   * @param {Function} [config.transport] - Optional custom transport function for unit testing
   * @param {Function} [config.httpClient] - Optional custom HTTP request function for testing
   */
  constructor(config = {}) {
    super();
    this.bucket = config.bucket || process.env.BACKUP_S3_BUCKET || process.env.S3_BUCKET || null;
    this.region = config.region || process.env.BACKUP_S3_REGION || process.env.AWS_REGION || 'us-east-1';
    this.endpoint = config.endpoint || process.env.BACKUP_S3_ENDPOINT || process.env.S3_ENDPOINT || `https://s3.${this.region}.amazonaws.com`;
    this.accessKeyId = config.accessKeyId || process.env.BACKUP_S3_ACCESS_KEY_ID || process.env.AWS_ACCESS_KEY_ID || null;
    this.secretAccessKey = config.secretAccessKey || process.env.BACKUP_S3_SECRET_ACCESS_KEY || process.env.AWS_SECRET_ACCESS_KEY || null;

    let prefix = config.prefix || process.env.BACKUP_S3_PREFIX || 'backups/';
    if (!prefix.endsWith('/')) prefix += '/';
    if (prefix.startsWith('/')) prefix = prefix.substring(1);
    this.prefix = prefix;

    this.forcePathStyle = config.forcePathStyle !== undefined
      ? config.forcePathStyle
      : (process.env.BACKUP_S3_FORCE_PATH_STYLE === 'true' || this.endpoint.includes('localhost') || this.endpoint.includes('127.0.0.1'));

    this.serverSideEncryption = config.serverSideEncryption || process.env.BACKUP_S3_SSE || null;
    this.timeoutMs = config.timeoutMs || 10000;
    this.maxRetries = config.maxRetries || 3;
    this.transport = config.transport || config.httpClient || null;
  }

  get isConfigured() {
    return Boolean(this.bucket && this.accessKeyId && this.secretAccessKey);
  }

  /**
   * Resolve S3 Host and Request Path
   */
  _resolveS3Url(objectKey = '', query = '') {
    const endpointParsed = new URL(this.endpoint);
    let host = endpointParsed.hostname;
    let reqPath = '';

    if (this.forcePathStyle) {
      reqPath = `/${this.bucket}/${objectKey}`;
      host = endpointParsed.host;
    } else {
      if (endpointParsed.hostname.startsWith(`${this.bucket}.`)) {
        host = endpointParsed.host;
      } else {
        host = `${this.bucket}.${endpointParsed.host}`;
      }
      reqPath = `/${objectKey}`;
    }

    if (query) {
      reqPath += (reqPath.includes('?') ? '&' : '?') + query;
    }

    return {
      protocol: endpointParsed.protocol,
      host,
      hostname: endpointParsed.hostname,
      port: endpointParsed.port || (endpointParsed.protocol === 'https:' ? 443 : 80),
      path: reqPath
    };
  }

  /**
   * Compute AWS Signature Version 4 Headers
   */
  _signRequest({ method, path: reqPath, host, headers = {}, payload = '' }) {
    if (!this.isConfigured) {
      throw new Error('S3 backup credentials not configured (requires bucket, accessKeyId, secretAccessKey)');
    }

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);

    const payloadHash = crypto.createHash('sha256').update(payload).digest('hex');

    const signedHeadersObj = {
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      ...headers
    };

    if (this.serverSideEncryption && method === 'PUT') {
      signedHeadersObj['x-amz-server-side-encryption'] = this.serverSideEncryption;
    }

    // Sort headers for canonical request
    const sortedHeaderKeys = Object.keys(signedHeadersObj).map(k => k.toLowerCase()).sort();
    const canonicalHeaders = sortedHeaderKeys.map(k => `${k}:${String(signedHeadersObj[k]).trim()}\n`).join('');
    const signedHeaders = sortedHeaderKeys.join(';');

    const [pathname, queryString = ''] = reqPath.split('?');
    // Sort query parameters
    const canonicalQueryString = queryString
      .split('&')
      .filter(Boolean)
      .map(p => p.split('='))
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([k, v]) => `${encodeURIComponent(decodeURIComponent(k))}=${v !== undefined ? encodeURIComponent(decodeURIComponent(v)) : ''}`)
      .join('&');

    const canonicalUri = pathname.split('/').map(segment => encodeURIComponent(decodeURIComponent(segment))).join('/');

    const canonicalRequest = [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].join('\n');

    const credentialScope = `${dateStamp}/${this.region}/s3/aws4_request`;
    const stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
    ].join('\n');

    // Key derivation: kDate -> kRegion -> kService -> kSigning
    const hmac = (key, data) => crypto.createHmac('sha256', key).update(data).digest();
    const kDate = hmac(`AWS4${this.secretAccessKey}`, dateStamp);
    const kRegion = hmac(kDate, this.region);
    const kService = hmac(kRegion, 's3');
    const kSigning = hmac(kService, 'aws4_request');
    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');

    const authorizationHeader = `AWS4-HMAC-SHA256 Credential=${this.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    return {
      ...signedHeadersObj,
      'Authorization': authorizationHeader
    };
  }

  async _executeWithRetry(reqFn) {
    let lastErr = null;
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        const response = await reqFn();
        if (response.statusCode === 503 || response.statusCode === 429) {
          if (attempt < this.maxRetries) {
            await new Promise(r => setTimeout(r, 50 * Math.pow(2, attempt - 1)));
            continue;
          }
        }
        return response;
      } catch (err) {
        lastErr = err;
        if (attempt < this.maxRetries && !err.message?.includes('timed out')) {
          await new Promise(r => setTimeout(r, 50 * Math.pow(2, attempt - 1)));
          continue;
        }
        throw err;
      }
    }
    throw lastErr;
  }

  async upload(key, data, options = {}) {
    const payload = Buffer.isBuffer(data) ? data : Buffer.from(typeof data === 'string' ? data : JSON.stringify(data, null, 2), 'utf8');
    const checksum = crypto.createHash('sha256').update(payload).digest('hex');
    const cleanKey = key.startsWith('/') ? key.substring(1) : key;
    const s3Key = cleanKey.startsWith(this.prefix) ? cleanKey : `${this.prefix}${cleanKey}`;

    const urlInfo = this._resolveS3Url(s3Key);
    const headers = {
      'content-type': options.contentType || 'application/json',
      'content-length': payload.length
    };

    const signedHeaders = this._signRequest({
      method: 'PUT',
      path: urlInfo.path,
      host: urlInfo.host,
      headers,
      payload
    });

    const response = await this._executeWithRetry(() => this._makeHttpRequest({
      protocol: urlInfo.protocol,
      hostname: urlInfo.hostname,
      port: urlInfo.port,
      path: urlInfo.path,
      method: 'PUT',
      headers: signedHeaders,
      body: payload
    }));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`S3 write error for ${key} (${response.statusCode}): ${response.body}`);
    }

    return {
      key,
      bytesWritten: payload.length,
      sha256: checksum,
      location: `s3://${this.bucket}/${s3Key}`,
      serverSideEncryption: response.headers?.['x-amz-server-side-encryption'] || this.serverSideEncryption || null
    };
  }

  async download(key) {
    const cleanKey = key.startsWith('/') ? key.substring(1) : key;
    const s3Key = cleanKey.startsWith(this.prefix) ? cleanKey : `${this.prefix}${cleanKey}`;
    const urlInfo = this._resolveS3Url(s3Key);

    const signedHeaders = this._signRequest({
      method: 'GET',
      path: urlInfo.path,
      host: urlInfo.host,
      payload: ''
    });

    const response = await this._executeWithRetry(() => this._makeHttpRequest({
      protocol: urlInfo.protocol,
      hostname: urlInfo.hostname,
      port: urlInfo.port,
      path: urlInfo.path,
      method: 'GET',
      headers: signedHeaders
    }));

    if (response.statusCode === 404) {
      const err = new Error(`Object ${key} not found in remote S3 storage`);
      err.code = 'OBJECT_NOT_FOUND';
      err.statusCode = 404;
      throw err;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`S3 read error for ${key} (${response.statusCode}): ${response.body}`);
    }

    return Buffer.isBuffer(response.body) ? response.body : Buffer.from(response.body, 'utf8');
  }

  async list(prefix = '') {
    const cleanPrefix = prefix.startsWith('/') ? prefix.substring(1) : prefix;
    const fullPrefix = cleanPrefix.startsWith(this.prefix) ? cleanPrefix : `${this.prefix}${cleanPrefix}`;
    const query = `list-type=2&prefix=${encodeURIComponent(fullPrefix)}`;
    const urlInfo = this._resolveS3Url('', query);

    const signedHeaders = this._signRequest({
      method: 'GET',
      path: urlInfo.path,
      host: urlInfo.host,
      payload: ''
    });

    const response = await this._executeWithRetry(() => this._makeHttpRequest({
      protocol: urlInfo.protocol,
      hostname: urlInfo.hostname,
      port: urlInfo.port,
      path: urlInfo.path,
      method: 'GET',
      headers: signedHeaders
    }));

    if (response.statusCode !== 200) {
      throw new Error(`S3 list error (${response.statusCode}): ${response.body}`);
    }

    const keys = [];
    const keyRegex = /<Key>(.*?)<\/Key>/g;
    const sizeRegex = /<Size>(\d+)<\/Size>/g;
    let match;
    while ((match = keyRegex.exec(response.body)) !== null) {
      const fullKey = match[1];
      const relKey = fullKey.startsWith(this.prefix) ? fullKey.substring(this.prefix.length) : fullKey;
      if (relKey && !relKey.endsWith('/')) {
        keys.push({ key: relKey, size: 0 });
      }
    }

    return keys;
  }

  async delete(key) {
    const cleanKey = key.startsWith('/') ? key.substring(1) : key;
    const s3Key = cleanKey.startsWith(this.prefix) ? cleanKey : `${this.prefix}${cleanKey}`;
    const urlInfo = this._resolveS3Url(s3Key);

    const signedHeaders = this._signRequest({
      method: 'DELETE',
      path: urlInfo.path,
      host: urlInfo.host,
      payload: ''
    });

    const response = await this._executeWithRetry(() => this._makeHttpRequest({
      protocol: urlInfo.protocol,
      hostname: urlInfo.hostname,
      port: urlInfo.port,
      path: urlInfo.path,
      method: 'DELETE',
      headers: signedHeaders
    }));

    return { success: response.statusCode === 204 || response.statusCode === 200 };
  }

  async exists(key) {
    try {
      await this.download(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Snapshot Object Operations (Phase 33 contract)
  async writeBackupObject(backupId, objectKey, data) {
    const key = `backups/${backupId}/${objectKey}`;
    const res = await this.upload(key, data);
    return {
      objectKey,
      byteSize: res.bytesWritten,
      sha256Checksum: res.sha256,
      location: res.location,
      serverSideEncryption: res.serverSideEncryption
    };
  }

  async readBackupObject(backupId, objectKey) {
    const key = `backups/${backupId}/${objectKey}`;
    const buf = await this.download(key);
    const content = buf.toString('utf8');
    const checksum = this.calculateChecksum(content);
    return {
      content,
      data: JSON.parse(content),
      byteSize: buf.length,
      sha256Checksum: checksum
    };
  }

  async listBackupObjects(backupId) {
    const prefix = `backups/${backupId}/`;
    const objs = await this.list(prefix);
    return objs.map(o => o.key.substring(prefix.length));
  }

  async deleteBackup(backupId) {
    const prefix = `backups/${backupId}/`;
    const objs = await this.list(prefix);
    for (const obj of objs) {
      await this.delete(obj.key);
    }
    return true;
  }

  getDiagnostics() {
    return {
      provider: 'S3BackupProvider',
      configured: this.isConfigured,
      bucket: this.bucket,
      region: this.region,
      prefix: this.prefix
    };
  }

  async checkHealth() {
    if (!this.isConfigured) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        provider: 'S3BackupProvider',
        error: 'Missing required S3 configuration (BACKUP_S3_BUCKET, BACKUP_S3_ACCESS_KEY_ID, BACKUP_S3_SECRET_ACCESS_KEY)'
      };
    }

    try {
      const query = `list-type=2&max-keys=1&prefix=${encodeURIComponent(this.prefix)}`;
      const urlInfo = this._resolveS3Url('', query);

      const signedHeaders = this._signRequest({
        method: 'GET',
        path: urlInfo.path,
        host: urlInfo.host,
        payload: ''
      });

      const response = await this._makeHttpRequest({
        protocol: urlInfo.protocol,
        hostname: urlInfo.hostname,
        port: urlInfo.port,
        path: urlInfo.path,
        method: 'GET',
        headers: signedHeaders
      });

      const isHealthy = response.statusCode === 200;
      return {
        status: isHealthy ? 'HEALTHY' : 'DEGRADED',
        check: isHealthy ? 'PASS' : 'FAIL',
        provider: 'S3BackupProvider',
        bucket: this.bucket,
        region: this.region,
        prefix: this.prefix,
        statusCode: response.statusCode
      };
    } catch (err) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        provider: 'S3BackupProvider',
        bucket: this.bucket,
        error: err.message
      };
    }
  }

  async _makeHttpRequest({ protocol, hostname, port, path: reqPath, method, headers, body }) {
    if (typeof this.transport === 'function') {
      const fullUrl = `${protocol}//${hostname}:${port}${reqPath}`;
      let timer;
      const timeoutPromise = new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`S3 HTTP request timed out after ${this.timeoutMs}ms`)), this.timeoutMs);
      });
      try {
        const res = await Promise.race([
          this.transport(fullUrl, { method, headers, body }),
          timeoutPromise
        ]);
        clearTimeout(timer);
        return res;
      } catch (err) {
        clearTimeout(timer);
        throw err;
      }
    }

    return new Promise((resolve, reject) => {
      const isHttps = protocol === 'https:';
      const transportModule = isHttps ? https : http;

      const req = transportModule.request({
        protocol,
        hostname,
        port,
        path: reqPath,
        method,
        headers,
        timeout: this.timeoutMs
      }, (res) => {
        let resBody = '';
        res.setEncoding('utf8');
        res.on('data', chunk => { resBody += chunk; });
        res.on('end', () => {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: resBody
          });
        });
      });

      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy(new Error(`S3 HTTP request timed out after ${this.timeoutMs}ms`));
      });

      if (body) {
        req.write(body);
      }
      req.end();
    });
  }
}

/**
 * Factory for creating backup providers with explicit mode selection
 */
function createBackupProvider(type = process.env.BACKUP_PROVIDER_TYPE || 'local', options = {}) {
  const normalizedType = String(type).trim().toLowerCase();

  switch (normalizedType) {
    case 's3':
    case 'remote':
    case 'cloud':
      return new S3BackupProvider(options);

    case 'memory':
    case 'test':
      return new MemoryBackupProvider(options);

    case 'local':
    default:
      return new LocalBackupProvider(options);
  }
}

module.exports = {
  BackupProvider,
  LocalBackupProvider,
  MemoryBackupProvider,
  S3BackupProvider,
  createBackupProvider
};
