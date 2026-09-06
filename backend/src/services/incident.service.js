'use strict';

/**
 * EH Home — Platform Incident Service (Phase 43)
 *
 * Manages production platform incidents, deterministic lifecycle transitions,
 * root-cause analysis, and federated timeline correlation referencing existing
 * operational, security, device, and OTA telemetry records.
 */

const crypto = require('crypto');

const VALID_INCIDENT_STATUSES = ['OPEN', 'ACKNOWLEDGED', 'INVESTIGATING', 'MITIGATING', 'RESOLVED', 'CLOSED'];
const VALID_INCIDENT_SEVERITIES = ['SEV1', 'SEV2', 'SEV3', 'SEV4'];

const ALLOWED_TRANSITIONS = {
  OPEN: ['ACKNOWLEDGED', 'INVESTIGATING', 'CLOSED'],
  ACKNOWLEDGED: ['INVESTIGATING', 'MITIGATING', 'RESOLVED', 'CLOSED'],
  INVESTIGATING: ['MITIGATING', 'RESOLVED', 'CLOSED'],
  MITIGATING: ['RESOLVED', 'INVESTIGATING', 'CLOSED'],
  RESOLVED: ['CLOSED', 'INVESTIGATING'],
  CLOSED: []
};

class IncidentService {
  constructor({
    incidentRepository,
    alertRepository = null,
    operationalEventRepository = null,
    securityAuditRepository = null,
    fleetRepository = null,
    notificationService = null,
    logger = null
  }) {
    this.incidentRepo = incidentRepository;
    this.alertRepo = alertRepository;
    this.opEventRepo = operationalEventRepository;
    this.auditRepo = securityAuditRepository;
    this.fleetRepo = fleetRepository;
    this.notificationService = notificationService;
    this.logger = logger;
  }

  async createIncident({
    title,
    description = '',
    severity = 'SEV3',
    affected_component = 'UNKNOWN',
    affected_homes = [],
    affected_devices = [],
    commander_user_id = null,
    correlated_event_ids = [],
    correlated_audit_record_ids = [],
    correlated_rollout_ids = [],
    metadata = {}
  }) {
    if (!title || typeof title !== 'string' || !title.trim()) {
      throw new Error('Incident title is required and cannot be empty');
    }

    if (!VALID_INCIDENT_SEVERITIES.includes(severity)) {
      throw new Error(`Invalid severity: ${severity}. Must be one of ${VALID_INCIDENT_SEVERITIES.join(', ')}`);
    }

    const incidentId = `inc-${crypto.randomUUID()}`;
    const now = new Date().toISOString();

    const incident = await this.incidentRepo.create({
      id: incidentId,
      title: title.trim(),
      description: description.trim(),
      severity,
      status: 'OPEN',
      affected_component,
      affected_homes,
      affected_devices,
      commander_user_id,
      correlated_event_ids,
      correlated_audit_record_ids,
      correlated_rollout_ids,
      opened_at: now,
      metadata
    });

    if (this.logger) {
      this.logger.info(`Incident created: ${incidentId} [${severity}] - ${title}`, {
        incidentId,
        severity,
        component: affected_component
      });
    }

    if (this.notificationService && (severity === 'SEV1' || severity === 'SEV2')) {
      try {
        await this.notificationService.notifyOperators({
          title: `[${severity}] Platform Incident: ${title}`,
          body: description || `Incident ${incidentId} opened on component ${affected_component}`,
          data: { incidentId, severity, component: affected_component }
        });
      } catch (err) {
        if (this.logger) this.logger.warn('Failed to dispatch incident notification', { error: err.message });
      }
    }

    return incident;
  }

  async updateIncidentStatus(incidentId, nextStatus, { actorUserId = null, rootCause = null, mitigationSummary = null, notes = null } = {}) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) {
      throw new Error(`Incident ${incidentId} not found`);
    }

    const currentStatus = incident.status;
    if (currentStatus === nextStatus) {
      return incident;
    }

    const validTargets = ALLOWED_TRANSITIONS[currentStatus] || [];
    if (!validTargets.includes(nextStatus)) {
      throw new Error(`Invalid incident status transition from ${currentStatus} to ${nextStatus}. Allowed: [${validTargets.join(', ')}]`);
    }

    const updates = {
      status: nextStatus
    };

    const now = new Date().toISOString();
    if (nextStatus === 'ACKNOWLEDGED' && !incident.acknowledged_at) {
      updates.acknowledged_at = now;
    }
    if (nextStatus === 'MITIGATING' && !incident.mitigated_at) {
      updates.mitigated_at = now;
    }
    if (nextStatus === 'RESOLVED') {
      if (!incident.resolved_at) updates.resolved_at = now;
      if (!incident.mitigated_at) updates.mitigated_at = now;
      if (rootCause) updates.root_cause = rootCause;
      if (mitigationSummary) updates.mitigation_summary = mitigationSummary;
    }
    if (nextStatus === 'CLOSED') {
      if (!incident.closed_at) updates.closed_at = now;
      if (rootCause && !incident.root_cause) updates.root_cause = rootCause;
      if (mitigationSummary && !incident.mitigation_summary) updates.mitigation_summary = mitigationSummary;
    }

    if (rootCause) updates.root_cause = rootCause;
    if (mitigationSummary) updates.mitigation_summary = mitigationSummary;

    if (notes) {
      updates.metadata = {
        ...(incident.metadata || {}),
        [`status_note_${Date.now()}`]: { actor: actorUserId, note: notes, timestamp: now }
      };
    }

    const updated = await this.incidentRepo.update(incidentId, updates);

    if (this.logger) {
      this.logger.info(`Incident ${incidentId} transitioned from ${currentStatus} to ${nextStatus}`, {
        incidentId,
        fromStatus: currentStatus,
        toStatus: nextStatus,
        actorUserId
      });
    }

    return updated;
  }

  async assignCommander(incidentId, commanderUserId) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) {
      throw new Error(`Incident ${incidentId} not found`);
    }

    return await this.incidentRepo.update(incidentId, {
      commander_user_id: commanderUserId
    });
  }

  async updateSeverity(incidentId, newSeverity, reason = null) {
    if (!VALID_INCIDENT_SEVERITIES.includes(newSeverity)) {
      throw new Error(`Invalid severity: ${newSeverity}`);
    }

    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) {
      throw new Error(`Incident ${incidentId} not found`);
    }

    const metadata = {
      ...(incident.metadata || {}),
      [`severity_change_${Date.now()}`]: {
        from: incident.severity,
        to: newSeverity,
        reason,
        timestamp: new Date().toISOString()
      }
    };

    return await this.incidentRepo.update(incidentId, {
      severity: newSeverity,
      metadata
    });
  }

  async linkAlert(incidentId, alertId) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) {
      throw new Error(`Incident ${incidentId} not found`);
    }

    if (this.alertRepo) {
      const alert = await this.alertRepo.findById(alertId);
      if (!alert) {
        throw new Error(`Alert ${alertId} not found`);
      }
      await this.alertRepo.update(alertId, { incident_id: incidentId });
    }

    return { linked: true, incidentId, alertId };
  }

  /**
   * Aggregates a comprehensive timeline of the incident by referencing existing records
   * without duplicating raw data.
   */
  async getIncidentTimeline(incidentId) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) {
      throw new Error(`Incident ${incidentId} not found`);
    }

    const timeline = [];

    // 1. Lifecycle milestones
    if (incident.opened_at) {
      timeline.push({
        type: 'LIFECYCLE',
        timestamp: incident.opened_at,
        summary: `Incident opened with severity ${incident.severity}`,
        details: { status: 'OPEN', severity: incident.severity }
      });
    }
    if (incident.acknowledged_at) {
      timeline.push({
        type: 'LIFECYCLE',
        timestamp: incident.acknowledged_at,
        summary: 'Incident acknowledged by response team',
        details: { status: 'ACKNOWLEDGED' }
      });
    }
    if (incident.mitigated_at) {
      timeline.push({
        type: 'LIFECYCLE',
        timestamp: incident.mitigated_at,
        summary: 'Incident mitigation applied',
        details: { status: 'MITIGATING', mitigation_summary: incident.mitigation_summary }
      });
    }
    if (incident.resolved_at) {
      timeline.push({
        type: 'LIFECYCLE',
        timestamp: incident.resolved_at,
        summary: 'Incident resolved',
        details: { status: 'RESOLVED', root_cause: incident.root_cause }
      });
    }
    if (incident.closed_at) {
      timeline.push({
        type: 'LIFECYCLE',
        timestamp: incident.closed_at,
        summary: 'Incident closed',
        details: { status: 'CLOSED' }
      });
    }

    // 2. Referenced platform alerts
    if (this.alertRepo) {
      const alerts = await this.alertRepo.find({ incident_id: incidentId });
      alerts.forEach(alt => {
        timeline.push({
          type: 'ALERT',
          timestamp: alt.first_triggered_at,
          summary: `Alert triggered: ${alt.title} (${alt.rule_id})`,
          details: {
            alert_id: alt.id,
            rule_id: alt.rule_id,
            severity: alt.severity,
            occurrence_count: alt.occurrence_count
          }
        });
      });
    }

    // 3. Referenced operational events
    if (this.opEventRepo && incident.correlated_event_ids && incident.correlated_event_ids.length > 0) {
      for (const eventId of incident.correlated_event_ids) {
        const ev = await this.opEventRepo.findById(eventId);
        if (ev) {
          timeline.push({
            type: 'OPERATIONAL_EVENT',
            timestamp: ev.timestamp || ev.created_at,
            summary: `Operational event: ${ev.type || ev.event_type || 'EVENT'}`,
            details: {
              event_id: ev.id,
              level: ev.level,
              component: ev.component
            }
          });
        }
      }
    }

    // 4. Referenced security audit records
    if (this.auditRepo && incident.correlated_audit_record_ids && incident.correlated_audit_record_ids.length > 0) {
      for (const recordId of incident.correlated_audit_record_ids) {
        const rec = await this.auditRepo.findById ? await this.auditRepo.findById(recordId) : null;
        if (rec) {
          timeline.push({
            type: 'SECURITY_AUDIT',
            timestamp: rec.timestamp,
            summary: `Security audit record: ${rec.action} on ${rec.resourceType}`,
            details: {
              record_id: rec.id,
              action: rec.action,
              outcome: rec.outcome
            }
          });
        }
      }
    }

    // Sort timeline chronologically (ascending)
    timeline.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    return {
      incident_id: incidentId,
      title: incident.title,
      current_status: incident.status,
      severity: incident.severity,
      affected_component: incident.affected_component,
      timeline_entry_count: timeline.length,
      timeline
    };
  }

  async getIncident(incidentId) {
    return await this.incidentRepo.findById(incidentId);
  }

  async listIncidents(filters = {}) {
    return await this.incidentRepo.find(filters);
  }
}

module.exports = {
  IncidentService,
  VALID_INCIDENT_STATUSES,
  VALID_INCIDENT_SEVERITIES,
  ALLOWED_TRANSITIONS
};
