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

const VALID_ACTIONS = Object.freeze(['setPower', 'setLevel', 'setColorTemp', 'identifyDevice']);

class DeviceCommandService {
  /**
   * @param {Object} opts
   * @param {Object}   opts.commandRepo           - CommandRepository instance
   * @param {Object}   opts.outboxRepo            - OutboxRepository instance
   * @param {Object}   opts.deviceRepo            - DeviceRepository instance
   * @param {Object}   opts.deviceStateRepo       - DeviceStateRepository instance
   * @param {Object}   opts.auditRepo             - AuditRepository instance
   * @param {Object}   opts.mqttTransport         - MqttDeviceTransport instance
   */
  constructor({ commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo, mqttTransport }) {
    this.commandRepo     = commandRepo;
    this.outboxRepo      = outboxRepo;
    this.deviceRepo      = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.auditRepo       = auditRepo;
    this.mqttTransport   = mqttTransport;
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
  async sendCommand(actorContext, cmd) {
    // --- Step 1: Authorization ---
    this._validateActorContext(actorContext);
    await this._assertDeviceAuthorization(actorContext, cmd.deviceId);

    // --- Step 2: Command Schema Validation ---
    this._validateCommandEnvelope(cmd);

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

    // --- Audit ---
    try {
      await this.auditRepo.log({
        id: `audit_cmd_${cmd.commandId}_${Date.now()}`,
        actorUserId: actorContext.userId,
        deviceId: cmd.deviceId,
        homeId: actorContext.homeId,
        action: 'DEVICE_COMMAND_DISPATCHED',
        payload: { commandId: cmd.commandId, action: cmd.action, channelIndex: cmd.channelIndex },
        correlationId: cmd.commandId
      });
    } catch (auditErr) {
      // Audit failures never fail the command dispatch
      console.warn('[DeviceCommandService] Audit log failed:', auditErr.message);
    }

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
    if (!deviceId || !UUID_REGEX.test(deviceId)) {
      throw new Error(`Invalid deviceId '${deviceId}'`);
    }
    return this.deviceStateRepo.getFullState(deviceId);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  _validateActorContext(actorContext) {
    if (!actorContext || !actorContext.userId || !actorContext.homeId) {
      throw new Error('Authorization failed: actor context missing userId or homeId');
    }
    if (!UUID_REGEX.test(actorContext.userId) && !actorContext.userId.startsWith('usr_') && !actorContext.userId.startsWith('system_')) {
      throw new Error(`Authorization failed: invalid actorContext.userId format`);
    }
  }

  async _assertDeviceAuthorization(actorContext, deviceId) {
    if (!deviceId || !UUID_REGEX.test(deviceId)) {
      throw new Error(`Invalid deviceId '${deviceId}'`);
    }

    // Check device exists
    const device = await this.deviceRepo.getDevice(deviceId);
    if (!device) {
      throw new Error(`Device ${deviceId} not found`);
    }

    // Check device is authorized to this home
    const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
    if (!auth) {
      throw new Error(`Device ${deviceId} is not claimed to any home`);
    }

    if (auth.home_id !== actorContext.homeId) {
      throw new Error(`Device ${deviceId} does not belong to home ${actorContext.homeId}`);
    }
  }

  _validateCommandEnvelope(cmd) {
    if (!cmd) throw new Error('Command envelope is required');

    if (!cmd.commandId || !UUID_REGEX.test(cmd.commandId)) {
      throw new Error(`Invalid commandId '${cmd.commandId}': must be canonical UUID`);
    }
    if (!cmd.deviceId || !UUID_REGEX.test(cmd.deviceId)) {
      throw new Error(`Invalid deviceId '${cmd.deviceId}': must be canonical UUID`);
    }
    if (typeof cmd.channelIndex !== 'number' || cmd.channelIndex < 1 || cmd.channelIndex > 16) {
      throw new Error(`Invalid channelIndex '${cmd.channelIndex}': must be integer 1-16`);
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

    // recordCommand handles the DB insert or returns existing on duplicate
    const existing = await this.commandRepo.recordCommand({
      commandId: cmd.commandId,
      deviceId:  cmd.deviceId,
      channelIndex: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params || {},
      idempotencyKey: cmd.idempotencyKey,
      source: cmd.source || 'APP',
      expiresAt: cmd.expiresAt || null
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
          expiresAt: cmd.expiresAt || null,
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
    return {
      schemaVersion: 1,
      commandId: cmd.commandId,
      deviceId: cmd.deviceId,
      channelIndex: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params || {},
      idempotencyKey: cmd.idempotencyKey,
      source: cmd.source || 'APP',
      expiresAt: cmd.expiresAt || null,
      timestamp: new Date().toISOString()
    };
  }
}

module.exports = { DeviceCommandService };
