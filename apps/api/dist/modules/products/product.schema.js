"use strict";
/**
 * EH Home Product Domain Schemas
 *
 * Request validation schemas and response contracts for Product & Design Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateVariantBodySchema = exports.CreateVariantBodySchema = exports.UpdateProductBodySchema = exports.CreateProductBodySchema = exports.ImportDefinitionOptionsSchema = exports.ProductSummarySchema = exports.ProductDetailSchema = exports.VariantDetailSchema = exports.ProductAssetSchema = exports.GetVariantParamsSchema = exports.GetProductParamsSchema = exports.ListProductsQuerySchema = void 0;
const zod_1 = require("zod");
const contracts_1 = require("@eh-home/contracts");
// Query filter schema for listing products
exports.ListProductsQuerySchema = zod_1.z.object({
    familyId: zod_1.z.string().optional(),
    status: contracts_1.ProductStatusSchema.optional(),
    category: contracts_1.ProductCategorySchema.optional(),
    connectivity: zod_1.z.enum(['wifi', 'ble', 'thread', 'matter']).optional(),
    capability: zod_1.z.string().optional(),
    search: zod_1.z.string().optional(),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(50),
    offset: zod_1.z.coerce.number().int().min(0).default(0),
});
// Route parameters schema for product details
exports.GetProductParamsSchema = zod_1.z.object({
    productId: zod_1.z.string().min(1, { message: 'Product ID is required' }),
});
// Route parameters schema for variant details
exports.GetVariantParamsSchema = zod_1.z.object({
    variantId: zod_1.z.string().min(1, { message: 'Variant ID is required' }),
});
// Product Asset / Media metadata abstraction (Step 9)
exports.ProductAssetSchema = zod_1.z.object({
    assetId: zod_1.z.string(),
    productVariantId: zod_1.z.string(),
    kind: zod_1.z.enum([
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
    purpose: zod_1.z.enum(['marketing', 'technical', 'packaging', 'catalog', 'wiring', 'dimensions']),
    url: zod_1.z.string(),
    mimeType: zod_1.z.string().optional(),
    sortOrder: zod_1.z.number().int().default(0),
    isPublished: zod_1.z.boolean().default(true),
});
// Variant summary presentation for product detail responses
exports.VariantDetailSchema = zod_1.z.object({
    variantId: zod_1.z.string(),
    productId: zod_1.z.string(),
    variantSlug: zod_1.z.string(),
    displayName: zod_1.z.string(),
    channelCount: zod_1.z.number().int(),
    channels: zod_1.z.array(contracts_1.ChannelDefSchema),
    hardwareProfile: contracts_1.HardwareProfileSchema,
    connectivityProfile: contracts_1.ConnectivityProfileSchema,
    capabilities: zod_1.z.array(zod_1.z.string()),
    electricalSpecifications: zod_1.z.record(zod_1.z.unknown()),
    firmwareFamily: zod_1.z.string(),
    supportedHardwareRevisions: zod_1.z.array(zod_1.z.string()),
    assets: zod_1.z.array(exports.ProductAssetSchema).default([]),
    createdAt: zod_1.z.string(),
});
// Canonical Product Detail response schema
exports.ProductDetailSchema = zod_1.z.object({
    id: zod_1.z.string(),
    familyId: zod_1.z.string(),
    displayName: zod_1.z.string(),
    description: zod_1.z.string().nullable().optional(),
    schemaVersion: zod_1.z.number().int().default(1),
    status: contracts_1.ProductStatusSchema,
    variants: zod_1.z.array(exports.VariantDetailSchema),
    capabilities: zod_1.z.array(zod_1.z.string()),
    createdAt: zod_1.z.string(),
    updatedAt: zod_1.z.string(),
});
// Product summary item in catalog list
exports.ProductSummarySchema = zod_1.z.object({
    id: zod_1.z.string(),
    familyId: zod_1.z.string(),
    displayName: zod_1.z.string(),
    description: zod_1.z.string().nullable().optional(),
    status: contracts_1.ProductStatusSchema,
    variantCount: zod_1.z.number().int(),
    variantIds: zod_1.z.array(zod_1.z.string()),
    capabilities: zod_1.z.array(zod_1.z.string()),
    thumbnailUrl: zod_1.z.string().nullable().optional(),
    createdAt: zod_1.z.string(),
    updatedAt: zod_1.z.string(),
});
// Import Static Definition Options
exports.ImportDefinitionOptionsSchema = zod_1.z.object({
    dryRun: zod_1.z.boolean().default(false),
    overwriteExisting: zod_1.z.boolean().default(false),
});
// Create Product Schema
exports.CreateProductBodySchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    familyId: zod_1.z.string().min(1),
    displayName: zod_1.z.string().min(1),
    description: zod_1.z.string().optional(),
    status: contracts_1.ProductStatusSchema.default('DRAFT'),
});
// Update Product Schema
exports.UpdateProductBodySchema = zod_1.z.object({
    displayName: zod_1.z.string().optional(),
    description: zod_1.z.string().optional(),
    status: contracts_1.ProductStatusSchema.optional(),
});
// Create Variant Schema
exports.CreateVariantBodySchema = zod_1.z.object({
    id: zod_1.z.string().min(1),
    productId: zod_1.z.string().min(1),
    variantSlug: zod_1.z.string().min(1),
    displayName: zod_1.z.string().min(1),
    channelCount: zod_1.z.number().int().min(1).default(1),
    channels: zod_1.z.array(zod_1.z.any()).default([]),
    hardwareProfile: zod_1.z.any().default({}),
    connectivityProfile: zod_1.z.any().default({}),
    capabilities: zod_1.z.array(zod_1.z.string()).default([]),
    electricalSpecifications: zod_1.z.record(zod_1.z.unknown()).default({}),
    firmwareFamily: zod_1.z.string().min(1),
    supportedHardwareRevisions: zod_1.z.array(zod_1.z.string()).default(['HW_1_0']),
});
// Update Variant Schema
exports.UpdateVariantBodySchema = zod_1.z.object({
    displayName: zod_1.z.string().optional(),
    channelCount: zod_1.z.number().int().min(1).optional(),
    channels: zod_1.z.array(zod_1.z.any()).optional(),
    hardwareProfile: zod_1.z.any().optional(),
    connectivityProfile: zod_1.z.any().optional(),
    capabilities: zod_1.z.array(zod_1.z.string()).optional(),
    electricalSpecifications: zod_1.z.record(zod_1.z.unknown()).optional(),
    firmwareFamily: zod_1.z.string().optional(),
    supportedHardwareRevisions: zod_1.z.array(zod_1.z.string()).optional(),
});
//# sourceMappingURL=product.schema.js.map