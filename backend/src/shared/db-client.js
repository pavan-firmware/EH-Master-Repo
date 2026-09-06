'use strict';

/**
 * EH Home — Unified Database Client & Factory (Phase 37)
 *
 * Implements deterministic persistence adapter selection:
 * - TEST: InMemoryDatabaseAdapter (default, deterministic and isolated)
 * - INTEGRATION: PostgreSQLDatabaseAdapter (when DB_ADAPTER=postgres or mode=postgres explicitly declared)
 * - PRODUCTION: PostgreSQLDatabaseAdapter (enforced in production with connection validation)
 */

const { DatabaseAdapter } = require('./database-adapter');
const { InMemoryDatabaseAdapter } = require('./in-memory-db-adapter');
const { PostgreSQLDatabaseAdapter } = require('./postgres-db-adapter');

class DatabaseClient {
  /**
   * @param {DatabaseAdapter|string|object} [adapterOrOptions] - Optional underlying database adapter, mode, or connection string
   */
  constructor(adapterOrOptions = null) {
    if (adapterOrOptions && typeof adapterOrOptions.insert === 'function') {
      this.adapter = adapterOrOptions;
    } else if (typeof adapterOrOptions === 'string') {
      if (adapterOrOptions === ':memory:' || adapterOrOptions === 'memory' || adapterOrOptions === 'test') {
        this.adapter = new InMemoryDatabaseAdapter();
      } else if (adapterOrOptions.startsWith('postgres://') || adapterOrOptions.startsWith('postgresql://')) {
        this.adapter = new PostgreSQLDatabaseAdapter({ connectionString: adapterOrOptions });
      } else {
        this.adapter = new InMemoryDatabaseAdapter();
      }
    } else if (adapterOrOptions && typeof adapterOrOptions === 'object') {
      if (adapterOrOptions.mode === 'postgres' || adapterOrOptions.dbAdapter === 'postgres') {
        this.adapter = new PostgreSQLDatabaseAdapter(adapterOrOptions);
      } else {
        this.adapter = new InMemoryDatabaseAdapter();
      }
    } else {
      this.adapter = new InMemoryDatabaseAdapter();
    }

    // Preserve legacy table Map access for in-memory testing if underlying adapter supports it
    if (this.adapter.tables) {
      this.tables = this.adapter.tables;
    }
  }

  async connect() {
    return this.adapter.connect();
  }

  async close() {
    return this.adapter.close();
  }

  getTable(name) {
    if (typeof this.adapter.getTable === 'function') {
      return this.adapter.getTable(name);
    }
    throw new Error('Direct table map access is only supported on in-memory adapter');
  }

  async query(sql, params = []) {
    return this.adapter.query(sql, params);
  }

  async insert(table, id, data) {
    return this.adapter.insert(table, id, data);
  }

  async findById(table, id) {
    return this.adapter.findById(table, id);
  }

  async find(table, filter = null, options = {}) {
    return this.adapter.find(table, filter, options);
  }

  async update(table, id, updates) {
    return this.adapter.update(table, id, updates);
  }

  async delete(table, id) {
    return this.adapter.delete(table, id);
  }

  async withTransaction(callback) {
    return this.adapter.withTransaction(callback);
  }

  async checkHealth() {
    return this.adapter.checkHealth();
  }
}

/**
 * Factory for creating database client with deterministic adapter selection
 *
 * @param {Object} [opts={}]
 * @param {'inmemory'|'postgres'} [opts.mode] - Explicit mode override
 * @param {string} [opts.connectionString]
 * @param {Object} [opts.config] - Runtime config dictionary
 * @returns {DatabaseClient}
 */
function createDatabaseClient(opts = {}) {
  if (opts.adapter) {
    return new DatabaseClient(opts.adapter);
  }

  const envAdapter = (process.env.DB_ADAPTER || '').trim().toLowerCase();
  const nodeEnv = (process.env.NODE_ENV || 'development').trim().toLowerCase();

  // Explicit mode precedence:
  // 1. Explicit opts.mode
  // 2. Explicit process.env.DB_ADAPTER
  // 3. Production environment -> postgres
  // 4. Default -> inmemory (guarantees unit tests never silently switch to postgres)
  let selectedMode = 'inmemory';

  if (opts.mode === 'postgres' || opts.mode === 'inmemory') {
    selectedMode = opts.mode;
  } else if (envAdapter === 'postgres' || envAdapter === 'inmemory') {
    selectedMode = envAdapter;
  } else if (nodeEnv === 'production') {
    selectedMode = 'postgres';
  }

  if (selectedMode === 'postgres') {
    const connectionString = opts.connectionString ||
      (opts.config && opts.config.databaseUrl) ||
      process.env.DATABASE_URL;

    const pgAdapter = new PostgreSQLDatabaseAdapter({
      connectionString,
      max: opts.max || (opts.config && opts.config.dbPoolMax) || 20,
      idleTimeoutMillis: opts.idleTimeoutMillis || 30000,
      connectionTimeoutMillis: opts.connectionTimeoutMillis || 5000,
      statementTimeoutMillis: opts.statementTimeoutMillis || 10000,
      ...opts
    });

    return new DatabaseClient(pgAdapter);
  }

  return new DatabaseClient(new InMemoryDatabaseAdapter());
}

module.exports = {
  DatabaseClient,
  createDatabaseClient,
  DatabaseAdapter,
  InMemoryDatabaseAdapter,
  PostgreSQLDatabaseAdapter
};
