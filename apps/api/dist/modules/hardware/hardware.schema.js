"use strict";
/**
 * EH Home Hardware & BOM Domain Schemas
 *
 * Request validation contracts and response schemas for Hardware & BOM Management.
 * Reuses canonical contracts from @eh-home/contracts.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.BOMDetailSchema = exports.HardwareRevisionDetailSchema = exports.CreateBOMSpecificationBodySchema = exports.ComponentSubstitutionSchema = exports.UpdateHardwareRevisionStatusBodySchema = exports.CreateHardwareRevisionBodySchema = exports.GetHardwareRevisionParamsSchema = exports.ListHardwareRevisionsQuerySchema = void 0;
const zod_1 = require("zod");
const contracts_1 = require("@eh-home/contracts");
// Query filter schema for listing hardware revisions
exports.ListHardwareRevisionsQuerySchema = zod_1.z.object({
    productVariantId: zod_1.z.string().optional(),
    status: contracts_1.HardwareRevisionStatusSchema.optional(),
    revisionCode: zod_1.z.string().optional(),
    mcuFamily: zod_1.z.string().optional(),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(50),
    offset: zod_1.z.coerce.number().int().min(0).default(0),
});
// Route parameters schema for hardware revision details
exports.GetHardwareRevisionParamsSchema = zod_1.z.object({
    hardwareRevisionId: zod_1.z.string().min(1, { message: 'Hardware revision ID is required' }),
});
// Create Hardware Revision Request Body
exports.CreateHardwareRevisionBodySchema = zod_1.z.object({
    id: zod_1.z.string().optional(),
    revisionCode: contracts_1.HardwareRevisionCodeSchema,
    productVariantId: zod_1.z.string().min(1),
    pcbName: zod_1.z.string().min(1),
    pcbRevision: zod_1.z.string().default('v1.0'),
    displayName: zod_1.z.string().min(1),
    lifecycleStatus: contracts_1.HardwareRevisionStatusSchema.default('DRAFT'),
    layerCount: zod_1.z.number().int().min(1).max(8).default(2),
    mcuFamily: zod_1.z.string().default('esp32-c6'),
    dimensionsMm: zod_1.z
        .object({
        width: zod_1.z.number().positive(),
        height: zod_1.z.number().positive(),
        thickness: zod_1.z.number().positive().default(1.6),
    })
        .optional(),
    pinMap: zod_1.z.record(zod_1.z.number().int()).default({}),
    schematicAssetUrl: zod_1.z.string().optional(),
    gerberAssetUrl: zod_1.z.string().optional(),
    renderAssetUrl: zod_1.z.string().optional(),
    designMetadata: zod_1.z.record(zod_1.z.unknown()).default({}),
});
// Update Hardware Revision Status Request Body
exports.UpdateHardwareRevisionStatusBodySchema = zod_1.z.object({
    status: contracts_1.HardwareRevisionStatusSchema,
    reason: zod_1.z.string().optional(),
});
// Component Substitution Schema
exports.ComponentSubstitutionSchema = zod_1.z.object({
    id: zod_1.z.string(),
    bomItemId: zod_1.z.string(),
    substituteMpn: zod_1.z.string().min(1),
    substituteManufacturer: zod_1.z.string().optional(),
    approvalStatus: zod_1.z.enum(['PENDING', 'APPROVED', 'REJECTED']).default('APPROVED'),
    qualificationNotes: zod_1.z.string().optional(),
    createdAt: zod_1.z.string(),
});
// Create BOM Specification Request Body
exports.CreateBOMSpecificationBodySchema = zod_1.z.object({
    id: zod_1.z.string().optional(),
    hardwareRevisionId: zod_1.z.string().min(1),
    version: contracts_1.SemanticVersionSchema.default('1.0.0'),
    lifecycleStatus: contracts_1.BOMSpecificationStatusSchema.default('DRAFT'),
    notes: zod_1.z.string().optional(),
    effectiveDate: zod_1.z.string().optional(),
    items: zod_1.z.array(contracts_1.BOMItemSchema).min(1),
});
// Hardware Revision Detail Presentation Schema
exports.HardwareRevisionDetailSchema = zod_1.z.object({
    id: zod_1.z.string(),
    revisionCode: zod_1.z.string(),
    productVariantId: zod_1.z.string(),
    pcbName: zod_1.z.string(),
    pcbRevision: zod_1.z.string(),
    displayName: zod_1.z.string(),
    lifecycleStatus: contracts_1.HardwareRevisionStatusSchema,
    layerCount: zod_1.z.number().int(),
    mcuFamily: zod_1.z.string(),
    dimensionsMm: zod_1.z.record(zod_1.z.unknown()).nullable().optional(),
    pinMap: zod_1.z.record(zod_1.z.number().int()),
    schematicAssetUrl: zod_1.z.string().nullable().optional(),
    gerberAssetUrl: zod_1.z.string().nullable().optional(),
    renderAssetUrl: zod_1.z.string().nullable().optional(),
    designMetadata: zod_1.z.record(zod_1.z.unknown()),
    effectiveAt: zod_1.z.string().nullable().optional(),
    deprecatedAt: zod_1.z.string().nullable().optional(),
    createdAt: zod_1.z.string(),
    updatedAt: zod_1.z.string(),
});
// Complete BOM with Items Presentation Schema
exports.BOMDetailSchema = zod_1.z.object({
    id: zod_1.z.string(),
    hardwareRevisionId: zod_1.z.string(),
    version: zod_1.z.string(),
    lifecycleStatus: contracts_1.BOMSpecificationStatusSchema,
    totalUniqueComponents: zod_1.z.number().int(),
    notes: zod_1.z.string().nullable().optional(),
    effectiveDate: zod_1.z.string().nullable().optional(),
    items: zod_1.z.array(contracts_1.BOMItemSchema),
    createdAt: zod_1.z.string(),
    updatedAt: zod_1.z.string(),
});
//# sourceMappingURL=hardware.schema.js.map