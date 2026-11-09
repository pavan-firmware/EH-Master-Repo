"use strict";
/**
 * EH Home API Application Builder
 * Constructs Fastify instance, registers plugins, error handlers, and routes.
 * Decoupled from network listening for test isolation.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildApp = buildApp;
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const config_1 = require("./config");
const correlation_1 = require("./plugins/correlation");
const error_handler_1 = require("./plugins/error-handler");
const database_1 = require("./plugins/database");
const routes_1 = require("./routes");
const audit_service_1 = require("./modules/audit/audit.service");
const audit_repository_1 = require("./modules/audit/audit.repository");
const security_service_1 = require("./modules/security/security.service");
const security_repository_1 = require("./modules/security/security.repository");
const storage_service_1 = require("./modules/storage/storage.service");
const memory_storage_provider_1 = require("./modules/storage/providers/memory-storage.provider");
const disk_storage_provider_1 = require("./modules/storage/providers/disk-storage.provider");
const s3_storage_provider_1 = require("./modules/storage/providers/s3-storage.provider");
const backup_service_1 = require("./modules/backup/backup.service");
const restore_service_1 = require("./modules/backup/restore.service");
async function buildApp(opts = {}) {
    const config = opts.config || (0, config_1.loadConfig)();
    const app = (0, fastify_1.default)({
        logger: config.NODE_ENV === 'test' ? false : { level: config.LOG_LEVEL },
        bodyLimit: config.BODY_LIMIT_BYTES,
        connectionTimeout: config.REQUEST_TIMEOUT_MS,
        ...opts.fastifyOptions,
    });
    // Services Initialization & Decoration
    const auditService = opts.auditService || new audit_service_1.AuditService(new audit_repository_1.AuditRepository());
    const securityService = opts.securityService || new security_service_1.SecurityService(new security_repository_1.SecurityRepository(), auditService);
    let storageProvider;
    if (opts.storageProvider) {
        storageProvider = opts.storageProvider;
    }
    else if (config.STORAGE_PROVIDER === 'disk') {
        storageProvider = new disk_storage_provider_1.DiskStorageProvider(config.STORAGE_ROOT);
    }
    else if (config.STORAGE_PROVIDER === 's3' || config.STORAGE_PROVIDER === 'minio') {
        storageProvider = new s3_storage_provider_1.S3StorageProvider({
            endpoint: config.S3_ENDPOINT,
            region: config.S3_REGION,
            accessKeyId: config.S3_ACCESS_KEY_ID,
            secretAccessKey: config.S3_SECRET_ACCESS_KEY,
            forcePathStyle: config.S3_FORCE_PATH_STYLE,
        });
    }
    else {
        storageProvider = new memory_storage_provider_1.MemoryStorageProvider();
    }
    const storageService = opts.storageService || new storage_service_1.StorageService(storageProvider, auditService);
    const backupService = opts.backupService || new backup_service_1.BackupService(storageService, undefined, auditService);
    backupService.setRetentionPolicy({
        maxBackupsCount: config.BACKUP_RETENTION_MAX_COUNT,
        retentionDays: config.BACKUP_RETENTION_DAYS,
    });
    const restoreService = opts.restoreService || new restore_service_1.RestoreService(storageService, undefined, auditService);
    app.__defaultAuditService = auditService;
    app.__defaultSecurityService = securityService;
    app.storageProvider = storageProvider;
    app.storageService = storageService;
    app.backupService = backupService;
    app.restoreService = restoreService;
    // 1. CORS
    await app.register(cors_1.default, {
        origin: config.CORS_ORIGIN,
        methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'x-request-id', 'x-correlation-id'],
    });
    // 2. Request Correlation & ID
    await app.register(correlation_1.correlation);
    // 3. Centralized Error Handling
    await app.register(error_handler_1.errorHandler);
    // 4. Database Integration
    if (!opts.skipDatabase) {
        await app.register(database_1.database, opts.databaseOptions || {});
    }
    // 5. Routes
    await app.register(routes_1.registerRoutes);
    return app;
}
//# sourceMappingURL=app.js.map