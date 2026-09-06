/**
 * Platform Alert Repository
 *
 * Persists and queries operational alerts, supporting deterministic deduplication
 * and incident association.
 */

class PlatformAlertRepository {
  constructor(db) {
    this.db = db;
    this.tableName = 'platform_alerts';
  }

  async create(data) {
    const record = {
      id: data.id,
      rule_id: data.rule_id,
      title: data.title,
      description: data.description || '',
      severity: data.severity || 'SEV3',
      status: data.status || 'ACTIVE',
      deduplication_key: data.deduplication_key,
      occurrence_count: data.occurrence_count || 1,
      first_triggered_at: data.first_triggered_at || new Date().toISOString(),
      last_triggered_at: data.last_triggered_at || new Date().toISOString(),
      resolved_at: data.resolved_at || null,
      incident_id: data.incident_id || null,
      context: data.context || {},
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

  async findByDeduplicationKey(deduplicationKey, activeOnly = true) {
    const records = await this.db.find(this.tableName);
    const matches = records.filter(r => {
      if (r.deduplication_key !== deduplicationKey) return false;
      if (activeOnly && r.status !== 'ACTIVE' && r.status !== 'SUPPRESSED') return false;
      return true;
    });

    matches.sort((a, b) => new Date(b.last_triggered_at || b.created_at) - new Date(a.last_triggered_at || a.created_at));
    return matches.length > 0 ? matches[0] : null;
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
      if (filters.rule_id && r.rule_id !== filters.rule_id) return false;
      if (filters.status && r.status !== filters.status) return false;
      if (filters.severity && r.severity !== filters.severity) return false;
      if (filters.incident_id && r.incident_id !== filters.incident_id) return false;
      if (filters.deduplication_key && r.deduplication_key !== filters.deduplication_key) return false;
      return true;
    });

    filtered.sort((a, b) => new Date(b.last_triggered_at || b.created_at) - new Date(a.last_triggered_at || a.created_at));

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

module.exports = { PlatformAlertRepository };
