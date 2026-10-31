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
  // Migration 033 is required for durable inventory/packing storage. During
  // local bench testing the API may be connected while that migration is not
  // installed (or PostgreSQL may be unavailable). In that case use the
  // repository's in-memory adapter instead of turning a successful flash into
  // an HTTP 500 and losing the label workflow.
  let db: typeof fastify.db | undefined = fastify.db;
  try {
    const result = await fastify.dbPool.query(`
      SELECT to_regclass('public.inventory_items') AS inventory_items,
             to_regclass('public.packaging_cartons') AS packaging_cartons,
             to_regclass('public.dual_scan_verifications') AS dual_scan_verifications,
             to_regclass('public.packaging_records') AS packaging_records
    `);
    const tables = result.rows[0] || {};
    if (!tables.inventory_items || !tables.packaging_cartons || !tables.dual_scan_verifications || !tables.packaging_records) {
      fastify.log.warn('Inventory migration 033 is not installed; using in-memory inventory for bench testing.');
      db = undefined;
    }
  } catch (error) {
    fastify.log.warn({ error }, 'Inventory database unavailable; using in-memory inventory for bench testing.');
    db = undefined;
  }
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

  // 8. GET /api/v1/inventory/items — List inventory items
  fastify.get('/items', async (request: any, reply) => {
    const filters = {
      status: request.query?.status,
      productVariantId: request.query?.productVariantId,
      cartonId: request.query?.cartonId,
      limit: Number(request.query?.limit) || 50,
      offset: Number(request.query?.offset) || 0,
    };
    const items = await service.listInventoryItems(filters);
    return reply.status(200).send({
      success: true,
      data: items,
      count: items.length,
    });
  });

  // 9. GET /api/v1/inventory/cartons — List packaging cartons
  fastify.get('/cartons', async (request: any, reply) => {
    const filters = {
      status: request.query?.status,
      limit: Number(request.query?.limit) || 50,
      offset: Number(request.query?.offset) || 0,
    };
    const cartons = await service.listCartons(filters);
    return reply.status(200).send({
      success: true,
      data: cartons,
      count: cartons.length,
    });
  });

  // 10. GET /api/v1/inventory/qc — List QC verification logs
  fastify.get('/qc', async (request: any, reply) => {
    const filters = {
      stationId: request.query?.stationId,
      deviceId: request.query?.deviceId,
      limit: Number(request.query?.limit) || 50,
      offset: Number(request.query?.offset) || 0,
    };
    const qcLogs = await service.listQcRecords(filters);
    return reply.status(200).send({
      success: true,
      data: qcLogs,
      count: qcLogs.length,
    });
  });

  // 11. POST /api/v1/inventory/qc — Record QC operation
  fastify.post('/qc', async (request: any, reply) => {
    const body = request.body || {};
    const created = await service.recordQcOperation(body);
    return reply.status(201).send({
      success: true,
      data: created,
    });
  });

  // 12. POST /api/v1/inventory/adjust — Adjust inventory item status
  fastify.post('/adjust', async (request: any, reply) => {
    const { deviceId, status, notes } = request.body || {};
    if (!deviceId || !status) {
      return reply.status(400).send({ success: false, error: 'deviceId and status required' });
    }
    const updated = await service.adjustInventory(deviceId, status, notes);
    return reply.status(200).send({
      success: true,
      data: updated,
    });
  });
};
