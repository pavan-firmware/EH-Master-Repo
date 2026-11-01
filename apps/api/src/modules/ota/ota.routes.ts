import { FastifyPluginAsync } from 'fastify';
import { OtaRepository } from './ota.repository';
import { OtaService } from './ota.service';
import {
  CheckOtaUpdateRequestSchema,
  CreateOtaJobRequestSchema,
  UpdateOtaJobStatusSchema,
  AuthorizeOtaJobRequestSchema
} from './ota.schema';

export const otaRoutes: FastifyPluginAsync = async (app) => {
  const db = (app as any).db;
  const repo = new OtaRepository(db);
  const service = new OtaService(repo);

  // 1. Check for Eligible OTA Update
  app.post('/check', async (req, reply) => {
    const parseResult = CheckOtaUpdateRequestSchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.errors });
    }

    const check = await service.checkUpdate(parseResult.data);
    return reply.status(200).send({ success: true, data: check });
  });

  // 2. Register / Publish Signed Release Manifest
  app.post('/releases', async (req, reply) => {
    try {
      const release = await service.registerRelease(req.body as any);
      return reply.status(201).send({ success: true, data: release });
    } catch (err: any) {
      return reply.status(400).send({ success: false, error: err.message });
    }
  });

  // 3. Create OTA Execution Job (Initial state: REQUESTED)
  app.post('/jobs', async (req, reply) => {
    const parseResult = CreateOtaJobRequestSchema.safeParse(req.body);
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.errors });
    }

    const { deviceId, releaseId, rolloutId, fromVersion } = parseResult.data;

    try {
      const job = await service.createOtaJob({ deviceId, releaseId, rolloutId, fromVersion });
      return reply.status(201).send({ success: true, data: job });
    } catch (err: any) {
      return reply.status(400).send({ success: false, error: err.message });
    }
  });

  // 4. Authorize OTA Job (Security Gate: REQUESTED -> AUTHORIZED)
  app.post('/jobs/:jobId/authorize', async (req, reply) => {
    const { jobId } = req.params as { jobId: string };
    const parseResult = AuthorizeOtaJobRequestSchema.safeParse(req.body || {});
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.errors });
    }

    try {
      const authResult = await service.authorizeOtaJob(jobId, parseResult.data);
      if (!authResult.authorized) {
        return reply.status(422).send({ success: false, error: authResult.errorMessage, data: authResult });
      }
      return reply.status(200).send({ success: true, data: authResult });
    } catch (err: any) {
      return reply.status(400).send({ success: false, error: err.message });
    }
  });

  // 5. Update OTA Job Status / Lifecycle Progress
  app.patch('/jobs/:jobId/status', async (req, reply) => {
    const { jobId } = req.params as { jobId: string };
    const parseResult = UpdateOtaJobStatusSchema.safeParse({ ...(req.body as any), jobId });
    if (!parseResult.success) {
      return reply.status(400).send({ success: false, error: parseResult.error.errors });
    }

    const { status, progressPercent, errorCode, errorMessage } = parseResult.data;
    try {
      const updated = await service.updateJobProgress(jobId, status, progressPercent, errorCode, errorMessage);
      if (!updated) {
        return reply.status(404).send({ success: false, error: `Job ${jobId} not found` });
      }
      return reply.status(200).send({ success: true, data: updated });
    } catch (err: any) {
      return reply.status(422).send({ success: false, error: err.message });
    }
  });

  // 6. Cancel OTA Job (REQUESTED / AUTHORIZED / AVAILABLE -> CANCELLED)
  app.post('/jobs/:jobId/cancel', async (req, reply) => {
    const { jobId } = req.params as { jobId: string };
    const reason = (req.body as any)?.reason || 'Cancelled by operator';
    try {
      const cancelled = await service.cancelOtaJob(jobId, reason);
      return reply.status(200).send({ success: true, data: cancelled });
    } catch (err: any) {
      return reply.status(422).send({ success: false, error: err.message });
    }
  });

  // 7. Query Latest OTA Status for Device
  app.get('/devices/:deviceId/status', async (req, reply) => {
    const { deviceId } = req.params as { deviceId: string };
    const job = await service.getLatestJob(deviceId);
    return reply.status(200).send({ success: true, data: job || null });
  });

  // 8. Query Specific Job by ID
  app.get('/jobs/:jobId', async (req, reply) => {
    const { jobId } = req.params as { jobId: string };
    const job = await service.getJobById(jobId);
    if (!job) {
      return reply.status(404).send({ success: false, error: `Job ${jobId} not found` });
    }
    return reply.status(200).send({ success: true, data: job });
  });
};
