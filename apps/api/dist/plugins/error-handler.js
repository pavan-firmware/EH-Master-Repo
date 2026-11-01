"use strict";
/**
 * EH Home API Centralized Error Handler
 * Enforces structured, safe error envelopes conforming to @eh-home/contracts.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = void 0;
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const zod_1 = require("zod");
const errorHandlerPlugin = async (app) => {
    // Handle 404 Not Found
    app.setNotFoundHandler((req, reply) => {
        const errorBody = {
            schemaVersion: 1,
            success: false,
            error: {
                code: 'ROUTE_NOT_FOUND',
                message: `Route ${req.method} ${req.url} does not exist`,
            },
            meta: {
                requestId: req.correlationId || 'unknown',
                timestamp: new Date().toISOString(),
            },
        };
        reply.status(404).send(errorBody);
    });
    // Handle All Other Errors
    app.setErrorHandler((rawError, req, reply) => {
        const error = rawError || {};
        const requestId = req.correlationId || 'unknown';
        const timestamp = new Date().toISOString();
        // 1. Zod Validation Error
        if (error instanceof zod_1.ZodError) {
            const details = {};
            error.issues.forEach((issue) => {
                details[issue.path.join('.')] = issue.message;
            });
            const response = {
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'VALIDATION_ERROR',
                    message: 'The request payload failed validation constraints',
                    details,
                },
                meta: { requestId, timestamp },
            };
            return reply.status(400).send(response);
        }
        // 2. Fastify Validation Error (e.g., Schema compiler / payload limit)
        if (error.validation) {
            const response = {
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'BAD_REQUEST',
                    message: error.message,
                },
                meta: { requestId, timestamp },
            };
            return reply.status(400).send(response);
        }
        // 3. Explicit HTTP Errors with statusCode
        const statusCode = error.statusCode && error.statusCode >= 400 && error.statusCode < 500
            ? error.statusCode
            : 500;
        if (statusCode < 500) {
            const response = {
                schemaVersion: 1,
                success: false,
                error: {
                    code: error.errorCode || error.code || 'CLIENT_ERROR',
                    message: error.message,
                },
                meta: { requestId, timestamp },
            };
            return reply.status(statusCode).send(response);
        }
        // 4. Server Errors (500) - Redact internals to prevent information leakage
        req.log.error({
            err: {
                message: error.message,
                stack: error.stack,
                code: error.code,
            },
            requestId,
        }, 'Unhandled internal server error');
        const safeResponse = {
            schemaVersion: 1,
            success: false,
            error: {
                code: 'INTERNAL_SERVER_ERROR',
                message: 'An unexpected internal server error occurred. Please quote the requestId to support.',
            },
            meta: { requestId, timestamp },
        };
        return reply.status(500).send(safeResponse);
    });
};
exports.errorHandler = (0, fastify_plugin_1.default)(errorHandlerPlugin, {
    name: 'errorHandler',
    fastify: '5.x',
});
//# sourceMappingURL=error-handler.js.map