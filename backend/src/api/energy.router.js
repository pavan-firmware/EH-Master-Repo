'use strict';

/**
 * EH Home — Energy Intelligence & Telemetry REST API Router (Phase 19)
 */

class EnergyApiRouter {
  /**
   * @param {Object} opts
   * @param {Object} opts.energyService       - EnergyService instance
   * @param {Object} opts.homeAuthService     - HomeAuthorizationService instance
   * @param {Object} [opts.telemetryRepo]     - DeviceTelemetryRepository instance
   * @param {Object} [opts.thresholdRepo]     - EnergyThresholdRepository instance
   * @param {Object} [opts.eventRepo]         - EnergyEventRepository instance
   */
  constructor({ energyService, homeAuthService, telemetryRepo = null, thresholdRepo = null, eventRepo = null }) {
    this.energyService = energyService;
    this.homeAuth = homeAuthService;
    this.telemetryRepo = telemetryRepo || (energyService ? energyService.telemetryRepo : null);
    this.thresholdRepo = thresholdRepo || (energyService ? energyService.thresholdRepo : null);
    this.eventRepo = eventRepo || (energyService ? energyService.eventRepo : null);
  }

  async handleRequest(req, actorContext) {
    const { method, path, query = {}, body = {} } = req;
    const userId = actorContext ? actorContext.userId : null;

    if (!userId) {
      return { statusCode: 401, body: { success: false, error: 'Unauthorized: missing authentication token' } };
    }

    // 1. GET /api/v1/energy/devices/:deviceId/latest
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

    // 2. GET /api/v1/energy/devices/:deviceId/history
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

    // 3. GET /api/v1/energy/devices/:deviceId/summary
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

    // 4. GET /api/v1/energy/rooms/:roomId/summary
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

    // 5. GET /api/v1/energy/homes/:homeId/summary
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

    // 6. GET /api/v1/energy/homes/:homeId/trends
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

    // 7. GET /api/v1/energy/homes/:homeId/top-consumers
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

    // 8. GET /api/v1/energy/homes/:homeId/thresholds
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

    // 9. POST /api/v1/energy/homes/:homeId/thresholds
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

    // 10. GET /api/v1/energy/homes/:homeId/events
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
