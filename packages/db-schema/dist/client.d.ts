/**
 * EH Home Database Client & Pool Configuration
 * Environment-based connection manager for apps/api and background workers.
 */
import { Pool } from 'pg';
import { NodePgDatabase } from 'drizzle-orm/node-postgres';
import * as schema from './schema';
import * as relations from './relations';
export interface DatabaseConfig {
    connectionString?: string;
    host?: string;
    port?: number;
    database?: string;
    user?: string;
    password?: string;
    ssl?: boolean | {
        rejectUnauthorized?: boolean;
    };
    maxConnections?: number;
    idleTimeoutMillis?: number;
    connectionTimeoutMillis?: number;
}
export declare function getDatabaseConfig(): DatabaseConfig;
export declare function createDatabasePool(customConfig?: DatabaseConfig): Pool;
export type EhDatabase = NodePgDatabase<typeof schema & typeof relations>;
export declare function createDrizzleClient(pool?: Pool): {
    db: EhDatabase;
    pool: Pool;
};
//# sourceMappingURL=client.d.ts.map