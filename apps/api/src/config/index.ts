/**
 * EH Home API Configuration
 * Validates environment variables at boot using Zod.
 */

import { z } from 'zod';

export const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().default('0.0.0.0'),
  PORT: z.coerce.number().int().min(1024).max(65535).default(3100),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.string().url().optional(),
  DB_HOST: z.string().default('localhost'),
  DB_PORT: z.coerce.number().int().default(5432),
  DB_NAME: z.string().default('eh_home'),
  DB_USER: z.string().default('eh_user'),
  DB_PASSWORD: z.string().optional(),
  DB_SSL: z.coerce.boolean().default(false),
  CORS_ORIGIN: z.string().default('*'),
  REQUEST_TIMEOUT_MS: z.coerce.number().int().default(15000),
  BODY_LIMIT_BYTES: z.coerce.number().int().default(10485760), // 10MB default for firmware binaries & backups

  // Storage & MinIO S3-compatible configuration (Part 16)
  STORAGE_PROVIDER: z.enum(['memory', 's3', 'minio']).default('memory'),
  S3_ENDPOINT: z.string().default('http://127.0.0.1:9000'),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY_ID: z.string().default('minioadmin'),
  S3_SECRET_ACCESS_KEY: z.string().default('minioadmin'),
  S3_FORCE_PATH_STYLE: z.coerce.boolean().default(true),

  // Backup & Recovery configuration (Part 16)
  BACKUP_RETENTION_MAX_COUNT: z.coerce.number().int().default(30),
  BACKUP_RETENTION_DAYS: z.coerce.number().int().default(30),
});


export type AppConfig = z.infer<typeof EnvSchema>;

export function loadConfig(envOverrides?: Record<string, string | undefined>): AppConfig {
  const source = {
    ...process.env,
    ...envOverrides,
  };

  const parsed = EnvSchema.safeParse(source);

  if (!parsed.success) {
    const errorDetails = parsed.error.issues
      .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
      .join('\n');
    throw new Error(`[Configuration Error] Invalid environment configuration:\n${errorDetails}`);
  }

  return parsed.data;
}
