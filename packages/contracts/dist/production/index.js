"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.QcTestLogSchema = exports.QcMeasurementSchema = exports.BatchDeviceAssociationSchema = exports.ProductionBatchSchema = exports.ProductionBatchStatusSchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.ProductionBatchStatusSchema = zod_1.z.enum([
    'PLANNED',
    'IN_PRODUCTION',
    'QC_IN_PROGRESS',
    'COMPLETED',
    'CANCELLED'
]);
exports.ProductionBatchSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    batchId: zod_1.z.string().uuid(),
    batchCode: zod_1.z.string().regex(/^BATCH-[A-Z0-9-]+$/, {
        message: 'Must be a valid batch code (e.g. BATCH-2026-SW3X-001)'
    }),
    productVariantId: zod_1.z.string().min(1),
    hardwareRevisionCode: common_1.HardwareRevisionCodeSchema,
    firmwareReleaseId: zod_1.z.string().uuid(),
    targetQuantity: zod_1.z.number().int().positive(),
    manufacturedCount: zod_1.z.number().int().nonnegative().default(0),
    passedQcCount: zod_1.z.number().int().nonnegative().default(0),
    failedQcCount: zod_1.z.number().int().nonnegative().default(0),
    status: exports.ProductionBatchStatusSchema.default('PLANNED'),
    operatorUserId: zod_1.z.string().uuid().optional(),
    notes: zod_1.z.string().optional(),
    scheduledStartDate: zod_1.z.string().datetime().optional(),
    completedAt: zod_1.z.string().datetime().optional(),
    createdAt: zod_1.z.string().datetime()
});
exports.BatchDeviceAssociationSchema = zod_1.z.object({
    batchId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    assignedAt: zod_1.z.string().datetime()
});
exports.QcMeasurementSchema = zod_1.z.object({
    parameter: zod_1.z.string().min(1),
    measuredValue: zod_1.z.number(),
    unit: zod_1.z.string().min(1),
    lowerLimit: zod_1.z.number().optional(),
    upperLimit: zod_1.z.number().optional(),
    passed: zod_1.z.boolean()
});
exports.QcTestLogSchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema,
    testLogId: zod_1.z.string().uuid(),
    deviceId: zod_1.z.string().uuid(),
    serialNumber: common_1.SerialNumberSchema,
    batchId: zod_1.z.string().uuid(),
    testStationId: zod_1.z.string().min(1),
    operatorUserId: zod_1.z.string().uuid().optional(),
    overallResult: zod_1.z.enum(['PASS', 'FAIL']),
    measurements: zod_1.z.array(exports.QcMeasurementSchema).default([]),
    failureReason: zod_1.z.string().optional(),
    testedAt: zod_1.z.string().datetime()
});
//# sourceMappingURL=index.js.map