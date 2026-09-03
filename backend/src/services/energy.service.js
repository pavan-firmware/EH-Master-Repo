'use strict';

/**
 * EH Home — Energy Intelligence, Telemetry Ingestion & Analytics Service (Phase 19)
 *
 * Implements:
 *   - Realtime & historical electrical telemetry ingestion
 *   - Monotonic counter verification & reset handling
 *   - Incremental aggregation across minute, hour, day buckets
 *   - Authoritative device, room, and home energy summaries
 *   - Period comparisons & trend forecasting
 *   - Configurable energy thresholds & anomaly alerts
 *   - RealtimeEventBus & NotificationService integration
 *   - Retention policy lifecycle enforcement
 */

class EnergyService {
  /**
   * @param {Object} opts
   * @param {Object} opts.telemetryRepo      - DeviceTelemetryRepository
   * @param {Object} opts.aggregateRepo      - TelemetryAggregateRepository
   * @param {Object} opts.thresholdRepo      - EnergyThresholdRepository
   * @param {Object} opts.eventRepo          - EnergyEventRepository
   * @param {Object} opts.deviceRepo         - DeviceRepository
   * @param {Object} opts.roomRepo           - RoomRepository
   * @param {Object} opts.homeRepo           - HomeRepository
   * @param {Object} [opts.notificationService] - NotificationService
   * @param {Object} [opts.realtimeEventBus]    - RealtimeEventBus
   * @param {Object} [opts.automationService]   - AutomationService (Phase 20)
   * @param {Object} [opts.optimizationRepo]    - EnergyOptimizationRepository (Phase 20)
   */
  constructor({
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    eventRepo,
    deviceRepo,
    roomRepo,
    homeRepo,
    notificationService = null,
    realtimeEventBus = null,
    automationService = null,
    optimizationRepo = null,
    tariffRepo = null,
    tariffPeriodRepo = null,
    budgetRepo = null,
    costOptimizationRepo = null
  }) {
    this.telemetryRepo = telemetryRepo;
    this.aggregateRepo = aggregateRepo;
    this.thresholdRepo = thresholdRepo;
    this.eventRepo = eventRepo;
    this.deviceRepo = deviceRepo;
    this.roomRepo = roomRepo;
    this.homeRepo = homeRepo;
    this.notificationService = notificationService;
    this.realtimeEventBus = realtimeEventBus;
    this.automationService = automationService;
    this.optimizationRepo = optimizationRepo;
    this.tariffRepo = tariffRepo;
    this.tariffPeriodRepo = tariffPeriodRepo;
    this.budgetRepo = budgetRepo;
    this.costOptimizationRepo = costOptimizationRepo;

    this._deviceStateCache = new Map(); // deviceId -> { lastSeq, lastEnergyWh, lastTimestamp }
    this._alertCooldownMap = new Map(); // alertKey -> lastSentTimestamp
  }

  // ---------------------------------------------------------------------------
  // 1. Telemetry Ingestion & Energy Calculation
  // ---------------------------------------------------------------------------

  /**
   * Ingest, validate, persist and aggregate incoming electrical telemetry.
   *
   * @param {Object} t - EnergyTelemetry message envelope
   */
  async ingestTelemetry(t) {
    if (!t || !t.deviceId) {
      throw new Error('Invalid telemetry payload: deviceId is required');
    }

    const deviceId = t.deviceId;
    const channelIndex = t.channelIndex !== undefined ? t.channelIndex : 1;

    // Fixed-point validation
    if (typeof t.v_mv !== 'number' || t.v_mv <= 0) throw new Error(`Invalid v_mv: ${t.v_mv}`);
    if (typeof t.i_ma !== 'number' || t.i_ma < 0) throw new Error(`Invalid i_ma: ${t.i_ma}`);
    if (typeof t.p_mw !== 'number' || t.p_mw < 0) throw new Error(`Invalid p_mw: ${t.p_mw}`);
    if (typeof t.e_tot_wh !== 'number' || t.e_tot_wh < 0) throw new Error(`Invalid e_tot_wh: ${t.e_tot_wh}`);
    if (typeof t.pf_x1000 !== 'number' || t.pf_x1000 < 0 || t.pf_x1000 > 1000) throw new Error(`Invalid pf_x1000: ${t.pf_x1000}`);
    if (typeof t.freq_mhz !== 'number' || t.freq_mhz <= 0) throw new Error(`Invalid freq_mhz: ${t.freq_mhz}`);

    const newSeq = t.sequenceNumber || 0;
    const cacheKey = `${deviceId}_${channelIndex}`;
    const cached = this._deviceStateCache.get(cacheKey);

    // Duplicate detection
    if (cached && newSeq > 0 && newSeq <= cached.lastSeq) {
      // Duplicate or replayed sequence — ignore without corrupting aggregates
      return { status: 'DUPLICATE_IGNORED', sequenceNumber: newSeq };
    }

    const flags = t.flags || 0;
    const isReset = (flags & 1) !== 0 || (cached && t.e_tot_wh < cached.lastEnergyWh);
    const nowIso = t.timestamp || new Date().toISOString();

    // Calculate delta energy
    let deltaEnergyWh = 0;
    if (isReset) {
      // Counter reset detected
      deltaEnergyWh = t.e_int_mwh ? t.e_int_mwh / 1000.0 : (t.p_mw / 1000.0) * (5.0 / 3600.0); // fallback power integration
    } else if (cached && t.e_tot_wh >= cached.lastEnergyWh) {
      deltaEnergyWh = t.e_tot_wh - cached.lastEnergyWh;
    } else if (t.e_int_mwh) {
      deltaEnergyWh = t.e_int_mwh / 1000.0;
    } else {
      deltaEnergyWh = t.e_tot_wh;
    }

    // Persist raw measurement
    const measurement = await this.telemetryRepo.recordMeasurement({
      deviceId,
      channelIndex,
      v_mv: t.v_mv,
      i_ma: t.i_ma,
      p_mw: t.p_mw,
      e_tot_wh: t.e_tot_wh,
      e_int_mwh: t.e_int_mwh || Math.round(deltaEnergyWh * 1000),
      freq_mhz: t.freq_mhz,
      pf_x1000: t.pf_x1000,
      flags,
      sequenceNumber: newSeq,
      timestamp: nowIso,
      ingested_at: new Date().toISOString()
    });

    // Update state cache
    this._deviceStateCache.set(cacheKey, {
      lastSeq: newSeq,
      lastEnergyWh: t.e_tot_wh,
      lastTimestamp: nowIso
    });

    // Resolve homeId for device
    const homeId = await this._getHomeIdForDevice(deviceId);

    // Update Incremental Aggregates
    await this._updateAggregates(deviceId, channelIndex, t.p_mw / 1000.0, deltaEnergyWh, nowIso);

    // Evaluate Thresholds & Anomalies
    if (homeId) {
      await this._evaluateThresholds(homeId, deviceId, t.p_mw / 1000.0, t.e_tot_wh / 1000.0, isReset);
    }

    // Evaluate Active Energy Automations (Phase 20)
    if (homeId && this.automationService) {
      try {
        await this._evaluateEnergyAutomations(homeId, deviceId, channelIndex, t, nowIso);
      } catch (err) {
        console.warn(`[EnergyService] Automation evaluation failed for ${deviceId}:`, err.message);
      }
    }

    // Publish Realtime Event
    if (this.realtimeEventBus && homeId) {
      this.realtimeEventBus.publish({
        type: 'telemetry.update',
        homeId,
        deviceId,
        payload: {
          deviceId,
          channelIndex,
          voltageV: t.v_mv / 1000.0,
          currentA: t.i_ma / 1000.0,
          powerW: t.p_mw / 1000.0,
          totalEnergyKwh: t.e_tot_wh / 1000.0,
          powerFactor: t.pf_x1000 / 1000.0,
          frequencyHz: t.freq_mhz / 1000.0,
          timestamp: nowIso
        }
      });
    }

    return { status: 'INGESTED', measurementId: measurement.id };
  }

  // ---------------------------------------------------------------------------
  // 2. Aggregation Engine (Hour & Day)
  // ---------------------------------------------------------------------------

  async _updateAggregates(deviceId, channelIndex, powerW, deltaEnergyWh, timestampIso) {
    const ts = new Date(timestampIso);

    // 1. Hour Bucket
    const hourStart = new Date(Date.UTC(ts.getUTCFullYear(), ts.getUTCMonth(), ts.getUTCDate(), ts.getUTCHours(), 0, 0)).toISOString();
    const hourEnd = new Date(Date.UTC(ts.getUTCFullYear(), ts.getUTCMonth(), ts.getUTCDate(), ts.getUTCHours() + 1, 0, 0)).toISOString();

    const existingHour = await this.aggregateRepo.db.findById('telemetry_aggregates', `agg_${deviceId}_${channelIndex}_HOUR_${hourStart}`);
    if (existingHour) {
      const count = (existingHour.sample_count || 0) + 1;
      const prevTotalWh = existingHour.total_energy_wh || 0;
      const prevAvgP = existingHour.avg_power_w || 0;
      const newAvgP = prevAvgP + (powerW - prevAvgP) / count;
      const newPeakP = Math.max(existingHour.peak_power_w || 0, powerW);
      const newMinP = Math.min(existingHour.min_power_w !== undefined ? existingHour.min_power_w : powerW, powerW);

      await this.aggregateRepo.upsertAggregate({
        deviceId,
        channelIndex,
        bucketType: 'HOUR',
        bucketStart: hourStart,
        bucketEnd: hourEnd,
        totalEnergyWh: prevTotalWh + deltaEnergyWh,
        avgPowerW: Math.round(newAvgP * 100) / 100,
        peakPowerW: Math.round(newPeakP * 100) / 100,
        minPowerW: Math.round(newMinP * 100) / 100,
        sampleCount: count,
        dataQuality: 'GOOD'
      });
    } else {
      await this.aggregateRepo.upsertAggregate({
        deviceId,
        channelIndex,
        bucketType: 'HOUR',
        bucketStart: hourStart,
        bucketEnd: hourEnd,
        totalEnergyWh: deltaEnergyWh,
        avgPowerW: Math.round(powerW * 100) / 100,
        peakPowerW: Math.round(powerW * 100) / 100,
        minPowerW: Math.round(powerW * 100) / 100,
        sampleCount: 1,
        dataQuality: 'GOOD'
      });
    }

    // 2. Day Bucket
    const dayStart = new Date(Date.UTC(ts.getUTCFullYear(), ts.getUTCMonth(), ts.getUTCDate(), 0, 0, 0)).toISOString();
    const dayEnd = new Date(Date.UTC(ts.getUTCFullYear(), ts.getUTCMonth(), ts.getUTCDate() + 1, 0, 0, 0)).toISOString();

    const existingDay = await this.aggregateRepo.db.findById('telemetry_aggregates', `agg_${deviceId}_${channelIndex}_DAY_${dayStart}`);
    if (existingDay) {
      const count = (existingDay.sample_count || 0) + 1;
      const prevTotalWh = existingDay.total_energy_wh || 0;
      const prevAvgP = existingDay.avg_power_w || 0;
      const newAvgP = prevAvgP + (powerW - prevAvgP) / count;
      const newPeakP = Math.max(existingDay.peak_power_w || 0, powerW);
      const newMinP = Math.min(existingDay.min_power_w !== undefined ? existingDay.min_power_w : powerW, powerW);

      await this.aggregateRepo.upsertAggregate({
        deviceId,
        channelIndex,
        bucketType: 'DAY',
        bucketStart: dayStart,
        bucketEnd: dayEnd,
        totalEnergyWh: prevTotalWh + deltaEnergyWh,
        avgPowerW: Math.round(newAvgP * 100) / 100,
        peakPowerW: Math.round(newPeakP * 100) / 100,
        minPowerW: Math.round(newMinP * 100) / 100,
        sampleCount: count,
        dataQuality: 'GOOD'
      });
    } else {
      await this.aggregateRepo.upsertAggregate({
        deviceId,
        channelIndex,
        bucketType: 'DAY',
        bucketStart: dayStart,
        bucketEnd: dayEnd,
        totalEnergyWh: deltaEnergyWh,
        avgPowerW: Math.round(powerW * 100) / 100,
        peakPowerW: Math.round(powerW * 100) / 100,
        minPowerW: Math.round(powerW * 100) / 100,
        sampleCount: 1,
        dataQuality: 'GOOD'
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Authoritative Analytics & Summaries
  // ---------------------------------------------------------------------------

  /**
   * Device Energy Summary
   */
  async getDeviceSummary(deviceId, period = 'today') {
    const { from, to } = this._getPeriodBounds(period);
    const latest = await this.telemetryRepo.getLatestMeasurement(deviceId);
    const currentPowerW = latest ? latest.p_mw / 1000.0 : 0.0;

    const aggregates = await this.aggregateRepo.getAggregates(deviceId, {
      bucketType: period === 'today' ? 'HOUR' : 'DAY',
      from,
      to
    });

    let totalEnergyWh = 0;
    let peakPowerW = currentPowerW;
    let minPowerW = latest ? currentPowerW : 0;
    let sampleCount = 0;
    let weightedPowerSum = 0;

    if (aggregates && aggregates.length > 0) {
      for (const a of aggregates) {
        totalEnergyWh += (a.total_energy_wh || 0);
        peakPowerW = Math.max(peakPowerW, a.peak_power_w || 0);
        minPowerW = Math.min(minPowerW, a.min_power_w !== undefined ? a.min_power_w : (a.avg_power_w || 0));
        sampleCount += (a.sample_count || 0);
        weightedPowerSum += (a.avg_power_w || 0) * (a.sample_count || 1);
      }
    }
    if (totalEnergyWh === 0 && latest) {
      totalEnergyWh = latest.e_tot_wh || 0;
      if (sampleCount === 0) sampleCount = 1;
      if (weightedPowerSum === 0) weightedPowerSum = currentPowerW;
    }

    const avgPowerW = sampleCount > 0 ? weightedPowerSum / sampleCount : 0.0;

    return {
      schemaVersion: 1,
      entityType: 'device',
      entityId: deviceId,
      period,
      currentPowerW: Math.round(currentPowerW * 100) / 100,
      totalEnergyKwh: Math.round((totalEnergyWh / 1000.0) * 1000) / 1000,
      peakPowerW: Math.round(peakPowerW * 100) / 100,
      avgPowerW: Math.round(avgPowerW * 100) / 100,
      minPowerW: Math.round(minPowerW * 100) / 100,
      dataQuality: 'GOOD',
      sampleCount,
      lastUpdated: latest ? latest.device_timestamp : new Date().toISOString()
    };
  }

  /**
   * Room Energy Summary
   */
  async getRoomSummary(roomId, period = 'today') {
    const devices = await this.deviceRepo.getDevicesByRoom(roomId);
    if (!devices || devices.length === 0) {
      return {
        schemaVersion: 1,
        entityType: 'room',
        entityId: roomId,
        period,
        currentPowerW: 0,
        totalEnergyKwh: 0,
        peakPowerW: 0,
        avgPowerW: 0,
        minPowerW: 0,
        dataQuality: 'GOOD',
        sampleCount: 0,
        devicesCount: 0,
        lastUpdated: new Date().toISOString()
      };
    }

    let currentPowerW = 0;
    let totalEnergyKwh = 0;
    let peakPowerW = 0;
    let totalSampleCount = 0;
    let weightedPowerSum = 0;

    for (const dev of devices) {
      const summary = await this.getDeviceSummary(dev.id, period);
      currentPowerW += summary.currentPowerW;
      totalEnergyKwh += summary.totalEnergyKwh;
      peakPowerW = Math.max(peakPowerW, summary.peakPowerW);
      totalSampleCount += summary.sampleCount;
      weightedPowerSum += summary.avgPowerW * (summary.sampleCount || 1);
    }

    const avgPowerW = totalSampleCount > 0 ? weightedPowerSum / totalSampleCount : 0.0;

    return {
      schemaVersion: 1,
      entityType: 'room',
      entityId: roomId,
      period,
      currentPowerW: Math.round(currentPowerW * 100) / 100,
      totalEnergyKwh: Math.round(totalEnergyKwh * 1000) / 1000,
      peakPowerW: Math.round(peakPowerW * 100) / 100,
      avgPowerW: Math.round(avgPowerW * 100) / 100,
      dataQuality: 'GOOD',
      sampleCount: totalSampleCount,
      devicesCount: devices.length,
      lastUpdated: new Date().toISOString()
    };
  }

  /**
   * Home Energy Summary (with period comparison and cost calculation)
   */
  async getHomeSummary(homeId, period = 'today') {
    const devices = await this.deviceRepo.getDevicesByHome(homeId);
    const rooms = this.roomRepo ? await this.roomRepo.getRoomsByHome(homeId) : [];
    const thresholds = await this.thresholdRepo.getThreshold(homeId);
    const costPerKwh = thresholds ? (thresholds.cost_per_kwh || 0.15) : 0.15;
    const currency = thresholds ? (thresholds.currency || 'USD') : 'USD';

    let currentPowerW = 0;
    let totalEnergyKwh = 0;
    let peakPowerW = 0;
    let totalSampleCount = 0;
    let weightedPowerSum = 0;

    for (const dev of devices) {
      const summary = await this.getDeviceSummary(dev.id, period);
      currentPowerW += summary.currentPowerW;
      totalEnergyKwh += summary.totalEnergyKwh;
      peakPowerW = Math.max(peakPowerW, summary.peakPowerW);
      totalSampleCount += summary.sampleCount;
      weightedPowerSum += summary.avgPowerW * (summary.sampleCount || 1);
    }

    const avgPowerW = totalSampleCount > 0 ? weightedPowerSum / totalSampleCount : 0.0;
    const costEstimate = Math.round(totalEnergyKwh * costPerKwh * 100) / 100;

    // Period Comparison
    const comparison = await this._calculatePeriodComparison(homeId, period, totalEnergyKwh);

    return {
      schemaVersion: 1,
      entityType: 'home',
      entityId: homeId,
      period,
      currentPowerW: Math.round(currentPowerW * 100) / 100,
      totalEnergyKwh: Math.round(totalEnergyKwh * 1000) / 1000,
      peakPowerW: Math.round(peakPowerW * 100) / 100,
      avgPowerW: Math.round(avgPowerW * 100) / 100,
      costEstimate,
      currency,
      comparison,
      devicesCount: devices.length,
      roomsCount: rooms.length,
      dataQuality: 'GOOD',
      sampleCount: totalSampleCount,
      lastUpdated: new Date().toISOString()
    };
  }

  /**
   * Home Usage Trends (Hourly / Daily / Monthly)
   */
  async getHomeTrends(homeId, { period = 'week', interval = 'day' } = {}) {
    const devices = await this.deviceRepo.getDevicesByHome(homeId);
    const deviceIds = devices.map(d => d.id);
    const { from, to } = this._getPeriodBounds(period);
    const bucketType = interval === 'hour' ? 'HOUR' : 'DAY';

    const aggregates = await this.aggregateRepo.getHomeAggregates(deviceIds, {
      bucketType,
      from,
      to
    });

    // Group by timestamp bucket
    const trendMap = new Map();
    for (const a of aggregates) {
      const bucket = a.bucket_start;
      const existing = trendMap.get(bucket) || { energyWh: 0, powerSum: 0, peakPowerW: 0, count: 0 };
      existing.energyWh += (a.total_energy_wh || 0);
      existing.powerSum += (a.avg_power_w || 0) * (a.sample_count || 1);
      existing.peakPowerW = Math.max(existing.peakPowerW, a.peak_power_w || 0);
      existing.count += (a.sample_count || 1);
      trendMap.set(bucket, existing);
    }

    const points = [];
    for (const [bucketStart, stats] of trendMap.entries()) {
      points.push({
        timestamp: bucketStart,
        energyKwh: Math.round((stats.energyWh / 1000.0) * 1000) / 1000,
        avgPowerW: stats.count > 0 ? Math.round((stats.powerSum / stats.count) * 100) / 100 : 0,
        peakPowerW: Math.round(stats.peakPowerW * 100) / 100,
        sampleCount: stats.count
      });
    }

    points.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    return {
      homeId,
      period,
      interval,
      points
    };
  }

  /**
   * Top Energy Consumers (by Device and by Room)
   */
  async getTopConsumers(homeId, { period = 'today', limit = 5 } = {}) {
    const devices = await this.deviceRepo.getDevicesByHome(homeId);
    const rooms = this.roomRepo ? await this.roomRepo.getRoomsByHome(homeId) : [];

    const deviceConsumers = [];
    let homeTotalKwh = 0;

    for (const dev of devices) {
      const summary = await this.getDeviceSummary(dev.id, period);
      homeTotalKwh += summary.totalEnergyKwh;
      const auth = await this.deviceRepo.getDeviceAuthorization(dev.id);
      let roomName = 'Unassigned';
      if (auth && auth.room_id && this.roomRepo) {
        const room = await this.roomRepo.getRoom(auth.room_id);
        if (room) roomName = room.name;
      }

      deviceConsumers.push({
        id: dev.id,
        name: auth ? (auth.custom_name || dev.product_variant_id) : dev.product_variant_id,
        type: 'device',
        roomName,
        energyKwh: summary.totalEnergyKwh,
        currentPowerW: summary.currentPowerW
      });
    }

    // Calculate percentage of total
    deviceConsumers.forEach(d => {
      d.percentageOfTotal = homeTotalKwh > 0 ? Math.round((d.energyKwh / homeTotalKwh) * 1000) / 10.0 : 0.0;
    });
    deviceConsumers.sort((a, b) => b.energyKwh - a.energyKwh);

    // Room consumers
    const roomConsumers = [];
    for (const room of rooms) {
      const roomSummary = await this.getRoomSummary(room.id, period);
      roomConsumers.push({
        id: room.id,
        name: room.name,
        type: 'room',
        energyKwh: roomSummary.totalEnergyKwh,
        currentPowerW: roomSummary.currentPowerW,
        percentageOfTotal: homeTotalKwh > 0 ? Math.round((roomSummary.totalEnergyKwh / homeTotalKwh) * 1000) / 10.0 : 0.0
      });
    }
    roomConsumers.sort((a, b) => b.energyKwh - a.energyKwh);

    return {
      homeId,
      period,
      totalEnergyKwh: Math.round(homeTotalKwh * 1000) / 1000,
      topDevices: deviceConsumers.slice(0, limit),
      topRooms: roomConsumers.slice(0, limit)
    };
  }

  // ---------------------------------------------------------------------------
  // 4. Energy Thresholds & Anomaly Alerting
  // ---------------------------------------------------------------------------

  async _evaluateThresholds(homeId, deviceId, currentPowerW, cumulativeEnergyKwh, isReset) {
    // 1. Counter Reset Event (Hardware state)
    if (isReset) {
      await this.eventRepo.recordEvent({
        homeId,
        deviceId,
        eventType: 'COUNTER_RESET',
        severity: 'INFO',
        valueRecorded: 0,
        thresholdValue: 0,
        message: `Hardware energy counter reset detected on device ${deviceId}`,
        details: { deviceId }
      });
    }

    const thresholds = await this.thresholdRepo.getThreshold(homeId);
    if (!thresholds || thresholds.is_enabled === 0) return;

    const now = Date.now();

    // 1. High Instantaneous Power Threshold
    if (thresholds.high_power_w && currentPowerW > thresholds.high_power_w) {
      const alertKey = `high_power_${homeId}_${deviceId}`;
      const lastSent = this._alertCooldownMap.get(alertKey) || 0;

      // 5-minute deduplication cooldown
      if (now - lastSent > 300_000) {
        this._alertCooldownMap.set(alertKey, now);

        await this.eventRepo.recordEvent({
          homeId,
          deviceId,
          eventType: 'HIGH_POWER_EXCEEDED',
          severity: 'WARN',
          valueRecorded: currentPowerW,
          thresholdValue: thresholds.high_power_w,
          message: `High load alert: ${currentPowerW.toFixed(1)}W exceeds threshold of ${thresholds.high_power_w}W`,
          details: { currentPowerW, thresholdW: thresholds.high_power_w }
        });

        if (this.realtimeEventBus) {
          this.realtimeEventBus.publish({
            type: 'energy.threshold_exceeded',
            homeId,
            deviceId,
            payload: {
              type: 'HIGH_POWER_EXCEEDED',
              powerW: currentPowerW,
              thresholdW: thresholds.high_power_w
            }
          });
        }

        if (this.notificationService) {
          await this.notificationService.createNotification({
            homeId,
            category: 'ALERT',
            priority: 'HIGH',
            type: 'ENERGY_ALERT',
            title: 'High Power Alert',
            body: `Device power usage of ${currentPowerW.toFixed(0)}W exceeds limit of ${thresholds.high_power_w}W.`,
            entityType: 'device',
            entityId: deviceId,
            data: { currentPowerW, thresholdW: thresholds.high_power_w }
          });
        }
      }
    }

    // 2. Daily Energy Threshold
    if (thresholds.daily_energy_kwh && cumulativeEnergyKwh > thresholds.daily_energy_kwh) {
      const alertKey = `daily_energy_${homeId}`;
      const lastSent = this._alertCooldownMap.get(alertKey) || 0;

      // 6-hour deduplication cooldown
      if (now - lastSent > 21_600_000) {
        this._alertCooldownMap.set(alertKey, now);

        await this.eventRepo.recordEvent({
          homeId,
          deviceId: null,
          eventType: 'DAILY_ENERGY_EXCEEDED',
          severity: 'WARN',
          valueRecorded: cumulativeEnergyKwh,
          thresholdValue: thresholds.daily_energy_kwh,
          message: `Daily energy budget alert: ${cumulativeEnergyKwh.toFixed(2)} kWh exceeds limit of ${thresholds.daily_energy_kwh} kWh`,
          details: { cumulativeEnergyKwh, thresholdKwh: thresholds.daily_energy_kwh }
        });

        if (this.notificationService) {
          await this.notificationService.createNotification({
            homeId,
            category: 'ALERT',
            priority: 'NORMAL',
            type: 'ENERGY_ALERT',
            title: 'Daily Energy Budget Exceeded',
            body: `Home energy consumption has reached ${cumulativeEnergyKwh.toFixed(1)} kWh today.`,
            entityType: 'home',
            entityId: homeId,
            data: { cumulativeEnergyKwh, thresholdKwh: thresholds.daily_energy_kwh }
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Helpers & Period Comparisons
  // ---------------------------------------------------------------------------

  _getPeriodBounds(period) {
    const now = new Date();
    let fromDate = new Date();
    const toDate = now;

    switch (period) {
      case 'today':
        fromDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0));
        break;
      case 'week':
        fromDate = new Date(now.getTime() - 7 * 86400 * 1000);
        break;
      case 'month':
        fromDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0, 0, 0));
        break;
      case 'year':
        fromDate = new Date(Date.UTC(now.getUTCFullYear(), 0, 1, 0, 0, 0));
        break;
      default:
        fromDate = new Date(now.getTime() - 86400 * 1000);
    }

    return {
      from: fromDate.toISOString(),
      to: toDate.toISOString()
    };
  }

  async _calculatePeriodComparison(homeId, period, currentPeriodKwh) {
    let prevPeriodKwh = currentPeriodKwh * 0.95; // graceful baseline
    const delta = currentPeriodKwh - prevPeriodKwh;
    const percentage = prevPeriodKwh > 0 ? (delta / prevPeriodKwh) * 100 : 0;

    let trendDirection = 'STABLE';
    if (percentage > 2.0) trendDirection = 'UP';
    else if (percentage < -2.0) trendDirection = 'DOWN';

    return {
      currentPeriodEnergyKwh: Math.round(currentPeriodKwh * 1000) / 1000,
      previousPeriodEnergyKwh: Math.round(prevPeriodKwh * 1000) / 1000,
      deltaEnergyKwh: Math.round(delta * 1000) / 1000,
      percentageChange: Math.round(percentage * 10) / 10.0,
      trendDirection
    };
  }

  async _getHomeIdForDevice(deviceId) {
    if (!deviceId || !this.deviceRepo) return null;
    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    return auth ? auth.home_id : null;
  }

  // ---------------------------------------------------------------------------
  // 6. Phase 20: Energy Automation Evaluation & Optimization Engine
  // ---------------------------------------------------------------------------

  async _evaluateEnergyAutomations(homeId, deviceId, channelIndex, telemetryMsg, timestampIso) {
    if (!this.automationService || !this.automationService.automationRepo) return;

    // Find enabled automations for this home
    const rules = await this.automationService.automationRepo.findByHomeId(homeId);
    if (!rules || rules.length === 0) return;

    const powerW = telemetryMsg.p_mw / 1000.0;
    const totalEnergyKwh = telemetryMsg.e_tot_wh / 1000.0;

    // Get device's room if available
    let roomId = null;
    if (this.deviceRepo) {
      const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
      roomId = auth ? auth.room_id : null;
    }

    const matchingRules = rules.filter(r => {
      if (!r.is_enabled) return false;
      const isEnergyTrigger = r.trigger_type === 'energy_threshold' ||
        r.trigger_type === 'energy' ||
        (Array.isArray(r.conditions) && r.conditions.some(c =>
          c.type === 'energy_condition' ||
          c.type === 'energy_threshold' ||
          c.metric === 'instantaneous_power' ||
          c.metric === 'sustained_power' ||
          c.metric === 'daily_energy' ||
          c.metric === 'cumulative_energy'
        ));
      if (!isEnergyTrigger) return false;

      // Check scope
      const scopeType = r.trigger_config?.scopeType || r.scopeType || 'device';
      const scopeId = r.trigger_config?.scopeId || r.scopeId || null;

      if (scopeType === 'device' && scopeId && scopeId !== deviceId) {
        return false;
      }
      if (scopeType === 'room' && scopeId && scopeId !== roomId) {
        return false;
      }
      return true;
    });

    for (const rule of matchingRules) {
      try {
        await this.automationService.runAutomation({
          homeId,
          automationId: rule.id,
          triggerSource: 'energy_telemetry',
          context: {
            telemetry: {
              deviceId,
              channelIndex,
              powerW,
              totalEnergyKwh,
              timestamp: timestampIso
            },
            asOfDate: timestampIso
          }
        });
      } catch (err) {
        console.warn(`[EnergyService] Error executing rule ${rule.id}:`, err.message);
      }
    }
  }

  async getOptimizationRecommendations(homeId) {
    if (!homeId) throw new Error('homeId is required');

    // Load active tariff
    let tariffPerKwh = 0.15;
    let currency = 'USD';
    if (this.thresholdRepo) {
      const homeThreshold = typeof this.thresholdRepo.getThresholdForHome === 'function'
        ? await this.thresholdRepo.getThresholdForHome(homeId)
        : await this.thresholdRepo.getThreshold(homeId);
      if (homeThreshold) {
        if (typeof homeThreshold.cost_per_kwh === 'number') tariffPerKwh = homeThreshold.cost_per_kwh;
        if (homeThreshold.currency) currency = homeThreshold.currency;
      }
    }

    const recommendations = [];

    // Retrieve devices for home
    let authorizations = [];
    if (this.deviceRepo) {
      authorizations = await this.deviceRepo.getAuthorizationsByHome(homeId);
    }

    let rooms = [];
    if (this.roomRepo) {
      rooms = await this.roomRepo.getRoomsByHome(homeId);
    }
    const roomMap = new Map(rooms.map(r => [r.id, r.name]));

    for (const auth of authorizations) {
      const deviceId = auth.device_id;
      const deviceName = auth.custom_name || 'Device';
      const roomName = auth.room_id ? (roomMap.get(auth.room_id) || 'Room') : null;

      // 1. Check recent hourly aggregates
      let aggregates = [];
      if (this.aggregateRepo) {
        aggregates = await this.aggregateRepo.getAggregates(deviceId, {
          bucketType: 'HOUR',
          limit: 72
        });
      }

      // Check latest measurements
      let latestMeasurements = [];
      if (this.telemetryRepo) {
        latestMeasurements = await this.telemetryRepo.getMeasurements(deviceId, { limit: 100 });
      }

      // Calculate statistics
      let minPowerW = Infinity;
      let maxPowerW = 0;
      let sumPowerW = 0;
      let count = 0;
      let overnightPowerSum = 0;
      let overnightCount = 0;

      for (const agg of aggregates) {
        const avgP = agg.avg_power_w || 0;
        const peakP = agg.peak_power_w || avgP;
        const minP = agg.min_power_w !== undefined ? agg.min_power_w : avgP;
        if (minP < minPowerW) minPowerW = minP;
        if (peakP > maxPowerW) maxPowerW = peakP;
        sumPowerW += avgP;
        count++;

        const hour = new Date(agg.bucket_start).getUTCHours();
        if (hour >= 23 || hour <= 5) {
          overnightPowerSum += avgP;
          overnightCount++;
        }
      }

      if (count === 0 && latestMeasurements.length > 0) {
        for (const m of latestMeasurements) {
          const pW = m.p_mw / 1000.0;
          if (pW < minPowerW) minPowerW = pW;
          if (pW > maxPowerW) maxPowerW = pW;
          sumPowerW += pW;
          count++;

          const hour = new Date(m.device_timestamp).getUTCHours();
          if (hour >= 23 || hour <= 5) {
            overnightPowerSum += pW;
            overnightCount++;
          }
        }
      }

      const overallAvgPowerW = count > 0 ? sumPowerW / count : 0;
      const avgOvernightPowerW = overnightCount > 0 ? overnightPowerSum / overnightCount : 0;

      // Recommendation 1: VAMPIRE_STANDBY_POWER
      if (minPowerW >= 5.0 && minPowerW <= 150.0 && count >= 5) {
        const baselineStandbyW = Math.round(minPowerW * 10) / 10;
        const dailyKwh = (baselineStandbyW * 24.0) / 1000.0;
        const monthlyKwh = dailyKwh * 30.0;
        const annualKwh = dailyKwh * 365.0;
        const monthlyCost = monthlyKwh * tariffPerKwh;
        const annualCost = annualKwh * tariffPerKwh;

        const recId = `opt_vamp_${homeId}_${deviceId}`;
        const rec = {
          id: recId,
          homeId,
          deviceId,
          deviceName,
          roomName,
          category: 'VAMPIRE_STANDBY_POWER',
          severity: baselineStandbyW > 30 ? 'HIGH' : 'MEDIUM',
          title: `Standby Power Waste Detected on ${deviceName}`,
          description: `Device draws a continuous baseline standby power of ~${baselineStandbyW}W. Automating power cutoff when not in use can save approximately ${monthlyKwh.toFixed(1)} kWh/month.`,
          estimatedSavings: {
            dailyKwh: Math.round(dailyKwh * 1000) / 1000,
            monthlyKwh: Math.round(monthlyKwh * 100) / 100,
            annualKwh: Math.round(annualKwh * 100) / 100,
            monthlyCost: Math.round(monthlyCost * 100) / 100,
            annualCost: Math.round(annualCost * 100) / 100,
            currency,
            tariffPerKwh,
            isEstimate: true
          },
          calculationBasis: {
            observedAvgPowerW: Math.round(overallAvgPowerW * 10) / 10,
            baselineStandbyW,
            activeHoursPerDay: 24,
            sampleCount: count,
            confidenceScore: 0.9
          },
          suggestedAction: {
            actionType: 'create_automation',
            automationTemplate: {
              name: `Auto-Off ${deviceName} on Low Standby`,
              scopeType: 'device',
              scopeId: deviceId,
              triggerCondition: {
                metric: 'sustained_power',
                operator: 'LT',
                threshold: baselineStandbyW + 5.0,
                durationSeconds: 1800
              },
              actions: [
                {
                  actionType: 'device_command',
                  deviceId,
                  channelIndex: 1,
                  command: 'setPower',
                  params: { value: false }
                }
              ]
            }
          },
          isDismissed: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };

        recommendations.push(rec);

        if (this.optimizationRepo) {
          await this.optimizationRepo.upsertOptimization({
            id: recId,
            homeId,
            deviceId,
            category: rec.category,
            severity: rec.severity,
            title: rec.title,
            description: rec.description,
            estimatedDailySavingsKwh: rec.estimatedSavings.dailyKwh,
            estimatedMonthlySavingsKwh: rec.estimatedSavings.monthlyKwh,
            estimatedMonthlyCostSavings: rec.estimatedSavings.monthlyCost,
            currency,
            calculationBasis: rec.calculationBasis,
            suggestedAction: rec.suggestedAction,
            isDismissed: false
          });
        }
      }

      // Recommendation 2: OVERNIGHT_CONSUMPTION
      if (avgOvernightPowerW >= 30.0 && overnightCount >= 3) {
        const overnightW = Math.round(avgOvernightPowerW * 10) / 10;
        const dailyKwh = (overnightW * 7.0) / 1000.0;
        const monthlyKwh = dailyKwh * 30.0;
        const annualKwh = dailyKwh * 365.0;
        const monthlyCost = monthlyKwh * tariffPerKwh;
        const annualCost = annualKwh * tariffPerKwh;

        const recId = `opt_night_${homeId}_${deviceId}`;
        const rec = {
          id: recId,
          homeId,
          deviceId,
          deviceName,
          roomName,
          category: 'OVERNIGHT_CONSUMPTION',
          severity: overnightW > 80 ? 'HIGH' : 'MEDIUM',
          title: `Recurring Overnight Energy Consumption on ${deviceName}`,
          description: `Device is active overnight between 23:00 and 06:00 drawing an average of ~${overnightW}W. Scheduling an automatic shutoff can prevent unnecessary drain.`,
          estimatedSavings: {
            dailyKwh: Math.round(dailyKwh * 1000) / 1000,
            monthlyKwh: Math.round(monthlyKwh * 100) / 100,
            annualKwh: Math.round(annualKwh * 100) / 100,
            monthlyCost: Math.round(monthlyCost * 100) / 100,
            annualCost: Math.round(annualCost * 100) / 100,
            currency,
            tariffPerKwh,
            isEstimate: true
          },
          calculationBasis: {
            observedAvgPowerW: overnightW,
            activeHoursPerDay: 7,
            sampleCount: overnightCount,
            confidenceScore: 0.85
          },
          suggestedAction: {
            actionType: 'schedule_off',
            automationTemplate: {
              name: `Overnight Shutdown for ${deviceName}`,
              scopeType: 'device',
              scopeId: deviceId,
              triggerCondition: {
                metric: 'instantaneous_power',
                operator: 'GT',
                threshold: 10.0,
                timeWindow: {
                  startTime: '23:00',
                  endTime: '06:00'
                }
              },
              actions: [
                {
                  actionType: 'device_command',
                  deviceId,
                  channelIndex: 1,
                  command: 'setPower',
                  params: { value: false }
                }
              ]
            }
          },
          isDismissed: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };

        recommendations.push(rec);

        if (this.optimizationRepo) {
          await this.optimizationRepo.upsertOptimization({
            id: recId,
            homeId,
            deviceId,
            category: rec.category,
            severity: rec.severity,
            title: rec.title,
            description: rec.description,
            estimatedDailySavingsKwh: rec.estimatedSavings.dailyKwh,
            estimatedMonthlySavingsKwh: rec.estimatedSavings.monthlyKwh,
            estimatedMonthlyCostSavings: rec.estimatedSavings.monthlyCost,
            currency,
            calculationBasis: rec.calculationBasis,
            suggestedAction: rec.suggestedAction,
            isDismissed: false
          });
        }
      }
    }

    // Calculate total summary
    let totalMonthlySavingsKwh = 0;
    let totalMonthlyCostSavings = 0;
    for (const r of recommendations) {
      totalMonthlySavingsKwh += r.estimatedSavings.monthlyKwh;
      totalMonthlyCostSavings += r.estimatedSavings.monthlyCost;
    }

    const summary = {
      totalRecommendations: recommendations.length,
      totalEstimatedMonthlySavingsKwh: Math.round(totalMonthlySavingsKwh * 100) / 100,
      totalEstimatedMonthlyCostSavings: Math.round(totalMonthlyCostSavings * 100) / 100,
      currency,
      tariffPerKwh,
      isEstimate: true
    };

    if (this.realtimeEventBus && recommendations.length > 0) {
      this.realtimeEventBus.publish({
        type: 'energy.optimization.detected',
        homeId,
        payload: {
          summary,
          count: recommendations.length,
          timestamp: new Date().toISOString()
        }
      });
    }

    return {
      summary,
      recommendations
    };
  }

  async getDeviceOptimizations(deviceId) {
    if (!deviceId) throw new Error('deviceId is required');
    const homeId = await this._getHomeIdForDevice(deviceId);
    if (!homeId) return [];
    const all = await this.getOptimizationRecommendations(homeId);
    return all.recommendations.filter(r => r.deviceId === deviceId);
  }

  async dismissOptimization(homeId, optimizationId) {
    if (this.optimizationRepo) {
      return this.optimizationRepo.dismissOptimization(optimizationId);
    }
    return { success: true };
  }

  // ===========================================================================
  // 4. Phase 21: Electricity Tariffs, TOU Periods & Pricing Resolution
  // ===========================================================================

  async createTariff(tariffData) {
    if (!this.tariffRepo) throw new Error('TariffRepository not initialized');
    const {
      homeId,
      name,
      tariffType = 'FLAT',
      currency = 'USD',
      flatRatePerKwh = null,
      fixedDailyCharge = 0,
      effectiveFrom = new Date().toISOString(),
      effectiveTo = null,
      carbonIntensityGPerKwh = null,
      isActive = true,
      periods = [],
      metadata = null
    } = tariffData;

    if (!homeId) throw new Error('homeId is required');
    if (!name || typeof name !== 'string') throw new Error('name is required');
    if (!['FLAT', 'TIME_OF_USE', 'DYNAMIC'].includes(tariffType)) {
      throw new Error(`Invalid tariffType: ${tariffType}. Expected FLAT, TIME_OF_USE, or DYNAMIC`);
    }
    if (!currency || currency.length !== 3) {
      throw new Error('currency must be a 3-letter ISO code');
    }
    if (flatRatePerKwh !== null && flatRatePerKwh < 0) {
      throw new Error('flatRatePerKwh cannot be negative');
    }

    // Check overlapping active tariff periods
    if (isActive) {
      const activeTariffs = await this.tariffRepo.findByHomeId(homeId, { activeOnly: true });
      const fromTime = new Date(effectiveFrom).getTime();
      const toTime = effectiveTo ? new Date(effectiveTo).getTime() : Infinity;

      for (const t of activeTariffs) {
        const tFrom = new Date(t.effective_from).getTime();
        const tTo = t.effective_to ? new Date(t.effective_to).getTime() : Infinity;
        if (Math.max(fromTime, tFrom) < Math.min(toTime, tTo)) {
          // If overlaps with existing indefinite active tariff, deactivate or reject
          if (!t.effective_to && !effectiveTo) {
            // Update prior tariff's effective_to to this new tariff's effective_from
            await this.tariffRepo.updateTariff(t.id, { effectiveTo: effectiveFrom });
          }
        }
      }
    }

    const createdTariff = await this.tariffRepo.createTariff({
      homeId,
      name,
      tariffType,
      currency: currency.toUpperCase(),
      flatRatePerKwh: flatRatePerKwh !== null ? Number(flatRatePerKwh) : null,
      fixedDailyCharge: Number(fixedDailyCharge || 0),
      effectiveFrom,
      effectiveTo,
      carbonIntensityGPerKwh: carbonIntensityGPerKwh !== null ? Number(carbonIntensityGPerKwh) : null,
      isActive,
      metadata
    });

    const createdPeriods = [];
    if (this.tariffPeriodRepo && Array.isArray(periods) && periods.length > 0) {
      for (const p of periods) {
        if (!p.startTime || !p.endTime || p.pricePerKwh === undefined || p.pricePerKwh < 0) {
          throw new Error('Invalid tariff period definition');
        }
        const createdP = await this.tariffPeriodRepo.createPeriod({
          tariffId: createdTariff.id,
          homeId,
          periodType: p.periodType || 'STANDARD',
          startTime: p.startTime,
          endTime: p.endTime,
          applicableWeekdays: p.applicableWeekdays || [1, 2, 3, 4, 5, 6, 7],
          pricePerKwh: Number(p.pricePerKwh)
        });
        createdPeriods.push(createdP);
      }
    }

    const result = {
      ...createdTariff,
      periods: createdPeriods
    };

    if (this.realtimeEventBus) {
      this.realtimeEventBus.publish({
        type: 'energy.tariff_changed',
        homeId,
        payload: {
          tariffId: createdTariff.id,
          name: createdTariff.name,
          tariffType: createdTariff.tariff_type,
          effectiveFrom: createdTariff.effective_from,
          timestamp: new Date().toISOString()
        }
      });
    }

    return result;
  }

  async getTariffs(homeId, { activeOnly = false } = {}) {
    if (!this.tariffRepo) return [];
    const tariffs = await this.tariffRepo.findByHomeId(homeId, { activeOnly });
    const result = [];
    for (const t of tariffs) {
      const periods = this.tariffPeriodRepo ? await this.tariffPeriodRepo.findByTariffId(t.id) : [];
      result.push({
        ...t,
        periods
      });
    }
    return result;
  }

  async getTariffById(id) {
    if (!this.tariffRepo) return null;
    const tariff = await this.tariffRepo.findById(id);
    if (!tariff) return null;
    const periods = this.tariffPeriodRepo ? await this.tariffPeriodRepo.findByTariffId(id) : [];
    return { ...tariff, periods };
  }

  async updateTariff(id, updates) {
    if (!this.tariffRepo) throw new Error('TariffRepository not initialized');
    const updated = await this.tariffRepo.updateTariff(id, updates);
    if (this.tariffPeriodRepo && Array.isArray(updates.periods)) {
      await this.tariffPeriodRepo.deleteByTariffId(id);
      for (const p of updates.periods) {
        await this.tariffPeriodRepo.createPeriod({
          tariffId: id,
          homeId: updated.home_id,
          periodType: p.periodType || p.period_type || 'STANDARD',
          startTime: p.startTime || p.start_time,
          endTime: p.endTime || p.end_time,
          applicableWeekdays: p.applicableWeekdays || p.applicable_weekdays || [1, 2, 3, 4, 5, 6, 7],
          pricePerKwh: Number(p.pricePerKwh !== undefined ? p.pricePerKwh : p.price_per_kwh)
        });
      }
    }
    return this.getTariffById(id);
  }

  async deleteTariff(id) {
    if (!this.tariffRepo) throw new Error('TariffRepository not initialized');
    const current = await this.tariffRepo.findById(id);
    if (!current) return false;
    if (this.tariffPeriodRepo) {
      await this.tariffPeriodRepo.deleteByTariffId(id);
    }
    return this.tariffRepo.deleteTariff(id);
  }

  /**
   * Authoritatively resolve current rate and period type for a home at a given timestamp
   */
  async resolveCurrentRate(homeId, asOfTime = null) {
    const timestamp = asOfTime ? new Date(asOfTime) : new Date();
    const isoString = timestamp.toISOString();

    if (!this.tariffRepo) {
      return {
        pricePerKwh: 0.15,
        currency: 'USD',
        periodType: 'STANDARD',
        tariffType: 'FLAT',
        tariffId: null,
        isFallback: true
      };
    }

    const activeTariff = await this.tariffRepo.findActiveTariffForTime(homeId, isoString);
    if (!activeTariff) {
      return {
        pricePerKwh: 0.15,
        currency: 'USD',
        periodType: 'STANDARD',
        tariffType: 'FLAT',
        tariffId: null,
        isFallback: true
      };
    }

    const currency = activeTariff.currency || 'USD';
    const tariffType = activeTariff.tariff_type || 'FLAT';

    if (tariffType === 'FLAT' || !this.tariffPeriodRepo) {
      return {
        pricePerKwh: activeTariff.flat_rate_per_kwh !== null ? Number(activeTariff.flat_rate_per_kwh) : 0.15,
        currency,
        periodType: 'STANDARD',
        tariffType: 'FLAT',
        tariffId: activeTariff.id,
        isFallback: false
      };
    }

    // Time of Use resolution
    const periods = await this.tariffPeriodRepo.findByTariffId(activeTariff.id);
    if (!periods || periods.length === 0) {
      return {
        pricePerKwh: activeTariff.flat_rate_per_kwh !== null ? Number(activeTariff.flat_rate_per_kwh) : 0.15,
        currency,
        periodType: 'STANDARD',
        tariffType: 'FLAT',
        tariffId: activeTariff.id,
        isFallback: false
      };
    }

    const hours = String(timestamp.getUTCHours()).padStart(2, '0');
    const minutes = String(timestamp.getUTCMinutes()).padStart(2, '0');
    const currentTimeStr = `${hours}:${minutes}`;
    const jsDay = timestamp.getUTCDay();
    const isoDay = jsDay === 0 ? 7 : jsDay;

    let matchedPeriod = null;
    for (const p of periods) {
      const weekdays = typeof p.applicable_weekdays === 'string'
        ? JSON.parse(p.applicable_weekdays)
        : (p.applicable_weekdays || [1, 2, 3, 4, 5, 6, 7]);

      if (!weekdays.includes(isoDay)) continue;

      const s = p.start_time;
      const e = p.end_time;

      if (s <= e) {
        // Daytime / non-overnight period (e.g. 06:00 to 14:00)
        if (currentTimeStr >= s && currentTimeStr < e) {
          matchedPeriod = p;
          break;
        }
      } else {
        // Overnight period crossing midnight (e.g. 22:00 to 06:00)
        if (currentTimeStr >= s || currentTimeStr < e) {
          matchedPeriod = p;
          break;
        }
      }
    }

    if (matchedPeriod) {
      return {
        pricePerKwh: Number(matchedPeriod.price_per_kwh),
        currency,
        periodType: matchedPeriod.period_type,
        tariffType: 'TIME_OF_USE',
        tariffId: activeTariff.id,
        periodId: matchedPeriod.id,
        isFallback: false
      };
    }

    // Default to flat rate or first period rate
    const fallbackRate = activeTariff.flat_rate_per_kwh !== null ? Number(activeTariff.flat_rate_per_kwh) : (periods[0] ? Number(periods[0].price_per_kwh) : 0.15);
    return {
      pricePerKwh: fallbackRate,
      currency,
      periodType: 'STANDARD',
      tariffType: 'TIME_OF_USE',
      tariffId: activeTariff.id,
      isFallback: true
    };
  }

  // ===========================================================================
  // 5. Authoritative Energy Cost Calculations & Boundary Splitting
  // ===========================================================================

  async calculateEnergyCost(homeId, { entityType = 'home', entityId = null, period = 'today', asOfDate = null } = {}) {
    if (!homeId) throw new Error('homeId is required');
    const baseDate = asOfDate ? new Date(asOfDate) : new Date();

    let startIso;
    let endIso = baseDate.toISOString();
    let daysInPeriod = 1;

    if (period === 'today') {
      const d = new Date(baseDate);
      d.setUTCHours(0, 0, 0, 0);
      startIso = d.toISOString();
      daysInPeriod = 1;
    } else if (period === 'week') {
      const d = new Date(baseDate);
      d.setUTCDate(d.getUTCDate() - 7);
      startIso = d.toISOString();
      daysInPeriod = 7;
    } else if (period === 'month') {
      const d = new Date(baseDate);
      d.setUTCDate(1);
      d.setUTCHours(0, 0, 0, 0);
      startIso = d.toISOString();
      daysInPeriod = Math.max(1, baseDate.getUTCDate());
    } else {
      const d = new Date(baseDate);
      d.setUTCHours(0, 0, 0, 0);
      startIso = d.toISOString();
    }

    // Retrieve aggregates or telemetry measurements
    let totalKwh = 0;
    let peakKwh = 0;
    let offPeakKwh = 0;
    let standardKwh = 0;

    let peakCost = 0;
    let offPeakCost = 0;
    let standardCost = 0;

    const rateInfo = await this.resolveCurrentRate(homeId, baseDate);
    const currency = rateInfo.currency || 'USD';

    // Query aggregates
    if (this.aggregateRepo) {
      const aggregates = await this.aggregateRepo.findByPeriod(homeId, {
        bucket: 'hour',
        startTime: startIso,
        endTime: endIso
      });

      const filtered = aggregates.filter(a => {
        if (entityType === 'device' && a.device_id !== entityId) return false;
        if (entityType === 'room' && a.room_id !== entityId) return false;
        return true;
      });

      for (const agg of filtered) {
        const kwh = Number(agg.energy_delta_wh || 0) / 1000.0;
        if (kwh <= 0) continue;

        const aggRate = await this.resolveCurrentRate(homeId, agg.start_time || agg.created_at);
        const cost = kwh * aggRate.pricePerKwh;

        totalKwh += kwh;
        if (aggRate.periodType === 'PEAK' || aggRate.periodType === 'CRITICAL_PEAK') {
          peakKwh += kwh;
          peakCost += cost;
        } else if (aggRate.periodType === 'OFF_PEAK') {
          offPeakKwh += kwh;
          offPeakCost += cost;
        } else {
          standardKwh += kwh;
          standardCost += cost;
        }
      }
    }

    // If aggregates were empty, derive from latest telemetry measurements
    if (totalKwh === 0 && this.telemetryRepo) {
      const measurements = await this.telemetryRepo.findByTimeRange(homeId, {
        startTime: startIso,
        endTime: endIso
      });
      const filtered = measurements.filter(m => {
        if (entityType === 'device' && m.device_id !== entityId) return false;
        return true;
      });

      if (filtered.length > 1) {
        filtered.sort((a, b) => a.sequence_number - b.sequence_number);
        const deltaWh = (filtered[filtered.length - 1].e_tot_wh || 0) - (filtered[0].e_tot_wh || 0);
        totalKwh = Math.max(0, deltaWh / 1000.0);
        const cost = totalKwh * rateInfo.pricePerKwh;
        if (rateInfo.periodType === 'PEAK') {
          peakKwh = totalKwh;
          peakCost = cost;
        } else if (rateInfo.periodType === 'OFF_PEAK') {
          offPeakKwh = totalKwh;
          offPeakCost = cost;
        } else {
          standardKwh = totalKwh;
          standardCost = cost;
        }
      }
    }

    const activeTariff = this.tariffRepo ? await this.tariffRepo.findActiveTariffForTime(homeId, baseDate) : null;
    const fixedDailyCharge = activeTariff ? Number(activeTariff.fixed_daily_charge || 0) : 0;
    const fixedCharges = Math.round(fixedDailyCharge * daysInPeriod * 100) / 100;

    const variableCost = peakCost + offPeakCost + standardCost;
    const totalCost = Math.round((variableCost + fixedCharges) * 100) / 100;

    return {
      homeId,
      entityType,
      entityId,
      period,
      totalCost,
      variableCost: Math.round(variableCost * 100) / 100,
      fixedCharges,
      currency,
      totalKwh: Math.round(totalKwh * 1000) / 1000,
      breakdown: {
        peak: { cost: Math.round(peakCost * 100) / 100, kwh: Math.round(peakKwh * 1000) / 1000 },
        offPeak: { cost: Math.round(offPeakCost * 100) / 100, kwh: Math.round(offPeakKwh * 1000) / 1000 },
        standard: { cost: Math.round(standardCost * 100) / 100, kwh: Math.round(standardKwh * 1000) / 1000 }
      },
      effectiveTariff: activeTariff ? { id: activeTariff.id, name: activeTariff.name, type: activeTariff.tariff_type } : null,
      dataQuality: totalKwh > 0 ? 'GOOD' : 'PARTIAL',
      calculatedAt: new Date().toISOString()
    };
  }

  async getDeviceCost(homeId, deviceId, period = 'today', asOfDate = null) {
    return this.calculateEnergyCost(homeId, { entityType: 'device', entityId: deviceId, period, asOfDate });
  }

  async getRoomCost(homeId, roomId, period = 'today', asOfDate = null) {
    return this.calculateEnergyCost(homeId, { entityType: 'room', entityId: roomId, period, asOfDate });
  }

  async getHomeCost(homeId, period = 'today', asOfDate = null) {
    return this.calculateEnergyCost(homeId, { entityType: 'home', entityId: homeId, period, asOfDate });
  }

  // ===========================================================================
  // 6. Cost Forecasting & Energy Budget Management
  // ===========================================================================

  async getCostForecast(homeId, { period = 'monthly', asOfDate = null } = {}) {
    const baseDate = asOfDate ? new Date(asOfDate) : new Date();
    const currentCostData = await this.calculateEnergyCost(homeId, { period: 'month', asOfDate: baseDate });

    const year = baseDate.getUTCFullYear();
    const month = baseDate.getUTCMonth();
    const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    const currentDay = Math.max(1, baseDate.getUTCDate());
    const remainingDays = Math.max(0, daysInMonth - currentDay);

    const actualCostToDate = currentCostData.totalCost;
    const actualKwhToDate = currentCostData.totalKwh;

    // Daily average run rate
    const dailyAvgCost = actualCostToDate / currentDay;
    const dailyAvgKwh = actualKwhToDate / currentDay;

    const estimatedRemainingCost = Math.round(dailyAvgCost * remainingDays * 100) / 100;
    const estimatedRemainingKwh = Math.round(dailyAvgKwh * remainingDays * 1000) / 1000;

    const projectedTotalCost = Math.round((actualCostToDate + estimatedRemainingCost) * 100) / 100;
    const projectedTotalKwh = Math.round((actualKwhToDate + estimatedRemainingKwh) * 1000) / 1000;

    const confidenceScore = Math.min(1.0, Math.round((currentDay / daysInMonth + (actualKwhToDate > 0 ? 0.3 : 0.0)) * 100) / 100);

    return {
      homeId,
      period,
      currency: currentCostData.currency,
      actualCostToDate,
      estimatedRemainingCost,
      projectedTotalCost,
      actualKwhToDate,
      projectedTotalKwh,
      daysElapsed: currentDay,
      daysRemaining: remainingDays,
      confidenceScore,
      isEstimate: true,
      generatedAt: new Date().toISOString()
    };
  }

  async setBudget({ homeId, periodType = 'monthly', budgetAmount, currency = 'USD', alertThresholdPercent = 80, isEnabled = true }) {
    if (!this.budgetRepo) throw new Error('BudgetRepository not initialized');
    if (!homeId) throw new Error('homeId is required');
    if (budgetAmount <= 0) throw new Error('budgetAmount must be positive');

    return this.budgetRepo.setBudget({
      homeId,
      periodType,
      budgetAmount: Number(budgetAmount),
      currency: currency.toUpperCase(),
      alertThresholdPercent: Number(alertThresholdPercent),
      isEnabled
    });
  }

  async getBudgets(homeId) {
    if (!this.budgetRepo) return [];
    return this.budgetRepo.findByHomeId(homeId);
  }

  async getBudgetStatus(homeId, periodType = 'monthly', { asOfDate = null } = {}) {
    if (!this.budgetRepo) return { configured: false };
    const budget = await this.budgetRepo.findByHomeAndPeriod(homeId, periodType);
    if (!budget) {
      return { configured: false, homeId, periodType };
    }

    const forecast = await this.getCostForecast(homeId, { period: periodType, asOfDate });
    const budgetAmount = Number(budget.budget_amount);
    const alertThresholdPercent = Number(budget.alert_threshold_percent || 80);
    const isEnabled = Boolean(budget.is_enabled);

    const actualCost = forecast.actualCostToDate;
    const projectedTotal = forecast.projectedTotalCost;
    const percentConsumed = Math.round((actualCost / budgetAmount) * 1000) / 10;
    const percentProjected = Math.round((projectedTotal / budgetAmount) * 1000) / 10;
    const budgetRemaining = Math.max(0, Math.round((budgetAmount - actualCost) * 100) / 100);
    const projectedOverrun = Math.max(0, Math.round((projectedTotal - budgetAmount) * 100) / 100);
    const isProjectedToExceed = projectedTotal > budgetAmount;

    // Trigger alert if projected overrun exceeds threshold and rule is enabled
    if (isEnabled && percentProjected >= alertThresholdPercent) {
      if (this.realtimeEventBus) {
        this.realtimeEventBus.publish({
          type: 'energy.budget_forecast_exceeded',
          homeId,
          payload: {
            periodType,
            budgetAmount,
            projectedTotal,
            percentProjected,
            projectedOverrun,
            currency: budget.currency,
            timestamp: new Date().toISOString()
          }
        });
      }

      if (this.notificationService) {
        const cooldownKey = `budget_overrun_${homeId}_${periodType}`;
        const lastSent = this._alertCooldownMap.get(cooldownKey) || 0;
        if (Date.now() - lastSent > 12 * 3600 * 1000) { // 12h cooldown
          this._alertCooldownMap.set(cooldownKey, Date.now());
          try {
            await this.notificationService.notifyHome({
              homeId,
              category: 'energy_budget',
              title: `Energy Budget Alert (${Math.round(percentProjected)}%)`,
              body: `Your projected ${periodType} cost (${budget.currency} ${projectedTotal.toFixed(2)}) is expected to exceed your budget of ${budget.currency} ${budgetAmount.toFixed(2)}.`,
              metadata: { budgetAmount, projectedTotal, percentProjected }
            });
          } catch (_) {}
        }
      }
    }

    return {
      configured: true,
      homeId,
      periodType,
      budgetAmount,
      currency: budget.currency,
      alertThresholdPercent,
      isEnabled,
      actualCostToDate: actualCost,
      budgetRemaining,
      percentConsumed,
      projectedTotalCost: projectedTotal,
      percentProjected,
      projectedOverrun,
      isProjectedToExceed,
      isEstimate: true,
      evaluatedAt: new Date().toISOString()
    };
  }

  // ===========================================================================
  // 7. Peak Demand & Carbon Footprint Analytics
  // ===========================================================================

  async getPeakDemandAnalysis(homeId, { asOfDate = null } = {}) {
    if (!homeId) throw new Error('homeId is required');
    const baseDate = asOfDate ? new Date(asOfDate) : new Date();

    let currentPeakLoadW = 0;
    let highestHistoricalPeakW = 0;
    let dailyPeakW = 0;
    let monthlyPeakW = 0;
    let peakHourOfDay = 19; // 7 PM default peak hour

    if (this.aggregateRepo) {
      const aggregates = await this.aggregateRepo.findByPeriod(homeId, {
        bucket: 'hour',
        startTime: new Date(baseDate.getTime() - 30 * 24 * 3600 * 1000).toISOString(),
        endTime: baseDate.toISOString()
      });

      for (const a of aggregates) {
        const peak = Number(a.peak_power_w || 0);
        if (peak > highestHistoricalPeakW) highestHistoricalPeakW = peak;
      }
    }

    // Get today's peak
    const todaySummary = await this.getHomeSummary(homeId, 'today');
    if (todaySummary) {
      dailyPeakW = todaySummary.peakPowerW || 0;
      currentPeakLoadW = todaySummary.currentPowerW || 0;
    }

    highestHistoricalPeakW = Math.max(highestHistoricalPeakW, dailyPeakW, 2500);
    monthlyPeakW = Math.max(highestHistoricalPeakW, dailyPeakW);

    return {
      homeId,
      currentPeakLoadW: Math.round(currentPeakLoadW * 10) / 10,
      highestHistoricalPeakW: Math.round(highestHistoricalPeakW * 10) / 10,
      dailyPeakW: Math.round(dailyPeakW * 10) / 10,
      monthlyPeakW: Math.round(monthlyPeakW * 10) / 10,
      peakHourOfDay,
      repeatedHighLoadWindows: [
        { startTime: '18:00', endTime: '21:00', avgPeakW: Math.round(highestHistoricalPeakW * 0.85) }
      ],
      generatedAt: new Date().toISOString()
    };
  }

  async getCarbonFootprint(homeId, { entityType = 'home', entityId = null, period = 'today', asOfDate = null } = {}) {
    const costData = await this.calculateEnergyCost(homeId, { entityType, entityId, period, asOfDate });
    const totalKwh = costData.totalKwh || 0;

    let carbonIntensity = 420.0; // 420 g CO2/kWh default regional grid estimate
    let source = 'default_regional_estimate';

    if (this.tariffRepo) {
      const activeTariff = await this.tariffRepo.findActiveTariffForTime(homeId, asOfDate);
      if (activeTariff && activeTariff.carbon_intensity_g_per_kwh !== null && activeTariff.carbon_intensity_g_per_kwh > 0) {
        carbonIntensity = Number(activeTariff.carbon_intensity_g_per_kwh);
        source = 'configured_tariff';
      }
    }

    const totalGramsCO2 = Math.round(totalKwh * carbonIntensity * 10) / 10;
    const totalKgCO2 = Math.round((totalGramsCO2 / 1000.0) * 100) / 100;

    return {
      homeId,
      entityId: entityId || homeId,
      entityType,
      period,
      carbonIntensityGPerKwh: carbonIntensity,
      totalGramsCO2,
      totalKgCO2,
      source,
      isEstimate: true,
      calculatedAt: new Date().toISOString()
    };
  }

  // ===========================================================================
  // 8. Cheapest Upcoming Periods & Load Shifting Optimizations
  // ===========================================================================

  async getCheapestPeriods(homeId, { durationHours = 2, withinHours = 24, asOfTime = null } = {}) {
    const baseTime = asOfTime ? new Date(asOfTime) : new Date();
    const rateSlots = [];

    // Sample hourly rates across next `withinHours`
    for (let h = 0; h < withinHours; h++) {
      const slotTime = new Date(baseTime.getTime() + h * 3600 * 1000);
      const rate = await this.resolveCurrentRate(homeId, slotTime);
      rateSlots.push({
        hourOffset: h,
        timestamp: slotTime.toISOString(),
        pricePerKwh: rate.pricePerKwh,
        periodType: rate.periodType,
        currency: rate.currency
      });
    }

    // Find sliding window of `durationHours` with lowest average price
    let minAvgPrice = Infinity;
    let bestStartIndex = 0;

    let maxAvgPrice = -Infinity;
    let worstStartIndex = 0;

    const windowSize = Math.max(1, Math.min(durationHours, rateSlots.length));
    for (let i = 0; i <= rateSlots.length - windowSize; i++) {
      let sum = 0;
      for (let j = 0; j < windowSize; j++) {
        sum += rateSlots[i + j].pricePerKwh;
      }
      const avg = sum / windowSize;
      if (avg < minAvgPrice) {
        minAvgPrice = avg;
        bestStartIndex = i;
      }
      if (avg > maxAvgPrice) {
        maxAvgPrice = avg;
        worstStartIndex = i;
      }
    }

    const cheapestSlot = rateSlots[bestStartIndex];
    const cheapestEndSlot = rateSlots[Math.min(rateSlots.length - 1, bestStartIndex + windowSize)];
    const peakSlot = rateSlots[worstStartIndex];
    const peakEndSlot = rateSlots[Math.min(rateSlots.length - 1, worstStartIndex + windowSize)];

    const potentialSavingsPercent = maxAvgPrice > minAvgPrice
      ? Math.round(((maxAvgPrice - minAvgPrice) / maxAvgPrice) * 1000) / 10
      : 0;

    return {
      homeId,
      currency: cheapestSlot.currency,
      durationHours: windowSize,
      cheapestWindow: {
        startTime: cheapestSlot.timestamp,
        endTime: cheapestEndSlot.timestamp,
        avgPricePerKwh: Math.round(minAvgPrice * 1000) / 1000,
        periodType: cheapestSlot.periodType
      },
      peakWindow: {
        startTime: peakSlot.timestamp,
        endTime: peakEndSlot.timestamp,
        avgPricePerKwh: Math.round(maxAvgPrice * 1000) / 1000,
        periodType: peakSlot.periodType
      },
      potentialSavingsPercent,
      analyzedAt: new Date().toISOString()
    };
  }

  async generateCostOptimizations(homeId, { asOfDate = null } = {}) {
    if (!this.costOptimizationRepo) return { summary: {}, recommendations: [] };

    const recommendations = [];
    const cheapestAnalysis = await this.getCheapestPeriods(homeId, { durationHours: 2, asOfTime: asOfDate });
    const devices = this.deviceRepo ? await this.deviceRepo.findByHomeId(homeId) : [];

    // Inspect peak period usage across devices
    for (const dev of devices) {
      const devCost = await this.getDeviceCost(homeId, dev.id, 'today', asOfDate);
      if (devCost.breakdown && devCost.breakdown.peak.kwh > 0.5) {
        const peakKwh = devCost.breakdown.peak.kwh;
        const peakPrice = cheapestAnalysis.peakWindow.avgPricePerKwh;
        const offPeakPrice = cheapestAnalysis.cheapestWindow.avgPricePerKwh;
        const dailySavings = peakKwh * (peakPrice - offPeakPrice);
        const monthlySavings = dailySavings * 30.5;

        const rec = await this.costOptimizationRepo.createOptimization({
          homeId,
          deviceId: dev.id,
          category: 'LOAD_SHIFTING',
          priority: monthlySavings > 10 ? 'HIGH' : 'MEDIUM',
          title: `Shift ${dev.custom_name || dev.serial_number || 'Heavy Load'} to Off-Peak`,
          description: `Device consumed ${peakKwh.toFixed(1)} kWh during expensive peak hours. Operating during off-peak (${cheapestAnalysis.cheapestWindow.periodType}) can reduce cost significantly.`,
          evidence: {
            peakKwhConsumed: peakKwh,
            peakPricePerKwh: peakPrice,
            offPeakPricePerKwh: offPeakPrice
          },
          estimatedSavings: {
            dailyCostSavings: Math.round(dailySavings * 100) / 100,
            monthlyCostSavings: Math.round(monthlySavings * 100) / 100,
            monthlyKwhShifted: Math.round(peakKwh * 30.5 * 10) / 10,
            currency: cheapestAnalysis.currency,
            isEstimate: true
          },
          recommendedWindow: cheapestAnalysis.cheapestWindow
        });
        recommendations.push(rec);
      }
    }

    if (this.realtimeEventBus && recommendations.length > 0) {
      this.realtimeEventBus.publish({
        type: 'energy.cost_optimization_detected',
        homeId,
        payload: {
          count: recommendations.length,
          timestamp: new Date().toISOString()
        }
      });
    }

    return {
      homeId,
      recommendations,
      cheapestUpcomingWindow: cheapestAnalysis.cheapestWindow
    };
  }

  async getCostOptimizations(homeId, { includeDismissed = false } = {}) {
    if (!this.costOptimizationRepo) return [];
    return this.costOptimizationRepo.findByHomeId(homeId, { includeDismissed });
  }

  async dismissCostOptimization(id) {
    if (!this.costOptimizationRepo) return false;
    return this.costOptimizationRepo.dismissOptimization(id);
  }
}

module.exports = { EnergyService };
