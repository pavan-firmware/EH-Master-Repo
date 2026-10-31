"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ApiEnvelopeSchema = exports.PaginationQuerySchema = exports.SerialNumberSchema = exports.MacAddressSchema = exports.HardwareRevisionCodeSchema = exports.SemanticVersionSchema = exports.IsoDateTimeSchema = exports.IsoTimestampSchema = exports.UuidSchema = exports.SchemaVersionSchema = void 0;
const zod_1 = require("zod");
exports.SchemaVersionSchema = zod_1.z.number().int().min(1).max(1).default(1);
exports.UuidSchema = zod_1.z.string().uuid({ message: 'Must be a valid UUID v4' });
exports.IsoTimestampSchema = zod_1.z.string().datetime({ message: 'Must be an ISO 8601 UTC datetime string' });
exports.IsoDateTimeSchema = exports.IsoTimestampSchema;
exports.SemanticVersionSchema = zod_1.z.string().regex(/^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$/, {
    message: 'Must be a valid semantic version (e.g. 1.0.0 or 1.0.0-rc.1)'
});
exports.HardwareRevisionCodeSchema = zod_1.z.string().regex(/^HW_[0-9]+_[0-9]+$/, {
    message: 'Must be a valid hardware revision code (e.g. HW_1_0)'
});
exports.MacAddressSchema = zod_1.z.string().regex(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/, {
    message: 'Must be a valid 6-byte IEEE 802 MAC address'
});
exports.SerialNumberSchema = zod_1.z.string().regex(/^EH-[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]{4,5}$/, {
    message: 'Must be a valid EH serial number (e.g. EH-SW3X-2026-00001)'
});
exports.PaginationQuerySchema = zod_1.z.object({
    page: zod_1.z.coerce.number().int().min(1).default(1),
    limit: zod_1.z.coerce.number().int().min(1).max(100).default(20),
    cursor: zod_1.z.string().optional()
});
const ApiEnvelopeSchema = (dataSchema) => zod_1.z.object({
    schemaVersion: exports.SchemaVersionSchema,
    success: zod_1.z.boolean(),
    data: dataSchema.optional(),
    error: zod_1.z
        .object({
        code: zod_1.z.string(),
        message: zod_1.z.string(),
        details: zod_1.z.record(zod_1.z.unknown()).optional()
    })
        .optional(),
    meta: zod_1.z
        .object({
        requestId: zod_1.z.string().optional(),
        timestamp: exports.IsoTimestampSchema.default(() => new Date().toISOString()),
        pagination: zod_1.z
            .object({
            total: zod_1.z.number().int().nonnegative(),
            page: zod_1.z.number().int().positive(),
            limit: zod_1.z.number().int().positive(),
            hasMore: zod_1.z.boolean()
        })
            .optional()
    })
        .optional()
});
exports.ApiEnvelopeSchema = ApiEnvelopeSchema;
//# sourceMappingURL=index.js.map