/**
 * EH Home API Health & Readiness Plugin
 * Exposes /health (liveness) and /ready (dependency readiness).
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';

export const healthRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  // Liveness Check: Does not require database or downstream dependencies
  app.get('/health', async (_req, reply) => {
    return reply.status(200).send({
      status: 'UP',
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  });

  // Readiness Check: Verifies operational prerequisites (e.g. PostgreSQL connectivity, Storage backend)
  app.get('/ready', async (_req, reply) => {
    let isDbHealthy = false;
    if (typeof app.pingDb === 'function') {
      isDbHealthy = await app.pingDb();
    } else {
      isDbHealthy = true; // When DB plugin not loaded or mocked
    }

    let isStorageHealthy = true;
    let storageDetails: any = { status: 'UNKNOWN' };
    const storageService = (app as any).storageService;
    if (storageService && typeof storageService.isHealthy === 'function') {
      try {
        const storageHealth = await storageService.isHealthy();
        isStorageHealthy = storageHealth.healthy;
        storageDetails = storageHealth;
      } catch (err: any) {
        isStorageHealthy = false;
        storageDetails = { error: err?.message };
      }
    }

    const isAllReady = isDbHealthy && isStorageHealthy;

    if (!isAllReady) {
      return reply.status(503).send({
        status: 'DOWN',
        dependencies: {
          database: isDbHealthy ? 'HEALTHY' : 'UNAVAILABLE',
          storage: isStorageHealthy ? 'HEALTHY' : 'UNAVAILABLE',
        },
        storageDetails,
        timestamp: new Date().toISOString(),
      });
    }

    return reply.status(200).send({
      status: 'READY',
      dependencies: {
        database: 'HEALTHY',
        storage: 'HEALTHY',
      },
      storageDetails,
      timestamp: new Date().toISOString(),
    });
  });
};

