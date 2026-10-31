/**
 * EH Home API Centralized Error Handler
 * Enforces structured, safe error envelopes conforming to @eh-home/contracts.
 */
import { FastifyPluginAsync } from 'fastify';
export interface StructuredErrorResponse {
    schemaVersion: number;
    success: false;
    error: {
        code: string;
        message: string;
        details?: Record<string, unknown>;
    };
    meta: {
        requestId: string;
        timestamp: string;
    };
}
export declare const errorHandler: FastifyPluginAsync;
//# sourceMappingURL=error-handler.d.ts.map