'use strict';

/**
 * EH Home — Account API Router (Phase 16)
 *
 * Endpoints:
 *   GET    /api/v1/account/me              — Get current user profile and account details
 *   PATCH  /api/v1/account/profile         — Update user profile (name, phone, avatar, timezone)
 *   POST   /api/v1/account/change-password — Change account password
 *   GET    /api/v1/account/sessions        — List active device sessions
 *   DELETE /api/v1/account/sessions/:id    — Revoke a device session
 *   DELETE /api/v1/account                 — Delete account permanently
 */

class AccountApiRouter {
  constructor({ authService, homeRepo }) {
    this.authService = authService;
    this.homeRepo = homeRepo;
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

    try {
      // 1. GET /api/v1/account/me
      if (method === 'GET' && path === '/api/v1/account/me') {
        const profile = await this.authService.getProfile(userId);
        const sessions = await this.authService.listSessions(userId);
        return {
          status: 200,
          body: {
            success: true,
            data: {
              ...profile,
              activeSessionsCount: sessions.length
            },
            timestamp: new Date().toISOString()
          }
        };
      }

      // 2. PATCH /api/v1/account/profile
      if (method === 'PATCH' && path === '/api/v1/account/profile') {
        const updated = await this.authService.updateProfile(userId, body);
        return {
          status: 200,
          body: {
            success: true,
            data: updated,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 3. POST /api/v1/account/change-password
      if (method === 'POST' && path === '/api/v1/account/change-password') {
        const { oldPassword, newPassword } = body;
        if (!oldPassword || !newPassword) {
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: 'Old and new password required' },
              timestamp: new Date().toISOString()
            }
          };
        }

        await this.authService.changePassword(userId, { oldPassword, newPassword });
        return {
          status: 200,
          body: {
            success: true,
            data: { message: 'Password changed successfully. Other sessions invalidated.' },
            timestamp: new Date().toISOString()
          }
        };
      }

      // 4. GET /api/v1/account/sessions
      if (method === 'GET' && path === '/api/v1/account/sessions') {
        const sessions = await this.authService.listSessions(userId);
        return {
          status: 200,
          body: {
            success: true,
            data: sessions,
            total: sessions.length,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 5. DELETE /api/v1/account/sessions/:id
      if (method === 'DELETE' && path.startsWith('/api/v1/account/sessions/')) {
        const sessionId = path.replace('/api/v1/account/sessions/', '');
        const success = await this.authService.revokeSession(userId, sessionId);
        if (!success) {
          return {
            status: 404,
            body: {
              success: false,
              error: { code: 'NOT_FOUND', message: 'Session not found' },
              timestamp: new Date().toISOString()
            }
          };
        }
        return {
          status: 200,
          body: {
            success: true,
            data: { revokedSessionId: sessionId },
            timestamp: new Date().toISOString()
          }
        };
      }

      // 6. DELETE /api/v1/account
      if (method === 'DELETE' && path === '/api/v1/account') {
        const { password } = body;
        if (!password) {
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: 'Password confirmation required' },
              timestamp: new Date().toISOString()
            }
          };
        }

        await this.authService.deleteAccount(userId, { password, homeRepo: this.homeRepo });
        return {
          status: 200,
          body: {
            success: true,
            data: { message: 'Account permanently deleted' },
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
      const statusCode = err.code === 'INVALID_PASSWORD' ? 403 : (err.code === 'USER_NOT_FOUND' ? 404 : 400);
      return {
        status: statusCode,
        body: {
          success: false,
          error: { code: err.code || 'BAD_REQUEST', message: err.message },
          timestamp: new Date().toISOString()
        }
      };
    }
  }
}

module.exports = { AccountApiRouter };
