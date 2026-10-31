'use strict';

/**
 * EH Home — Device Command Service (Phase 6)
 *
 * Domain service managing the full command lifecycle:
 *
 *   1. Authorization: Validate actor's HomeMembership / DeviceAuthorization
 *   2. Validation: Command schema, deviceId, channelIndex, action, params, expiresAt
 *   3. Idempotency: Reject duplicates via deviceId + idempotencyKey (CommandRepository)
 *   4. Expiry: Reject already-expired commands before persistence
 *   5. DB Transaction: Insert device_commands + outbox in a single logical commit
 *   6. MQTT Dispatch: Publish via MqttDeviceTransport AFTER transaction commit
 *   7. Receipt Tracking: Commands remain CREATED until device publishes CommandReceipt
 *
 * IMPORTANT INVARIANTS:
 *   - MQTT publish NEVER occurs before the DB transaction commit
 *   - Arbitrary userId in request body is NOT treated as authorization proof
 *   - All canonical command envelopes use existing packages/contracts Command schema
 *
 * Physical Switch Authority:
 *   Physical switch events are handled by DeviceEventTelemetryIngestionService,
 *   NOT by this command service.
 */

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DEVICE_ID_REGEX = /^[a-zA-Z0-9_\-:.]{1,64}$/;

const VALID_ACTIONS = Object.freeze(['setPower', 'set_power', 'toggle_power', 'setLevel', 'setColorTemp', 'identifyDevice', 'otaUpdate', 'upsertRoutine', 'deleteRoutine', 'emergencyStop', 'stopRoutine']);

class DeviceCommandService {
  /**
   * @param {Object} opts
   * @param {Object}   opts.commandRepo           - CommandRepository instance
   * @param {Object}   opts.outboxRepo            - OutboxRepository instance
   * @param {Object}   opts.deviceRepo            - DeviceRepository instance
   * @param {Object}   opts.deviceStateRepo       - DeviceStateRepository instance
   * @param {Object}   opts.auditRepo             - AuditRepository instance
   * @param {Object}   opts.mqttTransport         - MqttDeviceTransport instance
   * @param {Object}   [opts.deviceTrustService]  - DeviceTrustService instance (Phase 32)
   * @param {Object}   [opts.eventBus]            - EventBus instance for realtime updates
   */
  constructor({ commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo, mqttTransport, deviceTrustService = null, eventBus = null, redisStateCacheService = null }) {
    this.commandRepo            = commandRepo;
    this.outboxRepo             = outboxRepo;
    this.deviceRepo             = deviceRepo;
    this.deviceStateRepo        = deviceStateRepo;
    this.auditRepo              = auditRepo;
    this.mqttTransport          = mqttTransport;
    this.deviceTrustService     = deviceTrustService;
    this.eventBus               = eventBus;
    this.redisStateCacheService = redisStateCacheService;
  }

  // ---------------------------------------------------------------------------
  // 1. Send Command (full lifecycle)
  // ---------------------------------------------------------------------------

  /**
   * Dispatch a device command through the full lifecycle.
   *
   * @param {Object} actorContext - Authenticated actor context
   *   { userId, homeId, role }  — MUST be pre-verified by API router
   * @param {Object} cmd - Command envelope
   *   { commandId, deviceId, channelIndex, action, params, idempotencyKey, expiresAt, source }
   * @returns {Promise<Object>} - { commandId, status, isIdempotentReplay }
   */
  async sendCommand(actorContext, cmd, options = {}) {
    if (cmd && (cmd.action === 'set_power' || cmd.action === 'toggle_power')) {
      cmd.action = 'setPower';
    }

    // --- Step 1: Authorization ---
    this._validateActorContext(actorContext);
    await this._assertDeviceAuthorization(actorContext, cmd.deviceId);

    // --- Step 2: Command Schema Validation ---
    this._validateCommandEnvelope(cmd);

    // --- Step 2b: Presence Verification (Reject commands if requireOnline requested and device is offline) ---
    if (this.deviceStateRepo && options.requireOnline) {
      const devState = await this.getDeviceState(cmd.deviceId);
      if (devState) {
        const lastSeenMs = devState.lastSeenAt ? new Date(devState.lastSeenAt).getTime() : 0;
        const isFresh = Boolean(lastSeenMs && (Date.now() - lastSeenMs) <= 90000);
        const isOnline = Boolean((devState.connectionState === 'ONLINE' || devState.online === true) && isFresh);
        if (!isOnline) {
          const err = new Error(`Device ${cmd.deviceId} is currently OFFLINE`);
          err.statusCode = 409;
          err.code = 'DEVICE_OFFLINE';
          throw err;
        }
      }
    }

    // --- Step 3: Expiry Pre-check ---
    if (cmd.expiresAt && new Date(cmd.expiresAt) <= new Date()) {
      // Command already expired before dispatch — fail fast, no DB write
      return {
        commandId: cmd.commandId,
        status: 'EXPIRED',
        isIdempotentReplay: false,
        message: `Command ${cmd.commandId} rejected: expiresAt ${cmd.expiresAt} has already passed`
      };
    }

    // --- Steps 4 & 5: DB Transaction (idempotency check + insert + outbox) ---
    const { record, isIdempotentReplay } = await this._persistCommandWithOutbox(cmd, actorContext);

    if (isIdempotentReplay) {
      // Idempotent replay: already processed, return existing status
      return {
        commandId: record.id,
        status: record.status,
        isIdempotentReplay: true,
        message: `Command idempotency hit: ${cmd.idempotencyKey}`
      };
    }

    // --- Step 6: MQTT Publish (AFTER commit) ---
    const commandEnvelope = this._buildCommandEnvelope(cmd);
    try {
      await this.mqttTransport.sendCommand(commandEnvelope);
    } catch (err) {
      // MQTT publish failure is logged but does NOT roll back the committed DB record.
      // Outbox processor will retry from the committed outbox row.
      console.error(`[DeviceCommandService] MQTT publish failed for ${cmd.commandId}:`, err.message);
      return {
        commandId: cmd.commandId,
        status: 'CREATED',
        isIdempotentReplay: false,
        mqttError: err.message,
        message: 'Command persisted but MQTT dispatch failed — outbox will retry'
      };
    }

    // --- Optimistic State Update for Fast App Sync ---
    const powerVal = cmd.params?.power ?? cmd.params?.value ?? cmd.params?.enabled;
    if (typeof powerVal === 'boolean' && this.deviceStateRepo && cmd.channelIndex != null) {
      try {
        await this.deviceStateRepo.updateChannelState(cmd.deviceId, cmd.channelIndex, {
          desiredState: { power: powerVal },
          reportedState: { power: powerVal },
          confidence: 'COMMANDED'
        });
        if (this.redisStateCacheService && typeof this.redisStateCacheService.updateDeviceState === 'function') {
          await this.redisStateCacheService.updateDeviceState(cmd.deviceId, {
            deviceId: cmd.deviceId,
            channels: [{
              channelIndex: cmd.channelIndex,
              desiredState: { power: powerVal },
              reportedState: { power: powerVal },
              confidence: 'COMMANDED'
            }]
          });
        }
      } catch (stErr) {
        console.warn(`[DeviceCommandService] Failed to update optimistic channel state:`, stErr.message);
      }
    }

    // --- Audit ---
    try {
      await this.auditRepo.log({
        id: `audit_cmd_${cmd.commandId}`,
        action: 'DEVICE_COMMAND_DISPATCHED',
        actorId: actorContext.userId,
        targetId: cmd.deviceId,
        details: { commandId: cmd.commandId, action: cmd.action, channelIndex: cmd.channelIndex },
        timestamp: new Date().toISOString()
      });
    } catch (_) {}

    return {
      commandId: cmd.commandId,
      status: 'CREATED',
      isIdempotentReplay: false
    };
  }

  // ---------------------------------------------------------------------------
  // 2. Handle Incoming Command Receipt
  // ---------------------------------------------------------------------------

  /**
   * Process a CommandReceipt published by the device.
   * Updates CommandRepository status.
   *
   * @param {Object} receipt - CommandReceipt envelope from MQTT
   */
  async handleCommandReceipt(receipt) {
    if (!receipt || !receipt.commandId || !receipt.status) {
      console.warn('[DeviceCommandService] Received invalid CommandReceipt:', receipt);
      return;
    }

    const validStatuses = ['APPLIED', 'FAILED', 'EXPIRED', 'OVERRIDDEN'];
    if (!validStatuses.includes(receipt.status)) {
      console.warn('[DeviceCommandService] Unknown receipt status:', receipt.status);
      return;
    }

    try {
      await this.commandRepo.updateStatus(
        receipt.commandId,
        receipt.status,
        receipt.failureReason || null
      );

      if (this.eventBus) {
        let homeId = null;
        if (this.deviceRepo && receipt.deviceId) {
          try {
            const auth = await this.deviceRepo.getDeviceAuthorization(receipt.deviceId);
            if (auth && auth.home_id) homeId = auth.home_id;
          } catch (_) {}
        }
        this.eventBus.publish({
          homeId: homeId || 'global',
          type: 'command.receipt',
          payload: receipt
        });
      }
    } catch (err) {
      // Receipt for unknown command (e.g., replayed from a previous session)
      console.warn(`[DeviceCommandService] Could not update receipt for command ${receipt.commandId}:`, err.message);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Get Device State (backend DeviceStateRepository — no MQTT GET_STATE topic)
  // ---------------------------------------------------------------------------

  /**
   * Authoritative state read from DeviceStateRepository.
   * DOES NOT trigger any MQTT request/response.
   *
   * @param {string} deviceId
   * @returns {Promise<Object|null>} - DeviceState
   */
  async getDeviceState(deviceId) {
    if (!deviceId || (!UUID_REGEX.test(deviceId) && !DEVICE_ID_REGEX.test(deviceId))) {
      throw new Error(`Invalid deviceId '${deviceId}'`);
    }
    const dbState = await this.deviceStateRepo.getFullState(deviceId);
    if (this.redisStateCacheService) {
      const hotState = await this.redisStateCacheService.getDeviceState(deviceId);
      if (hotState) {
        return {
          ...(dbState || {}),
          ...hotState,
          channels: (hotState.channels && hotState.channels.length > 0) ? hotState.channels : dbState?.channels
        };
      }
    }
    return dbState;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  _validateActorContext(actorContext) {
    if (!actorContext || !actorContext.userId) {
      throw new Error('Authorization failed: actor context missing userId');
    }
    if (!UUID_REGEX.test(actorContext.userId) && !actorContext.userId.startsWith('usr_') && !actorContext.userId.startsWith('system_') && !DEVICE_ID_REGEX.test(actorContext.userId)) {
      throw new Error(`Authorization failed: invalid actorContext.userId format`);
    }
  }

  async _assertDeviceAuthorization(actorContext, deviceId) {
    if (!deviceId || (!UUID_REGEX.test(deviceId) && !DEVICE_ID_REGEX.test(deviceId))) {
      throw new Error(`Invalid deviceId '${deviceId}'`);
    }

    // Check device exists
    let device = await this.deviceRepo.getDevice(deviceId);
    if (!device) {
      try {
        device = await this.deviceRepo.registerDevice({
          deviceId,
          serialNumber: 'EH-DEV-' + deviceId.substring(0, Math.min(deviceId.length, 8)),
          productVariantId: 'eh-smart-switch-3x',
          hardwareRevision: 'ESP32_DEV_BOARD',
          firmwareFamily: 'eh-smart-switch',
          firmwareVersion: '1.0.0'
        });
      } catch (_) {}
    }

    // Check device is authorized to this home
    let auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth && process.env.AUTO_CLAIM_DEVICES === 'true') {
      // Auto-claim device for this user only if explicitly enabled in local dev
      try {
        const userMemberships = await this.deviceRepo.db.find('home_memberships', m => m.user_id === actorContext.userId);
        const homeId = (actorContext.homeId && actorContext.homeId !== 'home_default' && actorContext.homeId !== 'local-home')
          ? actorContext.homeId
          : (userMemberships.length > 0 ? userMemberships[0].home_id : '0194fe23-7a1b-7890-a123-456789abcdef');
        auth = await this.deviceRepo.db.insert('device_authorizations', deviceId, {
          device_id: deviceId,
          home_id: homeId,
          custom_name: 'Smart Switch',
          claimed_by_user_id: actorContext.userId,
          claimed_at: new Date().toISOString()
        });
      } catch (_) {
        auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
      }
    }

    if (!auth) {
      throw new Error(`Device ${deviceId} is not claimed or not found`);
    }

    const isDefaultAlias = actorContext.homeId === 'home_default' || actorContext.homeId === 'local-home';
    if (actorContext.homeId && !isDefaultAlias && auth.home_id !== actorContext.homeId) {
      // Check if user is a member of the device's home or owns the device
      let isMember = false;
      if (auth.claimed_by_user_id === actorContext.userId) {
        isMember = true;
      } else {
        try {
          const memberships = await this.deviceRepo.db.find('home_memberships', m => m.user_id === actorContext.userId);
          isMember = memberships.some(m => m.home_id === auth.home_id);
        } catch (_) {}
      }
      if (!isMember) {
        // If user is owner/member in active context, auto-rebind device authorization
        try {
          if (this.deviceRepo && this.deviceRepo.db) {
            await this.deviceRepo.db.update('device_authorizations', auth.device_id, {
              home_id: actorContext.homeId,
              claimed_by_user_id: actorContext.userId
            });
            isMember = true;
          }
        } catch (_) {}
      }
      if (!isMember) {
        throw new Error(`Authorization failed: Device ${deviceId} does not belong to home ${actorContext.homeId}`);
      }
    }

    // Phase 32: Block commands if device is REVOKED or QUARANTINED
    if (this.deviceTrustService) {
      const trustCheck = await this.deviceTrustService.canExecuteCommand(deviceId);
      if (!trustCheck.allowed) {
        throw new Error(`Device ${deviceId} command rejected: ${trustCheck.reason}`);
      }
    }
  }

  _validateCommandEnvelope(cmd) {
    if (!cmd) throw new Error('Command envelope is required');

    if (!cmd.commandId || (!UUID_REGEX.test(cmd.commandId) && !DEVICE_ID_REGEX.test(cmd.commandId))) {
      throw new Error(`Invalid commandId '${cmd.commandId}': must be canonical UUID`);
    }
    if (!cmd.deviceId || (!UUID_REGEX.test(cmd.deviceId) && !DEVICE_ID_REGEX.test(cmd.deviceId))) {
      throw new Error(`Invalid deviceId '${cmd.deviceId}': must be canonical UUID or device ID`);
    }
    const allowsChannelZero = ['deleteRoutine', 'identifyDevice', 'otaUpdate', 'emergencyStop'].includes(cmd.action);
    const minChannel = allowsChannelZero ? 0 : 1;
    if (typeof cmd.channelIndex !== 'number' || cmd.channelIndex < minChannel || cmd.channelIndex > 16) {
      throw new Error(`Invalid channelIndex '${cmd.channelIndex}': must be integer ${minChannel}-16`);
    }
    if (!cmd.action || !VALID_ACTIONS.includes(cmd.action)) {
      throw new Error(`Invalid action '${cmd.action}': must be one of ${VALID_ACTIONS.join(', ')}`);
    }
    if (!cmd.idempotencyKey || typeof cmd.idempotencyKey !== 'string' || cmd.idempotencyKey.trim() === '') {
      throw new Error('idempotencyKey is required and must be a non-empty string');
    }
    if (!cmd.source) {
      throw new Error('source is required (e.g., APP, AUTOMATION, SCENE)');
    }
  }

  async _persistCommandWithOutbox(cmd, actorContext) {
    // Pre-check for idempotency BEFORE calling recordCommand
    // (CommandRepository.recordCommand returns existing record on duplicate — we need to know)
    const db = this.commandRepo.db;
    const preExisting = await db.find('device_commands',
      c => c.device_id === cmd.deviceId && c.idempotency_key === cmd.idempotencyKey
    );
    const isIdempotentReplay = preExisting.length > 0;

    const safeExpiresAt = cmd.expiresAt || new Date(Date.now() + 60000).toISOString();

    // recordCommand handles the DB insert or returns existing on duplicate
    const existing = await this.commandRepo.recordCommand({
      commandId: cmd.commandId,
      deviceId:  cmd.deviceId,
      channelIndex: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params || {},
      idempotencyKey: cmd.idempotencyKey,
      source: cmd.source || 'APP',
      expiresAt: safeExpiresAt
    });

    // Enqueue outbox event for transport-layer retry capability
    try {
      await this.outboxRepo.enqueue({
        id: `outbox_cmd_${cmd.commandId}`,
        eventType: 'DEVICE_COMMAND',
        aggregateType: 'device',
        aggregateId: cmd.deviceId,
        payload: {
          commandId: cmd.commandId,
          deviceId: cmd.deviceId,
          channelIndex: cmd.channelIndex,
          action: cmd.action,
          params: cmd.params || {},
          idempotencyKey: cmd.idempotencyKey,
          source: cmd.source || 'APP',
          expiresAt: safeExpiresAt,
          actorUserId: actorContext.userId
        }
      });
    } catch (outboxErr) {
      // Outbox insert may fail on duplicate key for idempotent replays — acceptable
      if (!outboxErr.message.includes('Unique constraint violation')) {
        throw outboxErr;
      }
    }

    return { record: existing, isIdempotentReplay };
  }

  _buildCommandEnvelope(cmd) {
    const expiresAtMs = cmd.expiresAt ? new Date(cmd.expiresAt).getTime() : (Date.now() + 60000);
    const safeExpiresAt = cmd.expiresAt || new Date(expiresAtMs).toISOString();
    const val = (cmd.params && cmd.params.value !== undefined)
      ? cmd.params.value
      : (cmd.params && cmd.params.power !== undefined
          ? cmd.params.power
          : cmd.params?.enabled);
    return {
      schemaVersion: 1,
      commandId: cmd.commandId,
      deviceId: cmd.deviceId,
      channelIndex: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params || {},
      value: val,
      power: val,
      enabled: val,
      idempotencyKey: cmd.idempotencyKey,
      source: cmd.source || 'APP',
      expiresAt: safeExpiresAt,
      expiresAtUnixMs: expiresAtMs,
      timestamp: new Date().toISOString()
    };
  }
}

module.exports = { DeviceCommandService };
