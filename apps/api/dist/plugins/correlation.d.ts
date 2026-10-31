/**
 * EH Home API Request Correlation Plugin
 * Generates or propagates request IDs across inbound and outbound boundaries.
 */
import { FastifyPluginAsync } from 'fastify';
declare module 'fastify' {
    interface FastifyRequest {
        correlationId: string;
    }
}
export declare const correlation: FastifyPluginAsync;
//# sourceMappingURL=correlation.d.ts.map