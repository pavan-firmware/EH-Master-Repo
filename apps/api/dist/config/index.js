"use strict";
/**
 * EH Home API Configuration
 * Validates environment variables at boot using Zod.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.EnvSchema = void 0;
exports.loadConfig = loadConfig;
const zod_1 = require("zod");
exports.EnvSchema = zod_1.z.object({
    NODE_ENV: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    HOST: zod_1.z.string().default('0.0.0.0'),
    PORT: zod_1.z.coerce.number().int().min(1024).max(65535).default(3100),
    LOG_LEVEL: zod_1.z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
    DATABASE_URL: zod_1.z.string().url().optional(),
    DB_HOST: zod_1.z.string().default('localhost'),
    DB_PORT: zod_1.z.coerce.number().int().default(5432),
    DB_NAME: zod_1.z.string().default('eh_home'),
    DB_USER: zod_1.z.string().default('eh_user'),
    DB_PASSWORD: zod_1.z.string().optional(),
    DB_SSL: zod_1.z.coerce.boolean().default(false),
    CORS_ORIGIN: zod_1.z.string().default('*'),
    REQUEST_TIMEOUT_MS: zod_1.z.coerce.number().int().default(15000),
    BODY_LIMIT_BYTES: zod_1.z.coerce.number().int().default(10485760), // 10MB default for firmware binaries & backups
    // Storage & MinIO S3-compatible configuration (Part 16)
    STORAGE_PROVIDER: zod_1.z.enum(['memory', 's3', 'minio']).default('memory'),
    S3_ENDPOINT: zod_1.z.string().default('http://127.0.0.1:9000'),
    S3_REGION: zod_1.z.string().default('us-east-1'),
    S3_ACCESS_KEY_ID: zod_1.z.string().default('minioadmin'),
    S3_SECRET_ACCESS_KEY: zod_1.z.string().default('minioadmin'),
    S3_FORCE_PATH_STYLE: zod_1.z.coerce.boolean().default(true),
    // Backup & Recovery configuration (Part 16)
    BACKUP_RETENTION_MAX_COUNT: zod_1.z.coerce.number().int().default(30),
    BACKUP_RETENTION_DAYS: zod_1.z.coerce.number().int().default(30),
});
function loadConfig(envOverrides) {
    const source = {
        ...process.env,
        ...envOverrides,
    };
    const parsed = exports.EnvSchema.safeParse(source);
    if (!parsed.success) {
        const errorDetails = parsed.error.issues
            .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
            .join('\n');
        throw new Error(`[Configuration Error] Invalid environment configuration:\n${errorDetails}`);
    }
    return parsed.data;
}
//# sourceMappingURL=index.js.map