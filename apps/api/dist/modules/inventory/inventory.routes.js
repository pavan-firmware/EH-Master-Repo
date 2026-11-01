"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.inventoryRoutes = void 0;
const inventory_repository_1 = require("./inventory.repository");
const inventory_service_1 = require("./inventory.service");
const inventory_schema_1 = require("./inventory.schema");
const inventoryRoutes = async (fastify) => {
    // Migration 033 is required for durable inventory/packing storage. During
    // local bench testing the API may be connected while that migration is not
    // installed (or PostgreSQL may be unavailable). In that case use the
    // repository's in-memory adapter instead of turning a successful flash into
    // an HTTP 500 and losing the label workflow.
    let db = fastify.db;
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
    }
    catch (error) {
        fastify.log.warn({ error }, 'Inventory database unavailable; using in-memory inventory for bench testing.');
        db = undefined;
    }
    const repository = new inventory_repository_1.InventoryRepository(db);
    const service = new inventory_service_1.InventoryService(repository);
    // 1. POST /api/v1/inventory/register — Register provisioned device
    fastify.post('/register', { schema: inventory_schema_1.registerInventorySchema }, async (request, reply) => {
        const result = await service.registerDevice(request.body);
        return reply.status(200).send(result);
    });
    // 2. GET /api/v1/inventory/device/:identifier & /devices/:identifier — Lookup device
    const handleGetDevice = async (request, reply) => {
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
    fastify.get('/devices/:identifier', { schema: inventory_schema_1.getDeviceSchema }, handleGetDevice);
    fastify.get('/device/:identifier', { schema: inventory_schema_1.getDeviceSchema }, handleGetDevice);
    // 3. POST /api/v1/inventory/dual-scan — Perform Dual-Scan verification
    fastify.post('/dual-scan', { schema: inventory_schema_1.dualScanSchema }, async (request, reply) => {
        const result = await service.performDualScan(request.body);
        return reply.status(200).send(result);
    });
    // 4. POST /api/v1/inventory/cartons — Create or lookup carton
    fastify.post('/cartons', { schema: inventory_schema_1.createCartonSchema }, async (request, reply) => {
        const carton = await service.createCarton(request.body);
        return reply.status(200).send({
            success: true,
            carton,
        });
    });
    // 5. GET /api/v1/inventory/cartons/:cartonId — Get carton by ID
    fastify.get('/cartons/:cartonId', { schema: inventory_schema_1.getCartonSchema }, async (request, reply) => {
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
    });
    // 6. POST /api/v1/inventory/pack — Complete packing operation (Atomic)
    fastify.post('/pack', { schema: inventory_schema_1.completePackingSchema }, async (request, reply) => {
        const result = await service.completePacking(request.body);
        return reply.status(200).send(result);
    });
    // 7. GET /api/v1/inventory/history & /packing-history — Query packaging audit trail
    const handleGetHistory = async (request, reply) => {
        const limit = Number(request.query?.limit) || 50;
        const offset = Number(request.query?.offset) || 0;
        const records = await service.getPackingHistory(limit, offset);
        return reply.status(200).send({
            success: true,
            records,
        });
    };
    fastify.get('/packing-history', { schema: inventory_schema_1.getPackingHistorySchema }, handleGetHistory);
    fastify.get('/history', { schema: inventory_schema_1.getPackingHistorySchema }, handleGetHistory);
    // 8. GET /api/v1/inventory/items — List inventory items
    fastify.get('/items', async (request, reply) => {
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
    fastify.get('/cartons', async (request, reply) => {
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
    fastify.get('/qc', async (request, reply) => {
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
    fastify.post('/qc', async (request, reply) => {
        const body = request.body || {};
        const created = await service.recordQcOperation(body);
        return reply.status(201).send({
            success: true,
            data: created,
        });
    });
    // 12. POST /api/v1/inventory/adjust — Adjust inventory item status
    fastify.post('/adjust', async (request, reply) => {
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
exports.inventoryRoutes = inventoryRoutes;
//# sourceMappingURL=inventory.routes.js.map