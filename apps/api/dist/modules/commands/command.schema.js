"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SendCommandResponseSchema = exports.SendCommandRequestSchema = exports.DeviceAvailabilityStatusSchema = exports.CommandActionSchema = exports.CommandReceiptSchema = exports.CommandEnvelopeSchema = void 0;
const zod_1 = require("zod");
const contracts_1 = require("@eh-home/contracts");
Object.defineProperty(exports, "CommandEnvelopeSchema", { enumerable: true, get: function () { return contracts_1.CommandEnvelopeSchema; } });
Object.defineProperty(exports, "CommandReceiptSchema", { enumerable: true, get: function () { return contracts_1.CommandReceiptSchema; } });
Object.defineProperty(exports, "CommandActionSchema", { enumerable: true, get: function () { return contracts_1.CommandActionSchema; } });
Object.defineProperty(exports, "DeviceAvailabilityStatusSchema", { enumerable: true, get: function () { return contracts_1.DeviceAvailabilityStatusSchema; } });
exports.SendCommandRequestSchema = zod_1.z.object({
    commandId: zod_1.z.string().uuid().optional(),
    channelIndex: zod_1.z.number().int().min(1).max(16).default(1),
    action: contracts_1.CommandActionSchema,
    params: zod_1.z.record(zod_1.z.unknown()).default({}),
    idempotencyKey: zod_1.z.string().min(1),
    source: zod_1.z.string().default('APP'),
    expiresAt: zod_1.z.string().datetime().optional()
});
exports.SendCommandResponseSchema = zod_1.z.object({
    commandId: zod_1.z.string().uuid(),
    status: zod_1.z.enum(['CREATED', 'APPLIED', 'FAILED', 'EXPIRED', 'OVERRIDDEN']),
    isIdempotentReplay: zod_1.z.boolean(),
    message: zod_1.z.string().optional()
});
//# sourceMappingURL=command.schema.js.map