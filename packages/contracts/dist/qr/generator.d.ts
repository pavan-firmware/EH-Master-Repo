import { QrPayload } from './base';
import { LabelDataModel, LabelTemplateId } from './label';
import { BenchProvisioningTraceabilityRecord } from '../provisioning';
/**
 * Checks if a string contains known secret patterns or private cryptographic material.
 */
export declare function containsSecretMaterial(str: string): boolean;
/**
 * Recursively scans an object or string and throws an error if any secret pattern is found.
 */
export declare function assertNoSecretsInRecord(data: unknown, path?: string): void;
/**
 * Generates a high-entropy, opaque, unguessable cryptographic token (32 base64url characters).
 * Contains ZERO secrets or device credentials. Works in Node.js and browser.
 */
export declare function generateOpaqueQrToken(): string;
/**
 * Generates a canonical QrPayload using an opaque token.
 * Output format: eh://p/v1?t=<OPAQUE_TOKEN>
 */
export declare function createOpaqueQrPayload(params?: {
    token?: string;
    generatedAt?: string;
}): QrPayload;
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
export declare function buildDeviceLabelData(record: BenchProvisioningTraceabilityRecord, opts?: BuildLabelDataOptions): LabelDataModel;
//# sourceMappingURL=generator.d.ts.map