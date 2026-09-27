import { FastifyPluginAsync } from 'fastify';
import { TelemetryRepository } from './telemetry.repository';
import { TelemetryIngestionService } from './telemetry.service';
import { TelemetryQueryFilterSchema } from './telemetry.schema';

export const telemetryRoutes: FastifyPluginAsync = async (app) => {
  const db = (app as any).db;
  const repo = new TelemetryRepository(db);
  const service = new TelemetryIngestionService(repo);

  // 1. Direct HTTP Ingestion Boundary (for gateways or local clients)
  app.post('/ingest', async (req, reply) => {
    const result = await service.ingest(req.body);
    if (!result.accepted) {
      if (result.status === 'DROPPED_DUPLICATE') {
        return reply.status(200).send({ success: false, status: result.status, message: result.reason });
      }
      return reply.status(400).send({ success: false, status: result.status, message: result.reason });
    }
    return reply.status(202).send({ success: true, status: 'ACCEPTED' });
  });

  // 2. Query Latest / Live Telemetry
  app.get('/devices/:deviceId/live', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const { channelIndex } = req.query as { channelIndex?: string };
    const ch = channelIndex ? parseInt(channelIndex, 10) : 1;
    const latest = await service.getLatest(deviceId, ch);
    if (!latest) {
      return reply.status(404).send({ success: false, error: `No telemetry found for device ${deviceId} channel ${ch}` });
    }
    return reply.status(200).send({ success: true, data: latest });
  });

  // 3. Query Historical Telemetry Series
  app.get('/devices/:deviceId/history', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const queryParams = req.query as Record<string, string | undefined>;

    const parsedFilter = TelemetryQueryFilterSchema.safeParse({
      deviceId,
      channelIndex: queryParams.channelIndex ? parseInt(queryParams.channelIndex, 10) : undefined,
      startTime: queryParams.startTime,
      endTime: queryParams.endTime,
      limit: queryParams.limit ? parseInt(queryParams.limit, 10) : 100
    });

    if (!parsedFilter.success) {
      return reply.status(400).send({ success: false, error: parsedFilter.error.errors });
    }

    const items = await service.query(parsedFilter.data);
    return reply.status(200).send({ success: true, count: items.length, data: items });
  });
};
