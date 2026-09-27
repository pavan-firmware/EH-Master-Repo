import { FastifyPluginAsync } from 'fastify';
import { DeviceCommandRepository } from './command.repository';
import { DeviceCommandService } from './command.service';
import { CommandReceiptSchema } from './command.schema';
import { MqttDeviceTransport } from '../mqtt/mqtt.transport';
import { randomUUID } from 'crypto';

export const commandRoutes: FastifyPluginAsync = async (app) => {
  const db = (app as any).db;
  const repo = new DeviceCommandRepository(db);
  const transport = (app as any).mqttTransport || new MqttDeviceTransport();
  const service = new DeviceCommandService(repo, transport);

  // 1. Dispatch Device Command
  app.post('/:deviceId/commands', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const authHeader = req.headers.authorization;
    const actorUserId = (req as any).user?.id || (req.headers['x-user-id'] as string) || (authHeader ? 'user_auth_context' : null);

    if (!actorUserId) {
      return reply.status(401).send({ success: false, error: 'Unauthorized: actor identity required' });
    }

    const body = req.body as any;
    const commandId = body.commandId || randomUUID();
    const expiresAt = body.expiresAt || new Date(Date.now() + 60000).toISOString();

    const envelope = {
      schemaVersion: 1,
      commandId,
      deviceId,
      channelIndex: body.channelIndex !== undefined ? body.channelIndex : 1,
      action: body.action,
      params: body.params || {},
      idempotencyKey: body.idempotencyKey || `idem_${commandId}`,
      source: body.source || 'APP',
      expiresAt,
      timestamp: new Date().toISOString()
    };

    try {
      const result = await service.sendCommand({ userId: actorUserId }, envelope);
      if (result.status === 'EXPIRED') {
        return reply.status(422).send({ success: false, data: result });
      }
      return reply.status(202).send({ success: true, data: result });
    } catch (err: any) {
      return reply.status(400).send({ success: false, error: err.message });
    }
  });

  // 2. Receive Command Receipt
  app.post('/:deviceId/command-receipts', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const parseResult = CommandReceiptSchema.safeParse({ ...req.body as any, deviceId });
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.errors });
    }

    await service.handleCommandReceipt(parseResult.data);
    return reply.status(200).send({ success: true, message: 'Receipt recorded' });
  });

  // 3. Get Device Live State & Availability
  app.get('/:deviceId/state', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const state = await service.getDeviceState(deviceId);
    if (!state) {
      return reply.status(404).send({ success: false, error: `Device ${deviceId} not found` });
    }
    return reply.status(200).send({ success: true, data: state });
  });

  // 4. Update Device Availability (LWT / Online hook)
  app.post('/:deviceId/availability', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const { status } = req.body as { status: string };
    if (!status || !['ONLINE', 'OFFLINE'].includes(status.toUpperCase())) {
      return reply.status(400).send({ success: false, error: "Invalid status: must be 'ONLINE' or 'OFFLINE'" });
    }

    await service.handleAvailability(deviceId, status);
    return reply.status(200).send({ success: true, availability: status.toUpperCase() });
  });
};
