/**
 * EH Home API Application Builder
 * Constructs Fastify instance, registers plugins, error handlers, and routes.
 * Decoupled from network listening for test isolation.
 */
import { FastifyInstance, FastifyServerOptions } from 'fastify';
import { AppConfig } from './config';
import { DatabasePluginOptions } from './plugins/database';
import { AuditService } from './modules/audit/audit.service';
import { SecurityService } from './modules/security/security.service';
import { IStorageProvider } from './modules/storage/storage.interface';
import { StorageService } from './modules/storage/storage.service';
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
export declare function buildApp(opts?: BuildAppOptions): Promise<FastifyInstance>;
//# sourceMappingURL=app.d.ts.map