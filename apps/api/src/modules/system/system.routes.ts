/**
 * System Module Routes
 * Fastify route handler demonstrating schema -> service -> response flow.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { SystemService } from './system.service';
import { EchoRequestSchema } from './system.schema';

export const systemRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const service = new SystemService(process.env.NODE_ENV || 'development');

  // GET /api/v1/system/info
  app.get('/info', async (_req, reply) => {
    const info = service.getSystemInfo();
    return reply.status(200).send({
      schemaVersion: 1,
      success: true,
      data: info,
      meta: {
        timestamp: new Date().toISOString(),
      },
    });
  });

  // POST /api/v1/system/echo
  app.post('/echo', async (req, reply) => {
    // Validate request body using Zod schema
    const validatedBody = EchoRequestSchema.parse(req.body);
    const result = service.echo(validatedBody);

    return reply.status(200).send({
      schemaVersion: 1,
      success: true,
      data: result,
      meta: {
        requestId: req.correlationId,
        timestamp: new Date().toISOString(),
      },
    });
  });
};
