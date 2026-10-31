"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.HardwareCompatibilitySchema = exports.HardwareRevisionSchema = exports.HardwareRevisionStatusSchema = exports.BOMSpecificationSchema = exports.BOMSpecificationStatusSchema = exports.BOMItemSchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.BOMItemSchema = zod_1.z.object({
    itemIndex: zod_1.z.number().int().min(1),
    referenceDesignator: zod_1.z.string().min(1),
    mpn: zod_1.z.string().min(1),
    manufacturer: zod_1.z.string().optional(),
    description: zod_1.z.string().min(1),
    footprint: zod_1.z.string().min(1),
    quantity: zod_1.z.number().int().positive().default(1),
    isDnf: zod_1.z.boolean().default(false),
    vendorPartNumber: zod_1.z.string().optional(),
    unitCostInr: zod_1.z.number().nonnegative().optional()
});
exports.BOMSpecificationStatusSchema = zod_1.z.enum([
    'DRAFT',
    'ACTIVE',
    'DEPRECATED',
    'SUPERSEDED'
]);
exports.BOMSpecificationSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    bomId: zod_1.z.string(),
    hardwareRevisionCode: common_1.HardwareRevisionCodeSchema,
    version: common_1.SemanticVersionSchema,
    lifecycleStatus: exports.BOMSpecificationStatusSchema.default('DRAFT'),
    items: zod_1.z.array(exports.BOMItemSchema).min(1),
    totalUniqueComponents: zod_1.z.number().int().positive().optional(),
    notes: zod_1.z.string().optional(),
    effectiveDate: zod_1.z.string().datetime().optional(),
    createdAt: zod_1.z.string().datetime()
});
exports.HardwareRevisionStatusSchema = zod_1.z.enum([
    'DRAFT',
    'VALIDATION',
    'APPROVED',
    'ACTIVE',
    'DEPRECATED',
    'RETIRED',
    'PROTOTYPE',
    'OBSOLETE'
]);
exports.HardwareRevisionSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    revisionCode: common_1.HardwareRevisionCodeSchema,
    productVariantId: zod_1.z.string().regex(/^[a-z0-9_-]+$/),
    pcbName: zod_1.z.string().min(1),
    layerCount: zod_1.z.number().int().min(1).max(8).default(2),
    dimensionsMm: zod_1.z.object({
        width: zod_1.z.number().positive(),
        height: zod_1.z.number().positive(),
        thickness: zod_1.z.number().positive().default(1.6)
    }).optional(),
    pinMap: zod_1.z.record(zod_1.z.number().int()),
    schematicAssetUrl: zod_1.z.string().url().optional(),
    gerberAssetUrl: zod_1.z.string().url().optional(),
    renderAssetUrl: zod_1.z.string().url().optional(),
    status: exports.HardwareRevisionStatusSchema.default('ACTIVE'),
    createdAt: zod_1.z.string().datetime()
});
exports.HardwareCompatibilitySchema = zod_1.z.object({
    hardwareRevisionCode: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    minFirmwareVersion: common_1.SemanticVersionSchema,
    maxFirmwareVersion: common_1.SemanticVersionSchema.optional(),
    incompatibleFirmwareVersions: zod_1.z.array(common_1.SemanticVersionSchema).default([]),
    verifiedAt: zod_1.z.string().datetime()
});
//# sourceMappingURL=index.js.map