import { z } from 'zod';
import { SchemaVersionSchema, HardwareRevisionCodeSchema, SemanticVersionSchema } from '../common';

export const BOMItemSchema = z.object({
  itemIndex: z.number().int().min(1),
  referenceDesignator: z.string().min(1),
  mpn: z.string().min(1),
  manufacturer: z.string().optional(),
  description: z.string().min(1),
  footprint: z.string().min(1),
  quantity: z.number().int().positive().default(1),
  isDnf: z.boolean().default(false),
  vendorPartNumber: z.string().optional(),
  unitCostInr: z.number().nonnegative().optional()
});
export type BOMItem = z.infer<typeof BOMItemSchema>;

export const BOMSpecificationStatusSchema = z.enum([
  'DRAFT',
  'ACTIVE',
  'DEPRECATED',
  'SUPERSEDED'
]);
export type BOMSpecificationStatus = z.infer<typeof BOMSpecificationStatusSchema>;

export const BOMSpecificationSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  bomId: z.string(),
  hardwareRevisionCode: HardwareRevisionCodeSchema,
  version: SemanticVersionSchema,
  lifecycleStatus: BOMSpecificationStatusSchema.default('DRAFT'),
  items: z.array(BOMItemSchema).min(1),
  totalUniqueComponents: z.number().int().positive().optional(),
  notes: z.string().optional(),
  effectiveDate: z.string().datetime().optional(),
  createdAt: z.string().datetime()
});
export type BOMSpecification = z.infer<typeof BOMSpecificationSchema>;

export const HardwareRevisionStatusSchema = z.enum([
  'DRAFT',
  'VALIDATION',
  'APPROVED',
  'ACTIVE',
  'DEPRECATED',
  'RETIRED',
  'PROTOTYPE',
  'OBSOLETE'
]);
export type HardwareRevisionStatus = z.infer<typeof HardwareRevisionStatusSchema>;

export const HardwareRevisionSchema = z.object({
  schemaVersion: SchemaVersionSchema,
  revisionCode: HardwareRevisionCodeSchema,
  productVariantId: z.string().regex(/^[a-z0-9_-]+$/),
  pcbName: z.string().min(1),
  layerCount: z.number().int().min(1).max(8).default(2),
  dimensionsMm: z.object({
    width: z.number().positive(),
    height: z.number().positive(),
    thickness: z.number().positive().default(1.6)
  }).optional(),
  pinMap: z.record(z.number().int()),
  schematicAssetUrl: z.string().url().optional(),
  gerberAssetUrl: z.string().url().optional(),
  renderAssetUrl: z.string().url().optional(),
  status: HardwareRevisionStatusSchema.default('ACTIVE'),
  createdAt: z.string().datetime()
});
export type HardwareRevision = z.infer<typeof HardwareRevisionSchema>;

export const HardwareCompatibilitySchema = z.object({
  hardwareRevisionCode: HardwareRevisionCodeSchema,
  firmwareFamily: z.string().min(1),
  minFirmwareVersion: SemanticVersionSchema,
  maxFirmwareVersion: SemanticVersionSchema.optional(),
  incompatibleFirmwareVersions: z.array(SemanticVersionSchema).default([]),
  verifiedAt: z.string().datetime()
});
export type HardwareCompatibility = z.infer<typeof HardwareCompatibilitySchema>;
