/**
 * System Health Repository
 *
 * Persists and retrieves periodic health check snapshots.
 */

class SystemHealthRepository {
  constructor(db) {
    this.db = db;
  }

  async saveSnapshot({ id, status, subsystems, metadata = {}, timestamp = new Date().toISOString() }) {
    const record = {
      id,
      status,
      subsystems_json: subsystems,
      metadata_json: metadata,
      recorded_at: timestamp
    };
    return this.db.insert('system_health_snapshots', id, record);
  }

  async getLatestSnapshot() {
    const snapshots = await this.db.find('system_health_snapshots');
    if (snapshots.length === 0) return null;
    snapshots.sort((a, b) => new Date(b.recorded_at) - new Date(a.recorded_at));
    return snapshots[0];
  }

  async getRecentSnapshots(limit = 20) {
    const snapshots = await this.db.find('system_health_snapshots');
    return snapshots
      .sort((a, b) => new Date(b.recorded_at) - new Date(a.recorded_at))
      .slice(0, limit);
  }
}

module.exports = { SystemHealthRepository };
