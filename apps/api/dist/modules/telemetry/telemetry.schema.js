"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TelemetryLiveStateSchema = exports.IngestTelemetryResponseSchema = exports.TelemetryQueryFilterSchema = exports.FixedPointEnergyTelemetrySchema = void 0;
const zod_1 = require("zod");
const contracts_1 = require("@eh-home/contracts");
Object.defineProperty(exports, "FixedPointEnergyTelemetrySchema", { enumerable: true, get: function () { return contracts_1.FixedPointEnergyTelemetrySchema; } });
Object.defineProperty(exports, "TelemetryQueryFilterSchema", { enumerable: true, get: function () { return contracts_1.TelemetryQueryFilterSchema; } });
exports.IngestTelemetryResponseSchema = zod_1.z.object({
    success: zod_1.z.boolean(),
    status: zod_1.z.enum(['ACCEPTED', 'DROPPED_DUPLICATE', 'REJECTED']),
    message: zod_1.z.string().optional()
});
exports.TelemetryLiveStateSchema = zod_1.z.object({
    deviceId: zod_1.z.string().uuid(),
    channelIndex: zod_1.z.number().int(),
    v_mv: zod_1.z.number().int(),
    i_ma: zod_1.z.number().int(),
    p_mw: zod_1.z.number().int(),
    e_tot_wh: zod_1.z.number().int(),
    pf_x1000: zod_1.z.number().int(),
    freq_mhz: zod_1.z.number().int(),
    sequenceNumber: zod_1.z.number().int(),
    timestamp: zod_1.z.string().datetime(),
    connectionState: zod_1.z.enum(['ONLINE', 'STALE', 'OFFLINE'])
});
//# sourceMappingURL=telemetry.schema.js.map