import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { SecurityRepository } from './security.repository';
import { SecurityService } from './security.service';
import { AuditService } from '../audit/audit.service';
import {
  ROLE_PERMISSIONS_MAP,
  HOME_ROLE_PERMISSIONS_MAP,
  UserRoleSchema,
  PrincipalStatusSchema
} from '@eh-home/contracts';
import { z } from 'zod';

const UpdateRoleBodySchema = z.object({
  role: UserRoleSchema
});

const UpdateStatusBodySchema = z.object({
  status: PrincipalStatusSchema
});

const ClaimDeviceBodySchema = z.object({
  homeId: z.string().min(1),
  customName: z.string().optional()
});

const TransferDeviceBodySchema = z.object({
  toUserId: z.string().min(1),
  targetHomeId: z.string().min(1)
});

const RevokeDeviceBodySchema = z.object({
  reason: z.string().default('Administrative revocation')
});

export const securityRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const getAuditService = (): AuditService | null => (app as any).auditService || (app as any).__defaultAuditService || null;
  const getSecurityService = (): SecurityService => {
    return (app as any).securityService || (app as any).__defaultSecurityService || new SecurityService(
      (app as any).securityRepository || new SecurityRepository(app),
      getAuditService() || undefined
    );
  };

  // 1. GET /api/v1/security/me — Return current principal and permissions
  app.get('/me', {
    preHandler: async (req, reply) => {
      await getSecurityService().authHook()(req, reply);
    }
  }, async (req, reply) => {
    const secContext = (req as any).securityContext;
    const permissions = ROLE_PERMISSIONS_MAP[secContext.principal.role as keyof typeof ROLE_PERMISSIONS_MAP] || [];
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
        platformRoles: ROLE_PERMISSIONS_MAP,
        homeRoles: HOME_ROLE_PERMISSIONS_MAP
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
    const { id } = req.params as { id: string };
    const parseResult = UpdateRoleBodySchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
      });
    }

    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
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
    const { id } = req.params as { id: string };
    const parseResult = UpdateStatusBodySchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
      });
    }

    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
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
    const { id } = req.params as { id: string };
    const parseResult = ClaimDeviceBodySchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
      });
    }

    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
    const result = await activeService.claimDevice(
      secContext,
      id,
      parseResult.data.homeId,
      parseResult.data.customName
    );
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
    const { id } = req.params as { id: string };
    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
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
    const { id } = req.params as { id: string };
    const parseResult = TransferDeviceBodySchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
      });
    }

    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
    const result = await activeService.transferDeviceOwnership(
      secContext,
      id,
      parseResult.data.toUserId,
      parseResult.data.targetHomeId
    );
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
    const { id } = req.params as { id: string };
    const parseResult = RevokeDeviceBodySchema.safeParse(req.body || {});
    const reason = parseResult.success ? parseResult.data.reason : 'Administrative revocation';

    const secContext = (req as any).securityContext;
    const activeService = (req.server as any).securityService || getSecurityService();
    const result = await activeService.revokeDevice(secContext, id, reason);
    return reply.status(200).send({
      success: true,
      data: result
    });
  });
};
