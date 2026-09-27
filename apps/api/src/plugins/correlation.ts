/**
 * EH Home API Request Correlation Plugin
 * Generates or propagates request IDs across inbound and outbound boundaries.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import fp from 'fastify-plugin';
import { randomUUID } from 'crypto';

declare module 'fastify' {
  interface FastifyRequest {
    correlationId: string;
  }
}

const correlationPlugin: FastifyPluginAsync = async (app: FastifyInstance) => {
  app.addHook('onRequest', async (req, reply) => {
    // Check incoming header
    const rawHeader = req.headers['x-request-id'] || req.headers['x-correlation-id'];
    let reqId = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;

    // Validate incoming ID format or generate a fresh UUID v4
    if (!reqId || typeof reqId !== 'string' || !/^[a-zA-Z0-9_-]{8,64}$/.test(reqId)) {
      reqId = randomUUID();
    }

    req.correlationId = reqId;
    reply.header('x-request-id', reqId);
  });
};

export const correlation = fp(correlationPlugin, {
  name: 'correlation',
  fastify: '5.x',
});
