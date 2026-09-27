import { FastifyPluginAsync } from 'fastify';
import { InventoryRepository } from './inventory.repository';
import { InventoryService } from './inventory.service';
import {
  registerInventorySchema,
  getDeviceSchema,
  dualScanSchema,
  createCartonSchema,
  getCartonSchema,
  completePackingSchema,
  getPackingHistorySchema,
} from './inventory.schema';

export const inventoryRoutes: FastifyPluginAsync = async (fastify) => {
  // Database instance from plugin
  const db = fastify.db;
  const repository = new InventoryRepository(db);
  const service = new InventoryService(repository);

  // 1. POST /api/v1/inventory/register — Register provisioned device
  fastify.post('/register', { schema: registerInventorySchema }, async (request, reply) => {
    const result = await service.registerDevice(request.body as any);
    return reply.status(200).send(result);
  });

  // 2. GET /api/v1/inventory/device/:identifier & /devices/:identifier — Lookup device
  const handleGetDevice = async (request: any, reply: any) => {
    const { identifier } = request.params;
    const device = await service.getDevice(identifier);
    if (!device) {
      return reply.status(404).send({
        success: false,
        error: 'DEVICE_NOT_FOUND',
        message: `Device '${identifier}' was not found in inventory.`,
      });
    }
    return reply.status(200).send({
      success: true,
      device,
    });
  };

  fastify.get<{ Params: { identifier: string } }>('/devices/:identifier', { schema: getDeviceSchema }, handleGetDevice);
  fastify.get<{ Params: { identifier: string } }>('/device/:identifier', { schema: getDeviceSchema }, handleGetDevice);

  // 3. POST /api/v1/inventory/dual-scan — Perform Dual-Scan verification
  fastify.post('/dual-scan', { schema: dualScanSchema }, async (request, reply) => {
    const result = await service.performDualScan(request.body as any);
    return reply.status(200).send(result);
  });

  // 4. POST /api/v1/inventory/cartons — Create or lookup carton
  fastify.post('/cartons', { schema: createCartonSchema }, async (request, reply) => {
    const carton = await service.createCarton(request.body as any);
    return reply.status(200).send({
      success: true,
      carton,
    });
  });

  // 5. GET /api/v1/inventory/cartons/:cartonId — Get carton by ID
  fastify.get<{ Params: { cartonId: string } }>(
    '/cartons/:cartonId',
    { schema: getCartonSchema },
    async (request, reply) => {
      const { cartonId } = request.params;
      const carton = await service.getCarton(cartonId);
      if (!carton) {
        return reply.status(404).send({
          success: false,
          error: 'CARTON_NOT_FOUND',
          message: `Carton '${cartonId}' was not found.`,
        });
      }
      return reply.status(200).send({
        success: true,
        carton,
      });
    }
  );

  // 6. POST /api/v1/inventory/pack — Complete packing operation (Atomic)
  fastify.post('/pack', { schema: completePackingSchema }, async (request, reply) => {
    const result = await service.completePacking(request.body as any);
    return reply.status(200).send(result);
  });

  // 7. GET /api/v1/inventory/history & /packing-history — Query packaging audit trail
  const handleGetHistory = async (request: any, reply: any) => {
    const limit = Number(request.query?.limit) || 50;
    const offset = Number(request.query?.offset) || 0;
    const records = await service.getPackingHistory(limit, offset);
    return reply.status(200).send({
      success: true,
      records,
    });
  };

  fastify.get<{ Querystring: { limit?: number; offset?: number } }>('/packing-history', { schema: getPackingHistorySchema }, handleGetHistory);
  fastify.get<{ Querystring: { limit?: number; offset?: number } }>('/history', { schema: getPackingHistorySchema }, handleGetHistory);
};
