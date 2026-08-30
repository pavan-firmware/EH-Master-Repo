'use strict';

/**
 * EH Home — NotificationApiRouter (Phase 15)
 *
 * REST Endpoints for Notification History, Preferences, Unread Counts, and Push Device Tokens.
 */

class NotificationApiRouter {
  constructor({ notificationRepository, notificationService, homeAuthorizationService = null }) {
    this.repo = notificationRepository;
    this.service = notificationService;
    this.homeAuth = homeAuthorizationService;
  }

  async handle(method, path, body = {}, headers = {}, params = {}) {
    const userId = params.userId || headers['x-user-id'] || 'system';

    try {
      // 1. GET /api/v1/notifications/unread-count
      if (method === 'GET' && path === '/api/v1/notifications/unread-count') {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          await this.homeAuth.assertMembership(userId, homeId);
        }
        const count = await this.repo.countUnread(userId, homeId);
        return { status: 200, body: { unreadCount: count } };
      }

      // 2. GET /api/v1/notifications/preferences
      if (method === 'GET' && path === '/api/v1/notifications/preferences') {
        const prefs = await this.repo.getPreferences(userId);
        return { status: 200, body: { data: prefs } };
      }

      // 3. PUT /api/v1/notifications/preferences
      if (method === 'PUT' && path === '/api/v1/notifications/preferences') {
        const prefs = await this.repo.upsertPreferences(userId, body);
        return { status: 200, body: { success: true, data: prefs } };
      }

      // 4. POST /api/v1/notifications/push-tokens
      if (method === 'POST' && path === '/api/v1/notifications/push-tokens') {
        const { pushToken, platform = 'android', deviceName = null } = body;
        if (!pushToken || typeof pushToken !== 'string') {
          return { status: 400, body: { error: 'INVALID_PUSH_TOKEN', message: 'pushToken is required' } };
        }
        const tokenId = `tok_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const record = await this.repo.upsertDeviceToken({
          id: tokenId,
          userId,
          pushToken,
          platform,
          deviceName
        });
        return { status: 201, body: { success: true, data: record } };
      }

      // 5. DELETE /api/v1/notifications/push-tokens/:token
      const tokenDeleteMatch = path.match(/^\/api\/v1\/notifications\/push-tokens\/(.+)$/);
      if (tokenDeleteMatch && method === 'DELETE') {
        const token = decodeURIComponent(tokenDeleteMatch[1]);
        await this.repo.removeDeviceToken(token, userId);
        return { status: 200, body: { success: true, message: 'Device token removed' } };
      }

      // 6. POST /api/v1/notifications/mark-all-read
      if (method === 'POST' && path === '/api/v1/notifications/mark-all-read') {
        const homeId = body.homeId || params.homeId || null;
        if (homeId && this.homeAuth) {
          await this.homeAuth.assertMembership(userId, homeId);
        }
        const updated = await this.repo.markAllRead(userId, homeId);
        return { status: 200, body: { success: true, markedCount: updated.length } };
      }

      // 7. PATCH /api/v1/notifications/:id/read
      const readMatch = path.match(/^\/api\/v1\/notifications\/([a-zA-Z0-9_-]+)\/read$/);
      if (readMatch && (method === 'PATCH' || method === 'POST')) {
        const notificationId = readMatch[1];
        const updated = await this.repo.markRead(notificationId, userId);
        if (!updated) {
          return { status: 404, body: { error: 'NOTIFICATION_NOT_FOUND', message: `Notification ${notificationId} not found` } };
        }
        return { status: 200, body: { success: true, data: updated } };
      }

      // 8. GET /api/v1/notifications
      if (method === 'GET' && (path === '/api/v1/notifications' || path === '/api/v1/notifications/')) {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          await this.homeAuth.assertMembership(userId, homeId);
        }
        const category = params.category || null;
        const unreadOnly = params.unreadOnly === 'true' || params.unreadOnly === true;
        const limit = parseInt(params.limit || '50', 10);
        const offset = parseInt(params.offset || '0', 10);

        const list = await this.repo.findUserNotifications(userId, {
          homeId,
          category,
          limit,
          offset,
          unreadOnly
        });
        const unreadCount = await this.repo.countUnread(userId, homeId);

        return {
          status: 200,
          body: {
            data: list,
            total: list.length,
            unreadCount
          }
        };
      }

      return null; // Route not matched
    } catch (err) {
      if (err.message && err.message.includes('403') || err.message.includes('not a member')) {
        return { status: 403, body: { error: 'FORBIDDEN', message: err.message } };
      }
      return { status: 500, body: { error: 'INTERNAL_ERROR', message: err.message } };
    }
  }
}

module.exports = { NotificationApiRouter };
