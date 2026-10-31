/**
 * EH Home Product Domain Schemas
 *
 * Request validation schemas and response contracts for Product & Design Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */

import { z } from 'zod';
import {
  ProductStatusSchema,
  ProductCategorySchema,
  HardwareProfileSchema,
  ConnectivityProfileSchema,
  ChannelDefSchema,
} from '@eh-home/contracts';

// Query filter schema for listing products
export const ListProductsQuerySchema = z.object({
  familyId: z.string().optional(),
  status: ProductStatusSchema.optional(),
  category: ProductCategorySchema.optional(),
  connectivity: z.enum(['wifi', 'ble', 'thread', 'matter']).optional(),
  capability: z.string().optional(),
  search: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export type ListProductsQuery = z.infer<typeof ListProductsQuerySchema>;

// Route parameters schema for product details
export const GetProductParamsSchema = z.object({
  productId: z.string().min(1, { message: 'Product ID is required' }),
});

export type GetProductParams = z.infer<typeof GetProductParamsSchema>;

// Route parameters schema for variant details
export const GetVariantParamsSchema = z.object({
  variantId: z.string().min(1, { message: 'Variant ID is required' }),
});

export type GetVariantParams = z.infer<typeof GetVariantParamsSchema>;

// Product Asset / Media metadata abstraction (Step 9)
export const ProductAssetSchema = z.object({
  assetId: z.string(),
  productVariantId: z.string(),
  kind: z.enum([
    'hero',
    'front',
    'rear',
    'installed',
    'packaging',
    'technicalDiagram',
    'diagram',
    'render',
    'icon',
    'thumbnail',
  ]),
  purpose: z.enum(['marketing', 'technical', 'packaging', 'catalog', 'wiring', 'dimensions']),
  url: z.string(),
  mimeType: z.string().optional(),
  sortOrder: z.number().int().default(0),
  isPublished: z.boolean().default(true),
});

export type ProductAsset = z.infer<typeof ProductAssetSchema>;

// Variant summary presentation for product detail responses
export const VariantDetailSchema = z.object({
  variantId: z.string(),
  productId: z.string(),
  variantSlug: z.string(),
  displayName: z.string(),
  channelCount: z.number().int(),
  channels: z.array(ChannelDefSchema),
  hardwareProfile: HardwareProfileSchema,
  connectivityProfile: ConnectivityProfileSchema,
  capabilities: z.array(z.string()),
  electricalSpecifications: z.record(z.unknown()),
  firmwareFamily: z.string(),
  supportedHardwareRevisions: z.array(z.string()),
  assets: z.array(ProductAssetSchema).default([]),
  createdAt: z.string(),
});

export type VariantDetail = z.infer<typeof VariantDetailSchema>;

// Canonical Product Detail response schema
export const ProductDetailSchema = z.object({
  id: z.string(),
  familyId: z.string(),
  displayName: z.string(),
  description: z.string().nullable().optional(),
  schemaVersion: z.number().int().default(1),
  status: ProductStatusSchema,
  variants: z.array(VariantDetailSchema),
  capabilities: z.array(z.string()),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type ProductDetail = z.infer<typeof ProductDetailSchema>;

// Product summary item in catalog list
export const ProductSummarySchema = z.object({
  id: z.string(),
  familyId: z.string(),
  displayName: z.string(),
  description: z.string().nullable().optional(),
  status: ProductStatusSchema,
  variantCount: z.number().int(),
  variantIds: z.array(z.string()),
  capabilities: z.array(z.string()),
  thumbnailUrl: z.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type ProductSummary = z.infer<typeof ProductSummarySchema>;

// Import Static Definition Options
export const ImportDefinitionOptionsSchema = z.object({
  dryRun: z.boolean().default(false),
  overwriteExisting: z.boolean().default(false),
});

export type ImportDefinitionOptions = z.infer<typeof ImportDefinitionOptionsSchema>;

// Create Product Schema
export const CreateProductBodySchema = z.object({
  id: z.string().min(1),
  familyId: z.string().min(1),
  displayName: z.string().min(1),
  description: z.string().optional(),
  status: ProductStatusSchema.default('DRAFT'),
});

export type CreateProductBody = z.infer<typeof CreateProductBodySchema>;

// Update Product Schema
export const UpdateProductBodySchema = z.object({
  displayName: z.string().optional(),
  description: z.string().optional(),
  status: ProductStatusSchema.optional(),
});

export type UpdateProductBody = z.infer<typeof UpdateProductBodySchema>;

// Create Variant Schema
export const CreateVariantBodySchema = z.object({
  id: z.string().min(1),
  productId: z.string().min(1),
  variantSlug: z.string().min(1),
  displayName: z.string().min(1),
  channelCount: z.number().int().min(1).default(1),
  channels: z.array(z.any()).default([]),
  hardwareProfile: z.any().default({}),
  connectivityProfile: z.any().default({}),
  capabilities: z.array(z.string()).default([]),
  electricalSpecifications: z.record(z.unknown()).default({}),
  firmwareFamily: z.string().min(1),
  supportedHardwareRevisions: z.array(z.string()).default(['HW_1_0']),
});

export type CreateVariantBody = z.infer<typeof CreateVariantBodySchema>;

// Update Variant Schema
export const UpdateVariantBodySchema = z.object({
  displayName: z.string().optional(),
  channelCount: z.number().int().min(1).optional(),
  channels: z.array(z.any()).optional(),
  hardwareProfile: z.any().optional(),
  connectivityProfile: z.any().optional(),
  capabilities: z.array(z.string()).optional(),
  electricalSpecifications: z.record(z.unknown()).optional(),
  firmwareFamily: z.string().optional(),
  supportedHardwareRevisions: z.array(z.string()).optional(),
});

export type UpdateVariantBody = z.infer<typeof UpdateVariantBodySchema>;

