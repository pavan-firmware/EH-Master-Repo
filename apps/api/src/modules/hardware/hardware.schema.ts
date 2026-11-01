/**
 * EH Home Hardware & BOM Domain Schemas
 *
 * Request validation contracts and response schemas for Hardware & BOM Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */

import { z } from 'zod';
import {
  HardwareRevisionStatusSchema,
  BOMSpecificationStatusSchema,
  BOMItemSchema,
  HardwareRevisionCodeSchema,
  SemanticVersionSchema,
} from '@eh-home/contracts';

// Query filter schema for listing hardware revisions
export const ListHardwareRevisionsQuerySchema = z.object({
  productVariantId: z.string().optional(),
  status: HardwareRevisionStatusSchema.optional(),
  revisionCode: z.string().optional(),
  mcuFamily: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export type ListHardwareRevisionsQuery = z.infer<typeof ListHardwareRevisionsQuerySchema>;

// Route parameters schema for hardware revision details
export const GetHardwareRevisionParamsSchema = z.object({
  hardwareRevisionId: z.string().min(1, { message: 'Hardware revision ID is required' }),
});

export type GetHardwareRevisionParams = z.infer<typeof GetHardwareRevisionParamsSchema>;

// Create Hardware Revision Request Body
export const CreateHardwareRevisionBodySchema = z.object({
  id: z.string().optional(),
  revisionCode: HardwareRevisionCodeSchema,
  productVariantId: z.string().min(1),
  pcbName: z.string().min(1),
  pcbRevision: z.string().default('v1.0'),
  displayName: z.string().min(1),
  lifecycleStatus: HardwareRevisionStatusSchema.default('DRAFT'),
  layerCount: z.number().int().min(1).max(8).default(2),
  mcuFamily: z.string().default('esp32-c6'),
  dimensionsMm: z
    .object({
      width: z.number().positive(),
      height: z.number().positive(),
      thickness: z.number().positive().default(1.6),
    })
    .optional(),
  pinMap: z.record(z.number().int()).default({}),
  schematicAssetUrl: z.string().optional(),
  gerberAssetUrl: z.string().optional(),
  renderAssetUrl: z.string().optional(),
  designMetadata: z.record(z.unknown()).default({}),
});

export type CreateHardwareRevisionBody = z.infer<typeof CreateHardwareRevisionBodySchema>;

// Update Hardware Revision Status Request Body
export const UpdateHardwareRevisionStatusBodySchema = z.object({
  status: HardwareRevisionStatusSchema,
  reason: z.string().optional(),
});

export type UpdateHardwareRevisionStatusBody = z.infer<typeof UpdateHardwareRevisionStatusBodySchema>;

// Component Substitution Schema
export const ComponentSubstitutionSchema = z.object({
  id: z.string(),
  bomItemId: z.string(),
  substituteMpn: z.string().min(1),
  substituteManufacturer: z.string().optional(),
  approvalStatus: z.enum(['PENDING', 'APPROVED', 'REJECTED']).default('APPROVED'),
  qualificationNotes: z.string().optional(),
  createdAt: z.string(),
});

export type ComponentSubstitution = z.infer<typeof ComponentSubstitutionSchema>;

// Create BOM Specification Request Body
export const CreateBOMSpecificationBodySchema = z.object({
  id: z.string().optional(),
  hardwareRevisionId: z.string().min(1),
  version: SemanticVersionSchema.default('1.0.0'),
  lifecycleStatus: BOMSpecificationStatusSchema.default('DRAFT'),
  notes: z.string().optional(),
  effectiveDate: z.string().optional(),
  items: z.array(BOMItemSchema).min(1),
});

export type CreateBOMSpecificationBody = z.infer<typeof CreateBOMSpecificationBodySchema>;

// Hardware Revision Detail Presentation Schema
export const HardwareRevisionDetailSchema = z.object({
  id: z.string(),
  revisionCode: z.string(),
  productVariantId: z.string(),
  pcbName: z.string(),
  pcbRevision: z.string(),
  displayName: z.string(),
  lifecycleStatus: HardwareRevisionStatusSchema,
  layerCount: z.number().int(),
  mcuFamily: z.string(),
  dimensionsMm: z.record(z.unknown()).nullable().optional(),
  pinMap: z.record(z.number().int()),
  schematicAssetUrl: z.string().nullable().optional(),
  gerberAssetUrl: z.string().nullable().optional(),
  renderAssetUrl: z.string().nullable().optional(),
  designMetadata: z.record(z.unknown()),
  effectiveAt: z.string().nullable().optional(),
  deprecatedAt: z.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type HardwareRevisionDetail = z.infer<typeof HardwareRevisionDetailSchema>;

// Complete BOM with Items Presentation Schema
export const BOMDetailSchema = z.object({
  id: z.string(),
  hardwareRevisionId: z.string(),
  version: z.string(),
  lifecycleStatus: BOMSpecificationStatusSchema,
  totalUniqueComponents: z.number().int(),
  notes: z.string().nullable().optional(),
  effectiveDate: z.string().nullable().optional(),
  items: z.array(BOMItemSchema),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type BOMDetail = z.infer<typeof BOMDetailSchema>;
