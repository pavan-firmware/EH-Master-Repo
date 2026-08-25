'use strict';

/**
 * EH Home — Device Command API Router (Phase 6)
 *
 * REST API endpoints for authenticated device command dispatch and state queries.
 *
 * Security:
 *   - All routes require an authenticated actor context
 *   - Actor context is injected by a mock middleware for testing
 *     (production auth uses real token/session middleware)
 *   - Arbitrary userId in request body is NEVER treated as authorization proof
 *
 * Routes:
 *   POST /api/v1/commands/send         — Dispatch command to device
 *   GET  /api/v1/commands/:commandId   — Get command status by ID
 *   GET  /api/v1/devices/:deviceId/state — Get authoritative device state (from DeviceStateRepository)
 */

const { DeviceCommandService } = require('../services/device-command.service');
const { DeviceEventTelemetryIngestionService } = require('../services/device-event-telemetry-ingestion.service');
const {
  CommandRepository,
  OutboxRepository,
  DeviceRepository,
  DeviceStateRepository,
  EventRepository,
  AuditRepository
} = require('../repositories/index');
const { MqttDeviceTransport, MockMqttClient } = require('../services/mqtt-device-transport');
const { DatabaseClient } = require('../shared/db-client');
const { MqttTopicBuilder } = require('../shared/mqtt-topic-builder');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Build and configure all Phase 6 services from a shared DatabaseClient.
 * In production, db would be a real PostgreSQL-backed client.
 *
 * @param {DatabaseClient} db
 * @param {Object} [mqttClient] - Optional injected MQTT client (mock or real)
 * @returns {{ commandService, ingestionService, transport }}
 */
function buildPhase6Services(db, mqttClient = null) {
  const commandRepo     = new CommandRepository(db);
  const outboxRepo      = new OutboxRepository(db);
  const deviceRepo      = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const eventRepo       = new EventRepository(db);
  const auditRepo       = new AuditRepository(db);

  // Wire up the ingestion service first so we can attach callbacks to transport
  const ingestionService = new DeviceEventTelemetryIngestionService({
    deviceStateRepo, eventRepo, commandRepo, outboxRepo, auditRepo
  });

  const transport = new MqttDeviceTransport({
    mqttClient: mqttClient || new MockMqttClient(),
    onReceipt:     (receipt) => commandService.handleCommandReceipt(receipt),
    onState:       (state)   => ingestionService.handleDeviceState(state),
    onEvent:       (event)   => ingestionService.handleDeviceEvent(event),
    onTelemetry:   (telem)   => ingestionService.handleTelemetry(telem),
    onAvailability:(id, av)  => ingestionService.handleAvailability(id, av),
  });

  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
    mqttTransport: transport
  });

  return { commandService, ingestionService, transport, commandRepo, deviceStateRepo };
}

/**
 * Mock authentication middleware factory.
 * Injects authenticated actor context from test request header or environment.
 *
 * PRODUCTION REQUIREMENT:
 *   Replace with real JWT/session token verification.
 *   Never trust actorContext from request body.
 */
function mockAuthMiddleware(req, res, next) {
  // In testing, actor context is provided via X-Actor-Context header (JSON encoded)
  const actorHeader = req.headers['x-actor-context'];
  if (actorHeader) {
    try {
      req.actorContext = JSON.parse(actorHeader);
    } catch (_) {
      return res.status(401).json({ error: 'Invalid X-Actor-Context header' });
    }
  } else {
    return res.status(401).json({
      error: 'Unauthorized: authentication required',
      hint: 'Provide X-Actor-Context header with {userId, homeId, role} for test environments'
    });
  }
  next();
}

/**
 * Build Express-compatible route handler functions for device command operations.
 * Returns an object with handler functions (not an Express router instance)
 * to avoid requiring express as a dependency in the backend services layer.
 *
 * @param {{ commandService, deviceStateRepo, commandRepo }} services
 * @returns {Object} - Route handler functions
 */
function buildRouteHandlers(services) {
  const { commandService, commandRepo } = services;

  return {
    /**
     * POST /api/v1/commands/send
     * Body: { commandId, deviceId, channelIndex, action, params, idempotencyKey, expiresAt, source }
     */
    async sendCommand(req, res) {
      const actorContext = req.actorContext;
      if (!actorContext) {
        return res.status(401).json({ error: 'Unauthorized: no actor context' });
      }

      const cmd = req.body;
      if (!cmd) {
        return res.status(400).json({ error: 'Request body is required' });
      }

      try {
        const result = await commandService.sendCommand(actorContext, cmd);

        if (result.status === 'EXPIRED') {
          return res.status(422).json({
            error: 'Command rejected: already expired',
            commandId: result.commandId,
            status: result.status
          });
        }

        return res.status(result.isIdempotentReplay ? 200 : 202).json(result);
      } catch (err) {
        if (err.message.includes('Authorization failed') || err.message.includes('does not belong')) {
          return res.status(403).json({ error: err.message });
        }
        if (err.message.includes('not found')) {
          return res.status(404).json({ error: err.message });
        }
        if (err.message.includes('Invalid')) {
          return res.status(400).json({ error: err.message });
        }
        console.error('[DeviceCommandRouter] Unhandled error:', err);
        return res.status(500).json({ error: 'Internal server error' });
      }
    },

    /**
     * GET /api/v1/commands/:commandId
     * Returns command status record.
     */
    async getCommand(req, res) {
      const { commandId } = req.params;
      if (!commandId || !UUID_REGEX.test(commandId)) {
        return res.status(400).json({ error: `Invalid commandId '${commandId}'` });
      }

      try {
        const record = await commandRepo.getCommand(commandId);
        if (!record) {
          return res.status(404).json({ error: `Command ${commandId} not found` });
        }
        return res.status(200).json(record);
      } catch (err) {
        return res.status(500).json({ error: err.message });
      }
    },

    /**
     * GET /api/v1/devices/:deviceId/state
     * Returns authoritative device state from DeviceStateRepository.
     * Does NOT trigger MQTT GET_STATE topic.
     */
    async getDeviceState(req, res) {
      const { deviceId } = req.params;
      if (!deviceId || !UUID_REGEX.test(deviceId)) {
        return res.status(400).json({ error: `Invalid deviceId '${deviceId}'` });
      }

      const actorContext = req.actorContext;
      if (!actorContext) {
        return res.status(401).json({ error: 'Unauthorized: no actor context' });
      }

      try {
        const state = await commandService.getDeviceState(deviceId);
        if (!state) {
          return res.status(404).json({ error: `Device state for ${deviceId} not found` });
        }
        return res.status(200).json(state);
      } catch (err) {
        if (err.message.includes('Invalid')) {
          return res.status(400).json({ error: err.message });
        }
        return res.status(500).json({ error: err.message });
      }
    }
  };
}

module.exports = {
  buildPhase6Services,
  buildRouteHandlers,
  mockAuthMiddleware,
};
