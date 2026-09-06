'use strict';

/**
 * EH Home — In-Memory Database Adapter (Phase 37)
 *
 * Provides deterministic, isolated in-memory relational mock storage for
 * unit tests, local test harnesses, and protocol simulators.
 */

const { DatabaseAdapter } = require('./database-adapter');

const KNOWN_TABLES = [
  'users', 'refresh_tokens', 'homes', 'home_memberships', 'floors', 'rooms',
  'product_families', 'products', 'product_variants', 'capabilities',
  'product_capabilities', 'product_images', 'devices', 'device_credentials',
  'network_identity', 'device_authorizations', 'device_state', 'channel_state',
  'device_commands', 'device_events', 'audit_logs', 'outbox', 'provisioning_sessions',
  'scenes', 'automations', 'schedules', 'automation_execution_logs',
  'device_activity_logs', 'device_health_metrics',
  'notifications', 'push_device_tokens', 'user_notification_preferences', 'notification_delivery_queue',
  'user_profiles', 'home_invitations',
  'sync_checkpoints', 'pending_change_audits', 'data_export_records',
  'firmware_releases', 'ota_rollouts', 'ota_operations', 'device_maintenance_logs',
  'device_telemetry_measurements', 'telemetry_aggregates', 'energy_threshold_configs', 'energy_events',
  'energy_automation_executions', 'energy_optimizations',
  'energy_tariffs', 'tariff_periods', 'energy_budgets', 'cost_optimizations',
  'energy_forecasts', 'energy_anomalies', 'energy_baselines', 'forecast_accuracy_records', 'energy_efficiency_scores',
  'presence_signals', 'presence_states', 'home_contexts', 'context_overrides', 'context_transitions',
  'intelligence_decisions', 'intelligence_recommendations', 'intelligence_decision_outcomes',
  'reliability_incidents', 'reliability_diagnostics', 'reliability_recovery_attempts',
  'reliability_health_snapshots', 'maintenance_recommendations',
  'device_transports', 'device_connection_states', 'commissioning_sessions',
  'transport_health_snapshots',
  'product_models', 'device_add_sessions',
  'local_route_cache', 'edge_execution_records', 'local_discovery_nodes',
  'matter_devices', 'matter_fabrics', 'matter_endpoints', 'matter_sync_state', 'external_platform_links',
  'platform_events', 'notification_aggregations', 'notification_actions',
  'operational_events', 'security_audit_records', 'system_health_snapshots',
  'device_trust_states', 'device_credential_lifecycle', 'device_revocations', 'device_provisioning_records',
  'backup_records', 'backup_objects', 'restore_operations', 'recovery_checkpoints', 'recovery_integrity_results',
  'schema_migrations'
];

class InMemoryDatabaseAdapter extends DatabaseAdapter {
  constructor() {
    super();
    this.tables = new Map();
    this.isConnected = true;
    this._initTables();
  }

  _initTables() {
    KNOWN_TABLES.forEach(t => {
      if (!this.tables.has(t)) {
        this.tables.set(t, new Map());
      }
    });
  }

  async connect() {
    this.isConnected = true;
  }

  async close() {
    this.isConnected = false;
  }

  getTable(name) {
    if (!this.isConnected) {
      throw new Error('Database is closed or disconnected');
    }
    let tbl = this.tables.get(name);
    if (!tbl) {
      tbl = new Map();
      this.tables.set(name, tbl);
    }
    return tbl;
  }

  async query(sql, params = []) {
    if (!this.isConnected) {
      throw new Error('Database is closed or disconnected');
    }
    // Simple mock response for probe queries like SELECT 1
    return { rows: [], rowCount: 0 };
  }

  async insert(table, id, data) {
    const tbl = this.getTable(table);
    if (tbl.has(id)) {
      throw new Error(`Unique constraint violation: ${table} with id ${id} already exists`);
    }
    const record = {
      ...data,
      id,
      created_at: data.created_at || new Date().toISOString()
    };
    tbl.set(id, record);
    return { ...record };
  }

  async findById(table, id) {
    const tbl = this.getTable(table);
    const item = tbl.get(id);
    return item ? { ...item } : null;
  }

  async find(table, filter = null, options = {}) {
    const tbl = this.getTable(table);
    const results = [];

    for (const record of tbl.values()) {
      let matches = true;

      if (typeof filter === 'function') {
        matches = filter(record);
      } else if (filter && typeof filter === 'object') {
        for (const [k, v] of Object.entries(filter)) {
          if (record[k] !== v) {
            matches = false;
            break;
          }
        }
      }

      if (matches) {
        results.push({ ...record });
      }
    }

    if (options.limit && typeof options.limit === 'number') {
      return results.slice(0, options.limit);
    }
    return results;
  }

  async update(table, id, updates) {
    const tbl = this.getTable(table);
    const existing = tbl.get(id);
    if (!existing) {
      throw new Error(`Record ${id} not found in ${table}`);
    }
    const updated = {
      ...existing,
      ...updates,
      updated_at: new Date().toISOString()
    };
    tbl.set(id, updated);
    return { ...updated };
  }

  async delete(table, id) {
    const tbl = this.getTable(table);
    return tbl.delete(id);
  }

  async withTransaction(callback) {
    if (!this.isConnected) {
      throw new Error('Database is closed or disconnected');
    }

    // Deep snapshot of current tables state for rollback
    const snapshot = new Map();
    for (const [tableName, map] of this.tables.entries()) {
      snapshot.set(tableName, new Map(map));
    }

    try {
      const result = await callback(this);
      return result;
    } catch (err) {
      // Rollback to snapshot on error
      this.tables = snapshot;
      throw err;
    }
  }

  async checkHealth() {
    if (!this.isConnected) {
      return {
        status: 'UNAVAILABLE',
        check: 'FAIL',
        latencyMs: 0,
        error: 'In-memory database closed'
      };
    }
    return {
      status: 'HEALTHY',
      check: 'PASS',
      latencyMs: 0,
      mode: 'inmemory'
    };
  }
}

module.exports = { InMemoryDatabaseAdapter, KNOWN_TABLES };
