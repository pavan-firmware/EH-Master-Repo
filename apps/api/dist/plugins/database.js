"use strict";
/**
 * EH Home Database Plugin
 * Integrates @eh-home/db-schema Drizzle client and PostgreSQL connection pool.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.database = void 0;
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const db_schema_1 = require("@eh-home/db-schema");
const databasePlugin = async (app, opts) => {
    const pool = opts.pool || (0, db_schema_1.createDatabasePool)();
    const { db } = (0, db_schema_1.createDrizzleClient)(pool);
    const pingDb = async () => {
        try {
            const client = await pool.connect();
            try {
                await client.query('SELECT 1');
                return true;
            }
            finally {
                client.release();
            }
        }
        catch (err) {
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
exports.database = (0, fastify_plugin_1.default)(databasePlugin, {
    name: 'database',
    fastify: '5.x',
});
//# sourceMappingURL=database.js.map