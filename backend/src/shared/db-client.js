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
      // Phase 25 — Proactive Device Reliability + Self-Healing
      'reliability_incidents', 'reliability_diagnostics', 'reliability_recovery_attempts',
      'reliability_health_snapshots', 'maintenance_recommendations',
      // Phase 26 — Multi-Protocol Device Connectivity & Interoperability
      'device_transports', 'device_connection_states', 'commissioning_sessions',
      'transport_health_snapshots',
      // Phase 27 — Product Discovery & Consumer Device Add
      'product_models', 'device_add_sessions',
      // Phase 28 — Local-First Home Control & Edge Execution
      'local_route_cache', 'edge_execution_records', 'local_discovery_nodes'
    ];
    tableNames.forEach(t => this.tables.set(t, new Map()));
  }

  async query(sql, params = []) {
    // Mock query execution against in-memory tables
    return { rows: [], rowCount: 0 };
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
    const record = { ...data, created_at: data.created_at || new Date().toISOString(), id };
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
