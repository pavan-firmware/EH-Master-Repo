'use strict';

/**
 * Backup Provider Abstraction (Phase 33)
 *
 * Provider-neutral interface for writing, reading, verifying, and deleting backup artifacts.
 *
 * STRICT BOUNDARY:
 * - Does not claim cloud storage if only local storage is present.
 * - Computes cryptographic SHA-256 digests for all objects.
 * - Enforces atomic file writes to prevent partial/corrupt snapshots.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

class BackupProvider {
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

  calculateChecksum(data) {
    const payload = typeof data === 'string' ? data : JSON.stringify(data);
    return crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
  }
}

class LocalBackupProvider extends BackupProvider {
  /**
   * @param {Object} [opts]
   * @param {string} [opts.baseDir] - Root directory on filesystem for backup snapshots
   */
  constructor(opts = {}) {
    super();
    this.baseDir = opts.baseDir || path.resolve(process.cwd(), 'var', 'backups');
    this._ensureBaseDir();
  }

  _ensureBaseDir() {
    if (!fs.existsSync(this.baseDir)) {
      fs.mkdirSync(this.baseDir, { recursive: true });
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

    const payload = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
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
      path: targetPath
    };
  }

  async readBackupObject(backupId, objectKey) {
    const filePath = path.join(this._getBackupDir(backupId), objectKey);
    if (!fs.existsSync(filePath)) {
      throw new Error(`Backup object ${objectKey} for backup ${backupId} not found`);
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
}

class MemoryBackupProvider extends BackupProvider {
  constructor() {
    super();
    this.storage = new Map(); // backupId -> Map(objectKey -> { payload, checksum, byteSize })
  }

  async writeBackupObject(backupId, objectKey, data) {
    if (!this.storage.has(backupId)) {
      this.storage.set(backupId, new Map());
    }
    const payload = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
    const checksum = this.calculateChecksum(payload);
    const byteSize = Buffer.byteLength(payload, 'utf8');

    this.storage.get(backupId).set(objectKey, { payload, checksum, byteSize });

    return {
      objectKey,
      byteSize,
      sha256Checksum: checksum
    };
  }

  async readBackupObject(backupId, objectKey) {
    const bMap = this.storage.get(backupId);
    if (!bMap || !bMap.has(objectKey)) {
      throw new Error(`Backup object ${objectKey} for backup ${backupId} not found in memory`);
    }
    const item = bMap.get(objectKey);
    const checksum = this.calculateChecksum(item.payload);
    return {
      content: item.payload,
      data: JSON.parse(item.payload),
      byteSize: Buffer.byteLength(item.payload, 'utf8'),
      sha256Checksum: checksum
    };
  }

  async listBackupObjects(backupId) {
    const bMap = this.storage.get(backupId);
    if (!bMap) return [];
    return Array.from(bMap.keys());
  }

  async deleteBackup(backupId) {
    return this.storage.delete(backupId);
  }
}

module.exports = {
  BackupProvider,
  LocalBackupProvider,
  MemoryBackupProvider
};
