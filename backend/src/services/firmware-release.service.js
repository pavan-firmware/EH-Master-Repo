'use strict';

/**
 * EH Home — Firmware Release Management Service (Phase 41)
 *
 * Enforces:
 * 1. Strict artifact validation (HTTPS URL, 64-char SHA256, 128-char Ed25519 signature, binary size limit)
 * 2. Immutable release integrity & canonical lifecycle (DRAFT -> PUBLISHED -> DEPRECATED / REVOKED)
 * 3. Zero secret storage (no private signing keys stored or accepted)
 * 4. Multi-channel support (development, beta, production, staging, canary)
 */

const crypto = require('crypto');

const ALLOWED_CHANNELS = ['development', 'beta', 'production', 'staging', 'canary'];
const ALLOWED_STATUSES = ['DRAFT', 'PUBLISHED', 'DEPRECATED', 'REVOKED'];
const MAX_BINARY_SIZE_BYTES = 1792 * 1024; // 1792 KB default partition limit

class FirmwareReleaseService {
  /**
   * @param {Object} opts
   * @param {Object} opts.firmwareRepo            - FirmwareReleaseRepository
   * @param {Object} [opts.operationsAuditService] - OperationsAuditService (Phase 31)
   * @param {Object} [opts.notificationService]    - NotificationService (Phase 30)
   */
  constructor({
    firmwareRepo,
    operationsAuditService = null,
    notificationService = null
  }) {
    if (!firmwareRepo) throw new Error('firmwareRepo is required for FirmwareReleaseService');
    this.firmwareRepo = firmwareRepo;
    this.auditService = operationsAuditService;
    this.notificationService = notificationService;
    this._inMemoryReleases = new Map();
  }

  // ===========================================================================
  // 1. Artifact Validation & Integrity
  // ===========================================================================

  validateArtifact(manifest) {
    if (!manifest || typeof manifest !== 'object') {
      return { valid: false, error: 'Release manifest must be a non-null object' };
    }
    const productVariantId = manifest.productVariantId || manifest.product_variant_id;
    if (!productVariantId) {
      return { valid: false, error: 'productVariantId is required' };
    }
    if (!manifest.version || typeof manifest.version !== 'string') {
      return { valid: false, error: 'version is required and must be a valid semver string' };
    }
    const downloadUrl = manifest.downloadUrl || manifest.download_url;
    if (!downloadUrl || typeof downloadUrl !== 'string') {
      return { valid: false, error: 'downloadUrl is required' };
    }
    if (!downloadUrl.startsWith('https://')) {
      return { valid: false, error: 'downloadUrl must use secure HTTPS protocol' };
    }
    if (!manifest.sha256 || typeof manifest.sha256 !== 'string' || manifest.sha256.length !== 64 || !/^[0-9a-fA-F]{64}$/.test(manifest.sha256)) {
      return { valid: false, error: 'sha256 must be a 64-character hexadecimal SHA-256 hash' };
    }
    const ed25519Signature = manifest.ed25519Signature || manifest.ed25519_signature;
    if (!ed25519Signature || typeof ed25519Signature !== 'string' || ed25519Signature.length !== 128 || !/^[0-9a-fA-F]{128}$/.test(ed25519Signature)) {
      return { valid: false, error: 'ed25519Signature must be a 128-character hexadecimal Ed25519 signature' };
    }
    const size = Number(manifest.binarySizeBytes || manifest.binary_size_bytes || 0);
    if (isNaN(size) || size <= 0) {
      return { valid: false, error: 'binarySizeBytes must be a positive integer' };
    }
    if (size > MAX_BINARY_SIZE_BYTES) {
      return { valid: false, error: `binarySizeBytes (${size}) exceeds maximum partition capacity (${MAX_BINARY_SIZE_BYTES} bytes)` };
    }

    const channel = manifest.releaseChannel || manifest.release_channel || 'production';
    if (!ALLOWED_CHANNELS.includes(channel)) {
      return { valid: false, error: `Invalid releaseChannel '${channel}'. Must be one of: ${ALLOWED_CHANNELS.join(', ')}` };
    }

    return { valid: true };
  }

  // ===========================================================================
  // 2. Release Management
  // ===========================================================================

  async createRelease(manifest, actorUserId = null) {
    const validation = this.validateArtifact(manifest);
    if (!validation.valid) {
      throw new Error(`Invalid firmware release: ${validation.error}`);
    }

    const releaseId = manifest.id || manifest.releaseId || `rel_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    const status = manifest.status || 'DRAFT';

    if (!ALLOWED_STATUSES.includes(status)) {
      throw new Error(`Invalid release status '${status}'`);
    }

    const fullRelease = {
      schemaVersion: 1,
      id: releaseId,
      releaseId,
      productVariantId: manifest.productVariantId,
      hardwareRevision: manifest.hardwareRevision || null,
      firmwareFamily: manifest.firmwareFamily || 'esp32-switch-platform',
      version: manifest.version,
      minFirmwareVersion: manifest.minFirmwareVersion || null,
      releaseChannel: manifest.releaseChannel || 'production',
      binarySizeBytes: Number(manifest.binarySizeBytes),
      sha256: manifest.sha256.toLowerCase(),
      ed25519Signature: manifest.ed25519Signature.toLowerCase(),
      downloadUrl: manifest.downloadUrl,
      releaseNotes: manifest.releaseNotes || null,
      status,
      createdAt: now,
      releasedAt: status === 'PUBLISHED' ? now : null
    };

    this._inMemoryReleases.set(releaseId, fullRelease);
    if (this.firmwareRepo && typeof this.firmwareRepo.createRelease === 'function') {
      await this.firmwareRepo.createRelease(fullRelease);
    }

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'FIRMWARE_RELEASE_CREATED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'FIRMWARE_RELEASE',
        resourceId: releaseId,
        metadata: {
          productVariantId: fullRelease.productVariantId,
          version: fullRelease.version,
          releaseChannel: fullRelease.releaseChannel,
          status: fullRelease.status
        }
      });
    }

    return fullRelease;
  }

  async publishRelease(releaseId, actorUserId = null) {
    const release = await this.getRelease(releaseId);
    if (!release) {
      throw new Error(`Firmware release '${releaseId}' not found`);
    }
    if (release.status === 'PUBLISHED') {
      return release;
    }
    if (release.status === 'REVOKED') {
      throw new Error(`Cannot publish REVOKED firmware release '${releaseId}'`);
    }

    const now = new Date().toISOString();
    release.status = 'PUBLISHED';
    release.releasedAt = now;

    this._inMemoryReleases.set(releaseId, release);
    if (this.firmwareRepo && typeof this.firmwareRepo.updateStatus === 'function') {
      await this.firmwareRepo.updateStatus(releaseId, 'PUBLISHED');
    }

    if (this.auditService) {
      await this.auditService.logOperationalEvent({
        eventType: 'FIRMWARE_RELEASE_PUBLISHED',
        source: 'ADMIN_API',
        actorUserId,
        resourceType: 'FIRMWARE_RELEASE',
        resourceId: releaseId,
        metadata: {
          productVariantId: release.productVariantId || release.product_variant_id,
          version: release.version,
          releaseChannel: release.releaseChannel || release.release_channel
        }
      });
    }

    if (this.notificationService) {
      await this.notificationService.createNotification({
        category: 'SYSTEM',
        priority: 'NORMAL',
        type: 'FIRMWARE_RELEASE_PUBLISHED',
        title: 'New Firmware Release Published',
        body: `Firmware v${release.version} published for ${release.productVariantId || release.product_variant_id} (${release.releaseChannel || release.release_channel})`,
        entityType: 'firmware_release',
        entityId: releaseId
      });
    }

    return release;
  }

  async revokeRelease(releaseId, reason = 'Security revocation', actorUserId = null) {
    const release = await this.getRelease(releaseId);
    if (!release) throw new Error(`Firmware release '${releaseId}' not found`);

    release.status = 'REVOKED';
    this._inMemoryReleases.set(releaseId, release);
    if (this.firmwareRepo && typeof this.firmwareRepo.updateStatus === 'function') {
      await this.firmwareRepo.updateStatus(releaseId, 'REVOKED');
    }

    if (this.auditService) {
      await this.auditService.logSecurityAuditRecord({
        actorUserId,
        action: 'FIRMWARE_RELEASE_REVOKED',
        resourceType: 'FIRMWARE_RELEASE',
        resourceId: releaseId,
        outcome: 'SUCCESS',
        payload: { reason, version: release.version, productVariantId: release.productVariantId || release.product_variant_id }
      });
    }

    return release;
  }

  async getRelease(releaseId) {
    if (this.firmwareRepo && typeof this.firmwareRepo.findById === 'function') {
      const found = await this.firmwareRepo.findById(releaseId);
      if (found) return found;
    }
    return this._inMemoryReleases.get(releaseId) || null;
  }

  async listReleases(filters = {}) {
    if (this.firmwareRepo && typeof this.firmwareRepo.listReleases === 'function') {
      return this.firmwareRepo.listReleases(filters);
    }
    let list = Array.from(this._inMemoryReleases.values());
    if (filters.productVariantId) {
      list = list.filter(r => (r.productVariantId || r.product_variant_id) === filters.productVariantId);
    }
    if (filters.releaseChannel) {
      list = list.filter(r => (r.releaseChannel || r.release_channel) === filters.releaseChannel);
    }
    if (filters.status) {
      list = list.filter(r => r.status === filters.status);
    }
    return list;
  }
}

module.exports = { FirmwareReleaseService, ALLOWED_CHANNELS, ALLOWED_STATUSES, MAX_BINARY_SIZE_BYTES };
