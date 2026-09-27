import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { StorageService } from './storage.service';
import { SecurityService } from '../security/security.service';
import { StorageBucket, StorageBucketSchema } from '@eh-home/contracts';

export const storageRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const getStorageService = (): StorageService => {
    return (app as any).storageService;
  };

  const getSecurityService = (): SecurityService => {
    return (app as any).securityService || (app as any).__defaultSecurityService;
  };


  // 1. Storage Health & Readiness
  app.get('/health', async (_req, reply) => {
    const service = getStorageService();
    if (!service) {
      return reply.status(503).send({ status: 'DOWN', reason: 'StorageService not initialized' });
    }
    const health = await service.isHealthy();
    return reply.status(health.healthy ? 200 : 503).send(health);
  });

  // 2. Upload Object (POST /upload)
  app.post(
    '/upload',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('storage:write')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const body = req.body as any;

      if (!body || !body.bucket || !body.key || body.content === undefined) {
        return reply.status(400).send({
          error: 'BAD_REQUEST',
          message: 'Missing required fields: bucket, key, content'
        });
      }

      const parseBucket = StorageBucketSchema.safeParse(body.bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({
          error: 'INVALID_BUCKET',
          message: `Invalid bucket: ${body.bucket}`
        });
      }

      const secContext = (req as any).securityContext;
      const content = Buffer.isBuffer(body.content)
        ? body.content
        : typeof body.content === 'string'
        ? Buffer.from(body.content, body.encoding === 'base64' ? 'base64' : 'utf8')
        : Buffer.from(body.content);

      const metadata = await service.putObject(
        body.bucket as StorageBucket,
        body.key,
        content,
        {
          contentType: body.contentType,
          classification: body.classification,
          customMetadata: body.customMetadata
        },
        secContext
      );

      return reply.status(201).send({ success: true, metadata });
    }
  );

  // 3. Download/Retrieve Object (GET /object/:bucket/*)
  app.get(
    '/object/:bucket/*',
    {
      preHandler: async (req, reply) => {
        const { bucket } = req.params as { bucket: string };
        // Public assets bucket is open, protected buckets require authentication & storage:read
        if (bucket !== 'eh-product-assets') {
          const secService = getSecurityService();
          if (secService) {
            await secService.authHook()(req, reply);
            await secService.requirePermissionHook('storage:read')(req, reply);
          }
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const { bucket } = req.params as { bucket: string };
      const rawKey = (req.params as any)['*'];

      if (!rawKey) {
        return reply.status(400).send({ error: 'BAD_REQUEST', message: 'Missing object key' });
      }

      const parseBucket = StorageBucketSchema.safeParse(bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({ error: 'INVALID_BUCKET', message: `Invalid bucket: ${bucket}` });
      }

      try {
        const { content, metadata } = await service.getObject(bucket as StorageBucket, rawKey);
        reply.header('Content-Type', metadata.contentType);
        reply.header('ETag', metadata.etag);
        reply.header('x-amz-meta-sha256', metadata.sha256);
        return reply.status(200).send(content);
      } catch (err: any) {
        if (err.statusCode === 404) {
          return reply.status(404).send({ error: 'NOT_FOUND', message: err.message });
        }
        throw err;
      }
    }
  );

  // 4. Object Metadata (HEAD or GET /metadata/:bucket/*)
  app.get(
    '/metadata/:bucket/*',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('storage:read')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const { bucket } = req.params as { bucket: string };
      const rawKey = (req.params as any)['*'];

      const parseBucket = StorageBucketSchema.safeParse(bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({ error: 'INVALID_BUCKET', message: `Invalid bucket: ${bucket}` });
      }

      try {
        const metadata = await service.headObject(bucket as StorageBucket, rawKey);
        return reply.status(200).send(metadata);
      } catch (err: any) {
        if (err.statusCode === 404) {
          return reply.status(404).send({ error: 'NOT_FOUND', message: err.message });
        }
        throw err;
      }
    }
  );

  // 5. Presigned URL (POST /signed-url)
  app.post(
    '/signed-url',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          const body = req.body as any;
          const requiredPerm = body?.action === 'PUT' ? 'storage:write' : 'storage:read';
          await secService.requirePermissionHook(requiredPerm)(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const body = req.body as any;

      if (!body || !body.bucket || !body.key) {
        return reply.status(400).send({
          error: 'BAD_REQUEST',
          message: 'Missing required fields: bucket, key'
        });
      }

      const parseBucket = StorageBucketSchema.safeParse(body.bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({ error: 'INVALID_BUCKET', message: `Invalid bucket: ${body.bucket}` });
      }

      const result = await service.getSignedUrl(
        body.bucket as StorageBucket,
        body.key,
        body.expiresInSeconds || 900,
        body.action || 'GET'
      );

      return reply.status(200).send(result);
    }
  );

  // 6. List Objects (GET /list/:bucket)
  app.get(
    '/list/:bucket',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('storage:read')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const { bucket } = req.params as { bucket: string };
      const query = req.query as { prefix?: string; limit?: string; continuationToken?: string };

      const parseBucket = StorageBucketSchema.safeParse(bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({ error: 'INVALID_BUCKET', message: `Invalid bucket: ${bucket}` });
      }

      const limit = query.limit ? parseInt(query.limit, 10) : 100;
      const listRes = await service.listObjects(
        bucket as StorageBucket,
        query.prefix,
        limit,
        query.continuationToken
      );

      return reply.status(200).send(listRes);
    }
  );

  // 7. Delete Object (DELETE /object/:bucket/*)
  app.delete(
    '/object/:bucket/*',
    {
      preHandler: async (req, reply) => {
        const secService = getSecurityService();
        if (secService) {
          await secService.authHook()(req, reply);
          await secService.requirePermissionHook('storage:delete')(req, reply);
        }
      }
    },
    async (req, reply) => {
      const service = getStorageService();
      const { bucket } = req.params as { bucket: string };
      const rawKey = (req.params as any)['*'];

      const parseBucket = StorageBucketSchema.safeParse(bucket);
      if (!parseBucket.success) {
        return reply.status(400).send({ error: 'INVALID_BUCKET', message: `Invalid bucket: ${bucket}` });
      }

      const secContext = (req as any).securityContext;
      const deleted = await service.deleteObject(bucket as StorageBucket, rawKey, secContext);
      return reply.status(200).send({ success: deleted });
    }
  );
};
