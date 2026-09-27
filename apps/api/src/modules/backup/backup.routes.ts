import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { BackupService } from './backup.service';
import { RestoreService } from './restore.service';
import { SecurityService } from '../security/security.service';

export const backupRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const getBackupService = (): BackupService => {
    return (app as any).backupService;
  };

  const getRestoreService = (): RestoreService => {
    return (app as any).restoreService;
  };

  const getSecurityService = (): SecurityService => {
    return (app as any).securityService || (app as any).__defaultSecurityService;
  };


  // 1. Create Backup (POST /create)
  app.post(
    '/create',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:create')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getBackupService();
      const secContext = (req as any).securityContext;
      const result = await service.createBackup(secContext);
      return reply.status(201).send(result);
    }
  );

  // 2. List Backups (GET /)
  app.get(
    '/',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:read')(req, reply);
        }
      }
    },
    async (_req, reply) => {
      const service = getBackupService();
      const list = await service.listBackups();
      return reply.status(200).send(list);
    }
  );

  // 3. Get Specific Backup (GET /:backupId)
  app.get(
    '/:backupId',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:read')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getBackupService();
      const { backupId } = req.params as { backupId: string };
      try {
        const snapshot = await service.getBackup(backupId);
        return reply.status(200).send(snapshot);
      } catch (err: any) {
        return reply.status(404).send({ error: 'NOT_FOUND', message: err.message });
      }
    }
  );

  // 4. Verify Backup Integrity (POST /:backupId/verify)
  app.post(
    '/:backupId/verify',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:read')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const restoreService = getRestoreService();
      const { backupId } = req.params as { backupId: string };
      try {
        const verification = await restoreService.verifyBackupIntegrity(backupId);
        return reply.status(200).send(verification);
      } catch (err: any) {
        return reply.status(400).send({ error: 'VERIFICATION_FAILED', message: err.message });
      }
    }
  );

  // 5. Restore Backup (POST /:backupId/restore)
  app.post(
    '/:backupId/restore',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:restore')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const restoreService = getRestoreService();
      const { backupId } = req.params as { backupId: string };
      const secContext = (req as any).securityContext;
      try {
        const result = await restoreService.restoreBackup(backupId, secContext);
        return reply.status(200).send(result);
      } catch (err: any) {
        return reply.status(400).send({ error: 'RESTORE_FAILED', message: err.message });
      }
    }
  );

  // 6. Prune Backups by Retention Policy (POST /prune)
  app.post(
    '/prune',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('backup:delete')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getBackupService();
      const body = (req.body as any) || {};
      const secContext = (req as any).securityContext;
      const result = await service.pruneExpiredBackups(body, secContext);
      return reply.status(200).send(result);
    }
  );
};
