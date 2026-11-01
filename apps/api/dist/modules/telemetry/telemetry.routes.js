"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.telemetryRoutes = void 0;
const telemetry_repository_1 = require("./telemetry.repository");
const telemetry_service_1 = require("./telemetry.service");
const telemetry_schema_1 = require("./telemetry.schema");
const telemetryRoutes = async (app) => {
    const db = app.db;
    const repo = new telemetry_repository_1.TelemetryRepository(db);
    const service = new telemetry_service_1.TelemetryIngestionService(repo);
    // 1. Direct HTTP Ingestion Boundary (for gateways or local clients)
    app.post('/ingest', async (req, reply) => {
        const result = await service.ingest(req.body);
        if (!result.accepted) {
            if (result.status === 'DROPPED_DUPLICATE') {
                return reply.status(200).send({ success: false, status: result.status, message: result.reason });
            }
            return reply.status(400).send({ success: false, status: result.status, message: result.reason });
        }
        return reply.status(202).send({ success: true, status: 'ACCEPTED' });
    });
    // 2. Query Latest / Live Telemetry
    app.get('/devices/:deviceId/live', async (req, reply) => {
        const { deviceId } = req.params;
        const { channelIndex } = req.query;
        const ch = channelIndex ? parseInt(channelIndex, 10) : 1;
        const latest = await service.getLatest(deviceId, ch);
        if (!latest) {
            return reply.status(404).send({ success: false, error: `No telemetry found for device ${deviceId} channel ${ch}` });
        }
        return reply.status(200).send({ success: true, data: latest });
    });
    // 3. Query Historical Telemetry Series
    app.get('/devices/:deviceId/history', async (req, reply) => {
        const { deviceId } = req.params;
        const queryParams = req.query;
        const parsedFilter = telemetry_schema_1.TelemetryQueryFilterSchema.safeParse({
            deviceId,
            channelIndex: queryParams.channelIndex ? parseInt(queryParams.channelIndex, 10) : undefined,
            startTime: queryParams.startTime,
            endTime: queryParams.endTime,
            limit: queryParams.limit ? parseInt(queryParams.limit, 10) : 100
        });
        if (!parsedFilter.success) {
            return reply.status(400).send({ success: false, error: parsedFilter.error.errors });
        }
        const items = await service.query(parsedFilter.data);
        return reply.status(200).send({ success: true, count: items.length, data: items });
    });
};
exports.telemetryRoutes = telemetryRoutes;
//# sourceMappingURL=telemetry.routes.js.map