'use strict';

/**
 * EH Home — Alert Rules Engine (Phase 43)
 *
 * Evaluates operational metrics and health thresholds against deterministic alert rules,
 * enforcing alert deduplication and correlation to prevent alert storms.
 */

const crypto = require('crypto');

const STANDARD_RULES = {
  API_5XX_SPIKE: {
    id: 'RULE_API_5XX_SPIKE',
    title: 'High 5xx Server Error Rate',
    severity: 'SEV1',
    component: 'API_GATEWAY',
    evaluate: (metrics) => {
      let serverErrors = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('api_server_errors_total')) {
          serverErrors += v;
        }
      }
      return serverErrors >= 5;
    },
    buildContext: (metrics) => {
      let serverErrors = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('api_server_errors_total')) {
          serverErrors += v;
        }
      }
      return { server_errors: serverErrors };
    }
  },
  AUTH_BRUTE_FORCE_SPIKE: {
    id: 'RULE_AUTH_BRUTE_FORCE_SPIKE',
    title: 'Authentication Failure Spike Detected',
    severity: 'SEV2',
    component: 'AUTH_SERVICE',
    evaluate: (metrics) => {
      let failures = 0;
      let rateLimitHits = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('auth_failure_total')) {
          failures += v;
        }
        if (k.startsWith('rate_limit_hits_total')) {
          rateLimitHits += v;
        }
      }
      return failures >= 10 || rateLimitHits >= 20;
    },
    buildContext: (metrics) => {
      let failures = 0;
      let rateLimitHits = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('auth_failure_total')) {
          failures += v;
        }
        if (k.startsWith('rate_limit_hits_total')) {
          rateLimitHits += v;
        }
      }
      return { auth_failures: failures, rate_limit_hits: rateLimitHits };
    }
  },
  FLEET_OTA_FAILURE_SPIKE: {
    id: 'RULE_FLEET_OTA_FAILURE_SPIKE',
    title: 'Fleet OTA Rollout Failures Exceeded Threshold',
    severity: 'SEV1',
    component: 'FLEET_OTA',
    evaluate: (metrics) => {
      let totalFailures = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('ota_attempts_total') && (k.includes('outcome=FAILURE') || k.includes('outcome=FAILED'))) {
          totalFailures += v;
        }
      }
      return totalFailures >= 3;
    },
    buildContext: (metrics) => {
      let totalFailures = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('ota_attempts_total') && (k.includes('outcome=FAILURE') || k.includes('outcome=FAILED'))) {
          totalFailures += v;
        }
      }
      return { ota_failures: totalFailures };
    }
  },
  DEVICE_MASS_DISCONNECT: {
    id: 'RULE_DEVICE_MASS_DISCONNECT',
    title: 'Mass Device Disconnect Spike',
    severity: 'SEV2',
    component: 'DEVICE_GATEWAY',
    evaluate: (metrics) => {
      let disconnects = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('device_disconnects_total')) {
          disconnects += v;
        }
      }
      return disconnects >= 10;
    },
    buildContext: (metrics) => {
      let disconnects = 0;
      for (const [k, v] of Object.entries(metrics.counters || {})) {
        if (k.startsWith('device_disconnects_total')) {
          disconnects += v;
        }
      }
      return { disconnects };
    }
  },
  DATABASE_DEGRADATION: {
    id: 'RULE_DATABASE_DEGRADATION',
    title: 'Database Query Failures or High Latency',
    severity: 'SEV1',
    component: 'DATABASE',
    evaluate: (metrics) => {
      let dbFailures = 0;
      for (const [k, v] of Object.entries(metrics.counters)) {
        if (k.startsWith('db_queries_total') && k.includes('success=false')) {
          dbFailures += v;
        }
      }
      return dbFailures >= 5;
    },
    buildContext: (metrics) => {
      let dbFailures = 0;
      for (const [k, v] of Object.entries(metrics.counters)) {
        if (k.startsWith('db_queries_total') && k.includes('success=false')) {
          dbFailures += v;
        }
      }
      return { db_failures: dbFailures };
    }
  }
};

class AlertRulesService {
  constructor({ alertRepository, notificationService = null, logger = null }) {
    this.alertRepo = alertRepository;
    this.notificationService = notificationService;
    this.logger = logger;
    this.rules = new Map(Object.entries(STANDARD_RULES));
  }

  static computeDeduplicationKey(ruleId, component, discriminator = '') {
    const raw = `${ruleId}:${component}:${discriminator}`;
    return crypto.createHash('sha256').update(raw).digest('hex');
  }

  registerCustomRule(key, ruleDef) {
    if (!ruleDef.id || !ruleDef.title || !ruleDef.evaluate) {
      throw new Error('Custom rule must provide id, title, and evaluate function');
    }
    this.rules.set(key, ruleDef);
  }

  async evaluateMetrics(metricsSnapshot, options = {}) {
    const generatedAlerts = [];

    for (const [ruleKey, rule] of this.rules.entries()) {
      const isTriggered = rule.evaluate(metricsSnapshot);
      if (isTriggered) {
        const context = rule.buildContext ? rule.buildContext(metricsSnapshot) : {};
        const dedupKey = AlertRulesService.computeDeduplicationKey(
          rule.id,
          rule.component,
          options.discriminator || ''
        );

        // Check for existing active alert
        const existingAlert = await this.alertRepo.findByDeduplicationKey(dedupKey, true);

        if (existingAlert) {
          // Deduplicate: increment count and update timestamp
          const updated = await this.alertRepo.update(existingAlert.id, {
            occurrence_count: (existingAlert.occurrence_count || 1) + 1,
            last_triggered_at: new Date().toISOString(),
            context: { ...existingAlert.context, ...context }
          });
          generatedAlerts.push(updated || existingAlert);
        } else {
          // Create fresh alert
          const alertId = `alt-${crypto.randomUUID()}`;
          const newAlert = await this.alertRepo.create({
            id: alertId,
            rule_id: rule.id,
            title: rule.title,
            description: `Automated alert triggered by rule ${rule.id} on ${rule.component}`,
            severity: rule.severity,
            status: 'ACTIVE',
            deduplication_key: dedupKey,
            occurrence_count: 1,
            context,
            first_triggered_at: new Date().toISOString(),
            last_triggered_at: new Date().toISOString()
          });

          generatedAlerts.push(newAlert);

          if (this.logger) {
            this.logger.warn(`Alert triggered: ${rule.id}`, { alertId, ruleId: rule.id, severity: rule.severity });
          }
        }
      }
    }

    return generatedAlerts;
  }

  async resolveAlert(alertId, reason = 'Resolved by operator') {
    const alert = await this.alertRepo.findById(alertId);
    if (!alert) {
      throw new Error(`Alert ${alertId} not found`);
    }

    return await this.alertRepo.update(alertId, {
      status: 'RESOLVED',
      resolved_at: new Date().toISOString(),
      context: { ...alert.context, resolution_reason: reason }
    });
  }

  async listAlerts(filters = {}) {
    return await this.alertRepo.find(filters);
  }
}

module.exports = {
  AlertRulesService,
  STANDARD_RULES
};
