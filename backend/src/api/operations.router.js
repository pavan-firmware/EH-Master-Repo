'use strict';

/**
 * Operations API Router (Phase 31)
 *
 * Exposes secure operations, audit, trace, and observability endpoints:
 * - GET  /api/v1/operations/health             (Observational subsystem health check)
 * - GET  /api/v1/operations/metrics            (Derived operational metrics summary)
 * - GET  /api/v1/operations/events             (Scoped operational events query)
 * - GET  /api/v1/operations/traces/:traceId    (End-to-end multi-hop trace by correlation/traceId)
 * - GET  /api/v1/operations/audit              (Tamper-evident security audit log query)
 * - GET  /api/v1/operations/audit/integrity    (Cryptographic hash chain verification)
 * - GET  /api/v1/operations/errors             (Aggregated failure taxonomy & distribution)
 *
 * SECURITY & SCOPING (FIX 5):
 * - Server-side authentication and role check (401 / 403).
 * - homeId / deviceId queries require home membership validation.
 * - Global cross-home querying requires platform ADMIN / DIAGNOSTIC role.
 */

class OperationsApiRouter {
  constructor({
    operationsAuditService,
    operationTraceService,
    systemHealthService,
    operationsMetricsService,
    homeAuthorizationService = null
  }) {
    this.auditService = operationsAuditService;
    this.traceService = operationTraceService;
    this.healthService = systemHealthService;
    this.metricsService = operationsMetricsService;
    this.homeAuth = homeAuthorizationService;
  }

  async handle(method, rawPath, body = {}, headers = {}, params = {}) {
    const userId = params.userId || headers['x-user-id'] || null;
    const userRole = headers['x-user-role'] || params.userRole || null;
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPERADMIN' || headers['x-admin-role'] === 'true' || headers['x-diagnostic-role'] === 'true';

    // Normalize path
    const path = (rawPath.length > 1 && rawPath.endsWith('/')) ? rawPath.slice(0, -1) : rawPath;

    try {
      // 1. GET /api/v1/operations/health
      if (method === 'GET' && (path === '/api/v1/operations/health' || path === '/operations/health')) {
        const snapshot = await this.healthService.collectHealthSnapshot();
        return { status: 200, body: snapshot };
      }

      // All remaining endpoints require authentication
      if (!userId) {
        return {
          status: 401,
          body: { error: 'UNAUTHORIZED', message: 'Authentication required for operations endpoints' }
        };
      }

      // 2. GET /api/v1/operations/metrics
      if (method === 'GET' && (path === '/api/v1/operations/metrics' || path === '/operations/metrics')) {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
          if (!authCheck.isAuthorized && !isAdmin) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for home operations metrics' } };
          }
        } else if (!homeId && !isAdmin) {
          return { status: 403, body: { error: 'FORBIDDEN', message: 'Platform-wide metrics require admin privileges' } };
        }

        const metrics = await this.metricsService.getMetricsSummary({
          homeId,
          since: params.since || null
        });
        return { status: 200, body: metrics };
      }

      // 3. GET /api/v1/operations/events
      if (method === 'GET' && (path === '/api/v1/operations/events' || path === '/operations/events')) {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
          if (!authCheck.isAuthorized && !isAdmin) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for home operational events' } };
          }
        } else if (!homeId && !isAdmin) {
          return { status: 403, body: { error: 'FORBIDDEN', message: 'Cross-home event querying requires admin privileges' } };
        }

        const limit = parseInt(params.limit || '100', 10);
        const offset = parseInt(params.offset || '0', 10);
        const events = await this.auditService.getOperationalEvents({
          homeId,
          deviceId: params.deviceId || null,
          subsystem: params.subsystem || null,
          outcome: params.outcome || null,
          severity: params.severity || null,
          since: params.since || null,
          limit,
          offset
        });

        return { status: 200, body: { events, count: events.length } };
      }

      // 4. GET /api/v1/operations/traces/:correlationId
      if (method === 'GET' && (path.startsWith('/api/v1/operations/traces/') || path.startsWith('/operations/traces/'))) {
        const correlationId = path.replace('/api/v1/operations/traces/', '').replace('/operations/traces/', '');
        if (!correlationId) {
          return { status: 400, body: { error: 'BAD_REQUEST', message: 'Correlation ID required' } };
        }

        const trace = await this.traceService.getTraceByCorrelationId(correlationId);
        if (!trace) {
          return { status: 404, body: { error: 'NOT_FOUND', message: `Trace not found for correlationId ${correlationId}` } };
        }

        // Home authorization check if trace belongs to a specific home
        if (trace.metadata && trace.metadata.homeId && this.homeAuth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId: trace.metadata.homeId });
          if (!authCheck.isAuthorized && !isAdmin) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for this trace' } };
          }
        }

        return { status: 200, body: trace };
      }

      // 5. GET /api/v1/operations/audit/integrity
      if (method === 'GET' && (path === '/api/v1/operations/audit/integrity' || path === '/operations/audit/integrity')) {
        if (!isAdmin) {
          return { status: 403, body: { error: 'FORBIDDEN', message: 'Audit integrity verification requires admin role' } };
        }

        const integrity = await this.auditService.verifyChainIntegrity();
        return { status: 200, body: integrity };
      }

      // 6. GET /api/v1/operations/audit
      if (method === 'GET' && (path === '/api/v1/operations/audit' || path === '/operations/audit')) {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
          if (!authCheck.isAuthorized && !isAdmin) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for home security audit' } };
          }
        } else if (!homeId && !isAdmin) {
          return { status: 403, body: { error: 'FORBIDDEN', message: 'Cross-home security audit query requires admin role' } };
        }

        const limit = parseInt(params.limit || '100', 10);
        const offset = parseInt(params.offset || '0', 10);
        const records = await this.auditService.getSecurityAuditRecords({
          homeId,
          action: params.action || null,
          outcome: params.outcome || null,
          since: params.since || null,
          limit,
          offset
        });

        return { status: 200, body: { records, count: records.length } };
      }

      // 7. GET /api/v1/operations/errors
      if (method === 'GET' && (path === '/api/v1/operations/errors' || path === '/operations/errors')) {
        const homeId = params.homeId || null;
        if (homeId && this.homeAuth) {
          const authCheck = await this.homeAuth.authorizeRequest({ userId, homeId });
          if (!authCheck.isAuthorized && !isAdmin) {
            return { status: 403, body: { error: 'FORBIDDEN', message: 'Unauthorized for home error taxonomy' } };
          }
        } else if (!homeId && !isAdmin) {
          return { status: 403, body: { error: 'FORBIDDEN', message: 'Platform error taxonomy requires admin role' } };
        }

        const metrics = await this.metricsService.getMetricsSummary({
          homeId,
          since: params.since || null
        });

        return {
          status: 200,
          body: {
            failureCodes: metrics.failureCodes,
            totalFailures: metrics.failureCount,
            totalTimeouts: metrics.timeoutCount,
            subsystems: metrics.subsystems
          }
        };
      }

      return null;
    } catch (err) {
      return {
        status: 500,
        body: { error: 'INTERNAL_ERROR', message: err.message }
      };
    }
  }
}

module.exports = { OperationsApiRouter };
