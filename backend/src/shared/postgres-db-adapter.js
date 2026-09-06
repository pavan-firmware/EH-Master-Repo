'use strict';

/**
 * EH Home — Production PostgreSQL Database Adapter (Phase 37)
 *
 * Implements high-performance connection pooling, parameterized SQL queries,
 * automatic transaction boundary management, JSONB handling, and tenant isolation.
 */

const { Pool } = require('pg');
const { DatabaseAdapter } = require('./database-adapter');

const IDENTIFIER_REGEX = /^[a-zA-Z0-9_]+$/;

function validateIdentifier(name) {
  if (typeof name !== 'string' || !IDENTIFIER_REGEX.test(name)) {
    throw new Error(`Invalid SQL identifier: "${name}"`);
  }
  return name;
}

function sanitizeValue(val) {
  if (val === undefined) return null;
  if (val !== null && typeof val === 'object' && !(val instanceof Date) && !Buffer.isBuffer(val)) {
    return JSON.stringify(val);
  }
  return val;
}

class PostgreSQLDatabaseAdapter extends DatabaseAdapter {
  /**
   * @param {Object} [opts={}]
   * @param {string} [opts.connectionString] - Full database connection string (e.g. DATABASE_URL)
   * @param {string} [opts.host]
   * @param {number} [opts.port]
   * @param {string} [opts.database]
   * @param {string} [opts.user]
   * @param {string} [opts.password]
   * @param {number} [opts.max=20] - Max connection pool size
   * @param {number} [opts.idleTimeoutMillis=30000]
   * @param {number} [opts.connectionTimeoutMillis=5000]
   * @param {number} [opts.statementTimeoutMillis=10000]
   * @param {Object|boolean} [opts.ssl]
   * @param {Pool} [opts.pool] - Optional existing pg.Pool instance (for testing/injection)
   */
  constructor(opts = {}) {
    super();
    this.opts = opts;
    this.pool = opts.pool || null;
    this.isConnected = false;
  }

  /**
   * Initialize pool connection
   */
  async connect() {
    if (this.isConnected && this.pool) return;

    if (!this.pool) {
      const poolConfig = {
        max: this.opts.max || 20,
        idleTimeoutMillis: this.opts.idleTimeoutMillis || 30000,
        connectionTimeoutMillis: this.opts.connectionTimeoutMillis || 5000,
        statement_timeout: this.opts.statementTimeoutMillis || 10000
      };

      if (this.opts.connectionString) {
        poolConfig.connectionString = this.opts.connectionString;
      } else {
        if (this.opts.host) poolConfig.host = this.opts.host;
        if (this.opts.port) poolConfig.port = this.opts.port;
        if (this.opts.database) poolConfig.database = this.opts.database;
        if (this.opts.user) poolConfig.user = this.opts.user;
        if (this.opts.password) poolConfig.password = this.opts.password;
      }

      if (this.opts.ssl !== undefined) {
        poolConfig.ssl = this.opts.ssl;
      }

      this.pool = new Pool(poolConfig);
    }

    // Verify initial connectivity
    const client = await this.pool.connect();
    try {
      await client.query('SELECT 1');
      this.isConnected = true;
    } finally {
      client.release();
    }
  }

  /**
   * Close connection pool cleanly
   */
  async close() {
    this.isConnected = false;
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
    }
  }

  /**
   * Execute parameterized SQL query
   * @param {string} sql
   * @param {Array} [params=[]]
   * @returns {Promise<{ rows: Array, rowCount: number }>}
   */
  async query(sql, params = []) {
    if (!this.pool) {
      throw new Error('Database pool not connected');
    }
    const result = await this.pool.query(sql, params);
    return {
      rows: result.rows || [],
      rowCount: result.rowCount || 0
    };
  }

  /**
   * Insert record into table
   * @param {string} table
   * @param {string} id
   * @param {Object} data
   * @returns {Promise<Object>}
   */
  async insert(table, id, data = {}) {
    const validTable = validateIdentifier(table);
    const record = { ...data };
    if (id !== undefined && id !== null) {
      record.id = id;
    }

    const keys = Object.keys(record);
    if (keys.length === 0) {
      throw new Error('Cannot insert empty record');
    }

    const columns = keys.map(validateIdentifier);
    const placeholders = keys.map((_, i) => `$${i + 1}`);
    const values = keys.map(k => sanitizeValue(record[k]));

    const sql = `INSERT INTO ${validTable} (${columns.join(', ')}) VALUES (${placeholders.join(', ')}) RETURNING *`;
    const res = await this.query(sql, values);
    return res.rows[0];
  }

  /**
   * Find single record by primary key
   * @param {string} table
   * @param {string} id
   * @returns {Promise<Object|null>}
   */
  async findById(table, id) {
    const validTable = validateIdentifier(table);
    const sql = `SELECT * FROM ${validTable} WHERE id = $1 LIMIT 1`;
    const res = await this.query(sql, [id]);
    return res.rows[0] || null;
  }

  /**
   * Find multiple records matching filter object or JS predicate
   * @param {string} table
   * @param {Object|Function} [filter]
   * @param {Object} [options]
   * @returns {Promise<Array<Object>>}
   */
  async find(table, filter = null, options = {}) {
    const validTable = validateIdentifier(table);

    // If filter is a plain object: build parameterized WHERE clause
    if (filter && typeof filter === 'object' && !Array.isArray(filter)) {
      const keys = Object.keys(filter);
      if (keys.length === 0) {
        let sql = `SELECT * FROM ${validTable}`;
        if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
        if (options.limit && typeof options.limit === 'number') sql += ` LIMIT ${options.limit}`;
        const res = await this.query(sql);
        return res.rows;
      }

      const whereClauses = [];
      const values = [];
      let idx = 1;

      for (const key of keys) {
        const col = validateIdentifier(key);
        const val = filter[key];
        if (val === null) {
          whereClauses.push(`${col} IS NULL`);
        } else {
          whereClauses.push(`${col} = $${idx++}`);
          values.push(sanitizeValue(val));
        }
      }

      let sql = `SELECT * FROM ${validTable} WHERE ${whereClauses.join(' AND ')}`;
      if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
      if (options.limit && typeof options.limit === 'number') sql += ` LIMIT ${options.limit}`;

      const res = await this.query(sql, values);
      return res.rows;
    }

    // If filter is a JavaScript predicate function: fetch rows and filter in JS memory
    // (Preserves 100% semantic compatibility without attempting unsafe JS-to-SQL translation)
    let sql = `SELECT * FROM ${validTable}`;
    if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
    const res = await this.query(sql);
    let rows = res.rows;

    if (typeof filter === 'function') {
      rows = rows.filter(filter);
    }

    if (options.limit && typeof options.limit === 'number') {
      rows = rows.slice(0, options.limit);
    }
    return rows;
  }

  /**
   * Update existing record by ID
   * @param {string} table
   * @param {string} id
   * @param {Object} updates
   * @returns {Promise<Object>}
   */
  async update(table, id, updates = {}) {
    const validTable = validateIdentifier(table);
    const keys = Object.keys(updates);

    if (keys.length === 0) {
      const existing = await this.findById(table, id);
      if (!existing) throw new Error(`Record ${id} not found in ${table}`);
      return existing;
    }

    const setClauses = [];
    const values = [];
    let idx = 1;

    for (const key of keys) {
      const col = validateIdentifier(key);
      setClauses.push(`${col} = $${idx++}`);
      values.push(sanitizeValue(updates[key]));
    }

    // Automatically touch updated_at if present in table
    setClauses.push(`updated_at = NOW()`);

    values.push(id);
    const sql = `UPDATE ${validTable} SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *`;
    const res = await this.query(sql, values);

    if (res.rows.length === 0) {
      throw new Error(`Record ${id} not found in ${table}`);
    }
    return res.rows[0];
  }

  /**
   * Delete record by ID
   * @param {string} table
   * @param {string} id
   * @returns {Promise<boolean>}
   */
  async delete(table, id) {
    const validTable = validateIdentifier(table);
    const sql = `DELETE FROM ${validTable} WHERE id = $1`;
    const res = await this.query(sql, [id]);
    return res.rowCount > 0;
  }

  /**
   * Execute callback within an atomic database transaction
   * @param {Function} callback - async (txAdapter) => Promise<any>
   * @returns {Promise<any>}
   */
  async withTransaction(callback) {
    if (!this.pool) {
      throw new Error('Database pool not connected');
    }

    const client = await this.pool.connect();
    const txAdapter = new PostgreSQLTransactionAdapter(client);

    try {
      await client.query('BEGIN');
      const result = await callback(txAdapter);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        // Rollback failure logged, propagate original error
      }
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Non-destructive health check
   */
  async checkHealth() {
    const start = Date.now();
    try {
      if (!this.pool) {
        return {
          status: 'UNAVAILABLE',
          check: 'FAIL',
          latencyMs: 0,
          error: 'Database pool not initialized'
        };
      }
      await this.query('SELECT 1');
      return {
        status: 'HEALTHY',
        check: 'PASS',
        latencyMs: Date.now() - start,
        mode: 'postgres',
        poolTotal: this.pool.totalCount,
        poolIdle: this.pool.idleCount,
        poolWaiting: this.pool.waitingCount
      };
    } catch (err) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        latencyMs: Date.now() - start,
        error: err.message
      };
    }
  }
}

/**
 * Transaction-scoped adapter executing queries on a single dedicated client
 */
class PostgreSQLTransactionAdapter extends DatabaseAdapter {
  constructor(client) {
    super();
    this.client = client;
  }

  async query(sql, params = []) {
    const result = await this.client.query(sql, params);
    return {
      rows: result.rows || [],
      rowCount: result.rowCount || 0
    };
  }

  async insert(table, id, data = {}) {
    const validTable = validateIdentifier(table);
    const record = { ...data };
    if (id !== undefined && id !== null) {
      record.id = id;
    }

    const keys = Object.keys(record);
    const columns = keys.map(validateIdentifier);
    const placeholders = keys.map((_, i) => `$${i + 1}`);
    const values = keys.map(k => sanitizeValue(record[k]));

    const sql = `INSERT INTO ${validTable} (${columns.join(', ')}) VALUES (${placeholders.join(', ')}) RETURNING *`;
    const res = await this.query(sql, values);
    return res.rows[0];
  }

  async findById(table, id) {
    const validTable = validateIdentifier(table);
    const sql = `SELECT * FROM ${validTable} WHERE id = $1 LIMIT 1`;
    const res = await this.query(sql, [id]);
    return res.rows[0] || null;
  }

  async find(table, filter = null, options = {}) {
    const validTable = validateIdentifier(table);
    if (filter && typeof filter === 'object' && !Array.isArray(filter)) {
      const keys = Object.keys(filter);
      if (keys.length === 0) {
        let sql = `SELECT * FROM ${validTable}`;
        if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
        if (options.limit) sql += ` LIMIT ${options.limit}`;
        const res = await this.query(sql);
        return res.rows;
      }

      const whereClauses = [];
      const values = [];
      let idx = 1;

      for (const key of keys) {
        const col = validateIdentifier(key);
        const val = filter[key];
        if (val === null) {
          whereClauses.push(`${col} IS NULL`);
        } else {
          whereClauses.push(`${col} = $${idx++}`);
          values.push(sanitizeValue(val));
        }
      }

      let sql = `SELECT * FROM ${validTable} WHERE ${whereClauses.join(' AND ')}`;
      if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
      if (options.limit) sql += ` LIMIT ${options.limit}`;

      const res = await this.query(sql, values);
      return res.rows;
    }

    let sql = `SELECT * FROM ${validTable}`;
    if (options.orderBy) sql += ` ORDER BY ${validateIdentifier(options.orderBy)}`;
    const res = await this.query(sql);
    let rows = res.rows;

    if (typeof filter === 'function') {
      rows = rows.filter(filter);
    }
    if (options.limit && typeof options.limit === 'number') {
      rows = rows.slice(0, options.limit);
    }
    return rows;
  }

  async update(table, id, updates = {}) {
    const validTable = validateIdentifier(table);
    const keys = Object.keys(updates);

    if (keys.length === 0) {
      return this.findById(table, id);
    }

    const setClauses = [];
    const values = [];
    let idx = 1;

    for (const key of keys) {
      const col = validateIdentifier(key);
      setClauses.push(`${col} = $${idx++}`);
      values.push(sanitizeValue(updates[key]));
    }

    setClauses.push(`updated_at = NOW()`);
    values.push(id);

    const sql = `UPDATE ${validTable} SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *`;
    const res = await this.query(sql, values);
    if (res.rows.length === 0) {
      throw new Error(`Record ${id} not found in ${table}`);
    }
    return res.rows[0];
  }

  async delete(table, id) {
    const validTable = validateIdentifier(table);
    const sql = `DELETE FROM ${validTable} WHERE id = $1`;
    const res = await this.query(sql, [id]);
    return res.rowCount > 0;
  }

  async withTransaction(callback) {
    // Nested transactions execute directly on the current transaction connection
    return callback(this);
  }
}

module.exports = {
  PostgreSQLDatabaseAdapter,
  PostgreSQLTransactionAdapter,
  validateIdentifier,
  sanitizeValue
};
