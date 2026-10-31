"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.backupRoutes = void 0;
const backupRoutes = async (app) => {
    const getBackupService = () => {
        return app.backupService;
    };
    const getRestoreService = () => {
        return app.restoreService;
    };
    const getSecurityService = () => {
        return app.securityService || app.__defaultSecurityService;
    };
    // 1. Create Backup (POST /create)
    app.post('/create', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:create')(req, reply);
            }
        }
    }, async (req, reply) => {
        const service = getBackupService();
        const secContext = req.securityContext;
        const result = await service.createBackup(secContext);
        return reply.status(201).send(result);
    });
    // 2. List Backups (GET /)
    app.get('/', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:read')(req, reply);
            }
        }
    }, async (_req, reply) => {
        const service = getBackupService();
        const list = await service.listBackups();
        return reply.status(200).send(list);
    });
    // 3. Get Specific Backup (GET /:backupId)
    app.get('/:backupId', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:read')(req, reply);
            }
        }
    }, async (req, reply) => {
        const service = getBackupService();
        const { backupId } = req.params;
        try {
            const snapshot = await service.getBackup(backupId);
            return reply.status(200).send(snapshot);
        }
        catch (err) {
            return reply.status(404).send({ error: 'NOT_FOUND', message: err.message });
        }
    });
    // 4. Verify Backup Integrity (POST /:backupId/verify)
    app.post('/:backupId/verify', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:read')(req, reply);
            }
        }
    }, async (req, reply) => {
        const restoreService = getRestoreService();
        const { backupId } = req.params;
        try {
            const verification = await restoreService.verifyBackupIntegrity(backupId);
            return reply.status(200).send(verification);
        }
        catch (err) {
            return reply.status(400).send({ error: 'VERIFICATION_FAILED', message: err.message });
        }
    });
    // 5. Restore Backup (POST /:backupId/restore)
    app.post('/:backupId/restore', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:restore')(req, reply);
            }
        }
    }, async (req, reply) => {
        const restoreService = getRestoreService();
        const { backupId } = req.params;
        const secContext = req.securityContext;
        try {
            const result = await restoreService.restoreBackup(backupId, secContext);
            return reply.status(200).send(result);
        }
        catch (err) {
            return reply.status(400).send({ error: 'RESTORE_FAILED', message: err.message });
        }
    });
    // 6. Prune Backups by Retention Policy (POST /prune)
    app.post('/prune', {
        preHandler: async (req, reply) => {
            const secService = getSecurityService();
            if (secService) {
                await secService.authHook()(req, reply);
                await secService.requirePermissionHook('backup:delete')(req, reply);
            }
        }
    }, async (req, reply) => {
        const service = getBackupService();
        const body = req.body || {};
        const secContext = req.securityContext;
        const result = await service.pruneExpiredBackups(body, secContext);
        return reply.status(200).send(result);
    });
};
exports.backupRoutes = backupRoutes;
//# sourceMappingURL=backup.routes.js.map