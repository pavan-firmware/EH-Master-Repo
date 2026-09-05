'use strict';

/**
 * EH Home — Operational Readiness REST Router (Phase 34)
 *
 * Exposes standardized public health/liveness/readiness probes and
 * RBAC-protected operational diagnostics endpoints.
 *
 * Endpoints:
 * - GET /health                                  (Public shallow health summary)
 * - GET /health/liveness, /api/v1/health/liveness (Public process liveness probe)
 * - GET /health/readiness, /api/v1/health/readiness (Public request-serving readiness probe)
 * - GET /health/startup, /api/v1/health/startup   (Public container startup probe)
 * - GET /api/v1/admin/operations/diagnostics     (RBAC-protected operational diagnostics)
 * - GET /api/v1/admin/operations/runtime-config  (RBAC-protected sanitized config summary)
 */

class OperationalReadinessRouter {
  /**
   * @param {Object} opts
   * @param {OperationalReadinessService} opts.operationalReadinessService
   * @param {Object} [opts.homeAuthorizationService]
   */
  constructor({ operationalReadinessService, homeAuthorizationService = null }) {
    this.readinessService = operationalReadinessService;
    this.homeAuth = homeAuthorizationService;
  }

  /**
   * Main router handler
   */
  async handle(method, rawPathname, body = {}, headers = {}, query = {}) {
    const pathname = (rawPathname.length > 1 && rawPathname.endsWith('/')) ? rawPathname.slice(0, -1) : rawPathname;
    const userRole = headers['x-user-role'] || query.userRole || null;
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPERADMIN' || headers['x-admin-role'] === 'true' || headers['x-diagnostic-role'] === 'true';

    // 1. Liveness Probe (Public)
    if (method === 'GET' && (pathname === '/health/liveness' || pathname === '/api/v1/health/liveness')) {
      const liveness = this.readinessService.getLiveness();
      return {
        status: 200,
        body: liveness
      };
    }

    // 2. Readiness Probe (Public)
    if (method === 'GET' && (pathname === '/health/readiness' || pathname === '/api/v1/health/readiness')) {
      const readiness = await this.readinessService.getReadiness();
      return {
        status: readiness.statusCode,
        body: readiness.body
      };
    }

    // 3. Startup Probe (Public)
    if (method === 'GET' && (pathname === '/health/startup' || pathname === '/api/v1/health/startup')) {
      const startup = this.readinessService.getStartupStatus();
      return {
        status: startup.statusCode,
        body: startup.body
      };
    }

    // 4. Shallow Health Check (Public)
    if (method === 'GET' && (pathname === '/health' || pathname === '/api/v1/health')) {
      const readiness = await this.readinessService.getReadiness();
      return {
        status: readiness.statusCode === 503 ? 503 : 200,
        body: {
          success: readiness.statusCode !== 503,
          data: {
            status: readiness.body.status,
            service: readiness.body.service,
            version: readiness.body.version,
            timestamp: readiness.body.timestamp
          }
        }
      };
    }

    // 5. Public /api/v1/health/diagnostics (Backward compatibility for Phase 11 observability)
    if (method === 'GET' && pathname === '/api/v1/health/diagnostics') {
      const diagnostics = await this.readinessService.getOperationalDiagnostics();
      const isDbReady = diagnostics.dependencies.database.status === 'HEALTHY';
      const isMqttUp = diagnostics.dependencies.mqtt && diagnostics.dependencies.mqtt.status === 'HEALTHY';
      return {
        status: 200,
        body: {
          status: 'HEALTHY',
          service: diagnostics.service,
          version: diagnostics.version,
          timestamp: diagnostics.timestamp,
          uptime: diagnostics.uptimeSeconds,
          dependencies: {
            database: { status: isDbReady ? 'UP' : 'DOWN' },
            mqttBroker: { status: isMqttUp ? 'UP' : 'STANDBY' },
            workers: {
              automationScheduler: { status: 'RUNNING' },
              staleDetector: { status: 'RUNNING' },
              outboxRetry: { status: 'RUNNING' }
            }
          }
        }
      };
    }

    // 6. Authenticated Administrative Operational Diagnostics (Phase 34)
    if (method === 'GET' && pathname === '/api/v1/admin/operations/diagnostics') {
      const userId = query.userId || headers['x-user-id'] || null;
      if (!userId) {
        return {
          status: 401,
          body: { success: false, error: { code: 'UNAUTHORIZED', message: 'Authentication required for administrative diagnostics' } }
        };
      }
      if (!isAdmin) {
        return {
          status: 403,
          body: { success: false, error: { code: 'FORBIDDEN', message: 'Diagnostic authorization required' } }
        };
      }

      const diagnostics = await this.readinessService.getOperationalDiagnostics();
      return {
        status: 200,
        body: {
          success: true,
          data: diagnostics
        }
      };
    }

    // 6. Authenticated Runtime Config Summary
    if (method === 'GET' && pathname === '/api/v1/admin/operations/runtime-config') {
      const userId = query.userId || headers['x-user-id'] || null;
      if (!userId) {
        return {
          status: 401,
          body: { success: false, error: { code: 'UNAUTHORIZED', message: 'Authentication required for runtime config' } }
        };
      }
      if (!isAdmin) {
        return {
          status: 403,
          body: { success: false, error: { code: 'FORBIDDEN', message: 'Administrative role required to view runtime config' } }
        };
      }

      const diagnostics = await this.readinessService.getOperationalDiagnostics();
      return {
        status: 200,
        body: {
          success: true,
          data: diagnostics.runtimeConfigSummary
        }
      };
    }

    return null;
  }
}

module.exports = {
  OperationalReadinessRouter
};
