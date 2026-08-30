'use strict';

/**
 * EH Home — AutomationSceneApiRouter (Phase 10)
 *
 * REST Endpoints for Scenes, Automations, Schedules, and Execution History.
 */

class AutomationSceneApiRouter {
  constructor({ sceneService, automationService, scheduleService }) {
    this.sceneService = sceneService;
    this.automationService = automationService;
    this.scheduleService = scheduleService;
  }

  async handle(method, path, body = {}, headers = {}, params = {}) {
    const userId = params.userId || headers['x-user-id'] || 'usr_owner_1';

    try {
      // -----------------------------------------------------------------------
      // 1. SCENES ROUTES (/api/v1/homes/:homeId/scenes)
      // -----------------------------------------------------------------------
      const scenesListMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/scenes\/?$/);
      if (scenesListMatch) {
        const homeId = scenesListMatch[1];
        if (method === 'GET') {
          const data = await this.sceneService.listScenes({ homeId, userId });
          return { status: 200, body: { data, total: data.length } };
        }
        if (method === 'POST') {
          const scene = await this.sceneService.createScene({ ...body, homeId, userId });
          return { status: 201, body: { data: scene } };
        }
      }

      const sceneRunMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/scenes\/([a-zA-Z0-9_-]+)\/run\/?$/);
      if (sceneRunMatch && method === 'POST') {
        const [, homeId, sceneId] = sceneRunMatch;
        const result = await this.sceneService.runScene({ homeId, userId, sceneId, executionIdentity: body.executionIdentity });
        return { status: 200, body: { data: result } };
      }

      const sceneDetailMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/scenes\/([a-zA-Z0-9_-]+)\/?$/);
      if (sceneDetailMatch) {
        const [, homeId, sceneId] = sceneDetailMatch;
        if (method === 'GET') {
          const data = await this.sceneService.getScene({ homeId, userId, sceneId });
          return { status: 200, body: { data } };
        }
        if (method === 'PUT' || method === 'PATCH') {
          const data = await this.sceneService.updateScene({ homeId, userId, sceneId, updates: body });
          return { status: 200, body: { data } };
        }
        if (method === 'DELETE') {
          await this.sceneService.deleteScene({ homeId, userId, sceneId });
          return { status: 200, body: { success: true, message: `Scene ${sceneId} deleted` } };
        }
      }

      // -----------------------------------------------------------------------
      // 2. AUTOMATIONS ROUTES (/api/v1/homes/:homeId/automations)
      // -----------------------------------------------------------------------
      const autoListMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automations\/?$/);
      if (autoListMatch) {
        const homeId = autoListMatch[1];
        if (method === 'GET') {
          const data = await this.automationService.listAutomations({ homeId, userId });
          return { status: 200, body: { data, total: data.length } };
        }
        if (method === 'POST') {
          const auto = await this.automationService.createAutomation({ ...body, homeId, userId });
          return { status: 201, body: { data: auto } };
        }
      }

      const autoRunMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automations\/([a-zA-Z0-9_-]+)\/run\/?$/);
      if (autoRunMatch && method === 'POST') {
        const [, homeId, automationId] = autoRunMatch;
        const result = await this.automationService.runAutomation({
          homeId,
          userId,
          automationId,
          triggerSource: 'manual',
          executionIdentity: body.executionIdentity
        });
        return { status: 200, body: { data: result } };
      }

      const autoToggleMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automations\/([a-zA-Z0-9_-]+)\/toggle\/?$/);
      if (autoToggleMatch && (method === 'PATCH' || method === 'POST')) {
        const [, homeId, automationId] = autoToggleMatch;
        const data = await this.automationService.toggleAutomation({
          homeId,
          userId,
          automationId,
          isEnabled: body.isEnabled ?? body.is_enabled ?? true
        });
        return { status: 200, body: { data } };
      }

      const autoHistoryMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automations\/([a-zA-Z0-9_-]+)\/history\/?$/);
      if (autoHistoryMatch && method === 'GET') {
        const [, homeId, automationId] = autoHistoryMatch;
        const data = await this.automationService.getExecutionHistory({ homeId, userId, automationId, limit: params.limit });
        return { status: 200, body: { data, total: data.length } };
      }

      const autoDetailMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automations\/([a-zA-Z0-9_-]+)\/?$/);
      if (autoDetailMatch) {
        const [, homeId, automationId] = autoDetailMatch;
        if (method === 'GET') {
          const data = await this.automationService.getAutomation({ homeId, userId, automationId });
          return { status: 200, body: { data } };
        }
        if (method === 'PUT' || method === 'PATCH') {
          const data = await this.automationService.updateAutomation({ homeId, userId, automationId, updates: body });
          return { status: 200, body: { data } };
        }
        if (method === 'DELETE') {
          await this.automationService.deleteAutomation({ homeId, userId, automationId });
          return { status: 200, body: { success: true, message: `Automation ${automationId} deleted` } };
        }
      }

      // -----------------------------------------------------------------------
      // 3. SCHEDULES ROUTES (/api/v1/homes/:homeId/schedules)
      // -----------------------------------------------------------------------
      const schedListMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/schedules\/?$/);
      if (schedListMatch) {
        const homeId = schedListMatch[1];
        if (method === 'GET') {
          const data = await this.scheduleService.listSchedules({ homeId, userId });
          return { status: 200, body: { data, total: data.length } };
        }
        if (method === 'POST') {
          const sched = await this.scheduleService.createSchedule({ ...body, homeId, userId });
          return { status: 201, body: { data: sched } };
        }
      }

      const schedToggleMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/schedules\/([a-zA-Z0-9_-]+)\/toggle\/?$/);
      if (schedToggleMatch && (method === 'PATCH' || method === 'POST')) {
        const [, homeId, scheduleId] = schedToggleMatch;
        const data = await this.scheduleService.toggleSchedule({
          homeId,
          userId,
          scheduleId,
          isEnabled: body.isEnabled ?? body.is_enabled ?? true
        });
        return { status: 200, body: { data } };
      }

      const schedDetailMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/schedules\/([a-zA-Z0-9_-]+)\/?$/);
      if (schedDetailMatch) {
        const [, homeId, scheduleId] = schedDetailMatch;
        if (method === 'GET') {
          const data = await this.scheduleService.getSchedule({ homeId, userId, scheduleId });
          return { status: 200, body: { data } };
        }
        if (method === 'PUT' || method === 'PATCH') {
          const data = await this.scheduleService.updateSchedule({ homeId, userId, scheduleId, updates: body });
          return { status: 200, body: { data } };
        }
        if (method === 'DELETE') {
          await this.scheduleService.deleteSchedule({ homeId, userId, scheduleId });
          return { status: 200, body: { success: true, message: `Schedule ${scheduleId} deleted` } };
        }
      }

      // -----------------------------------------------------------------------
      // 4. HOME EXECUTION HISTORY (/api/v1/homes/:homeId/automation-history)
      // -----------------------------------------------------------------------
      const homeHistoryMatch = path.match(/^\/api\/v1\/homes\/([a-zA-Z0-9_-]+)\/automation-history\/?$/);
      if (homeHistoryMatch && method === 'GET') {
        const homeId = homeHistoryMatch[1];
        const data = await this.automationService.getExecutionHistory({ homeId, userId, limit: params.limit });
        return { status: 200, body: { data, total: data.length } };
      }

      return null;
    } catch (err) {
      return {
        status: err.statusCode || 500,
        body: {
          success: false,
          error: { code: err.code || 'AUTOMATION_ERROR', message: err.message }
        }
      };
    }
  }
}

module.exports = { AutomationSceneApiRouter };
