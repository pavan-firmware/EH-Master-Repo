/**
 * EH Home Database Plugin
 * Integrates @eh-home/db-schema Drizzle client and PostgreSQL connection pool.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import fp from 'fastify-plugin';
import { Pool } from 'pg';
import { createDatabasePool, createDrizzleClient, EhDatabase } from '@eh-home/db-schema';

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

const databasePlugin: FastifyPluginAsync<DatabasePluginOptions> = async (app: FastifyInstance, opts: DatabasePluginOptions) => {
  const pool = opts.pool || createDatabasePool();
  const { db } = createDrizzleClient(pool);

  const pingDb = async (): Promise<boolean> => {
    try {
      const client = await pool.connect();
      try {
        await client.query('SELECT 1');
        return true;
      } finally {
        client.release();
      }
    } catch (err) {
      app.log.warn({ err }, 'Database ping check failed');
      return false;
    }
  };

  app.decorate('db', db);
  app.decorate('dbPool', pool);
  app.decorate('pingDb', pingDb);

  app.addHook('onClose', async () => {
    app.log.info('Closing database connection pool...');
    await pool.end();
  });
};

export const database = fp(databasePlugin, {
  name: 'database',
  fastify: '5.x',
});
