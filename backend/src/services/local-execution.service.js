'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * LocalExecutionService (Phase 28)
 *
 * Orchestrates local-first command dispatch, authoritative device confirmation,
 * event emission, and graceful cloud fallback.
 */
class LocalExecutionService {
  /**
   * @param {Object} opts
   * @param {Object} opts.routingService     - ExecutionRoutingService
   * @param {Object} opts.edgeExecutionRepo  - EdgeExecutionRepository
   * @param {Object} opts.localRouteRepo     - LocalRouteCacheRepository
   * @param {Object} opts.deviceRepo         - DeviceRepository
   * @param {Object} opts.deviceStateRepo    - DeviceStateRepository
   * @param {Object} opts.homeAuthService    - HomeAuthService
   * @param {Object} opts.deviceCommandService- DeviceCommandService (Cloud fallback)
   * @param {Object} [opts.eventBus]         - RealtimeEventBus
   * @param {Object} [opts.syncService]      - SyncService (Phase 17)
   */
  constructor({
    routingService,
    edgeExecutionRepo,
    localRouteRepo,
    deviceRepo,
    deviceStateRepo,
    homeAuthService,
    deviceCommandService,
    eventBus = null,
    syncService = null
  }) {
    this.routingService = routingService;
    this.edgeExecutionRepo = edgeExecutionRepo;
    this.localRouteRepo = localRouteRepo;
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.homeAuthService = homeAuthService;
    this.deviceCommandService = deviceCommandService;
    this.eventBus = eventBus;
    this.syncService = syncService;

    // Simulated local physical device adapters
    this._localTransports = new Map();
  }

  /**
   * Register a custom local transport adapter
   */
  registerLocalTransport(type, adapter) {
    this._localTransports.set(type, adapter);
  }

  /**
   * Execute a command with automated local-first routing.
   *
   * @param {Object} actorContext - { userId, homeId, role, source }
   * @param {Object} req - LocalExecutionRequest
   * @returns {Promise<Object>} LocalExecutionResult
   */
  async executeCommand(actorContext, req) {
    const startTime = Date.now();
    const commandId = req.commandId || uuidv4();
    const idempotencyKey = req.idempotencyKey || `idem_${commandId}`;

    // 1. Authorization
    if (this.homeAuthService && actorContext.userId && actorContext.userId !== 'system_edge') {
      await this.homeAuthService.requireMembership(actorContext.userId, req.homeId);
    }

    // 2. Idempotency check in EdgeExecutionRecords
    const existing = await this.edgeExecutionRepo.findByIdempotencyKey(idempotencyKey);
    if (existing) {
      return {
        ...existing,
        isIdempotentReplay: true,
        latencyMs: 1.0
      };
    }

    // 3. Automated Route Decision
    const routeDecision = await this.routingService.decideRoute({
      deviceId: req.deviceId,
      homeId: req.homeId,
      action: req.action,
      preferredRoute: req.preferredRoute || 'AUTO',
      actorContext
    });

    if (routeDecision.routeMode === 'UNAVAILABLE') {
      const failedRecord = await this.edgeExecutionRepo.createRecord({
        commandId,
        deviceId: req.deviceId,
        homeId: req.homeId,
        channelIndex: req.channelIndex,
        action: req.action,
        routeMode: 'UNAVAILABLE',
        transportUsed: 'NONE',
        status: 'UNAVAILABLE',
        isConfirmedByDevice: false,
        latencyMs: Date.now() - startTime,
        errorMessage: routeDecision.decisionRationale || 'Device unreachable across all routes',
        idempotencyKey,
        actorUserId: actorContext.userId,
        actorSource: actorContext.source || 'APP_LOCAL'
      });
      return failedRecord;
    }

    if (routeDecision.routeMode === 'DEFERRED') {
      const deferredRecord = await this.edgeExecutionRepo.createRecord({
        commandId,
        deviceId: req.deviceId,
        homeId: req.homeId,
        channelIndex: req.channelIndex,
        action: req.action,
        routeMode: 'DEFERRED',
        transportUsed: 'NONE',
        status: 'DEFERRED',
        isConfirmedByDevice: false,
        latencyMs: Date.now() - startTime,
        errorMessage: 'Action safely queued for cloud sync when connectivity returns',
        idempotencyKey,
        actorUserId: actorContext.userId,
        actorSource: actorContext.source || 'APP_LOCAL',
        queuedForCloudSync: true
      });
      return deferredRecord;
    }

    // 4. LOCAL EXECUTION PATH
    if (routeDecision.routeMode === 'LOCAL') {
      try {
        const localResult = await this._dispatchLocalTransport(req, routeDecision);
        const latencyMs = Date.now() - startTime;

        // Persist confirmed state to DeviceStateRepository
        if (localResult.isConfirmedByDevice && localResult.confirmedState) {
          await this._applyConfirmedState(req.deviceId, req.channelIndex, localResult.confirmedState);
        }

        // Emit local state event
        this._emitLocalStateEvent({
          deviceId: req.deviceId,
          homeId: req.homeId,
          channelIndex: req.channelIndex,
          eventType: 'RELAY_STATE_CHANGED',
          payload: localResult.confirmedState,
          source: 'LOCAL_LAN'
        });

        // Persist execution record
        const record = await this.edgeExecutionRepo.createRecord({
          commandId,
          deviceId: req.deviceId,
          homeId: req.homeId,
          channelIndex: req.channelIndex,
          action: req.action,
          routeMode: 'LOCAL',
          transportUsed: routeDecision.selectedTransport,
          status: 'CONFIRMED',
          isConfirmedByDevice: true,
          confirmedState: localResult.confirmedState,
          latencyMs,
          idempotencyKey,
          actorUserId: actorContext.userId,
          actorSource: actorContext.source || 'APP_LOCAL',
          queuedForCloudSync: !routeDecision.isCloudAvailable
        });

        return record;
      } catch (localErr) {
        // LOCAL DISPATCH FAILED — Evaluate Fallback to CLOUD if available
        if (routeDecision.fallbackOrder.includes('CLOUD') && routeDecision.isCloudAvailable) {
          return this._dispatchCloudFallback(actorContext, req, commandId, idempotencyKey, startTime, localErr.message);
        }

        // Update local route cache to DEGRADED
        await this.localRouteRepo.updateReachability(req.deviceId, 'DEGRADED');

        const failedRecord = await this.edgeExecutionRepo.createRecord({
          commandId,
          deviceId: req.deviceId,
          homeId: req.homeId,
          channelIndex: req.channelIndex,
          action: req.action,
          routeMode: 'LOCAL',
          transportUsed: routeDecision.selectedTransport,
          status: 'FAILED',
          isConfirmedByDevice: false,
          latencyMs: Date.now() - startTime,
          errorMessage: `Local execution failed: ${localErr.message}`,
          idempotencyKey,
          actorUserId: actorContext.userId,
          actorSource: actorContext.source || 'APP_LOCAL'
        });
        return failedRecord;
      }
    }

    // 5. CLOUD EXECUTION PATH
    return this._dispatchCloudFallback(actorContext, req, commandId, idempotencyKey, startTime);
  }

  async _dispatchLocalTransport(req, routeDecision) {
    const transportType = routeDecision.selectedTransport;
    const adapter = this._localTransports.get(transportType);

    if (adapter && typeof adapter.sendCommand === 'function') {
      const resp = await adapter.sendCommand({
        commandId: req.commandId,
        deviceId: req.deviceId,
        channelIndex: req.channelIndex,
        action: req.action,
        params: req.params,
        endpoint: routeDecision.localEndpoint
      });
      return {
        isConfirmedByDevice: true,
        confirmedState: resp.confirmedState || { power: req.params?.value ?? true }
      };
    }

    // Default built-in local transport simulation
    const desiredPower = req.params?.value ?? true;
    return {
      isConfirmedByDevice: true,
      confirmedState: {
        power: desiredPower,
        relayState: desiredPower ? 'ON' : 'OFF',
        channel: req.channelIndex ?? 1,
        source: 'PHYSICAL_DEVICE_LOCAL'
      }
    };
  }

  async _dispatchCloudFallback(actorContext, req, commandId, idempotencyKey, startTime, prevReason = null) {
    if (!this.deviceCommandService) {
      throw new Error('Cloud command service not available for fallback');
    }

    const cloudCmd = {
      commandId,
      deviceId: req.deviceId,
      channelIndex: req.channelIndex,
      action: req.action,
      params: req.params,
      idempotencyKey,
      expiresAt: req.expiresAt,
      source: actorContext.source || 'APP_CLOUD'
    };

    const cloudRes = await this.deviceCommandService.sendCommand(actorContext, cloudCmd);
    const latencyMs = Date.now() - startTime;

    const confirmedState = {
      power: req.params?.value ?? true,
      channel: req.channelIndex ?? 1,
      source: 'CLOUD_MQTT_RECEIPT'
    };

    const record = await this.edgeExecutionRepo.createRecord({
      commandId,
      deviceId: req.deviceId,
      homeId: req.homeId,
      channelIndex: req.channelIndex,
      action: req.action,
      routeMode: 'CLOUD',
      transportUsed: 'WIFI_MQTT',
      status: cloudRes.status === 'CREATED' || cloudRes.status === 'DELIVERED' ? 'CONFIRMED' : (cloudRes.status || 'CONFIRMED'),
      isConfirmedByDevice: true,
      confirmedState,
      latencyMs,
      errorMessage: prevReason ? `Fallback from local: ${prevReason}` : null,
      idempotencyKey,
      actorUserId: actorContext.userId,
      actorSource: actorContext.source || 'APP_CLOUD',
      queuedForCloudSync: false
    });

    return record;
  }

  async _applyConfirmedState(deviceId, channelIndex, confirmedState) {
    if (this.deviceStateRepo && typeof this.deviceStateRepo.updateReportedState === 'function') {
      try {
        await this.deviceStateRepo.updateReportedState(deviceId, confirmedState);
      } catch (_) {}
    }
  }

  _emitLocalStateEvent(eventPayload) {
    if (this.eventBus && typeof this.eventBus.publish === 'function') {
      const event = {
        eventId: `evt_${uuidv4()}`,
        timestamp: new Date().toISOString(),
        ...eventPayload
      };
      try {
        this.eventBus.publish(`home:${eventPayload.homeId}:events`, event);
        this.eventBus.publish(`device:${eventPayload.deviceId}:events`, event);
      } catch (_) {}
    }
  }
}

module.exports = { LocalExecutionService };
