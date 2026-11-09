/**
 * EH Home API Application Builder
 * Constructs Fastify instance, registers plugins, error handlers, and routes.
 * Decoupled from network listening for test isolation.
 */

import Fastify, { FastifyInstance, FastifyServerOptions } from 'fastify';
import cors from '@fastify/cors';
import { AppConfig, loadConfig } from './config';
import { correlation } from './plugins/correlation';
import { errorHandler } from './plugins/error-handler';
import { database, DatabasePluginOptions } from './plugins/database';
import { registerRoutes } from './routes';
import { AuditService } from './modules/audit/audit.service';
import { AuditRepository } from './modules/audit/audit.repository';
import { SecurityService } from './modules/security/security.service';
import { SecurityRepository } from './modules/security/security.repository';
import { IStorageProvider } from './modules/storage/storage.interface';
import { StorageService } from './modules/storage/storage.service';
import { MemoryStorageProvider } from './modules/storage/providers/memory-storage.provider';
import { DiskStorageProvider } from './modules/storage/providers/disk-storage.provider';
import { S3StorageProvider } from './modules/storage/providers/s3-storage.provider';
import { BackupService } from './modules/backup/backup.service';
import { RestoreService } from './modules/backup/restore.service';

export interface BuildAppOptions {
  config?: AppConfig;
  fastifyOptions?: FastifyServerOptions;
  databaseOptions?: DatabasePluginOptions;
  skipDatabase?: boolean;
  storageProvider?: IStorageProvider;
  storageService?: StorageService;
  securityService?: SecurityService;
  auditService?: AuditService;
  backupService?: BackupService;
  restoreService?: RestoreService;
}

export async function buildApp(opts: BuildAppOptions = {}): Promise<FastifyInstance> {
  const config = opts.config || loadConfig();

  const app = Fastify({
    logger: config.NODE_ENV === 'test' ? false : { level: config.LOG_LEVEL },
    bodyLimit: config.BODY_LIMIT_BYTES,
    connectionTimeout: config.REQUEST_TIMEOUT_MS,
    ...opts.fastifyOptions,
  });

  // Services Initialization & Decoration
  const auditService = opts.auditService || new AuditService(new AuditRepository());
  const securityService = opts.securityService || new SecurityService(new SecurityRepository(), auditService);

  let storageProvider: IStorageProvider;
  if (opts.storageProvider) {
    storageProvider = opts.storageProvider;
  } else if (config.STORAGE_PROVIDER === 'disk') {
    storageProvider = new DiskStorageProvider(config.STORAGE_ROOT);
  } else if (config.STORAGE_PROVIDER === 's3' || config.STORAGE_PROVIDER === 'minio') {
    storageProvider = new S3StorageProvider({
      endpoint: config.S3_ENDPOINT,
      region: config.S3_REGION,
      accessKeyId: config.S3_ACCESS_KEY_ID,
      secretAccessKey: config.S3_SECRET_ACCESS_KEY,
      forcePathStyle: config.S3_FORCE_PATH_STYLE,
    });
  } else {
    storageProvider = new MemoryStorageProvider();
  }

  const storageService = opts.storageService || new StorageService(storageProvider, auditService);
  const backupService = opts.backupService || new BackupService(storageService, undefined, auditService);
  backupService.setRetentionPolicy({
    maxBackupsCount: config.BACKUP_RETENTION_MAX_COUNT,
    retentionDays: config.BACKUP_RETENTION_DAYS,
  });
  const restoreService = opts.restoreService || new RestoreService(storageService, undefined, auditService);

  (app as any).__defaultAuditService = auditService;
  (app as any).__defaultSecurityService = securityService;
  (app as any).storageProvider = storageProvider;
  (app as any).storageService = storageService;
  (app as any).backupService = backupService;
  (app as any).restoreService = restoreService;



  // 1. CORS
  await app.register(cors, {
    origin: config.CORS_ORIGIN,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-request-id', 'x-correlation-id'],
  });

  // 2. Request Correlation & ID
  await app.register(correlation);

  // 3. Centralized Error Handling
  await app.register(errorHandler);

  // 4. Database Integration
  if (!opts.skipDatabase) {
    await app.register(database, opts.databaseOptions || {});
  }

  // 5. Routes
  await app.register(registerRoutes);

  return app;
}

