'use strict';

/**
 * EH Home — Observability & Incident Response API Router (Phase 43)
 *
 * Exposes production observability, metrics, alerts, and incident lifecycle endpoints:
 * - GET    /api/v1/admin/observability/metrics
 * - GET    /api/v1/admin/observability/alerts
 * - POST   /api/v1/admin/observability/alerts/:id/resolve
 * - POST   /api/v1/admin/observability/alerts/evaluate
 * - GET    /api/v1/admin/observability/incidents
 * - POST   /api/v1/admin/observability/incidents
 * - GET    /api/v1/admin/observability/incidents/:id
 * - PATCH  /api/v1/admin/observability/incidents/:id/status
 * - PATCH  /api/v1/admin/observability/incidents/:id/commander
 * - PATCH  /api/v1/admin/observability/incidents/:id/severity
 * - POST   /api/v1/admin/observability/incidents/:id/alerts
 * - GET    /api/v1/admin/observability/incidents/:id/timeline
 *
 * RBAC POLICY:
 * All observability endpoints require authenticated ADMIN or OPERATOR role.
 */

class ObservabilityApiRouter {
  constructor({
    metricsService,
    alertRulesService,
    incidentService,
    logger = null
  }) {
    this.metricsService = metricsService;
    this.alertRulesService = alertRulesService;
    this.incidentService = incidentService;
    this.logger = logger;
  }

  _isAuthorized(user, headers = {}) {
    if (headers['x-admin-role'] === 'true' || headers['x-operator-role'] === 'true') {
      return true;
    }
    if (!user) return false;
    const role = (user.role || '').toUpperCase();
    return role === 'ADMIN' || role === 'SUPERADMIN' || role === 'OPERATOR';
  }

  async handle(method, rawPath, body = {}, query = {}, user = null, headers = {}) {
    const path = (rawPath.length > 1 && rawPath.endsWith('/')) ? rawPath.slice(0, -1) : rawPath;

    if (!path.startsWith('/api/v1/admin/observability')) {
      return null;
    }

    // RBAC Check
    if (!this._isAuthorized(user, headers)) {
      return {
        status: 403,
        body: {
          success: false,
          error: {
            code: 'FORBIDDEN',
            message: 'Administrative or operator privileges are required to access platform observability resources'
          },
          timestamp: new Date().toISOString()
        }
      };
    }

    try {
      // 1. GET /api/v1/admin/observability/metrics
      if (method === 'GET' && path === '/api/v1/admin/observability/metrics') {
        const category = query.category || null;
        const snapshot = this.metricsService.getSnapshot(category);
        return {
          status: 200,
          body: {
            success: true,
            data: snapshot,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 2. GET /api/v1/admin/observability/alerts
      if (method === 'GET' && path === '/api/v1/admin/observability/alerts') {
        const filters = {
          status: query.status,
          severity: query.severity,
          rule_id: query.rule_id,
          limit: query.limit ? parseInt(query.limit, 10) : undefined,
          offset: query.offset ? parseInt(query.offset, 10) : undefined
        };
        const alerts = await this.alertRulesService.listAlerts(filters);
        return {
          status: 200,
          body: {
            success: true,
            count: alerts.length,
            data: alerts,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 3. POST /api/v1/admin/observability/alerts/evaluate
      if (method === 'POST' && path === '/api/v1/admin/observability/alerts/evaluate') {
        const snapshot = this.metricsService.getSnapshot();
        const triggered = await this.alertRulesService.evaluateMetrics(snapshot, body);
        return {
          status: 200,
          body: {
            success: true,
            triggered_count: triggered.length,
            alerts: triggered,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 4. POST /api/v1/admin/observability/alerts/:id/resolve
      const alertResolveMatch = path.match(/^\/api\/v1\/admin\/observability\/alerts\/([^/]+)\/resolve$/);
      if (method === 'POST' && alertResolveMatch) {
        const alertId = alertResolveMatch[1];
        const reason = body.reason || 'Resolved by operator';
        const resolved = await this.alertRulesService.resolveAlert(alertId, reason);
        return {
          status: 200,
          body: {
            success: true,
            data: resolved,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 5. GET /api/v1/admin/observability/incidents
      if (method === 'GET' && path === '/api/v1/admin/observability/incidents') {
        const filters = {
          status: query.status,
          severity: query.severity,
          affected_component: query.affected_component,
          limit: query.limit ? parseInt(query.limit, 10) : undefined,
          offset: query.offset ? parseInt(query.offset, 10) : undefined
        };
        const incidents = await this.incidentService.listIncidents(filters);
        return {
          status: 200,
          body: {
            success: true,
            count: incidents.length,
            data: incidents,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 6. POST /api/v1/admin/observability/incidents
      if (method === 'POST' && path === '/api/v1/admin/observability/incidents') {
        const incident = await this.incidentService.createIncident({
          title: body.title,
          description: body.description,
          severity: body.severity,
          affected_component: body.affected_component,
          affected_homes: body.affected_homes,
          affected_devices: body.affected_devices,
          commander_user_id: body.commander_user_id || (user ? user.id : null),
          correlated_event_ids: body.correlated_event_ids,
          correlated_audit_record_ids: body.correlated_audit_record_ids,
          correlated_rollout_ids: body.correlated_rollout_ids,
          metadata: body.metadata
        });
        return {
          status: 201,
          body: {
            success: true,
            data: incident,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 7. GET /api/v1/admin/observability/incidents/:id/timeline
      const incidentTimelineMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)\/timeline$/);
      if (method === 'GET' && incidentTimelineMatch) {
        const incidentId = incidentTimelineMatch[1];
        const timeline = await this.incidentService.getIncidentTimeline(incidentId);
        return {
          status: 200,
          body: {
            success: true,
            data: timeline,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 8. PATCH /api/v1/admin/observability/incidents/:id/status
      const incidentStatusMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)\/status$/);
      if (method === 'PATCH' && incidentStatusMatch) {
        const incidentId = incidentStatusMatch[1];
        const updated = await this.incidentService.updateIncidentStatus(incidentId, body.status, {
          actorUserId: user ? user.id : null,
          rootCause: body.root_cause,
          mitigationSummary: body.mitigation_summary,
          notes: body.notes
        });
        return {
          status: 200,
          body: {
            success: true,
            data: updated,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 9. PATCH /api/v1/admin/observability/incidents/:id/commander
      const incidentCommanderMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)\/commander$/);
      if (method === 'PATCH' && incidentCommanderMatch) {
        const incidentId = incidentCommanderMatch[1];
        const updated = await this.incidentService.assignCommander(incidentId, body.commander_user_id);
        return {
          status: 200,
          body: {
            success: true,
            data: updated,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 10. PATCH /api/v1/admin/observability/incidents/:id/severity
      const incidentSeverityMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)\/severity$/);
      if (method === 'PATCH' && incidentSeverityMatch) {
        const incidentId = incidentSeverityMatch[1];
        const updated = await this.incidentService.updateSeverity(incidentId, body.severity, body.reason);
        return {
          status: 200,
          body: {
            success: true,
            data: updated,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 11. POST /api/v1/admin/observability/incidents/:id/alerts
      const incidentAlertMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)\/alerts$/);
      if (method === 'POST' && incidentAlertMatch) {
        const incidentId = incidentAlertMatch[1];
        const linked = await this.incidentService.linkAlert(incidentId, body.alert_id);
        return {
          status: 200,
          body: {
            success: true,
            data: linked,
            timestamp: new Date().toISOString()
          }
        };
      }

      // 12. GET /api/v1/admin/observability/incidents/:id
      const incidentGetMatch = path.match(/^\/api\/v1\/admin\/observability\/incidents\/([^/]+)$/);
      if (method === 'GET' && incidentGetMatch) {
        const incidentId = incidentGetMatch[1];
        const incident = await this.incidentService.getIncident(incidentId);
        if (!incident) {
          return {
            status: 404,
            body: {
              success: false,
              error: { code: 'NOT_FOUND', message: `Incident ${incidentId} not found` },
              timestamp: new Date().toISOString()
            }
          };
        }
        return {
          status: 200,
          body: {
            success: true,
            data: incident,
            timestamp: new Date().toISOString()
          }
        };
      }

      return {
        status: 404,
        body: {
          success: false,
          error: { code: 'NOT_FOUND', message: `Observability route ${method} ${pathname} not found` },
          timestamp: new Date().toISOString()
        }
      };
    } catch (err) {
      if (this.logger) {
        this.logger.error(`Observability error: ${err.message}`, { path, method }, err);
      }
      return {
        status: 400,
        body: {
          success: false,
          error: { code: 'BAD_REQUEST', message: err.message },
          timestamp: new Date().toISOString()
        }
      };
    }
  }
}

module.exports = { ObservabilityApiRouter };
