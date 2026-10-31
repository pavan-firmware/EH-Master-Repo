"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TelemetryAggregateRecordSchema = exports.TelemetryAggregateBucketSchema = exports.TelemetryQueryFilterSchema = exports.FixedPointEnergyTelemetrySchema = void 0;
const zod_1 = require("zod");
const common_1 = require("../common");
exports.FixedPointEnergyTelemetrySchema = zod_1.z.object({
    schemaVersion: common_1.SchemaVersionSchema.default(1),
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int().min(1).max(16).default(1),
    v_mv: zod_1.z.number().int().positive({ message: 'Voltage in mV must be positive' }),
    i_ma: zod_1.z.number().int().nonnegative({ message: 'Current in mA must be non-negative' }),
    p_mw: zod_1.z.number().int().nonnegative({ message: 'Power in mW must be non-negative' }),
    e_tot_wh: zod_1.z.number().int().nonnegative({ message: 'Total energy in Wh must be non-negative' }),
    e_int_mwh: zod_1.z.number().int().nonnegative({ message: 'Interval energy in mWh must be non-negative' }).optional(),
    freq_mhz: zod_1.z.number().int().positive({ message: 'Grid frequency in mHz must be positive' }).default(50000),
    pf_x1000: zod_1.z.number().int().min(0).max(1000, { message: 'Power factor x1000 must be in range 0..1000' }),
    flags: zod_1.z.number().int().default(0),
    sequenceNumber: zod_1.z.number().int().nonnegative().default(0),
    timestamp: zod_1.z.string().datetime(),
    ingestedAt: zod_1.z.string().datetime().optional()
});
exports.TelemetryQueryFilterSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int().min(1).max(16).optional(),
    startTime: zod_1.z.string().datetime().optional(),
    endTime: zod_1.z.string().datetime().optional(),
    limit: zod_1.z.number().int().min(1).max(1000).default(100)
});
exports.TelemetryAggregateBucketSchema = zod_1.z.enum(['1m', '5m', '1h', '1d', '1w', '1mo']);
exports.TelemetryAggregateRecordSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int().min(1).max(16),
    bucketType: exports.TelemetryAggregateBucketSchema,
    bucketStart: zod_1.z.string().datetime(),
    bucketEnd: zod_1.z.string().datetime(),
    totalEnergyWh: zod_1.z.number().nonnegative(),
    avgPowerW: zod_1.z.number().nonnegative(),
    peakPowerW: zod_1.z.number().nonnegative(),
    minPowerW: zod_1.z.number().nonnegative(),
    sampleCount: zod_1.z.number().int().nonnegative(),
    dataQuality: zod_1.z.enum(['GOOD', 'DEGRADED', 'INTERPOLATED']).default('GOOD')
});
//# sourceMappingURL=index.js.map