/**
 * In-Memory SQLite / Mock Relational Storage Client for Repository Integration Testing & Local Verification
 */

class DatabaseClient {
  constructor() {
    this.tables = new Map();
    this._initTables();
  }

  _initTables() {
    const tableNames = [
      'users', 'refresh_tokens', 'homes', 'home_memberships', 'floors', 'rooms',
      'product_families', 'products', 'product_variants', 'capabilities',
      'product_capabilities', 'product_images', 'devices', 'device_credentials',
      'network_identity', 'device_authorizations', 'device_state', 'channel_state',
      'device_commands', 'device_events', 'audit_logs', 'outbox'
    ];
    tableNames.forEach(t => this.tables.set(t, new Map()));
  }

  getTable(name) {
    const tbl = this.tables.get(name);
    if (!tbl) throw new Error(`Table ${name} does not exist`);
    return tbl;
  }

  async insert(table, id, data) {
    const tbl = this.getTable(table);
    if (tbl.has(id)) {
      throw new Error(`Unique constraint violation: ${table} with id ${id} already exists`);
    }
    const record = { ...data, id, created_at: new Date().toISOString() };
    tbl.set(id, record);
    return record;
  }

  async findById(table, id) {
    const tbl = this.getTable(table);
    return tbl.get(id) || null;
  }

  async find(table, predicate) {
    const tbl = this.getTable(table);
    const results = [];
    for (const record of tbl.values()) {
      if (!predicate || predicate(record)) {
        results.push(record);
      }
    }
    return results;
  }

  async update(table, id, updates) {
    const tbl = this.getTable(table);
    const existing = tbl.get(id);
    if (!existing) throw new Error(`Record ${id} not found in ${table}`);
    const updated = { ...existing, ...updates, updated_at: new Date().toISOString() };
    tbl.set(id, updated);
    return updated;
  }

  async delete(table, id) {
    const tbl = this.getTable(table);
    return tbl.delete(id);
  }
}

module.exports = { DatabaseClient };
