import { QrPayload, QrPayloadSchema, OpaqueQrTokenSchema, QrUriSchema } from './base';
import { LabelDataModel, LabelDataModelSchema, LabelTemplateId } from './label';
import { BenchProvisioningTraceabilityRecord } from '../provisioning';

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
export function containsSecretMaterial(str: string): boolean {
  if (!str || typeof str !== 'string') return false;
  return SECRET_PATTERNS.some((pat) => pat.test(str));
}

/**
 * Recursively scans an object or string and throws an error if any secret pattern is found.
 */
export function assertNoSecretsInRecord(data: unknown, path = 'root'): void {
  if (data === null || data === undefined) return;

  if (typeof data === 'string') {
    if (containsSecretMaterial(data)) {
      throw new Error(`Security Violation: Secret material detected at '${path}'. Secrets must never be serialized into QR codes or labels.`);
    }
    return;
  }

  if (typeof data === 'object') {
    if (Array.isArray(data)) {
      data.forEach((item, idx) => assertNoSecretsInRecord(item, `${path}[${idx}]`));
    } else {
      for (const [key, value] of Object.entries(data)) {
        const lowerKey = key.toLowerCase();
        if (
          lowerKey.includes('secret') ||
          lowerKey.includes('password') ||
          lowerKey.includes('privatekey') ||
          lowerKey.includes('private_key')
        ) {
          throw new Error(`Security Violation: Prohibited field name '${key}' detected at '${path}'.`);
        }
        assertNoSecretsInRecord(value, `${path}.${key}`);
      }
    }
  }
}

// ── 2. Opaque QR Token & Payload Generation ───────────────────────────

function toBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  const base64 = typeof btoa === 'function' ? btoa(binary) : Buffer.from(bytes).toString('base64');
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * Generates a high-entropy, opaque, unguessable cryptographic token (32 base64url characters).
 * Contains ZERO secrets or device credentials. Works in Node.js and browser.
 */
export function generateOpaqueQrToken(): string {
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
export function createOpaqueQrPayload(params?: { token?: string; generatedAt?: string }): QrPayload {
  const token = params?.token || generateOpaqueQrToken();
  OpaqueQrTokenSchema.parse(token);

  const qrUri = `eh://p/v1?t=${token}`;
  QrUriSchema.parse(qrUri);

  const payload: QrPayload = {
    schemaVersion: 1,
    token,
    qrUri,
    generatedAt: params?.generatedAt || new Date().toISOString()
  };

  assertNoSecretsInRecord(payload);
  return QrPayloadSchema.parse(payload);
}

import { PRODUCT_VARIANT_NAMES } from '../product';

export { PRODUCT_VARIANT_NAMES };

export interface BuildLabelDataOptions {
  token?: string;
  productDisplayName?: string;
  templateId?: LabelTemplateId;
}

/**
 * Maps a verified Part 09 BenchProvisioningTraceabilityRecord into a canonical LabelDataModel.
 * Preserves deviceId, serialNumber, traceId, productVariantId, and hardwareRevision.
 * Enforces zero-secret leakage.
 */
export function buildDeviceLabelData(
  record: BenchProvisioningTraceabilityRecord,
  opts?: BuildLabelDataOptions
): LabelDataModel {
  // Ensure source record contains zero secrets
  assertNoSecretsInRecord(record);

  const token = opts?.token || generateOpaqueQrToken();
  const qrPayload = createOpaqueQrPayload({ token });

  const displayName =
    opts?.productDisplayName ||
    PRODUCT_VARIANT_NAMES[record.productVariantId] ||
    record.productVariantId;

  const labelData: LabelDataModel = {
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
  return LabelDataModelSchema.parse(labelData);
}
