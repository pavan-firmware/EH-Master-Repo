"use strict";
/**
 * EH Home API Request Correlation Plugin
 * Generates or propagates request IDs across inbound and outbound boundaries.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.correlation = void 0;
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const crypto_1 = require("crypto");
const correlationPlugin = async (app) => {
    app.addHook('onRequest', async (req, reply) => {
        // Check incoming header
        const rawHeader = req.headers['x-request-id'] || req.headers['x-correlation-id'];
        let reqId = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;
        // Validate incoming ID format or generate a fresh UUID v4
        if (!reqId || typeof reqId !== 'string' || !/^[a-zA-Z0-9_-]{8,64}$/.test(reqId)) {
            reqId = (0, crypto_1.randomUUID)();
        }
        req.correlationId = reqId;
        reply.header('x-request-id', reqId);
    });
};
exports.correlation = (0, fastify_plugin_1.default)(correlationPlugin, {
    name: 'correlation',
    fastify: '5.x',
});
//# sourceMappingURL=correlation.js.map