"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PRODUCT_VARIANT_NAMES = void 0;
exports.containsSecretMaterial = containsSecretMaterial;
exports.assertNoSecretsInRecord = assertNoSecretsInRecord;
exports.generateOpaqueQrToken = generateOpaqueQrToken;
exports.createOpaqueQrPayload = createOpaqueQrPayload;
exports.buildDeviceLabelData = buildDeviceLabelData;
const base_1 = require("./base");
const label_1 = require("./label");
// ── 1. Secret Detection & Sanitization Enforcer ───────────────────────
const SECRET_PATTERNS = [
    /-----BEGIN\s+([A-Z\s]+)?PRIVATE\s+KEY-----/i,
    /wifi_password/i,
    /wifi_secret/i,
    /commissioning_secret/i,
    /factory_secret/i,
    /private_key/i,
    /client_key/i,
    /ca_private/i,
    /root_ca_key/i,
    /password\s*[:=]\s*\S+/i,
];
/**
 * Checks if a string contains known secret patterns or private cryptographic material.
 */
function containsSecretMaterial(str) {
    if (!str || typeof str !== 'string')
        return false;
    return SECRET_PATTERNS.some((pat) => pat.test(str));
}
/**
 * Recursively scans an object or string and throws an error if any secret pattern is found.
 */
function assertNoSecretsInRecord(data, path = 'root') {
    if (data === null || data === undefined)
        return;
    if (typeof data === 'string') {
        if (containsSecretMaterial(data)) {
            throw new Error(`Security Violation: Secret material detected at '${path}'. Secrets must never be serialized into QR codes or labels.`);
        }
        return;
    }
    if (typeof data === 'object') {
        if (Array.isArray(data)) {
            data.forEach((item, idx) => assertNoSecretsInRecord(item, `${path}[${idx}]`));
        }
        else {
            for (const [key, value] of Object.entries(data)) {
                const lowerKey = key.toLowerCase();
                if (lowerKey.includes('secret') ||
                    lowerKey.includes('password') ||
                    lowerKey.includes('privatekey') ||
                    lowerKey.includes('private_key')) {
                    throw new Error(`Security Violation: Prohibited field name '${key}' detected at '${path}'.`);
                }
                assertNoSecretsInRecord(value, `${path}.${key}`);
            }
        }
    }
}
// ── 2. Opaque QR Token & Payload Generation ───────────────────────────
function toBase64Url(bytes) {
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    const base64 = typeof btoa === 'function' ? btoa(binary) : Buffer.from(bytes).toString('base64');
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
/**
 * Generates a high-entropy, opaque, unguessable cryptographic token (32 base64url characters).
 * Contains ZERO secrets or device credentials. Works in Node.js and browser.
 */
function generateOpaqueQrToken() {
    if (typeof globalThis !== 'undefined' && globalThis.crypto && typeof globalThis.crypto.getRandomValues === 'function') {
        const buffer = new Uint8Array(24);
        globalThis.crypto.getRandomValues(buffer);
        return toBase64Url(buffer);
    }
    // Node.js fallback
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const nodeCrypto = require('crypto');
    return nodeCrypto.randomBytes(24).toString('base64url');
}
/**
 * Generates a canonical QrPayload using an opaque token.
 * Output format: eh://p/v1?t=<OPAQUE_TOKEN>
 */
function createOpaqueQrPayload(params) {
    const token = params?.token || generateOpaqueQrToken();
    base_1.OpaqueQrTokenSchema.parse(token);
    const qrUri = `eh://p/v1?t=${token}`;
    base_1.QrUriSchema.parse(qrUri);
    const payload = {
        schemaVersion: 1,
        token,
        qrUri,
        generatedAt: params?.generatedAt || new Date().toISOString()
    };
    assertNoSecretsInRecord(payload);
    return base_1.QrPayloadSchema.parse(payload);
}
const product_1 = require("../product");
Object.defineProperty(exports, "PRODUCT_VARIANT_NAMES", { enumerable: true, get: function () { return product_1.PRODUCT_VARIANT_NAMES; } });
/**
 * Maps a verified Part 09 BenchProvisioningTraceabilityRecord into a canonical LabelDataModel.
 * Preserves deviceId, serialNumber, traceId, productVariantId, and hardwareRevision.
 * Enforces zero-secret leakage.
 */
function buildDeviceLabelData(record, opts) {
    // Ensure source record contains zero secrets
    assertNoSecretsInRecord(record);
    const token = opts?.token || generateOpaqueQrToken();
    const qrPayload = createOpaqueQrPayload({ token });
    const displayName = opts?.productDisplayName ||
        product_1.PRODUCT_VARIANT_NAMES[record.productVariantId] ||
        record.productVariantId;
    const labelData = {
        schemaVersion: 1,
        brand: 'EH Home',
        deviceId: record.deviceId,
        serialNumber: record.serialNumber,
        productVariantId: record.productVariantId,
        productDisplayName: displayName,
        productFamily: record.firmwareFamily,
        hardwareRevision: record.hardwareRevision,
        firmwareFamily: record.firmwareFamily,
        firmwareVersion: record.firmwareVersion,
        qrUri: qrPayload.qrUri,
        qrToken: qrPayload.token,
        templateId: opts?.templateId || 'device-primary-50x30-v1',
        traceId: record.traceId,
        manufacturedAt: record.provisionedAt
    };
    assertNoSecretsInRecord(labelData);
    return label_1.LabelDataModelSchema.parse(labelData);
}
//# sourceMappingURL=generator.js.map