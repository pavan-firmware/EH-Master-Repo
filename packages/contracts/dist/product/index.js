"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CANONICAL_HARDWARE_REVISIONS = exports.PRODUCT_VARIANT_NAMES = exports.CANONICAL_APPROVED_VARIANTS = exports.CANONICAL_PRODUCT_DEFINITIONS = exports.ProductCatalogEntrySchema = exports.ProductMasterSchema = exports.ProductVariantSchema = exports.ConnectivityProfileSchema = exports.HardwareProfileSchema = exports.ChannelDefSchema = exports.ProductCategorySchema = exports.ProductStatusSchema = void 0;
exports.isCanonicalProductHardwareSupported = isCanonicalProductHardwareSupported;
exports.getHardwareRevisionDescription = getHardwareRevisionDescription;
exports.getCanonicalProductDefinition = getCanonicalProductDefinition;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.ProductStatusSchema = zod_1.z.enum([
    'DRAFT',
    'STAGED',
    'PUBLISHED',
    'DEPRECATED',
    'RETIRED'
]);
exports.ProductCategorySchema = zod_1.z.enum([
    'switches',
    'sockets',
    'lighting',
    'climate',
    'fans',
    'sensors',
    'energy',
    'security',
    'appliances',
    'controllers'
]);
exports.ChannelDefSchema = zod_1.z.object({
    channelIndex: zod_1.z.number().int().min(1),
    defaultLabel: zod_1.z.string().min(1),
    capabilities: zod_1.z.array(zod_1.z.string()).min(1),
    config: zod_1.z.record(zod_1.z.unknown()).optional()
});
exports.HardwareProfileSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    mcuFamily: zod_1.z.enum(['esp32', 'esp32-c3', 'esp32-c6', 'esp32-s3', 'esp32-wroom', 'custom']),
    flashSizeBytes: zod_1.z.number().int().positive(),
    psramSizeBytes: zod_1.z.number().int().positive().nullable().optional(),
    hasEnergyMetering: zod_1.z.boolean(),
    energyMeterChip: zod_1.z.string().nullable().optional(),
    maxRelayAmpsPerChannel: zod_1.z.number().positive().optional(),
    maxTotalAmps: zod_1.z.number().positive().optional(),
    gpioMap: zod_1.z.record(zod_1.z.number().int()).default({})
});
exports.ConnectivityProfileSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    supportsWifi: zod_1.z.boolean(),
    wifiStandards: zod_1.z.array(zod_1.z.string()).default([]),
    supportsBle: zod_1.z.boolean(),
    bleVersion: zod_1.z.string().nullable().optional(),
    supportsThread: zod_1.z.boolean().default(false),
    threadVersion: zod_1.z.string().nullable().optional(),
    supportsMatter: zod_1.z.boolean().default(false),
    matterDeviceType: zod_1.z.string().nullable().optional()
});
exports.ProductVariantSchema = zod_1.z.object({
    variantId: zod_1.z.string().regex(/^[a-z0-9_-]+$/),
    modelId: zod_1.z.string().regex(/^[a-z0-9_-]+$/),
    sku: zod_1.z.string().min(1),
    marketingName: zod_1.z.string().min(1),
    technicalName: zod_1.z.string().min(1),
    channelCount: zod_1.z.number().int().min(1).max(16),
    channels: zod_1.z.array(exports.ChannelDefSchema).min(1),
    hardwareProfile: exports.HardwareProfileSchema,
    connectivityProfile: exports.ConnectivityProfileSchema,
    capabilities: zod_1.z.array(zod_1.z.string()).min(1),
    electricalSpecifications: zod_1.z.record(zod_1.z.unknown()).default({}),
    firmwareFamily: zod_1.z.string().min(1),
    supportedHardwareRevisions: zod_1.z.array(common_1.HardwareRevisionCodeSchema).min(1)
});
exports.ProductMasterSchema = zod_1.z.object({
    productId: zod_1.z.string().regex(/^[a-z0-9_-]+$/),
    slug: zod_1.z.string().regex(/^[a-z0-9-]+$/),
    displayName: zod_1.z.string().min(1),
    category: exports.ProductCategorySchema,
    description: zod_1.z.string().default(''),
    status: exports.ProductStatusSchema.default('PUBLISHED'),
    variants: zod_1.z.array(exports.ProductVariantSchema).default([]),
    metadata: zod_1.z.record(zod_1.z.unknown()).default({})
});
exports.ProductCatalogEntrySchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    name: zod_1.z.string().min(1),
    category: exports.ProductCategorySchema,
    categoryDisplayName: zod_1.z.string().min(1),
    family: zod_1.z.string().min(1),
    familyDisplayName: zod_1.z.string().min(1),
    description: zod_1.z.string().default(''),
    channelCount: zod_1.z.number().int().min(1),
    capabilities: zod_1.z.array(zod_1.z.string()),
    supportedTransports: zod_1.z.array(zod_1.z.string()),
    firmwareFamily: zod_1.z.string().min(1),
    assets: zod_1.z.object({
        diagrams: zod_1.z.record(zod_1.z.string()).default({}),
        renders: zod_1.z.record(zod_1.z.string()).default({})
    }),
    isAvailable: zod_1.z.boolean().default(true)
});
exports.CANONICAL_PRODUCT_DEFINITIONS = [
    { variantId: 'eh-smart-switch-1x', displayName: 'EH Smart Switch 1-Gang', category: 'switches', firmwareFamily: 'esp32c6-switch-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-switch-2x', displayName: 'EH Smart Switch 2-Gang', category: 'switches', firmwareFamily: 'esp32c6-switch-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-switch-3x', displayName: 'EH Smart Switch 3-Gang', category: 'switches', firmwareFamily: 'esp32c6-switch-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-switch-4x', displayName: 'EH Smart Switch 4-Gang', category: 'switches', firmwareFamily: 'esp32c6-switch-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-socket-1x', displayName: 'EH Smart Socket 1-Gang', category: 'sockets', firmwareFamily: 'esp32c6-socket-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-socket-2x', displayName: 'EH Smart Socket 2-Gang', category: 'sockets', firmwareFamily: 'esp32c6-socket-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-socket-3x', displayName: 'EH Smart Socket 3-Gang', category: 'sockets', firmwareFamily: 'esp32c6-socket-platform', supportedHardwareRevisions: ['HW_1_0', 'HW_1_1'] },
    { variantId: 'eh-smart-fan-1x', displayName: 'EH Smart Fan Controller', category: 'fans', firmwareFamily: 'esp32c6-fan-platform', supportedHardwareRevisions: ['HW_1_0'] },
    { variantId: 'eh-smart-light-cct', displayName: 'EH Smart Light CCT', category: 'lighting', firmwareFamily: 'esp32c6-light-platform', supportedHardwareRevisions: ['HW_1_0'] },
    { variantId: 'eh-smart-hub-v1', displayName: 'EH Smart Hub Gateway', category: 'controllers', firmwareFamily: 'esp32s3-hub-platform', supportedHardwareRevisions: ['HW_1_0'] },
    { variantId: 'eh-sensor-node-v1', displayName: 'EH Environmental Sensor Node', category: 'sensors', firmwareFamily: 'esp32c6-sensor-platform', supportedHardwareRevisions: ['HW_1_0'] },
];
exports.CANONICAL_APPROVED_VARIANTS = new Set(exports.CANONICAL_PRODUCT_DEFINITIONS.map((p) => p.variantId));
exports.PRODUCT_VARIANT_NAMES = Object.fromEntries(exports.CANONICAL_PRODUCT_DEFINITIONS.map((p) => [p.variantId, p.displayName]));
exports.CANONICAL_HARDWARE_REVISIONS = new Set([
    'HW_1_0',
    'HW_1_1',
]);
/**
 * Checks if a compound productVariantId + hardwareRevision is canonically supported.
 */
function isCanonicalProductHardwareSupported(productVariantId, hardwareRevision) {
    const prod = exports.CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
    return !!prod && prod.supportedHardwareRevisions.includes(hardwareRevision);
}
/**
 * Resolves the authoritative hardware description for a compound productVariantId + hardwareRevision.
 * Returns undefined if the product variant is unknown or if the revision is not supported for that variant.
 */
function getHardwareRevisionDescription(productVariantId, hardwareRevision) {
    const prod = exports.CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
    if (!prod || !prod.supportedHardwareRevisions.includes(hardwareRevision)) {
        return undefined;
    }
    switch (prod.firmwareFamily) {
        case 'esp32s3-hub-platform':
            return hardwareRevision === 'HW_1_1'
                ? 'Rev 1.1 (ESP32-S3-WROOM-1-N8R8)'
                : 'Rev 1.0 (ESP32-S3-WROOM-1)';
        case 'esp32c6-switch-platform':
        case 'esp32c6-socket-platform':
        case 'esp32c6-fan-platform':
        case 'esp32c6-light-platform':
        case 'esp32c6-sensor-platform':
        default:
            return hardwareRevision === 'HW_1_1'
                ? 'Rev 1.1 (ESP32-C6-WROOM-1-N8)'
                : 'Rev 1.0 (ESP32-C6-WROOM-1)';
    }
}
/**
 * Resolves the CanonicalProductDefinition by variant ID.
 */
function getCanonicalProductDefinition(productVariantId) {
    return exports.CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
}
//# sourceMappingURL=index.js.map