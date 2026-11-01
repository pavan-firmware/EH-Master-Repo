"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StorageService = void 0;
const contracts_1 = require("@eh-home/contracts");
const audit_service_1 = require("../audit/audit.service");
const audit_repository_1 = require("../audit/audit.repository");
class StorageService {
    provider;
    auditService;
    constructor(provider, auditService) {
        this.provider = provider;
        this.auditService = auditService;
    }
    getProvider() {
        return this.provider;
    }
    setAuditService(auditService) {
        this.auditService = auditService;
    }
    async audit(action, actorId, actorRole, resourceType, resourceId, outcome, metadata, failureReason, correlationId) {
        const service = this.auditService || new audit_service_1.AuditService(new audit_repository_1.AuditRepository());
        await service.logSecurityEvent({
            actorId,
            actorRole,
            action,
            resourceType,
            resourceId,
            outcome,
            failureReason,
            correlationId,
            metadata
        });
    }
    /**
     * Universal PutObject with bucket validation, key sanitization, and classification
     */
    async putObject(bucket, rawKey, content, options, callerContext) {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const metadata = await this.provider.putObject(bucket, key, content, options);
        if (callerContext && bucket !== 'eh-product-assets') {
            await this.audit('OBJECT_STORED', callerContext.principal.id, callerContext.principal.role, 'STORAGE', `${bucket}/${key}`, 'SUCCESS', {
                bucket,
                key,
                sizeBytes: metadata.sizeBytes,
                sha256: metadata.sha256,
                classification: metadata.classification
            }, undefined, callerContext.correlationId);
        }
        return metadata;
    }
    /**
     * Retrieves an object's binary content and metadata
     */
    async getObject(bucket, rawKey) {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        return this.provider.getObject(bucket, key);
    }
    /**
     * Retrieves object metadata
     */
    async headObject(bucket, rawKey) {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        return this.provider.headObject(bucket, key);
    }
    /**
     * Deletes an object
     */
    async deleteObject(bucket, rawKey, callerContext) {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        const deleted = await this.provider.deleteObject(bucket, key);
        if (callerContext && deleted) {
            await this.audit('OBJECT_DELETED', callerContext.principal.id, callerContext.principal.role, 'STORAGE', `${bucket}/${key}`, 'SUCCESS', { bucket, key }, undefined, callerContext.correlationId);
        }
        return deleted;
    }
    /**
     * Lists objects
     */
    async listObjects(bucket, prefix, limit, continuationToken) {
        contracts_1.StorageBucketSchema.parse(bucket);
        return this.provider.listObjects(bucket, prefix, limit, continuationToken);
    }
    /**
     * Generates a signed URL
     */
    async getSignedUrl(bucket, rawKey, expiresInSeconds = 900, action = 'GET') {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        return this.provider.getSignedUrl(bucket, key, expiresInSeconds, action);
    }
    /**
     * Checks existence of an object
     */
    async hasObject(bucket, rawKey) {
        contracts_1.StorageBucketSchema.parse(bucket);
        const key = contracts_1.CanonicalObjectKeyBuilder.normalizeKey(rawKey);
        return this.provider.hasObject(bucket, key);
    }
    /**
     * Storage health check
     */
    async isHealthy() {
        return this.provider.isHealthy();
    }
    // ── High-Level Domain Asset Helpers ─────────────────────────────────────
    /**
     * Uploads a Product catalog image/asset
     */
    async uploadProductAsset(productId, variantId, assetId, filename, content, contentType = 'image/png', callerContext) {
        const key = contracts_1.CanonicalObjectKeyBuilder.buildProductAssetKey(productId, variantId, assetId, filename);
        return this.putObject('eh-product-assets', key, content, {
            contentType,
            classification: 'PUBLIC_ASSET',
            customMetadata: { productId, variantId, assetId }
        }, callerContext);
    }
    /**
     * Uploads a signed Firmware binary artifact
     */
    async uploadFirmwareBinary(family, version, targetMcu, sha256, content, callerContext) {
        const key = contracts_1.CanonicalObjectKeyBuilder.buildFirmwareKey(family, version, targetMcu, sha256);
        return this.putObject('eh-firmware-artifacts', key, content, {
            contentType: 'application/octet-stream',
            classification: 'PROTECTED_FIRMWARE',
            customMetadata: { family, version, targetMcu, sha256 }
        }, callerContext);
    }
    /**
     * Uploads a Manufacturing QR / Label document
     */
    async uploadManufacturingLabel(deviceId, qrToken, content, callerContext) {
        const key = contracts_1.CanonicalObjectKeyBuilder.buildLabelKey(deviceId, qrToken);
        return this.putObject('eh-manufacturing-labels', key, content, {
            contentType: 'application/pdf',
            classification: 'MANUFACTURING_DATA',
            customMetadata: { deviceId, qrToken }
        }, callerContext);
    }
}
exports.StorageService = StorageService;
//# sourceMappingURL=storage.service.js.map