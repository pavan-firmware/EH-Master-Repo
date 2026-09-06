'use strict';

/**
 * EH Home — Unified Database Adapter Interface (Phase 37)
 *
 * Defines the contract implemented by both InMemoryDatabaseAdapter
 * and PostgreSQLDatabaseAdapter. Repositories and application services
 * depend only on this abstraction.
 */

class DatabaseAdapter {
  /**
   * Initialize and connect adapter
   * @returns {Promise<void>}
   */
  async connect() {
    throw new Error('DatabaseAdapter.connect() must be implemented by subclass');
  }

  /**
   * Close connections / pools cleanly
   * @returns {Promise<void>}
   */
  async close() {
    throw new Error('DatabaseAdapter.close() must be implemented by subclass');
  }

  /**
   * Execute parameterized SQL query
   * @param {string} sql - Parameterized SQL query (e.g., 'SELECT * FROM users WHERE id = $1')
   * @param {Array} [params=[]] - Query parameters
   * @returns {Promise<{ rows: Array, rowCount: number }>}
   */
  async query(sql, params = []) {
    throw new Error('DatabaseAdapter.query() must be implemented by subclass');
  }

  /**
   * Insert record into table
   * @param {string} table
   * @param {string} id
   * @param {Object} data
   * @returns {Promise<Object>} Persisted record
   */
  async insert(table, id, data) {
    throw new Error('DatabaseAdapter.insert() must be implemented by subclass');
  }

  /**
   * Find single record by primary key ID
   * @param {string} table
   * @param {string} id
   * @returns {Promise<Object|null>}
   */
  async findById(table, id) {
    throw new Error('DatabaseAdapter.findById() must be implemented by subclass');
  }

  /**
   * Find multiple records matching filter object or optional predicate
   * @param {string} table
   * @param {Object|Function} [filter]
   * @param {Object} [options]
   * @returns {Promise<Array<Object>>}
   */
  async find(table, filter = null, options = {}) {
    throw new Error('DatabaseAdapter.find() must be implemented by subclass');
  }

  /**
   * Update existing record by ID
   * @param {string} table
   * @param {string} id
   * @param {Object} updates
   * @returns {Promise<Object>} Updated record
   */
  async update(table, id, updates) {
    throw new Error('DatabaseAdapter.update() must be implemented by subclass');
  }

  /**
   * Delete record by ID
   * @param {string} table
   * @param {string} id
   * @returns {Promise<boolean>} True if deleted
   */
  async delete(table, id) {
    throw new Error('DatabaseAdapter.delete() must be implemented by subclass');
  }

  /**
   * Execute callback within an atomic database transaction
   * @param {Function} callback - async (txAdapter) => Promise<any>
   * @returns {Promise<any>}
   */
  async withTransaction(callback) {
    throw new Error('DatabaseAdapter.withTransaction() must be implemented by subclass');
  }

  /**
   * Health probe check
   * @returns {Promise<{ status: string, latencyMs: number }>}
   */
  async checkHealth() {
    throw new Error('DatabaseAdapter.checkHealth() must be implemented by subclass');
  }
}

module.exports = { DatabaseAdapter };
