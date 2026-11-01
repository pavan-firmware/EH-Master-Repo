"use strict";
/**
 * System Module Schemas
 * Request & response validation contracts for the system module.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.EchoResponseSchema = exports.EchoRequestSchema = exports.SystemInfoResponseSchema = void 0;
const zod_1 = require("zod");
exports.SystemInfoResponseSchema = zod_1.z.object({
    service: zod_1.z.literal('eh-home-api'),
    version: zod_1.z.string(),
    nodeVersion: zod_1.z.string(),
    environment: zod_1.z.string(),
    uptimeSeconds: zod_1.z.number().int().nonnegative(),
    timestamp: zod_1.z.string().datetime(),
});
exports.EchoRequestSchema = zod_1.z.object({
    message: zod_1.z.string().min(1, { message: 'Message cannot be empty' }).max(256),
    metadata: zod_1.z.record(zod_1.z.unknown()).optional(),
});
exports.EchoResponseSchema = zod_1.z.object({
    echo: zod_1.z.string(),
    metadata: zod_1.z.record(zod_1.z.unknown()).optional(),
    receivedAt: zod_1.z.string().datetime(),
});
//# sourceMappingURL=system.schema.js.map