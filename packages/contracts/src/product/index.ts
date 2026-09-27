import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema } from '../common';

export const ProductStatusSchema = z.enum([
  'DRAFT',
  'STAGED',
  'PUBLISHED',
  'DEPRECATED',
  'RETIRED'
]);
export type ProductStatus = z.infer<typeof ProductStatusSchema>;

export const ProductCategorySchema = z.enum([
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
export type ProductCategory = z.infer<typeof ProductCategorySchema>;

export const ChannelDefSchema = z.object({
  channelIndex: z.number().int().min(1),
  defaultLabel: z.string().min(1),
  capabilities: z.array(z.string()).min(1),
  config: z.record(z.unknown()).optional()
});
export type ChannelDef = z.infer<typeof ChannelDefSchema>;

export const HardwareProfileSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  mcuFamily: z.enum(['esp32', 'esp32-c3', 'esp32-c6', 'esp32-s3', 'esp32-wroom', 'custom']),
  flashSizeBytes: z.number().int().positive(),
  psramSizeBytes: z.number().int().positive().nullable().optional(),
  hasEnergyMetering: z.boolean(),
  energyMeterChip: z.string().nullable().optional(),
  maxRelayAmpsPerChannel: z.number().positive().optional(),
  maxTotalAmps: z.number().positive().optional(),
  gpioMap: z.record(z.number().int()).default({})
});
export type HardwareProfile = z.infer<typeof HardwareProfileSchema>;

export const ConnectivityProfileSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  supportsWifi: z.boolean(),
  wifiStandards: z.array(z.string()).default([]),
  supportsBle: z.boolean(),
  bleVersion: z.string().nullable().optional(),
  supportsThread: z.boolean().default(false),
  threadVersion: z.string().nullable().optional(),
  supportsMatter: z.boolean().default(false),
  matterDeviceType: z.string().nullable().optional()
});
export type ConnectivityProfile = z.infer<typeof ConnectivityProfileSchema>;

export const ProductVariantSchema = z.object({
  variantId: z.string().regex(/^[a-z0-9_-]+$/),
  modelId: z.string().regex(/^[a-z0-9_-]+$/),
  sku: z.string().min(1),
  marketingName: z.string().min(1),
  technicalName: z.string().min(1),
  channelCount: z.number().int().min(1).max(16),
  channels: z.array(ChannelDefSchema).min(1),
  hardwareProfile: HardwareProfileSchema,
  connectivityProfile: ConnectivityProfileSchema,
  capabilities: z.array(z.string()).min(1),
  electricalSpecifications: z.record(z.unknown()).default({}),
  firmwareFamily: z.string().min(1),
  supportedHardwareRevisions: z.array(HardwareRevisionCodeSchema).min(1)
});
export type ProductVariant = z.infer<typeof ProductVariantSchema>;

export const ProductMasterSchema = z.object({
  productId: z.string().regex(/^[a-z0-9_-]+$/),
  slug: z.string().regex(/^[a-z0-9-]+$/),
  displayName: z.string().min(1),
  category: ProductCategorySchema,
  description: z.string().default(''),
  status: ProductStatusSchema.default('PUBLISHED'),
  variants: z.array(ProductVariantSchema).default([]),
  metadata: z.record(z.unknown()).default({})
});
export type ProductMaster = z.infer<typeof ProductMasterSchema>;

export const ProductCatalogEntrySchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  category: ProductCategorySchema,
  categoryDisplayName: z.string().min(1),
  family: z.string().min(1),
  familyDisplayName: z.string().min(1),
  description: z.string().default(''),
  channelCount: z.number().int().min(1),
  capabilities: z.array(z.string()),
  supportedTransports: z.array(z.string()),
  firmwareFamily: z.string().min(1),
  assets: z.object({
    diagrams: z.record(z.string()).default({}),
    renders: z.record(z.string()).default({})
  }),
  isAvailable: z.boolean().default(true)
});
export type ProductCatalogEntry = z.infer<typeof ProductCatalogEntrySchema>;

// ── Authoritative Product Catalog Source of Truth ──────────────────────

export interface CanonicalProductDefinition {
  variantId: string;
  displayName: string;
  category: ProductCategory;
  firmwareFamily: string;
  supportedHardwareRevisions: readonly string[];
}

export const CANONICAL_PRODUCT_DEFINITIONS: readonly CanonicalProductDefinition[] = [
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
] as const;

export const CANONICAL_APPROVED_VARIANTS: ReadonlySet<string> = new Set(
  CANONICAL_PRODUCT_DEFINITIONS.map((p) => p.variantId)
);

export const PRODUCT_VARIANT_NAMES: Record<string, string> = Object.fromEntries(
  CANONICAL_PRODUCT_DEFINITIONS.map((p) => [p.variantId, p.displayName])
);

export const CANONICAL_HARDWARE_REVISIONS: ReadonlySet<string> = new Set([
  'HW_1_0',
  'HW_1_1',
] as const);

/**
 * Checks if a compound productVariantId + hardwareRevision is canonically supported.
 */
export function isCanonicalProductHardwareSupported(productVariantId: string, hardwareRevision: string): boolean {
  const prod = CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
  return !!prod && prod.supportedHardwareRevisions.includes(hardwareRevision);
}

/**
 * Resolves the authoritative hardware description for a compound productVariantId + hardwareRevision.
 * Returns undefined if the product variant is unknown or if the revision is not supported for that variant.
 */
export function getHardwareRevisionDescription(productVariantId: string, hardwareRevision: string): string | undefined {
  const prod = CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
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
export function getCanonicalProductDefinition(productVariantId: string): CanonicalProductDefinition | undefined {
  return CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === productVariantId);
}

