"use strict";
/**
 * EH Home Firmware Domain Routes
 *
 * Fastify route plugin for Firmware Families, Releases, Builds, and Hardware Compatibility.
 * Follows the pattern: Route -> Validation -> Service -> Repository -> Drizzle.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.firmwareRoutes = void 0;
const firmware_repository_1 = require("./firmware.repository");
const firmware_service_1 = require("./firmware.service");
const firmware_schema_1 = require("./firmware.schema");
const firmwareRoutes = async (app) => {
    const repository = new firmware_repository_1.FirmwareRepository(app.db);
    const service = new firmware_service_1.FirmwareService(repository);
    // 1. GET /api/v1/firmware/families - List firmware families
    app.get('/families', async (req, reply) => {
        const query = firmware_schema_1.ListFirmwareFamiliesQuerySchema.parse(req.query);
        const result = await service.listFamilies(query);
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
    // 2. GET /api/v1/firmware/families/:familyId - Retrieve single family
    app.get('/families/:familyId', async (req, reply) => {
        const params = firmware_schema_1.FirmwareFamilyParamsSchema.parse(req.params);
        const family = await service.getFamily(params.familyId);
        if (!family) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'FIRMWARE_FAMILY_NOT_FOUND',
                    message: `Firmware family with ID '${params.familyId}' not found`,
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
            data: family,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 3. GET /api/v1/firmware/releases - List firmware releases
    app.get('/releases', async (req, reply) => {
        const query = firmware_schema_1.ListFirmwareReleasesQuerySchema.parse(req.query);
        const result = await service.listReleases(query);
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
    // 4. GET /api/v1/firmware/releases/:releaseId - Retrieve single release
    app.get('/releases/:releaseId', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        const release = await service.getRelease(params.releaseId);
        if (!release) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'FIRMWARE_RELEASE_NOT_FOUND',
                    message: `Firmware release with ID '${params.releaseId}' not found`,
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
            data: release,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 5. GET /api/v1/firmware/releases/:releaseId/compatibility - Retrieve compatibility
    app.get('/releases/:releaseId/compatibility', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        try {
            const compatibilities = await service.getCompatibility(params.releaseId);
            return reply.status(200).send({
                schemaVersion: 1,
                success: true,
                data: compatibilities,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'FIRMWARE_RELEASE_NOT_FOUND',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 5b. GET /api/v1/firmware/releases/:releaseId/readiness - Evaluate release-readiness gates (Part 08)
    app.get('/releases/:releaseId/readiness', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        try {
            const readiness = await service.evaluateReleaseReadiness(params.releaseId);
            return reply.status(200).send({
                schemaVersion: 1,
                success: true,
                data: readiness,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'FIRMWARE_RELEASE_NOT_FOUND',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 6. POST /api/v1/firmware/releases - Create a new firmware release
    app.post('/releases', async (req, reply) => {
        const body = firmware_schema_1.CreateFirmwareReleaseBodySchema.parse(req.body);
        try {
            const created = await service.createRelease(body);
            return reply.status(201).send({
                schemaVersion: 1,
                success: true,
                data: created,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(400).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'CREATE_RELEASE_FAILED',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 7. PATCH /api/v1/firmware/releases/:releaseId/status - Update release lifecycle status
    app.patch('/releases/:releaseId/status', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        const body = firmware_schema_1.UpdateReleaseStatusBodySchema.parse(req.body);
        try {
            const updated = await service.updateReleaseStatus(params.releaseId, body);
            return reply.status(200).send({
                schemaVersion: 1,
                success: true,
                data: updated,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            const isNotFound = err.message.includes('not found');
            return reply.status(isNotFound ? 404 : 400).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: isNotFound ? 'FIRMWARE_RELEASE_NOT_FOUND' : 'INVALID_LIFECYCLE_TRANSITION',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 8. POST /api/v1/firmware/releases/:releaseId/builds - Register build for release
    app.post('/releases/:releaseId/builds', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        const body = firmware_schema_1.RegisterBuildBodySchema.parse({
            ...req.body,
            firmwareReleaseId: params.releaseId,
        });
        try {
            const build = await service.registerBuild(body);
            return reply.status(201).send({
                schemaVersion: 1,
                success: true,
                data: build,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(400).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'REGISTER_BUILD_FAILED',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 9. POST /api/v1/firmware/releases/:releaseId/artifacts - Register artifact
    app.post('/releases/:releaseId/artifacts', async (req, reply) => {
        const body = firmware_schema_1.RegisterArtifactBodySchema.parse(req.body);
        try {
            const artifact = await service.registerArtifact(body);
            return reply.status(201).send({
                schemaVersion: 1,
                success: true,
                data: artifact,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(400).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'REGISTER_ARTIFACT_FAILED',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
    // 10. POST /api/v1/firmware/releases/:releaseId/compatibility - Define compatibility
    app.post('/releases/:releaseId/compatibility', async (req, reply) => {
        const params = firmware_schema_1.FirmwareReleaseParamsSchema.parse(req.params);
        const body = firmware_schema_1.DefineCompatibilityBodySchema.parse(req.body);
        try {
            const compat = await service.defineCompatibility(params.releaseId, body);
            return reply.status(201).send({
                schemaVersion: 1,
                success: true,
                data: compat,
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        catch (err) {
            return reply.status(400).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'DEFINE_COMPATIBILITY_FAILED',
                    message: err.message,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
    });
};
exports.firmwareRoutes = firmwareRoutes;
//# sourceMappingURL=firmware.routes.js.map