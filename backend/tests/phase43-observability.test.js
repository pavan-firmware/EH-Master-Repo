'use strict';

/**
 * Phase 43 — Production Observability, Monitoring & Incident Response Test Suite
 *
 * 30 Test Scenarios validating:
 * 1-5: Structured Logging & Sensitive Redaction
 * 6-10: Bounded Metrics Engine & Histogram Retention
 * 11-15: Deterministic Alert Rules & Deduplication
 * 16-20: Incident Lifecycle State Machine & Severity Escalation
 * 21-25: Federated Incident Timeline Aggregation (Zero Data Duplication)
 * 26-30: Observability REST API, RBAC Protection & Correlation IDs
 */

const assert = require('assert');
const crypto = require('crypto');
const { createApp } = require('../src/app');
const { InMemoryDatabaseAdapter } = require('../src/shared/in-memory-db-adapter');
const { StructuredLogger } = require('../src/shared/structured-logger');
const { MetricsService } = require('../src/services/metrics.service');
const { AlertRulesService, STANDARD_RULES } = require('../src/services/alert-rules.service');
const { IncidentService } = require('../src/services/incident.service');
const { ObservabilityApiRouter } = require('../src/api/observability.router');
const { PlatformIncidentRepository } = require('../src/repositories/platform-incident.repository');
const { PlatformAlertRepository } = require('../src/repositories/platform-alert.repository');
const { OperationalEventRepository } = require('../src/repositories/operational-event.repository');
const { SecurityAuditRepository } = require('../src/repositories/security-audit.repository');

async function runSuite() {
  console.log('=== PHASE 43: PRODUCTION OBSERVABILITY & INCIDENT RESPONSE TEST SUITE ===\n');

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  ✓ Scenario ${passed + failed + 1}: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  ✗ Scenario ${passed + failed + 1}: ${name}`);
      console.error(`    Error: ${err.message}`);
      if (err.stack) console.error(err.stack);
      failed++;
    }
  }

  // --- PART 1: STRUCTURED LOGGING & REDACTION (1-5) ---

  await test('StructuredLogger emits valid JSON with standard metadata', async () => {
    let captured = null;
    const logger = new StructuredLogger({
      serviceName: 'test-backend',
      sink: (msg) => { captured = JSON.parse(msg); }
    });

    logger.info('System boot complete', { version: '1.0.0', port: 8080 });

    assert.ok(captured, 'Log entry should be emitted');
    assert.strictEqual(captured.level, 'INFO');
    assert.strictEqual(captured.service, 'test-backend');
    assert.strictEqual(captured.message, 'System boot complete');
    assert.strictEqual(captured.context.version, '1.0.0');
    assert.strictEqual(captured.context.port, 8080);
    assert.ok(captured.timestamp, 'Timestamp must exist');
  });

  await test('StructuredLogger automatically redacts credentials, tokens, and secrets', async () => {
    let captured = null;
    const logger = new StructuredLogger({
      sink: (msg) => { captured = JSON.parse(msg); }
    });

    logger.warn('User login attempt failed', {
      email: 'admin@eh.com',
      password: 'SuperSecretPassword123!',
      api_key: 'eh_live_98374982374928374',
      sessionToken: 'jwt-token-value-here',
      user_credential: 'vault-credential-token',
      user_metadata: { private_key: 'PEM-DATA-SECRET' }
    });

    assert.ok(captured);
    assert.strictEqual(captured.context.email, 'admin@eh.com');
    assert.strictEqual(captured.context.password, '[REDACTED]');
    assert.strictEqual(captured.context.api_key, '[REDACTED]');
    assert.strictEqual(captured.context.sessionToken, '[REDACTED]');
    assert.strictEqual(captured.context.user_credential, '[REDACTED]');
    assert.strictEqual(captured.context.user_metadata.private_key, '[REDACTED]');
  });

  await test('StructuredLogger handles circular object references without throwing', async () => {
    let captured = null;
    const logger = new StructuredLogger({
      sink: (msg) => { captured = JSON.parse(msg); }
    });

    const circularObj = { name: 'RootNode' };
    circularObj.self = circularObj;

    assert.doesNotThrow(() => {
      logger.info('Circular reference check', { payload: circularObj });
    });

    assert.ok(captured);
    assert.strictEqual(captured.context.payload.name, 'RootNode');
    assert.strictEqual(captured.context.payload.self, '[CIRCULAR]');
  });

  await test('StructuredLogger formats error objects with stack traces safely', async () => {
    let captured = null;
    const logger = new StructuredLogger({
      errorSink: (msg) => { captured = JSON.parse(msg); }
    });

    const err = new Error('Database connection failed');
    logger.error('Failed to query repository', { queryId: 'q-101' }, err);

    assert.ok(captured);
    assert.strictEqual(captured.level, 'ERROR');
    assert.strictEqual(captured.message, 'Failed to query repository');
    assert.strictEqual(captured.error.name, 'Error');
    assert.strictEqual(captured.error.message, 'Database connection failed');
    assert.ok(captured.error.stack, 'Error stack trace must be recorded');
  });

  await test('StructuredLogger child logger inherits and propagates correlation IDs', async () => {
    let captured = null;
    const rootLogger = new StructuredLogger({
      sink: (msg) => { captured = JSON.parse(msg); }
    });

    const reqLogger = rootLogger.child({ correlationId: 'req-corr-999', userId: 'usr-123' });
    reqLogger.info('Processing device command');

    assert.ok(captured);
    assert.strictEqual(captured.correlation_id, 'req-corr-999');
    assert.strictEqual(captured.context.userId, 'usr-123');
  });

  // --- PART 2: BOUNDED METRICS ENGINE (6-10) ---

  await test('MetricsService records counters across labels correctly', async () => {
    const metrics = new MetricsService();

    metrics.incrementCounter('http_requests_total', 1, { method: 'GET', route: '/api/v1/devices' });
    metrics.incrementCounter('http_requests_total', 2, { method: 'GET', route: '/api/v1/devices' });
    metrics.incrementCounter('http_requests_total', 1, { method: 'POST', route: '/api/v1/devices' });

    const snapshot = metrics.getSnapshot();
    assert.strictEqual(snapshot.counters['http_requests_total{method=GET,route=/api/v1/devices}'], 3);
    assert.strictEqual(snapshot.counters['http_requests_total{method=POST,route=/api/v1/devices}'], 1);
  });

  await test('MetricsService manages gauge values with updates', async () => {
    const metrics = new MetricsService();

    metrics.setGauge('active_mqtt_connections', 142);
    assert.strictEqual(metrics.getSnapshot().gauges['active_mqtt_connections'], 142);

    metrics.setGauge('active_mqtt_connections', 150);
    assert.strictEqual(metrics.getSnapshot().gauges['active_mqtt_connections'], 150);
  });

  await test('MetricsService calculates histogram percentiles and statistics', async () => {
    const metrics = new MetricsService();

    for (let i = 1; i <= 100; i++) {
      metrics.recordHistogram('db_query_ms', i);
    }

    const snapshot = metrics.getSnapshot();
    const h = snapshot.histograms['db_query_ms'];
    assert.strictEqual(h.count, 100);
    assert.strictEqual(h.min, 1);
    assert.strictEqual(h.max, 100);
    assert.strictEqual(h.avg, 50.5);
    assert.strictEqual(h.p50, 51);
    assert.strictEqual(h.p90, 91);
    assert.strictEqual(h.p99, 100);
  });

  await test('MetricsService bounds sample retention to prevent memory growth', async () => {
    const maxSamples = 50;
    const metrics = new MetricsService({ maxSamples });

    for (let i = 1; i <= 200; i++) {
      metrics.recordHistogram('bounded_metric', i);
    }

    const entry = metrics.histograms.get('bounded_metric');
    assert.strictEqual(entry.samples.length, maxSamples);
    assert.strictEqual(entry.count, 200);
    assert.strictEqual(entry.samples[0], 151);
    assert.strictEqual(entry.samples[entry.samples.length - 1], 200);
  });

  await test('MetricsService extracts category-filtered snapshots', async () => {
    const metrics = new MetricsService();

    metrics.recordApiRequest({ method: 'GET', route: '/api/v1/homes', statusCode: 200, durationMs: 15 });
    metrics.recordAuthAttempt({ success: false, reason: 'invalid_password' });
    metrics.recordOtaAttempt({ outcome: 'SUCCESS' });
    metrics.recordDatabaseQuery({ durationMs: 4, success: true });

    const apiSnap = metrics.getSnapshot('api');
    assert.ok(Object.keys(apiSnap.counters).some(k => k.startsWith('api_')));
    assert.strictEqual(Object.keys(apiSnap.counters).filter(k => k.startsWith('auth_')).length, 0);

    const otaSnap = metrics.getSnapshot('ota');
    assert.ok(Object.keys(otaSnap.counters).some(k => k.startsWith('ota_')));
  });

  // --- PART 3: DETERMINISTIC ALERT RULES & DEDUPLICATION (11-15) ---

  await test('AlertRulesService evaluates API 5xx spike rule', async () => {
    const db = new InMemoryDatabaseAdapter();
    const alertRepo = new PlatformAlertRepository(db);
    const alertService = new AlertRulesService({ alertRepository: alertRepo });
    const metrics = new MetricsService();

    // Under threshold (4 errors)
    for (let i = 0; i < 4; i++) {
      metrics.recordApiRequest({ method: 'POST', route: '/api/v1/auth/login', statusCode: 500, durationMs: 100 });
    }
    let alerts = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(alerts.length, 0);

    // 5th error hits threshold
    metrics.recordApiRequest({ method: 'POST', route: '/api/v1/auth/login', statusCode: 500, durationMs: 100 });
    alerts = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(alerts.length, 1);
    assert.strictEqual(alerts[0].rule_id, 'RULE_API_5XX_SPIKE');
    assert.strictEqual(alerts[0].severity, 'SEV1');
  });

  await test('AlertRulesService evaluates auth brute force spike rule', async () => {
    const db = new InMemoryDatabaseAdapter();
    const alertRepo = new PlatformAlertRepository(db);
    const alertService = new AlertRulesService({ alertRepository: alertRepo });
    const metrics = new MetricsService();

    for (let i = 0; i < 10; i++) {
      metrics.recordAuthAttempt({ success: false, reason: 'bad_credentials' });
    }

    const alerts = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(alerts.length, 1);
    assert.strictEqual(alerts[0].rule_id, 'RULE_AUTH_BRUTE_FORCE_SPIKE');
    assert.strictEqual(alerts[0].severity, 'SEV2');
  });

  await test('AlertRulesService evaluates fleet OTA failure spike rule', async () => {
    const db = new InMemoryDatabaseAdapter();
    const alertRepo = new PlatformAlertRepository(db);
    const alertService = new AlertRulesService({ alertRepository: alertRepo });
    const metrics = new MetricsService();

    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'CHECKSUM_MISMATCH' });
    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'SIGNATURE_INVALID' });
    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'TIMEOUT' });

    const alerts = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(alerts.length, 1);
    assert.strictEqual(alerts[0].rule_id, 'RULE_FLEET_OTA_FAILURE_SPIKE');
  });

  await test('AlertRulesService deduplicates identical active alerts and increments count', async () => {
    const db = new InMemoryDatabaseAdapter();
    const alertRepo = new PlatformAlertRepository(db);
    const alertService = new AlertRulesService({ alertRepository: alertRepo });
    const metrics = new MetricsService();

    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'TIMEOUT' });
    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'TIMEOUT' });
    metrics.recordOtaAttempt({ outcome: 'FAILURE', failureReason: 'TIMEOUT' });

    // 1st evaluation -> creates alert
    const firstEval = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(firstEval.length, 1);
    const alertId = firstEval[0].id;
    assert.strictEqual(firstEval[0].occurrence_count, 1);

    // 2nd evaluation -> deduplicates
    const secondEval = await alertService.evaluateMetrics(metrics.getSnapshot());
    assert.strictEqual(secondEval.length, 1);
    assert.strictEqual(secondEval[0].id, alertId);
    assert.strictEqual(secondEval[0].occurrence_count, 2);

    const totalInDb = await alertRepo.count();
    assert.strictEqual(totalInDb, 1, 'Deduplication must not insert duplicate rows');
  });

  await test('AlertRulesService resolves active alert with reason', async () => {
    const db = new InMemoryDatabaseAdapter();
    const alertRepo = new PlatformAlertRepository(db);
    const alertService = new AlertRulesService({ alertRepository: alertRepo });

    const alert = await alertRepo.create({
      id: 'alt-test-01',
      rule_id: 'RULE_DEVICE_MASS_DISCONNECT',
      title: 'Mass Device Disconnect',
      deduplication_key: 'dedup-test-key',
      severity: 'SEV2',
      status: 'ACTIVE'
    });

    const resolved = await alertService.resolveAlert('alt-test-01', 'Network switch restored');
    assert.strictEqual(resolved.status, 'RESOLVED');
    assert.ok(resolved.resolved_at);
    assert.strictEqual(resolved.context.resolution_reason, 'Network switch restored');
  });

  // --- PART 4: INCIDENT LIFECYCLE STATE MACHINE (16-20) ---

  await test('IncidentService creates incident with OPEN status and milestone timestamp', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({
      title: 'Database connection pool exhausted',
      description: 'Multiple microservices reporting SQL connection timeout',
      severity: 'SEV1',
      affected_component: 'POSTGRESQL',
      affected_homes: ['home-01', 'home-02']
    });

    assert.ok(inc.id.startsWith('inc-'));
    assert.strictEqual(inc.status, 'OPEN');
    assert.strictEqual(inc.severity, 'SEV1');
    assert.strictEqual(inc.affected_component, 'POSTGRESQL');
    assert.ok(inc.opened_at);
  });

  await test('IncidentService traverses complete allowed lifecycle transitions', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({
      title: 'MQTT Broker Latency Spike',
      severity: 'SEV2',
      affected_component: 'MQTT_BROKER'
    });

    // OPEN -> ACKNOWLEDGED
    let cur = await incidentService.updateIncidentStatus(inc.id, 'ACKNOWLEDGED', { actorUserId: 'usr-ops-1' });
    assert.strictEqual(cur.status, 'ACKNOWLEDGED');
    assert.ok(cur.acknowledged_at);

    // ACKNOWLEDGED -> INVESTIGATING
    cur = await incidentService.updateIncidentStatus(inc.id, 'INVESTIGATING');
    assert.strictEqual(cur.status, 'INVESTIGATING');

    // INVESTIGATING -> MITIGATING
    cur = await incidentService.updateIncidentStatus(inc.id, 'MITIGATING');
    assert.strictEqual(cur.status, 'MITIGATING');
    assert.ok(cur.mitigated_at);

    // MITIGATING -> RESOLVED
    cur = await incidentService.updateIncidentStatus(inc.id, 'RESOLVED', {
      rootCause: 'Garbage collection pause on broker cluster',
      mitigationSummary: 'Adjusted JVM heap limit and added node'
    });
    assert.strictEqual(cur.status, 'RESOLVED');
    assert.ok(cur.resolved_at);
    assert.strictEqual(cur.root_cause, 'Garbage collection pause on broker cluster');

    // RESOLVED -> CLOSED
    cur = await incidentService.updateIncidentStatus(inc.id, 'CLOSED');
    assert.strictEqual(cur.status, 'CLOSED');
    assert.ok(cur.closed_at);
  });

  await test('IncidentService rejects invalid status transitions', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({
      title: 'Test Incident',
      severity: 'SEV3'
    });

    // OPEN -> RESOLVED (invalid jump)
    await assert.rejects(
      async () => {
        await incidentService.updateIncidentStatus(inc.id, 'RESOLVED');
      },
      /Invalid incident status transition/
    );

    // Close incident
    await incidentService.updateIncidentStatus(inc.id, 'CLOSED');

    // CLOSED -> OPEN (terminal state cannot transition)
    await assert.rejects(
      async () => {
        await incidentService.updateIncidentStatus(inc.id, 'OPEN');
      },
      /Invalid incident status transition/
    );
  });

  await test('IncidentService assigns and reassigns Incident Commander', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({
      title: 'API Gateway Rate Limit Failure',
      severity: 'SEV2'
    });

    const updated = await incidentService.assignCommander(inc.id, 'usr-commander-42');
    assert.strictEqual(updated.commander_user_id, 'usr-commander-42');
  });

  await test('IncidentService updates severity and tracks audit metadata', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({
      title: 'Degraded Sync Performance',
      severity: 'SEV3'
    });

    const escalated = await incidentService.updateSeverity(inc.id, 'SEV1', 'Cascading sync backlog affecting 10k homes');
    assert.strictEqual(escalated.severity, 'SEV1');
    assert.ok(Object.keys(escalated.metadata).some(k => k.startsWith('severity_change_')));
  });

  // --- PART 5: TIMELINE AGGREGATION & INVARIANT VALIDATION (21-25) ---

  await test('IncidentService links platform alerts to incident', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const alertRepo = new PlatformAlertRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo, alertRepository: alertRepo });

    const inc = await incidentService.createIncident({ title: 'Mass Disconnect Incident', severity: 'SEV2' });
    const alt = await alertRepo.create({
      id: 'alt-55',
      rule_id: 'RULE_DEVICE_MASS_DISCONNECT',
      title: '100 devices disconnected',
      deduplication_key: 'dedup-55',
      severity: 'SEV2'
    });

    const linkResult = await incidentService.linkAlert(inc.id, alt.id);
    assert.strictEqual(linkResult.linked, true);

    const updatedAlert = await alertRepo.findById(alt.id);
    assert.strictEqual(updatedAlert.incident_id, inc.id);
  });

  await test('IncidentService aggregates milestone timeline entries chronologically', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo });

    const inc = await incidentService.createIncident({ title: 'Timeline Milestone Test', severity: 'SEV3' });
    await incidentService.updateIncidentStatus(inc.id, 'ACKNOWLEDGED');
    await incidentService.updateIncidentStatus(inc.id, 'INVESTIGATING');
    await incidentService.updateIncidentStatus(inc.id, 'MITIGATING');
    await incidentService.updateIncidentStatus(inc.id, 'RESOLVED', { rootCause: 'Bug in auth validator' });

    const timelineData = await incidentService.getIncidentTimeline(inc.id);
    assert.strictEqual(timelineData.incident_id, inc.id);
    assert.strictEqual(timelineData.current_status, 'RESOLVED');
    assert.ok(timelineData.timeline_entry_count >= 4);

    const types = timelineData.timeline.map(t => t.details.status);
    assert.ok(types.includes('OPEN'));
    assert.ok(types.includes('ACKNOWLEDGED'));
    assert.ok(types.includes('MITIGATING'));
    assert.ok(types.includes('RESOLVED'));
  });

  await test('Incident timeline aggregates linked alerts and referenced operational events', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const alertRepo = new PlatformAlertRepository(db);
    const opEventRepo = new OperationalEventRepository(db);
    const incidentService = new IncidentService({
      incidentRepository: incidentRepo,
      alertRepository: alertRepo,
      operationalEventRepository: opEventRepo
    });

    const opEvent = await opEventRepo.create({
      id: 'op-ev-100',
      operation: 'SYSTEM_ERROR',
      subsystem: 'API_GATEWAY',
      action: 'PROCESS_REQUEST',
      source: 'GATEWAY',
      severity: 'ERROR',
      outcome: 'FAILURE',
      failureCode: 'CONN_REFUSED'
    });

    const inc = await incidentService.createIncident({
      title: 'Correlated Event Incident',
      severity: 'SEV2',
      correlated_event_ids: [opEvent.id]
    });

    const alt = await alertRepo.create({
      id: 'alt-77',
      rule_id: 'RULE_API_5XX_SPIKE',
      title: '5xx spike detected',
      deduplication_key: 'dedup-77',
      incident_id: inc.id
    });

    const timelineData = await incidentService.getIncidentTimeline(inc.id);
    assert.ok(timelineData.timeline.some(t => t.type === 'ALERT' && t.details.alert_id === 'alt-77'));
    assert.ok(timelineData.timeline.some(t => t.type === 'OPERATIONAL_EVENT' && t.details.event_id === 'op-ev-100'));
  });

  await test('Incident timeline references security audit records without duplicating rows', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const auditRepo = new SecurityAuditRepository(db);
    const incidentService = new IncidentService({
      incidentRepository: incidentRepo,
      securityAuditRepository: auditRepo
    });

    const auditRec = await auditRepo.appendRecord({
      id: 'sec-aud-99',
      actorUserId: 'attacker-ip',
      action: 'SUSPICIOUS_TOKEN_PROBE',
      resourceType: 'AUTH_SERVICE',
      outcome: 'DENIED'
    });

    const inc = await incidentService.createIncident({
      title: 'Security Probe Incident',
      severity: 'SEV1',
      correlated_audit_record_ids: [auditRec.id]
    });

    const timelineData = await incidentService.getIncidentTimeline(inc.id);
    const secEntry = timelineData.timeline.find(t => t.type === 'SECURITY_AUDIT');
    assert.ok(secEntry);
    assert.strictEqual(secEntry.details.record_id, 'sec-aud-99');
    assert.strictEqual(secEntry.details.action, 'SUSPICIOUS_TOKEN_PROBE');

    // Invariant: Verify table count remains isolated
    const incCount = await incidentRepo.count();
    const auditCount = await auditRepo.count ? await auditRepo.count() : (await db.find('security_audit_records')).length;
    assert.strictEqual(incCount, 1);
    assert.strictEqual(auditCount, 1);
  });

  await test('Incident timeline entries are chronologically sorted (ascending)', async () => {
    const db = new InMemoryDatabaseAdapter();
    const incidentRepo = new PlatformIncidentRepository(db);
    const alertRepo = new PlatformAlertRepository(db);
    const incidentService = new IncidentService({ incidentRepository: incidentRepo, alertRepository: alertRepo });

    const inc = await incidentService.createIncident({
      title: 'Time Ordering Test',
      severity: 'SEV2'
    });

    // Alert 1 (earlier)
    await alertRepo.create({
      id: 'alt-early',
      rule_id: 'R1',
      title: 'Early Alert',
      deduplication_key: 'd-1',
      incident_id: inc.id,
      first_triggered_at: new Date(Date.now() - 60000).toISOString()
    });

    // Alert 2 (later)
    await alertRepo.create({
      id: 'alt-late',
      rule_id: 'R2',
      title: 'Late Alert',
      deduplication_key: 'd-2',
      incident_id: inc.id,
      first_triggered_at: new Date(Date.now() + 60000).toISOString()
    });

    const timelineData = await incidentService.getIncidentTimeline(inc.id);
    for (let i = 0; i < timelineData.timeline.length - 1; i++) {
      const current = new Date(timelineData.timeline[i].timestamp).getTime();
      const next = new Date(timelineData.timeline[i + 1].timestamp).getTime();
      assert.ok(current <= next, `Timeline items must be chronological: ${current} <= ${next}`);
    }
  });

  // --- PART 6: REST API, RBAC & CORRELATION IDS (26-30) ---

  await test('GET /api/v1/admin/observability/metrics enforces 403 for non-admin users', async () => {
    const app = createApp();

    let resCode = null;
    let resBody = null;
    const res = {
      writeHead: (code, headers) => { resCode = code; },
      end: (data) => { resBody = JSON.parse(data); }
    };

    // Member request (not admin/operator)
    await app.handleRequest({
      method: 'GET',
      url: '/api/v1/admin/observability/metrics',
      headers: {},
      user: { id: 'usr-regular-member', role: 'MEMBER' }
    }, res);

    assert.strictEqual(resCode, 403);
    assert.strictEqual(resBody.error.code, 'FORBIDDEN');
  });

  await test('GET /api/v1/admin/observability/metrics returns snapshot for authorized admin', async () => {
    const app = createApp();

    let resCode = null;
    let resBody = null;
    const res = {
      writeHead: (code, headers) => { resCode = code; },
      end: (data) => { resBody = JSON.parse(data); }
    };

    await app.handleRequest({
      method: 'GET',
      url: '/api/v1/admin/observability/metrics?category=api',
      headers: {},
      user: { id: 'usr-admin-1', role: 'ADMIN' }
    }, res);

    assert.strictEqual(resCode, 200);
    assert.strictEqual(resBody.success, true);
    assert.ok(resBody.data.counters !== undefined);
  });

  await test('Observability REST API supports incident creation, status transition, and timeline fetching', async () => {
    const app = createApp();

    let resCode = null;
    let resBody = null;
    const makeRes = () => ({
      writeHead: (code) => { resCode = code; },
      end: (data) => { resBody = JSON.parse(data); }
    });

    // 1. Create incident
    await app.handleRequest({
      method: 'POST',
      url: '/api/v1/admin/observability/incidents',
      headers: { 'content-type': 'application/json' },
      user: { id: 'usr-admin-1', role: 'ADMIN' },
      body: {
        title: 'API Degradation Incident',
        severity: 'SEV2',
        affected_component: 'API_GATEWAY'
      }
    }, makeRes());

    assert.strictEqual(resCode, 201);
    const incidentId = resBody.data.id;

    // 2. Transition status to ACKNOWLEDGED
    await app.handleRequest({
      method: 'PATCH',
      url: `/api/v1/admin/observability/incidents/${incidentId}/status`,
      headers: { 'content-type': 'application/json' },
      user: { id: 'usr-admin-1', role: 'ADMIN' },
      body: { status: 'ACKNOWLEDGED' }
    }, makeRes());

    assert.strictEqual(resCode, 200);
    assert.strictEqual(resBody.data.status, 'ACKNOWLEDGED');

    // 3. Fetch timeline
    await app.handleRequest({
      method: 'GET',
      url: `/api/v1/admin/observability/incidents/${incidentId}/timeline`,
      headers: {},
      user: { id: 'usr-admin-1', role: 'ADMIN' }
    }, makeRes());

    assert.strictEqual(resCode, 200);
    assert.strictEqual(resBody.data.incident_id, incidentId);
    assert.ok(resBody.data.timeline.length >= 2);
  });

  await test('Observability endpoints enforce administrative rate limiting', async () => {
    const app = createApp();

    let lastCode = 200;
    for (let i = 0; i < 150; i++) {
      await app.handleRequest({
        method: 'GET',
        url: '/api/v1/admin/observability/metrics',
        headers: {},
        user: { id: 'usr-admin-rate-tester', role: 'ADMIN' },
        socket: { remoteAddress: '198.51.100.25' }
      }, {
        writeHead: (code) => { lastCode = code; },
        end: () => {}
      });
      if (lastCode === 429) break;
    }

    assert.strictEqual(lastCode, 429, 'Excessive administrative requests must trigger rate limit 429');
  });

  await test('HTTP requests attach and return X-Correlation-ID in response headers', async () => {
    const app = createApp();

    let responseHeaders = {};
    const res = {
      writeHead: (code, headers) => { responseHeaders = headers; },
      end: () => {}
    };

    await app.handleRequest({
      method: 'GET',
      url: '/health',
      headers: { 'x-correlation-id': 'client-corr-xyz-123' }
    }, res);

    assert.strictEqual(responseHeaders['X-Correlation-ID'], 'client-corr-xyz-123');
  });

  console.log(`\n=== RESULTS: ${passed}/${passed + failed} SCENARIOS PASSED ===`);
  if (failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  runSuite();
}

module.exports = { runSuite };
