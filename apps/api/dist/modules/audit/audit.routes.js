"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.auditRoutes = void 0;
const audit_repository_1 = require("./audit.repository");
const audit_service_1 = require("./audit.service");
const security_repository_1 = require("../security/security.repository");
const security_service_1 = require("../security/security.service");
const contracts_1 = require("@eh-home/contracts");
const auditRoutes = async (app) => {
    const getAuditService = () => {
        return app.auditService || app.__defaultAuditService || new audit_service_1.AuditService(app.auditRepository || new audit_repository_1.AuditRepository(app));
    };
    const getSecurityService = () => {
        return app.securityService || app.__defaultSecurityService || new security_service_1.SecurityService(app.securityRepository || new security_repository_1.SecurityRepository(app));
    };
    // 1. GET /api/v1/audit/events — Query audit trail (Requires audit:read)
    app.get('/events', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('audit:read')(req, reply);
        }
    }, async (req, reply) => {
        const rawQuery = req.query || {};
        const parseResult = contracts_1.AuditQueryFilterSchema.safeParse(rawQuery);
        if (!parseResult.success) {
            return reply.status(400).send({
                success: false,
                error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
            });
        }
        const secContext = req.securityContext;
        const activeAuditService = req.server.auditService || getAuditService();
        const result = await activeAuditService.queryAuditEvents(parseResult.data, secContext);
        return reply.status(200).send({
            success: true,
            data: result.records,
            meta: {
                total: result.total,
                limit: parseResult.data.limit,
                offset: parseResult.data.offset
            }
        });
    });
};
exports.auditRoutes = auditRoutes;
//# sourceMappingURL=audit.routes.js.map