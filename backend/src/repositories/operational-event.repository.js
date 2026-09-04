/**
 * Operational Event Repository
 *
 * Persists and queries operational events across all platform subsystems.
 */

class OperationalEventRepository {
  constructor(db) {
    this.db = db;
  }

  async create(eventData) {
    const record = {
      id: eventData.eventId || eventData.id,
      correlation_id: eventData.correlationId,
      causation_id: eventData.causationId || null,
      home_id: eventData.homeId || null,
      device_id: eventData.deviceId || null,
      room_id: eventData.roomId || null,
      user_id: eventData.userId || null,
      subsystem: eventData.subsystem,
      operation: eventData.operation,
      action: eventData.action,
      source: eventData.source,
      execution_path: eventData.executionPath || 'CLOUD',
      severity: eventData.severity || 'INFO',
      authorization_result: eventData.authorizationResult || 'AUTHORIZED',
      outcome: eventData.outcome || 'SUCCESS',
      failure_code: eventData.failureCode || null,
      duration_ms: eventData.durationMs !== undefined ? eventData.durationMs : null,
      metadata: eventData.metadata || {},
      redaction_markers: eventData.redactionMarkers || [],
      trace_lifecycle: eventData.traceLifecycle || null,
      occurred_at: eventData.timestamp || eventData.occurredAt || new Date().toISOString()
    };

    return this.db.insert('operational_events', record.id, record);
  }

  async findById(id) {
    return this.db.findById('operational_events', id);
  }

  async findByCorrelationId(correlationId) {
    const events = await this.db.find('operational_events', e => e.correlation_id === correlationId);
    return events.sort((a, b) => new Date(a.occurred_at) - new Date(b.occurred_at));
  }

  async findEvents({ homeId, deviceId, subsystem, outcome, severity, since, limit = 100, offset = 0 }) {
    const events = await this.db.find('operational_events', e => {
      if (homeId && e.home_id !== homeId) return false;
      if (deviceId && e.device_id !== deviceId) return false;
      if (subsystem && e.subsystem !== subsystem) return false;
      if (outcome && e.outcome !== outcome) return false;
      if (severity && e.severity !== severity) return false;
      if (since && new Date(e.occurred_at) < new Date(since)) return false;
      return true;
    });

    return events
      .sort((a, b) => new Date(b.occurred_at) - new Date(a.occurred_at))
      .slice(offset, offset + limit);
  }

  async countEvents({ homeId, since, subsystem, outcome }) {
    const events = await this.db.find('operational_events', e => {
      if (homeId && e.home_id !== homeId) return false;
      if (since && new Date(e.occurred_at) < new Date(since)) return false;
      if (subsystem && e.subsystem !== subsystem) return false;
      if (outcome && e.outcome !== outcome) return false;
      return true;
    });
    return events.length;
  }
}

module.exports = { OperationalEventRepository };
