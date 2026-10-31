"use strict";
/**
 * EH Home Hardware & BOM Domain Routes
 *
 * Fastify route plugin for Hardware Revisions and Bill of Materials (BOM).
 * Follows the pattern: Route -> Validation -> Service -> Repository -> Drizzle.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.hardwareRoutes = void 0;
const hardware_repository_1 = require("./hardware.repository");
const hardware_service_1 = require("./hardware.service");
const hardware_schema_1 = require("./hardware.schema");
const hardwareRoutes = async (app) => {
    const repository = new hardware_repository_1.HardwareRepository(app.db);
    const service = new hardware_service_1.HardwareService(repository);
    // 1. GET /api/v1/hardware/revisions - List hardware revisions
    app.get('/revisions', async (req, reply) => {
        const filters = hardware_schema_1.ListHardwareRevisionsQuerySchema.parse(req.query);
        const result = await service.listHardwareRevisions(filters);
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: result.items,
            pagination: {
                total: result.total,
                limit: result.limit,
                offset: result.offset,
            },
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 2. GET /api/v1/hardware/revisions/:hardwareRevisionId - Retrieve single revision
    app.get('/revisions/:hardwareRevisionId', async (req, reply) => {
        const params = hardware_schema_1.GetHardwareRevisionParamsSchema.parse(req.params);
        const revision = await service.getHardwareRevision(params.hardwareRevisionId);
        if (!revision) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'HARDWARE_REVISION_NOT_FOUND',
                    message: `Hardware revision with ID '${params.hardwareRevisionId}' not found`,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: revision,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 3. GET /api/v1/hardware/revisions/:hardwareRevisionId/bom - Retrieve BOM specification
    app.get('/revisions/:hardwareRevisionId/bom', async (req, reply) => {
        const params = hardware_schema_1.GetHardwareRevisionParamsSchema.parse(req.params);
        const bom = await service.getBOM(params.hardwareRevisionId);
        if (!bom) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'BOM_NOT_FOUND',
                    message: `Bill of Materials for hardware revision '${params.hardwareRevisionId}' not found`,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: bom,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 4. POST /api/v1/hardware/revisions - Create hardware revision
    app.post('/revisions', async (req, reply) => {
        const body = hardware_schema_1.CreateHardwareRevisionBodySchema.parse(req.body);
        const created = await service.createHardwareRevision(body);
        return reply.status(201).send({
            schemaVersion: 1,
            success: true,
            data: created,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 5. PATCH /api/v1/hardware/revisions/:hardwareRevisionId/status - Update lifecycle status
    app.patch('/revisions/:hardwareRevisionId/status', async (req, reply) => {
        const params = hardware_schema_1.GetHardwareRevisionParamsSchema.parse(req.params);
        const body = hardware_schema_1.UpdateHardwareRevisionStatusBodySchema.parse(req.body);
        const updated = await service.updateLifecycleStatus(params.hardwareRevisionId, body.status, body.reason);
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: updated,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 6. POST /api/v1/hardware/revisions/:hardwareRevisionId/bom - Create BOM
    app.post('/revisions/:hardwareRevisionId/bom', async (req, reply) => {
        const params = hardware_schema_1.GetHardwareRevisionParamsSchema.parse(req.params);
        const body = hardware_schema_1.CreateBOMSpecificationBodySchema.parse({
            ...(req.body || {}),
            hardwareRevisionId: params.hardwareRevisionId,
        });
        const created = await service.createBOM(body);
        return reply.status(201).send({
            schemaVersion: 1,
            success: true,
            data: created,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
};
exports.hardwareRoutes = hardwareRoutes;
//# sourceMappingURL=hardware.routes.js.map