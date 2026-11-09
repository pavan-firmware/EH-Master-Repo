"use strict";
/**
 * EH Home Database Client & Pool Configuration
 * Environment-based connection manager for apps/api and background workers.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDatabaseConfig = getDatabaseConfig;
exports.createDatabasePool = createDatabasePool;
exports.createDrizzleClient = createDrizzleClient;
const pg_1 = require("pg");
const node_postgres_1 = require("drizzle-orm/node-postgres");
const schema = __importStar(require("./schema"));
const relations = __importStar(require("./relations"));
function getDatabaseConfig() {
    const connectionString = process.env.DATABASE_URL;
    if (connectionString) {
        return {
            connectionString,
            ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
            maxConnections: parseInt(process.env.DATABASE_POOL_MAX || '20', 10),
            idleTimeoutMillis: parseInt(process.env.DATABASE_IDLE_TIMEOUT_MS || '30000', 10),
            connectionTimeoutMillis: parseInt(process.env.DATABASE_CONNECT_TIMEOUT_MS || '5000', 10),
        };
    }
    return {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432', 10),
        database: process.env.DB_NAME || 'eh_home_dev',
        user: process.env.DB_USER || 'eh_admin',
        // Development defaults match docker-compose. Production must provide
        // DB_PASSWORD or DATABASE_URL explicitly; never silently invent a secret.
        password: process.env.DB_PASSWORD || (process.env.NODE_ENV === 'development' ? 'eh_development_password_only' : undefined),
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
        maxConnections: parseInt(process.env.DATABASE_POOL_MAX || '20', 10),
        idleTimeoutMillis: parseInt(process.env.DATABASE_IDLE_TIMEOUT_MS || '30000', 10),
        connectionTimeoutMillis: parseInt(process.env.DATABASE_CONNECT_TIMEOUT_MS || '5000', 10),
    };
}
function createDatabasePool(customConfig) {
    const config = customConfig || getDatabaseConfig();
    const poolConfig = {
        connectionString: config.connectionString,
        host: config.host,
        port: config.port,
        database: config.database,
        user: config.user,
        password: config.password,
        ssl: config.ssl,
        max: config.maxConnections,
        idleTimeoutMillis: config.idleTimeoutMillis,
        connectionTimeoutMillis: config.connectionTimeoutMillis,
    };
    return new pg_1.Pool(poolConfig);
}
function createDrizzleClient(pool) {
    const activePool = pool || createDatabasePool();
    const db = (0, node_postgres_1.drizzle)(activePool, {
        schema: { ...schema, ...relations },
    });
    return { db, pool: activePool };
}
//# sourceMappingURL=client.js.map