/**
 * EH Home API Configuration
 * Validates environment variables at boot using Zod.
 */
import { z } from 'zod';
export declare const EnvSchema: z.ZodObject<{
    NODE_ENV: z.ZodDefault<z.ZodEnum<["development", "test", "production"]>>;
    HOST: z.ZodDefault<z.ZodString>;
    PORT: z.ZodDefault<z.ZodNumber>;
    LOG_LEVEL: z.ZodDefault<z.ZodEnum<["fatal", "error", "warn", "info", "debug", "trace", "silent"]>>;
    DATABASE_URL: z.ZodOptional<z.ZodString>;
    DB_HOST: z.ZodDefault<z.ZodString>;
    DB_PORT: z.ZodDefault<z.ZodNumber>;
    DB_NAME: z.ZodDefault<z.ZodString>;
    DB_USER: z.ZodDefault<z.ZodString>;
    DB_PASSWORD: z.ZodOptional<z.ZodString>;
    DB_SSL: z.ZodDefault<z.ZodBoolean>;
    CORS_ORIGIN: z.ZodDefault<z.ZodString>;
    REQUEST_TIMEOUT_MS: z.ZodDefault<z.ZodNumber>;
    BODY_LIMIT_BYTES: z.ZodDefault<z.ZodNumber>;
    STORAGE_PROVIDER: z.ZodDefault<z.ZodEnum<["memory", "s3", "minio"]>>;
    S3_ENDPOINT: z.ZodDefault<z.ZodString>;
    S3_REGION: z.ZodDefault<z.ZodString>;
    S3_ACCESS_KEY_ID: z.ZodDefault<z.ZodString>;
    S3_SECRET_ACCESS_KEY: z.ZodDefault<z.ZodString>;
    S3_FORCE_PATH_STYLE: z.ZodDefault<z.ZodBoolean>;
    BACKUP_RETENTION_MAX_COUNT: z.ZodDefault<z.ZodNumber>;
    BACKUP_RETENTION_DAYS: z.ZodDefault<z.ZodNumber>;
}, "strip", z.ZodTypeAny, {
    NODE_ENV: "development" | "test" | "production";
    HOST: string;
    PORT: number;
    LOG_LEVEL: "fatal" | "error" | "warn" | "info" | "debug" | "trace" | "silent";
    DB_HOST: string;
    DB_PORT: number;
    DB_NAME: string;
    DB_USER: string;
    DB_SSL: boolean;
    CORS_ORIGIN: string;
    REQUEST_TIMEOUT_MS: number;
    BODY_LIMIT_BYTES: number;
    STORAGE_PROVIDER: "memory" | "s3" | "minio";
    S3_ENDPOINT: string;
    S3_REGION: string;
    S3_ACCESS_KEY_ID: string;
    S3_SECRET_ACCESS_KEY: string;
    S3_FORCE_PATH_STYLE: boolean;
    BACKUP_RETENTION_MAX_COUNT: number;
    BACKUP_RETENTION_DAYS: number;
    DATABASE_URL?: string | undefined;
    DB_PASSWORD?: string | undefined;
}, {
    NODE_ENV?: "development" | "test" | "production" | undefined;
    HOST?: string | undefined;
    PORT?: number | undefined;
    LOG_LEVEL?: "fatal" | "error" | "warn" | "info" | "debug" | "trace" | "silent" | undefined;
    DATABASE_URL?: string | undefined;
    DB_HOST?: string | undefined;
    DB_PORT?: number | undefined;
    DB_NAME?: string | undefined;
    DB_USER?: string | undefined;
    DB_PASSWORD?: string | undefined;
    DB_SSL?: boolean | undefined;
    CORS_ORIGIN?: string | undefined;
    REQUEST_TIMEOUT_MS?: number | undefined;
    BODY_LIMIT_BYTES?: number | undefined;
    STORAGE_PROVIDER?: "memory" | "s3" | "minio" | undefined;
    S3_ENDPOINT?: string | undefined;
    S3_REGION?: string | undefined;
    S3_ACCESS_KEY_ID?: string | undefined;
    S3_SECRET_ACCESS_KEY?: string | undefined;
    S3_FORCE_PATH_STYLE?: boolean | undefined;
    BACKUP_RETENTION_MAX_COUNT?: number | undefined;
    BACKUP_RETENTION_DAYS?: number | undefined;
}>;
export type AppConfig = z.infer<typeof EnvSchema>;
export declare function loadConfig(envOverrides?: Record<string, string | undefined>): AppConfig;
//# sourceMappingURL=index.d.ts.map