'use strict';

/**
 * EH Home — Invitations API Router (Phase 16)
 *
 * Endpoints:
 *   GET  /api/v1/invitations/pending             — List pending invitations for authenticated user
 *   POST /api/v1/invitations/:code/accept        — Accept home invitation
 *   POST /api/v1/invitations/:code/reject        — Reject home invitation
 */

class InvitationApiRouter {
  constructor({ invitationService, userRepo }) {
    this.invitationService = invitationService;
    this.userRepo = userRepo;
  }

  async handle(method, path, body = {}, headers = {}, actorContext = null) {
    if (!actorContext || !actorContext.userId) {
      return {
        status: 401,
        body: {
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
          timestamp: new Date().toISOString()
        }
      };
    }

    const userId = actorContext.userId;
    const user = await this.userRepo.findById(userId);
    const userEmail = user ? user.email : null;

    try {
      // 1. GET /api/v1/invitations/pending
      if (method === 'GET' && path === '/api/v1/invitations/pending') {
        const invites = await this.invitationService.listPendingInvitationsForUser(userEmail);
        return {
          status: 200,
          body: {
            success: true,
            data: invites,
            total: invites.length,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 2. POST /api/v1/invitations/:code/accept
      const acceptMatch = path.match(/^\/api\/v1\/invitations\/([^\/]+)\/accept$/);
      if (method === 'POST' && acceptMatch) {
        const inviteCode = acceptMatch[1];
        const res = await this.invitationService.acceptInvitation({
          inviteCode,
          userId,
          email: userEmail
        });
        return {
          status: 200,
          body: {
            success: true,
            data: res,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 3. POST /api/v1/invitations/:code/reject
      const rejectMatch = path.match(/^\/api\/v1\/invitations\/([^\/]+)\/reject$/);
      if (method === 'POST' && rejectMatch) {
        const inviteCode = rejectMatch[1];
        const res = await this.invitationService.rejectInvitation({
          inviteCode,
          email: userEmail
        });
        return {
          status: 200,
          body: {
            success: true,
            data: res,
            timestamp: new Date().toISOString()
          }
        };
      }

      return {
        status: 404,
        body: {
          success: false,
          error: { code: 'NOT_FOUND', message: `Route ${method} ${path} not found` },
          timestamp: new Date().toISOString()
        }
      };
    } catch (err) {
      return {
        status: 400,
        body: {
          success: false,
          error: { code: 'BAD_REQUEST', message: err.message },
          timestamp: new Date().toISOString()
        }
      };
    }
  }
}

module.exports = { InvitationApiRouter };
