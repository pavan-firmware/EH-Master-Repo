/**
 * Platform Incident Repository
 *
 * Persists and queries production incidents, managing incident lifecycles
 * and operational correlations without duplicating underlying telemetry.
 */

class PlatformIncidentRepository {
  constructor(db) {
    this.db = db;
    this.tableName = 'platform_incidents';
  }

  async create(data) {
    const record = {
      id: data.id,
      title: data.title,
      description: data.description || '',
      severity: data.severity || 'SEV3',
      status: data.status || 'OPEN',
      affected_component: data.affected_component || 'UNKNOWN',
      affected_homes: Array.isArray(data.affected_homes) ? data.affected_homes : [],
      affected_devices: Array.isArray(data.affected_devices) ? data.affected_devices : [],
      commander_user_id: data.commander_user_id || null,
      correlated_event_ids: Array.isArray(data.correlated_event_ids) ? data.correlated_event_ids : [],
      correlated_audit_record_ids: Array.isArray(data.correlated_audit_record_ids) ? data.correlated_audit_record_ids : [],
      correlated_rollout_ids: Array.isArray(data.correlated_rollout_ids) ? data.correlated_rollout_ids : [],
      root_cause: data.root_cause || null,
      mitigation_summary: data.mitigation_summary || null,
      opened_at: data.opened_at || new Date().toISOString(),
      acknowledged_at: data.acknowledged_at || null,
      mitigated_at: data.mitigated_at || null,
      resolved_at: data.resolved_at || null,
      closed_at: data.closed_at || null,
      metadata: data.metadata || {},
      created_at: data.created_at || new Date().toISOString(),
      updated_at: data.updated_at || new Date().toISOString()
    };

    if (this.db.insert) {
      return await this.db.insert(this.tableName, record.id, record);
    }
    if (this.db.create) {
      return await this.db.create(this.tableName, record);
    }
    return record;
  }

  async findById(id) {
    if (this.db.findById) {
      return await this.db.findById(this.tableName, id);
    }
    const results = await this.db.find(this.tableName, { id });
    return results && results.length > 0 ? results[0] : null;
  }

  async update(id, updates) {
    const cleanUpdates = { ...updates, updated_at: new Date().toISOString() };
    if (this.db.update) {
      return await this.db.update(this.tableName, id, cleanUpdates);
    }
    return null;
  }

  async find(filters = {}) {
    let records = [];
    if (this.db.find) {
      records = await this.db.find(this.tableName);
    }

    let filtered = records.filter(r => {
      if (filters.status && r.status !== filters.status) return false;
      if (filters.severity && r.severity !== filters.severity) return false;
      if (filters.affected_component && r.affected_component !== filters.affected_component) return false;
      if (filters.commander_user_id && r.commander_user_id !== filters.commander_user_id) return false;
      return true;
    });

    filtered.sort((a, b) => new Date(b.opened_at || b.created_at) - new Date(a.opened_at || a.created_at));

    if (filters.limit) {
      const offset = filters.offset || 0;
      filtered = filtered.slice(offset, offset + filters.limit);
    }

    return filtered;
  }

  async count(filters = {}) {
    const list = await this.find(filters);
    return list.length;
  }
}

module.exports = { PlatformIncidentRepository };
