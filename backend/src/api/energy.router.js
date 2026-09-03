'use strict';

/**
 * EH Home — Energy Intelligence & Automation REST API Router (Phase 19 & Phase 20)
 */

class EnergyApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.energyService       - EnergyService instance
   * @param {Object} opts.homeAuthService     - HomeAuthorizationService instance
   * @param {Object} [opts.telemetryRepo]     - DeviceTelemetryRepository instance
   * @param {Object} [opts.thresholdRepo]     - EnergyThresholdRepository instance
   * @param {Object} [opts.eventRepo]         - EnergyEventRepository instance
   * @param {Object} [opts.automationService] - AutomationService instance (Phase 20)
   * @param {Object} [opts.executionRepo]     - EnergyAutomationExecutionRepository instance (Phase 20)
   * @param {Object} [opts.optimizationRepo]  - EnergyOptimizationRepository instance (Phase 20)
   */
  constructor({
    energyService,
    homeAuthService,
    telemetryRepo = null,
    thresholdRepo = null,
    eventRepo = null,
    automationService = null,
    executionRepo = null,
    optimizationRepo = null
  }) {
    this.energyService = energyService;
    this.homeAuth = homeAuthService;
    this.telemetryRepo = telemetryRepo || (energyService ? energyService.telemetryRepo : null);
    this.thresholdRepo = thresholdRepo || (energyService ? energyService.thresholdRepo : null);
    this.eventRepo = eventRepo || (energyService ? energyService.eventRepo : null);
    this.automationService = automationService || (energyService ? energyService.automationService : null);
    this.executionRepo = executionRepo;
    this.optimizationRepo = optimizationRepo || (energyService ? energyService.optimizationRepo : null);
  }

  async handleRequest(req, actorContext) {
    const { method, path, query = {}, body = {} } = req;
    const userId = actorContext ? actorContext.userId : null;

    if (!userId) {
      return { statusCode: 401, body: { success: false, error: 'Unauthorized: missing authentication token' } };
    }

    // -------------------------------------------------------------------------
    // 1. Phase 20: Energy Automations Routes (/api/v1/energy/automations/...)
    // -------------------------------------------------------------------------

    // 1.1 GET /api/v1/energy/automations/history (Home-level execution logs)
    if (method === 'GET' && path === '/api/v1/energy/automations/history') {
      const homeId = query.homeId;
      if (!homeId) {
        return { statusCode: 400, body: { success: false, error: 'homeId query parameter is required' } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const history = await this.automationService.getExecutionHistory({ homeId, userId, limit });
      return { statusCode: 200, body: { success: true, data: history, total: history.length } };
    }

    // 1.2 GET /api/v1/energy/automations (List energy automations)
    if (method === 'GET' && path === '/api/v1/energy/automations') {
      const homeId = query.homeId;
      if (!homeId) {
        return { statusCode: 400, body: { success: false, error: 'homeId query parameter is required' } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const data = await this.automationService.listAutomations({ homeId, userId, filterType: 'energy' });
      return { statusCode: 200, body: { success: true, data, total: data.length } };
    }

    // 1.3 POST /api/v1/energy/automations (Create energy automation)
    if (method === 'POST' && path === '/api/v1/energy/automations') {
      const homeId = body.homeId || query.homeId;
      if (!homeId) {
        return { statusCode: 400, body: { success: false, error: 'homeId is required in request body' } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageAutomations'
      });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      try {
        const auto = await this.automationService.createAutomation({
          ...body,
          homeId,
          userId,
          triggerType: body.triggerType || 'energy_threshold'
        });
        return { statusCode: 201, body: { success: true, data: auto } };
      } catch (err) {
        return { statusCode: err.statusCode || 400, body: { success: false, error: err.message } };
      }
    }

    // 1.4 GET /api/v1/energy/automations/:id/history
    const autoHistoryMatch = path.match(/^\/api\/v1\/energy\/automations\/([^/]+)\/history$/);
    if (method === 'GET' && autoHistoryMatch) {
      const automationId = autoHistoryMatch[1];
      const auto = await this.automationService.automationRepo.findById(automationId);
      if (!auto) {
        return { statusCode: 404, body: { success: false, error: `Automation ${automationId} not found` } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId: auto.home_id });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const data = await this.automationService.getExecutionHistory({ homeId: auto.home_id, userId, automationId, limit });
      return { statusCode: 200, body: { success: true, data, total: data.length } };
    }

    // 1.5 POST /api/v1/energy/automations/:id/enable
    const autoEnableMatch = path.match(/^\/api\/v1\/energy\/automations\/([^/]+)\/enable$/);
    if (method === 'POST' && autoEnableMatch) {
      const automationId = autoEnableMatch[1];
      const auto = await this.automationService.automationRepo.findById(automationId);
      if (!auto) {
        return { statusCode: 404, body: { success: false, error: `Automation ${automationId} not found` } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({
        userId,
        homeId: auto.home_id,
        requiredCapability: 'canManageAutomations'
      });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const updated = await this.automationService.toggleAutomation({
        homeId: auto.home_id,
        userId,
        automationId,
        isEnabled: true
      });
      return { statusCode: 200, body: { success: true, data: updated } };
    }

    // 1.6 POST /api/v1/energy/automations/:id/disable
    const autoDisableMatch = path.match(/^\/api\/v1\/energy\/automations\/([^/]+)\/disable$/);
    if (method === 'POST' && autoDisableMatch) {
      const automationId = autoDisableMatch[1];
      const auto = await this.automationService.automationRepo.findById(automationId);
      if (!auto) {
        return { statusCode: 404, body: { success: false, error: `Automation ${automationId} not found` } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({
        userId,
        homeId: auto.home_id,
        requiredCapability: 'canManageAutomations'
      });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const updated = await this.automationService.toggleAutomation({
        homeId: auto.home_id,
        userId,
        automationId,
        isEnabled: false
      });
      return { statusCode: 200, body: { success: true, data: updated } };
    }

    // 1.7 POST /api/v1/energy/automations/:id/evaluate or /run
    const autoEvalMatch = path.match(/^\/api\/v1\/energy\/automations\/([^/]+)\/(?:evaluate|run)$/);
    if (method === 'POST' && autoEvalMatch) {
      const automationId = autoEvalMatch[1];
      const auto = await this.automationService.automationRepo.findById(automationId);
      if (!auto) {
        return { statusCode: 404, body: { success: false, error: `Automation ${automationId} not found` } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({
        userId,
        homeId: auto.home_id,
        requiredCapability: 'canExecuteAutomations'
      });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const result = await this.automationService.runAutomation({
        homeId: auto.home_id,
        userId,
        automationId,
        triggerSource: 'manual_evaluation',
        context: body.context || {}
      });
      return { statusCode: 200, body: { success: true, data: result } };
    }

    // 1.8 GET, PUT, PATCH, DELETE /api/v1/energy/automations/:id
    const autoDetailMatch = path.match(/^\/api\/v1\/energy\/automations\/([^/]+)$/);
    if (autoDetailMatch) {
      const automationId = autoDetailMatch[1];
      const auto = await this.automationService.automationRepo.findById(automationId);
      if (!auto) {
        return { statusCode: 404, body: { success: false, error: `Automation ${automationId} not found` } };
      }

      if (method === 'GET') {
        const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId: auto.home_id });
        if (!authCheck.isAuthorized) {
          return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
        }
        return { statusCode: 200, body: { success: true, data: auto } };
      }

      if (method === 'PUT' || method === 'PATCH') {
        const authCheck = await this.homeAuth.authorizeRequest({
          userId,
          homeId: auto.home_id,
          requiredCapability: 'canManageAutomations'
        });
        if (!authCheck.isAuthorized) {
          return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
        }
        const updated = await this.automationService.updateAutomation({
          homeId: auto.home_id,
          userId,
          automationId,
          updates: body
        });
        return { statusCode: 200, body: { success: true, data: updated } };
      }

      if (method === 'DELETE') {
        const authCheck = await this.homeAuth.authorizeRequest({
          userId,
          homeId: auto.home_id,
          requiredCapability: 'canManageAutomations'
        });
        if (!authCheck.isAuthorized) {
          return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
        }
        await this.automationService.deleteAutomation({ homeId: auto.home_id, userId, automationId });
        return { statusCode: 200, body: { success: true, message: `Automation ${automationId} deleted` } };
      }
    }

    // -------------------------------------------------------------------------
    // 2. Phase 20: Energy Optimization Routes (/api/v1/energy/optimization/...)
    // -------------------------------------------------------------------------

    // 2.1 POST /api/v1/energy/optimization/:id/dismiss
    const optDismissMatch = path.match(/^\/api\/v1\/energy\/optimization\/([^/]+)\/dismiss$/);
    if (method === 'POST' && optDismissMatch) {
      const optId = optDismissMatch[1];
      const homeId = body.homeId || query.homeId;
      if (homeId) {
        const authCheck = await this.homeAuth.authorizeRequest({
          userId,
          homeId,
          requiredCapability: 'canManageHome'
        });
        if (!authCheck.isAuthorized) {
          return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
        }
      }
      await this.energyService.dismissOptimization(homeId, optId);
      return { statusCode: 200, body: { success: true, message: `Optimization ${optId} dismissed` } };
    }

    // 2.2 GET /api/v1/energy/optimization/:deviceId (Device-level optimizations)
    const optDeviceMatch = path.match(/^\/api\/v1\/energy\/optimization\/([^/]+)$/);
    if (method === 'GET' && optDeviceMatch) {
      const deviceId = optDeviceMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, deviceId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const recommendations = await this.energyService.getDeviceOptimizations(deviceId);
      return { statusCode: 200, body: { success: true, data: recommendations } };
    }

    // 2.3 GET /api/v1/energy/optimization (Home-level optimization recommendations)
    if (method === 'GET' && path === '/api/v1/energy/optimization') {
      const homeId = query.homeId;
      if (!homeId) {
        return { statusCode: 400, body: { success: false, error: 'homeId query parameter is required' } };
      }
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const result = await this.energyService.getOptimizationRecommendations(homeId);
      return { statusCode: 200, body: { success: true, data: result } };
    }

    // -------------------------------------------------------------------------
    // 3. Phase 19: Telemetry, Analytics, Thresholds & Events Routes
    // -------------------------------------------------------------------------

    // 3.1 GET /api/v1/energy/devices/:deviceId/latest
    const deviceLatestMatch = path.match(/^\/api\/v1\/energy\/devices\/([^/]+)\/latest$/);
    if (method === 'GET' && deviceLatestMatch) {
      const deviceId = deviceLatestMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, deviceId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const channelIndex = query.channelIndex ? parseInt(query.channelIndex, 10) : 1;
      const latest = await this.telemetryRepo.getLatestMeasurement(deviceId, channelIndex);
      return {
        statusCode: 200,
        body: {
          success: true,
          data: latest ? {
            deviceId: latest.device_id,
            channelIndex: latest.channel_index,
            voltageV: latest.v_mv / 1000.0,
            currentA: latest.i_ma / 1000.0,
            powerW: latest.p_mw / 1000.0,
            totalEnergyKwh: latest.e_tot_wh / 1000.0,
            intervalEnergyWh: latest.e_int_mwh / 1000.0,
            frequencyHz: latest.freq_mhz / 1000.0,
            powerFactor: latest.pf_x1000 / 1000.0,
            flags: latest.flags,
            sequenceNumber: latest.sequence_number,
            timestamp: latest.device_timestamp
          } : null
        }
      };
    }

    // 3.2 GET /api/v1/energy/devices/:deviceId/history
    const deviceHistoryMatch = path.match(/^\/api\/v1\/energy\/devices\/([^/]+)\/history$/);
    if (method === 'GET' && deviceHistoryMatch) {
      const deviceId = deviceHistoryMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, deviceId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const channelIndex = query.channelIndex ? parseInt(query.channelIndex, 10) : null;
      const limit = Math.min(parseInt(query.limit, 10) || 100, 500);
      const offset = parseInt(query.offset, 10) || 0;
      const from = query.from || null;
      const to = query.to || null;

      const measurements = await this.telemetryRepo.getMeasurements(deviceId, {
        channelIndex,
        from,
        to,
        limit,
        offset
      });

      return {
        statusCode: 200,
        body: {
          success: true,
          data: {
            deviceId,
            count: measurements.length,
            measurements: measurements.map(m => ({
              id: m.id,
              channelIndex: m.channel_index,
              voltageV: m.v_mv / 1000.0,
              currentA: m.i_ma / 1000.0,
              powerW: m.p_mw / 1000.0,
              totalEnergyKwh: m.e_tot_wh / 1000.0,
              frequencyHz: m.freq_mhz / 1000.0,
              powerFactor: m.pf_x1000 / 1000.0,
              sequenceNumber: m.sequence_number,
              timestamp: m.device_timestamp
            }))
          }
        }
      };
    }

    // 3.3 GET /api/v1/energy/devices/:deviceId/summary
    const deviceSummaryMatch = path.match(/^\/api\/v1\/energy\/devices\/([^/]+)\/summary$/);
    if (method === 'GET' && deviceSummaryMatch) {
      const deviceId = deviceSummaryMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, deviceId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const period = query.period || 'today';
      const summary = await this.energyService.getDeviceSummary(deviceId, period);
      return { statusCode: 200, body: { success: true, data: summary } };
    }

    // 3.4 GET /api/v1/energy/rooms/:roomId/summary
    const roomSummaryMatch = path.match(/^\/api\/v1\/energy\/rooms\/([^/]+)\/summary$/);
    if (method === 'GET' && roomSummaryMatch) {
      const roomId = roomSummaryMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, roomId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const period = query.period || 'today';
      const summary = await this.energyService.getRoomSummary(roomId, period);
      return { statusCode: 200, body: { success: true, data: summary } };
    }

    // 3.5 GET /api/v1/energy/homes/:homeId/summary
    const homeSummaryMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/summary$/);
    if (method === 'GET' && homeSummaryMatch) {
      const homeId = homeSummaryMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const period = query.period || 'today';
      const summary = await this.energyService.getHomeSummary(homeId, period);
      return { statusCode: 200, body: { success: true, data: summary } };
    }

    // 3.6 GET /api/v1/energy/homes/:homeId/trends
    const homeTrendsMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/trends$/);
    if (method === 'GET' && homeTrendsMatch) {
      const homeId = homeTrendsMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const period = query.period || 'week';
      const interval = query.interval || 'day';
      const trends = await this.energyService.getHomeTrends(homeId, { period, interval });
      return { statusCode: 200, body: { success: true, data: trends } };
    }

    // 3.7 GET /api/v1/energy/homes/:homeId/top-consumers
    const topConsumersMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/top-consumers$/);
    if (method === 'GET' && topConsumersMatch) {
      const homeId = topConsumersMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const period = query.period || 'today';
      const limit = parseInt(query.limit, 10) || 5;
      const top = await this.energyService.getTopConsumers(homeId, { period, limit });
      return { statusCode: 200, body: { success: true, data: top } };
    }

    // 3.8 GET /api/v1/energy/homes/:homeId/thresholds
    const getThresholdsMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/thresholds$/);
    if (method === 'GET' && getThresholdsMatch) {
      const homeId = getThresholdsMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const thresholds = await this.thresholdRepo.getThresholdsForHome(homeId);
      return { statusCode: 200, body: { success: true, data: thresholds } };
    }

    // 3.9 POST /api/v1/energy/homes/:homeId/thresholds
    const postThresholdsMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/thresholds$/);
    if (method === 'POST' && postThresholdsMatch) {
      const homeId = postThresholdsMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageHome'
      });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const { highPowerW, dailyEnergyKwh, monthlyEnergyKwh, costPerKwh, currency, deviceId, isEnabled } = body;
      const record = await this.thresholdRepo.upsertThreshold({
        homeId,
        deviceId: deviceId || null,
        highPowerW: highPowerW !== undefined ? Number(highPowerW) : null,
        dailyEnergyKwh: dailyEnergyKwh !== undefined ? Number(dailyEnergyKwh) : null,
        monthlyEnergyKwh: monthlyEnergyKwh !== undefined ? Number(monthlyEnergyKwh) : null,
        costPerKwh: costPerKwh !== undefined ? Number(costPerKwh) : 0.15,
        currency: currency || 'USD',
        isEnabled: isEnabled !== undefined ? Boolean(isEnabled) : true
      });

      return { statusCode: 200, body: { success: true, data: record } };
    }

    // 3.10 GET /api/v1/energy/homes/:homeId/events
    const getEventsMatch = path.match(/^\/api\/v1\/energy\/homes\/([^/]+)\/events$/);
    if (method === 'GET' && getEventsMatch) {
      const homeId = getEventsMatch[1];
      const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
      if (!authCheck.isAuthorized) {
        return { statusCode: authCheck.statusCode || 403, body: { success: false, error: authCheck.message } };
      }

      const limit = parseInt(query.limit, 10) || 50;
      const from = query.from || null;
      const events = await this.eventRepo.getEventsForHome(homeId, { limit, from });
      return { statusCode: 200, body: { success: true, data: events } };
    }

    return { statusCode: 404, body: { success: false, error: 'Endpoint not found' } };
  }
}

module.exports = { EnergyApiRouter };
