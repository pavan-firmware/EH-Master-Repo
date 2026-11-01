/**
 * EH Home Database Plugin
 * Integrates @eh-home/db-schema Drizzle client and PostgreSQL connection pool.
 */
import { FastifyPluginAsync } from 'fastify';
import { Pool } from 'pg';
import { EhDatabase } from '@eh-home/db-schema';
export interface DatabasePluginOptions {
    pool?: Pool;
    skipConnectionTest?: boolean;
}
declare module 'fastify' {
    interface FastifyInstance {
        db: EhDatabase;
        dbPool: Pool;
        pingDb: () => Promise<boolean>;
    }
}
export declare const database: FastifyPluginAsync<DatabasePluginOptions>;
//# sourceMappingURL=database.d.ts.map