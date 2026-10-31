"use strict";
/**
 * System Module Routes
 * Fastify route handler demonstrating schema -> service -> response flow.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.systemRoutes = void 0;
const system_service_1 = require("./system.service");
const system_schema_1 = require("./system.schema");
const systemRoutes = async (app) => {
    const service = new system_service_1.SystemService(process.env.NODE_ENV || 'development');
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
        const validatedBody = system_schema_1.EchoRequestSchema.parse(req.body);
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
exports.systemRoutes = systemRoutes;
//# sourceMappingURL=system.routes.js.map