"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.securityRoutes = void 0;
const security_repository_1 = require("./security.repository");
const security_service_1 = require("./security.service");
const contracts_1 = require("@eh-home/contracts");
const zod_1 = require("zod");
const UpdateRoleBodySchema = zod_1.z.object({
    role: contracts_1.UserRoleSchema
});
const UpdateStatusBodySchema = zod_1.z.object({
    status: contracts_1.PrincipalStatusSchema
});
const ClaimDeviceBodySchema = zod_1.z.object({
    homeId: zod_1.z.string().min(1),
    customName: zod_1.z.string().optional()
});
const TransferDeviceBodySchema = zod_1.z.object({
    toUserId: zod_1.z.string().min(1),
    targetHomeId: zod_1.z.string().min(1)
});
const RevokeDeviceBodySchema = zod_1.z.object({
    reason: zod_1.z.string().default('Administrative revocation')
});
const securityRoutes = async (app) => {
    const getAuditService = () => app.auditService || app.__defaultAuditService || null;
    const getSecurityService = () => {
        return app.securityService || app.__defaultSecurityService || new security_service_1.SecurityService(app.securityRepository || new security_repository_1.SecurityRepository(app), getAuditService() || undefined);
    };
    // 1. GET /api/v1/security/me — Return current principal and permissions
    app.get('/me', {
        preHandler: async (req, reply) => {
            await getSecurityService().authHook()(req, reply);
        }
    }, async (req, reply) => {
        const secContext = req.securityContext;
        const permissions = contracts_1.ROLE_PERMISSIONS_MAP[secContext.principal.role] || [];
        return reply.status(200).send({
            success: true,
            data: {
                principal: secContext.principal,
                permissions,
                authenticatedAt: secContext.authenticatedAt
            }
        });
    });
    // 2. GET /api/v1/security/roles — Return canonical roles and permission matrices
    app.get('/roles', async (_req, reply) => {
        return reply.status(200).send({
            success: true,
            data: {
                platformRoles: contracts_1.ROLE_PERMISSIONS_MAP,
                homeRoles: contracts_1.HOME_ROLE_PERMISSIONS_MAP
            }
        });
    });
    // 3. PATCH /api/v1/security/users/:id/role — Update user role (Requires user:manage_roles)
    app.patch('/users/:id/role', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('user:manage_roles')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const parseResult = UpdateRoleBodySchema.safeParse(req.body);
        if (!parseResult.success) {
            return reply.status(400).send({
                success: false,
                error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
            });
        }
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const updated = await activeService.updateUserRole(secContext, id, parseResult.data.role);
        return reply.status(200).send({
            success: true,
            data: updated
        });
    });
    // 4. PATCH /api/v1/security/users/:id/status — Update user status (Requires security:admin)
    app.patch('/users/:id/status', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('security:admin')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const parseResult = UpdateStatusBodySchema.safeParse(req.body);
        if (!parseResult.success) {
            return reply.status(400).send({
                success: false,
                error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
            });
        }
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const updated = await activeService.updateUserStatus(secContext, id, parseResult.data.status);
        return reply.status(200).send({
            success: true,
            data: updated
        });
    });
    // 5. POST /api/v1/security/devices/:id/claim — Claim device (Requires device:claim)
    app.post('/devices/:id/claim', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('device:claim')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const parseResult = ClaimDeviceBodySchema.safeParse(req.body);
        if (!parseResult.success) {
            return reply.status(400).send({
                success: false,
                error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
            });
        }
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const result = await activeService.claimDevice(secContext, id, parseResult.data.homeId, parseResult.data.customName);
        return reply.status(200).send({
            success: true,
            data: result
        });
    });
    // 6. POST /api/v1/security/devices/:id/unclaim — Unclaim device (Requires device:unclaim + ownership)
    app.post('/devices/:id/unclaim', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('device:unclaim')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const result = await activeService.unclaimDevice(secContext, id);
        return reply.status(200).send({
            success: true,
            data: result
        });
    });
    // 7. POST /api/v1/security/devices/:id/transfer — Transfer device ownership (Requires device:transfer + ownership)
    app.post('/devices/:id/transfer', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('device:transfer')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const parseResult = TransferDeviceBodySchema.safeParse(req.body);
        if (!parseResult.success) {
            return reply.status(400).send({
                success: false,
                error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
            });
        }
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const result = await activeService.transferDeviceOwnership(secContext, id, parseResult.data.toUserId, parseResult.data.targetHomeId);
        return reply.status(200).send({
            success: true,
            data: result
        });
    });
    // 8. POST /api/v1/security/devices/:id/revoke — Revoke device (Requires device:revoke)
    app.post('/devices/:id/revoke', {
        preHandler: async (req, reply) => {
            const sec = getSecurityService();
            await sec.authHook()(req, reply);
            await sec.requirePermissionHook('device:revoke')(req, reply);
        }
    }, async (req, reply) => {
        const { id } = req.params;
        const parseResult = RevokeDeviceBodySchema.safeParse(req.body || {});
        const reason = parseResult.success ? parseResult.data.reason : 'Administrative revocation';
        const secContext = req.securityContext;
        const activeService = req.server.securityService || getSecurityService();
        const result = await activeService.revokeDevice(secContext, id, reason);
        return reply.status(200).send({
            success: true,
            data: result
        });
    });
};
exports.securityRoutes = securityRoutes;
//# sourceMappingURL=security.routes.js.map