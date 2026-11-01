"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrintJobResultSchema = exports.PrintJobRequestSchema = exports.LabelDataModelSchema = exports.LabelDimensionsSchema = exports.LabelTemplateIdSchema = exports.PrinterErrorCodeSchema = exports.PrinterProtocolSchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
const base_1 = require("./base");
// ── 1. Printer Protocol & Error Code Schemas ──────────────────────────
exports.PrinterProtocolSchema = zod_1.z.enum(['TSPL', 'ESCPOS']);
exports.PrinterErrorCodeSchema = zod_1.z.enum([
    'PRINTER_NOT_FOUND',
    'PRINTER_UNAVAILABLE',
    'PRINTER_BUSY',
    'PRINTER_CONNECTION_FAILED',
    'UNSUPPORTED_PRINTER_PROTOCOL',
    'INVALID_LABEL_DATA',
    'INVALID_QR_PAYLOAD',
    'SECRET_DATA_DETECTED',
    'TEMPLATE_NOT_FOUND',
    'PRINT_FAILED'
]);
// ── 2. Label Template Identifiers ─────────────────────────────────────
exports.LabelTemplateIdSchema = zod_1.z.enum([
    'device-primary-50x30-v1',
    'device-compact-40x20-v1',
    'device-silicon-25x10-v1',
    'box-receipt-escpos-v1'
]);
// ── 3. Label Dimensions ───────────────────────────────────────────────
exports.LabelDimensionsSchema = zod_1.z.object({
    widthMm: zod_1.z.number().positive(),
    heightMm: zod_1.z.number().positive(),
    gapMm: zod_1.z.number().nonnegative().default(2),
    dpi: zod_1.z.enum(['203', '300']).default('203')
});
// ── 4. Canonical Label Data Model ─────────────────────────────────────
exports.LabelDataModelSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    brand: zod_1.z.literal('EH Home').default('EH Home'),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    productVariantId: zod_1.z.string().regex(/^eh-[a-z0-9-]+$/),
    productDisplayName: zod_1.z.string().min(1),
    productFamily: zod_1.z.string().min(1),
    hardwareRevision: common_1.HardwareRevisionCodeSchema,
    firmwareFamily: zod_1.z.string().min(1),
    firmwareVersion: zod_1.z.string().min(1),
    qrUri: base_1.QrUriSchema,
    qrToken: base_1.OpaqueQrTokenSchema,
    templateId: exports.LabelTemplateIdSchema.default('device-primary-50x30-v1'),
    traceId: zod_1.z.string().uuid().optional(),
    batchId: zod_1.z.string().uuid().optional(),
    manufacturedAt: zod_1.z.string().datetime().optional()
});
// ── 5. Print Job Request & Response ───────────────────────────────────
exports.PrintJobRequestSchema = zod_1.z.object({
    printerId: zod_1.z.string().min(1),
    protocol: exports.PrinterProtocolSchema.default('TSPL'),
    templateId: exports.LabelTemplateIdSchema.default('device-primary-50x30-v1'),
    labelData: exports.LabelDataModelSchema,
    copies: zod_1.z.number().int().positive().default(1)
});
exports.PrintJobResultSchema = zod_1.z.object({
    success: zod_1.z.boolean(),
    jobId: zod_1.z.string().optional(),
    protocol: exports.PrinterProtocolSchema,
    printerId: zod_1.z.string(),
    copiesPrinted: zod_1.z.number().int().nonnegative(),
    errorCode: exports.PrinterErrorCodeSchema.optional(),
    errorMessage: zod_1.z.string().optional(),
    renderedCommandPreview: zod_1.z.string().optional(),
    printedAt: zod_1.z.string().datetime().optional()
});
//# sourceMappingURL=label.js.map