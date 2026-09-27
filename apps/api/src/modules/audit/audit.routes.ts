import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { AuditRepository } from './audit.repository';
import { AuditService } from './audit.service';
import { SecurityRepository } from '../security/security.repository';
import { SecurityService } from '../security/security.service';
import { AuditQueryFilterSchema } from '@eh-home/contracts';

export const auditRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const getAuditService = (): AuditService => {
    return (app as any).auditService || (app as any).__defaultAuditService || new AuditService((app as any).auditRepository || new AuditRepository(app));
  };
  const getSecurityService = (): SecurityService => {
    return (app as any).securityService || (app as any).__defaultSecurityService || new SecurityService((app as any).securityRepository || new SecurityRepository(app));
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
    const parseResult = AuditQueryFilterSchema.safeParse(rawQuery);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: parseResult.error.message }
      });
    }

    const secContext = (req as any).securityContext;
    const activeAuditService = (req.server as any).auditService || getAuditService();
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
