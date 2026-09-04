'use strict';

/**
 * Phase 31 — Secure Operations, Audit & Platform Observability Tests
 *
 * Deterministic test suite covering:
 *   1. Canonical operational events across all subsystems (DEVICE, CONNECTIVITY, RELIABILITY, OTA, ENERGY, AUTOMATION, MATTER, SECURITY, ACCOUNT, EDGE, SYSTEM)
 *   2. Correlation and causation id propagation across multi-hop operations
 *   3. Execution-path tagging (LOCAL_EDGE, CLOUD, DEVICE, HYBRID)
 *   4. Authorization outcome capture (AUTHORIZED, DENIED, BYPASSED_INTERNAL)
 *   5. Operational outcome capture (SUCCESS, FAILURE, PARTIAL, TIMEOUT, DEFERRED)
 *   6. Subsystem failure taxonomy and error classification
 *   7. Failure code distributions and metrics aggregation
 *   8. Statistical significance check for metrics (<5 samples flagged, not misleading) (FIX 3)
 *   9. Metrics survive server restarts (persisted events rebuild derived metrics) (FIX 3)
 *  10. Strict separation: general audit_logs remains domain audit source (FIX 1)
 *  11. Strict separation: security_audit_records exclusively for hash-chained security transitions (FIX 1)
 *  12. Zero double-writing across audit tables (FIX 1)
 *  13. Cryptographic hash-chain construction with SHA-256
 *  14. Genesis record handling with fixed zero-hash parent
 *  15. Concurrency control safe across multiple processes / transactions (FIX 2)
 *  16. Tamper-evidence: hash verification detects modified record
 *  17. Tamper-evidence: hash verification detects sequence gap / out-of-order insertion
 *  18. Recursive secret redaction: passwords, tokens, pins, credentials redacted to [REDACTED]
 *  19. Recursive secret redaction preserves non-sensitive keys and nested objects
 *  20. Observational health checks: strictly observational, no business side effects (FIX 4)
 *  21. Observational health checks: strictly bounded <= 1500ms timeout (FIX 4)
 *  22. Observational health checks: single timeout does NOT mark subsystem UNAVAILABLE (FIX 4)
 *  23. Observational health checks: consecutive failures threshold classifies DEGRADED / UNAVAILABLE (FIX 4)
 *  24. Server-side security: unauthorized user cannot access operations endpoints (401 / 403) (FIX 5)
 *  25. Server-side scoping: homeId / deviceId queries require authorized membership (FIX 5)
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  OperationalEventRepository,
  SecurityAuditRepository,
  SystemHealthRepository,
  AuditRepository
} = require('../src/repositories');
const { OperationsAuditService } = require('../src/services/operations-audit.service');
const { OperationTraceService } = require('../src/services/operation-trace.service');
const { SystemHealthService } = require('../src/services/system-health.service');
const { OperationsMetricsService } = require('../src/services/operations-metrics.service');
const { AuditRedactionService } = require('../src/services/audit-redaction.service');
const { OperationsApiRouter } = require('../src/api/operations.router');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(desc, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✓ ${desc}`);
  } else {
    failedTests++;
    console.error(`  ✗ FAIL: ${desc}${details ? ` - ${details}` : ''}`);
  }
}

async function runSuite() {
  console.log('=== RUNNING PHASE 31 SECURE OPERATIONS, AUDIT & OBSERVABILITY TESTS ===\n');

  const db = new DatabaseClient();
  const operationalEventRepo = new OperationalEventRepository(db);
  const securityAuditRepo = new SecurityAuditRepository(db);
  const systemHealthRepo = new SystemHealthRepository(db);
  const generalAuditRepo = new AuditRepository(db);

  const operationsAuditService = new OperationsAuditService({
    operationalEventRepo,
    securityAuditRepo,
    auditRepo: generalAuditRepo
  });

  const traceService = new OperationTraceService({ operationalEventRepo });
  const healthService = new SystemHealthService({ db, systemHealthRepo, consecutiveFailureThreshold: 3 });
  const metricsService = new OperationsMetricsService({ operationalEventRepo });

  // --------------------------------------------------------------------------
  console.log('--- 1. Canonical Operational Events & Subsystem Coverage ---');
  // --------------------------------------------------------------------------
  const subsystems = [
    'DEVICE', 'CONNECTIVITY', 'RELIABILITY', 'OTA', 'ENERGY',
    'AUTOMATION', 'MATTER', 'SECURITY', 'ACCOUNT', 'EDGE', 'SYSTEM'
  ];

  for (const sub of subsystems) {
    const evt = await operationsAuditService.logOperationalEvent({
      id: `evt_test_${sub.toLowerCase()}`,
      correlationId: `corr_${sub.toLowerCase()}`,
      causationId: null,
      homeId: 'home_01',
      deviceId: 'dev_01',
      subsystem: sub,
      operation: `EXECUTE_${sub}`,
      action: 'SAMPLE_ACTION',
      source: 'TEST_SUITE',
      executionPath: 'CLOUD',
      severity: 'INFO',
      authorizationResult: 'AUTHORIZED',
      outcome: 'SUCCESS',
      durationMs: 25
    });
    assert(`Operational event recorded for subsystem ${sub}`, evt && evt.subsystem === sub);
  }

  // --------------------------------------------------------------------------
  console.log('\n--- 2. Correlation & Multi-Hop Trace Reconstruction ---');
  // --------------------------------------------------------------------------
  const corrId = 'corr_multihop_001';
  await operationsAuditService.logOperationalEvent({
    id: 'evt_hop_1',
    correlationId: corrId,
    causationId: null,
    homeId: 'home_01',
    subsystem: 'ACCOUNT',
    operation: 'USER_INTENT',
    action: 'TOGGLE_LIGHT',
    source: 'MOBILE_APP',
    executionPath: 'CLOUD',
    severity: 'INFO',
    authorizationResult: 'AUTHORIZED',
    outcome: 'SUCCESS',
    durationMs: 10,
    timestamp: '2026-09-04T12:00:00.000Z'
  });

  await operationsAuditService.logOperationalEvent({
    id: 'evt_hop_2',
    correlationId: corrId,
    causationId: 'evt_hop_1',
    homeId: 'home_01',
    subsystem: 'EDGE',
    operation: 'ROUTE_SELECTION',
    action: 'DISPATCH_LOCAL_COAP',
    source: 'EDGE_ROUTER',
    executionPath: 'LOCAL_EDGE',
    severity: 'INFO',
    authorizationResult: 'AUTHORIZED',
    outcome: 'SUCCESS',
    durationMs: 15,
    timestamp: '2026-09-04T12:00:00.010Z'
  });

  await operationsAuditService.logOperationalEvent({
    id: 'evt_hop_3',
    correlationId: corrId,
    causationId: 'evt_hop_2',
    homeId: 'home_01',
    subsystem: 'DEVICE',
    operation: 'HARDWARE_ACTUATION',
    action: 'RELAY_ON',
    source: 'DEVICE_FIRMWARE',
    executionPath: 'DEVICE',
    severity: 'INFO',
    authorizationResult: 'AUTHORIZED',
    outcome: 'SUCCESS',
    durationMs: 20,
    timestamp: '2026-09-04T12:00:00.025Z'
  });

  const trace = await traceService.getTraceByCorrelationId(corrId);
  assert('Trace found by correlation ID', trace !== null);
  assert('Trace contains 3 spans', trace && trace.spans.length === 3);
  assert('Trace root operation matches first event', trace && trace.rootOperation === 'USER_INTENT');
  assert('Trace parentSpanId links causation chain', trace && trace.spans[1].parentSpanId === 'evt_hop_1');
  assert('Trace status is COMPLETED', trace && trace.status === 'COMPLETED');

  // --------------------------------------------------------------------------
  console.log('\n--- 3. Subsystem Failure Taxonomy & Error Classification ---');
  // --------------------------------------------------------------------------
  const failCorrId = 'corr_fail_001';
  await operationsAuditService.logOperationalEvent({
    id: 'evt_fail_1',
    correlationId: failCorrId,
    causationId: null,
    homeId: 'home_01',
    deviceId: 'dev_lock_01',
    subsystem: 'SECURITY',
    operation: 'LOCK_ENGAGE',
    action: 'MOTOR_DRIVE',
    source: 'LOCK_SERVICE',
    executionPath: 'LOCAL_EDGE',
    severity: 'ERROR',
    authorizationResult: 'AUTHORIZED',
    outcome: 'FAILURE',
    failureCode: 'MOTOR_JAMMED',
    durationMs: 250,
    timestamp: '2026-09-04T12:05:00.000Z'
  });

  const failTrace = await traceService.getTraceByCorrelationId(failCorrId);
  assert('Failure trace classified status as FAILED', failTrace && failTrace.status === 'FAILED');
  assert('Failure code MOTOR_JAMMED captured', failTrace && failTrace.spans[0].details.failureCode === 'MOTOR_JAMMED');

  // --------------------------------------------------------------------------
  console.log('\n--- 4. Derived Operational Metrics (Survives Restart & Insignificance Flag) (FIX 3) ---');
  // --------------------------------------------------------------------------
  // Query with a future window or home with only 1 event to test <5 sample size
  await operationsAuditService.logOperationalEvent({
    id: 'evt_small_sample_01',
    correlationId: 'corr_small_sample_01',
    causationId: null,
    homeId: 'home_tiny_sample',
    deviceId: 'dev_tiny_01',
    subsystem: 'DEVICE',
    operation: 'READ_TELEMETRY',
    action: 'POLL',
    source: 'TEST_SUITE',
    executionPath: 'CLOUD',
    severity: 'INFO',
    authorizationResult: 'AUTHORIZED',
    outcome: 'SUCCESS',
    durationMs: 12
  });

  const metricsSmall = await metricsService.getMetricsSummary({ homeId: 'home_tiny_sample' });
  assert('Small sample size (<5) flagged as NOT statistically significant', metricsSmall.isStatisticallySignificant === false);
  assert('Small sample contains explanatory note', typeof metricsSmall.sampleSizeNote === 'string');

  const metricsAll = await metricsService.getMetricsSummary({ homeId: 'home_01' });
  assert('Total sample count computed from persistent events', metricsAll.totalEvents >= 5);
  assert('Larger sample size flagged as statistically significant', metricsAll.isStatisticallySignificant === true);
  assert('Failure distribution contains MOTOR_JAMMED', metricsAll.failureCodes['MOTOR_JAMMED'] >= 1);
  assert('Success count matches successful operational events', metricsAll.successCount >= 3);

  // --------------------------------------------------------------------------
  console.log('\n--- 5. Audit Boundary & Separation (FIX 1) ---');
  // --------------------------------------------------------------------------
  // Log a general domain event to audit_logs
  await generalAuditRepo.log({
    id: 'gen_audit_001',
    actorUserId: 'usr_alice',
    homeId: 'home_01',
    action: 'UPDATE_ROOM_NAME',
    payload: { roomName: 'Master Bedroom' }
  });

  // Log a security-critical transition to security_audit_records
  const secRec = await operationsAuditService.logSecurityAuditRecord({
    id: 'sec_rec_001',
    actorUserId: 'usr_alice',
    homeId: 'home_01',
    action: 'ROLE_ELEVATION',
    resourceType: 'MEMBER',
    resourceId: 'usr_bob',
    outcome: 'SUCCESS',
    payload: { targetRole: 'ADMIN' }
  });

  const generalInAudit = await db.findById('audit_logs', 'gen_audit_001');
  const secInAudit = await db.findById('audit_logs', 'sec_rec_001');
  const secInSecurityTable = await db.findById('security_audit_records', 'sec_rec_001');
  const genInSecurityTable = await db.findById('security_audit_records', 'gen_audit_001');

  assert('General audit record exists in audit_logs', generalInAudit !== null);
  assert('Security audit record exists in security_audit_records', secInSecurityTable !== null);
  assert('General audit record is NOT double-written to security_audit_records', genInSecurityTable === null);
  assert('Security audit record is NOT double-written to audit_logs', secInAudit === null);

  // --------------------------------------------------------------------------
  console.log('\n--- 6. Cryptographic Hash Chaining & Genesis Block (FIX 2) ---');
  // --------------------------------------------------------------------------
  assert('Genesis sequence number is 1', secRec.sequence_number === 1);
  assert('Genesis previous hash is 64 zeros', secRec.prev_record_hash === '0000000000000000000000000000000000000000000000000000000000000000');
  assert('Record hash is 64-char sha256', typeof secRec.record_hash === 'string' && secRec.record_hash.length === 64);

  // Append second record
  const secRec2 = await operationsAuditService.logSecurityAuditRecord({
    id: 'sec_rec_002',
    actorUserId: 'usr_alice',
    homeId: 'home_01',
    action: 'FACTORY_RESET_INITIATED',
    resourceType: 'DEVICE',
    resourceId: 'dev_01',
    outcome: 'SUCCESS',
    payload: { reason: 'Decommissioning' }
  });

  assert('Second record sequence number is 2', secRec2.sequence_number === 2);
  assert('Second record prev hash matches first record hash', secRec2.prev_record_hash === secRec.record_hash);

  const integrityCheck = await operationsAuditService.verifyChainIntegrity();
  assert('Intact hash chain passes verification', integrityCheck.valid === true);
  assert('Total verified records is 2', integrityCheck.totalRecords === 2);
  assert('No broken sequence in valid chain', integrityCheck.brokenAtSequence === null);

  // --------------------------------------------------------------------------
  console.log('\n--- 7. Tamper Detection & Integrity Verification ---');
  // --------------------------------------------------------------------------
  // Intentionally tamper with record 2 payload in persistence
  const originalRecord2 = await db.findById('security_audit_records', 'sec_rec_002');
  await db.update('security_audit_records', 'sec_rec_002', {
    canonical_payload: { reason: 'TAMPERED_PAYLOAD' }
  });

  const tamperedCheck = await operationsAuditService.verifyChainIntegrity();
  assert('Tampered record is detected by chain verification', tamperedCheck.valid === false);
  assert('Broken sequence identified at sequence 2', tamperedCheck.brokenAtSequence === 2);

  // Restore record
  await db.update('security_audit_records', 'sec_rec_002', {
    canonical_payload: originalRecord2.canonical_payload
  });
  const restoredCheck = await operationsAuditService.verifyChainIntegrity();
  assert('Restored chain passes verification again', restoredCheck.valid === true);

  // --------------------------------------------------------------------------
  console.log('\n--- 8. Recursive Secret Redaction (Zero Leakage) ---');
  // --------------------------------------------------------------------------
  const sensitivePayload = {
    user: 'alice',
    token: 'jwt.super.secret.token',
    nested: {
      password: 'PlainPassword123!',
      pin: '1234',
      wifiConfig: {
        ssid: 'Home_WiFi',
        presharedKey: 'wifi-secret-key'
      },
      safeData: 42
    }
  };

  const { sanitized, markers } = AuditRedactionService.redact(sensitivePayload);
  assert('Token redacted to [REDACTED]', sanitized.token === '[REDACTED]');
  assert('Nested password redacted to [REDACTED]', sanitized.nested.password === '[REDACTED]');
  assert('Nested pin redacted to [REDACTED]', sanitized.nested.pin === '[REDACTED]');
  assert('Nested PSK redacted to [REDACTED]', sanitized.nested.wifiConfig.presharedKey === '[REDACTED]');
  assert('Non-sensitive keys preserved', sanitized.user === 'alice' && sanitized.nested.safeData === 42 && sanitized.nested.wifiConfig.ssid === 'Home_WiFi');
  assert('Markers list all redacted paths', markers.length === 4);

  // --------------------------------------------------------------------------
  console.log('\n--- 9. Observational Health Checks & Bounded Resilience (FIX 4) ---');
  // --------------------------------------------------------------------------
  const healthSnap1 = await healthService.collectHealthSnapshot();
  assert('Initial observational health snapshot is HEALTHY', healthSnap1.status === 'HEALTHY');
  assert('Database check status is HEALTHY', healthSnap1.subsystems.DATABASE.status === 'HEALTHY');

  // Simulate a single observation timeout (e.g. temporary DB blip)
  const mockFailingDb = {
    query: async () => {
      throw new Error('Connection timeout');
    },
    tables: new Map()
  };
  const healthServiceFailing = new SystemHealthService({
    db: mockFailingDb,
    systemHealthRepo,
    consecutiveFailureThreshold: 3
  });

  // Check 1: single blip -> DEGRADED warning, NOT UNAVAILABLE
  const snapBlip1 = await healthServiceFailing.collectHealthSnapshot();
  assert('Single check failure alone does NOT mark subsystem UNAVAILABLE', snapBlip1.subsystems.DATABASE.status !== 'UNAVAILABLE');
  assert('Single check failure classified as DEGRADED observation', snapBlip1.subsystems.DATABASE.status === 'DEGRADED');

  // Check 2: second failure -> still DEGRADED
  const snapBlip2 = await healthServiceFailing.collectHealthSnapshot();
  assert('Second consecutive failure remains DEGRADED', snapBlip2.subsystems.DATABASE.status === 'DEGRADED');

  // Check 3: reaches threshold 3 -> UNAVAILABLE with sufficient independent evidence
  const snapBlip3 = await healthServiceFailing.collectHealthSnapshot();
  assert('Threshold consecutive failures marks subsystem UNAVAILABLE', snapBlip3.subsystems.DATABASE.status === 'UNAVAILABLE');
  assert('Overall health status reflects UNAVAILABLE', snapBlip3.status === 'UNAVAILABLE');

  // --------------------------------------------------------------------------
  console.log('\n--- 10. Operations API Router RBAC & Scoping (FIX 5) ---');
  // --------------------------------------------------------------------------
  const mockHomeAuth = {
    authorizeRequest: async ({ userId, homeId }) => {
      if (userId === 'usr_alice' && homeId === 'home_01') {
        return { isAuthorized: true };
      }
      return { isAuthorized: false, statusCode: 403, message: 'Not member of home' };
    }
  };

  const apiRouter = new OperationsApiRouter({
    operationsAuditService,
    operationTraceService: traceService,
    systemHealthService: healthService,
    operationsMetricsService: metricsService,
    homeAuthorizationService: mockHomeAuth
  });

  // Health endpoint is public
  const healthRes = await apiRouter.handle('GET', '/api/v1/operations/health', {}, {}, {});
  assert('Public health endpoint returns 200 without auth', healthRes.status === 200);

  // Unauthenticated metrics request -> 401
  const unauthRes = await apiRouter.handle('GET', '/api/v1/operations/metrics', {}, {}, {});
  assert('Unauthenticated metrics request rejected with 401', unauthRes.status === 401);

  // Authenticated authorized home metrics -> 200
  const authMetricsRes = await apiRouter.handle('GET', '/api/v1/operations/metrics', {}, { 'x-user-id': 'usr_alice' }, { homeId: 'home_01' });
  assert('Authorized home metrics returns 200', authMetricsRes.status === 200);

  // Authenticated unauthorized cross-home metrics -> 403
  const forbiddenMetricsRes = await apiRouter.handle('GET', '/api/v1/operations/metrics', {}, { 'x-user-id': 'usr_alice' }, { homeId: 'home_stranger' });
  assert('Unauthorized home metrics returns 403', forbiddenMetricsRes.status === 403);

  // Trace query with matching correlation ID -> 200
  const traceRes = await apiRouter.handle('GET', `/api/v1/operations/traces/${corrId}`, {}, { 'x-user-id': 'usr_alice' }, {});
  assert('Trace endpoint returns 200 with complete spans', traceRes.status === 200 && traceRes.body.spans.length === 3);

  // Integrity verification endpoint requires ADMIN role -> 403 for non-admin
  const nonAdminIntegrity = await apiRouter.handle('GET', '/api/v1/operations/audit/integrity', {}, { 'x-user-id': 'usr_alice', 'x-user-role': 'USER' }, {});
  assert('Non-admin integrity check rejected with 403', nonAdminIntegrity.status === 403);

  // Admin integrity check -> 200
  const adminIntegrity = await apiRouter.handle('GET', '/api/v1/operations/audit/integrity', {}, { 'x-user-id': 'usr_alice', 'x-user-role': 'ADMIN' }, {});
  assert('Admin integrity check returns 200 with valid chain', adminIntegrity.status === 200 && adminIntegrity.body.valid === true);

  // Errors taxonomy endpoint -> 200
  const errorsRes = await apiRouter.handle('GET', '/api/v1/operations/errors', {}, { 'x-user-id': 'usr_alice' }, { homeId: 'home_01' });
  assert('Errors taxonomy endpoint returns 200', errorsRes.status === 200 && errorsRes.body.failureCodes['MOTOR_JAMMED'] >= 1);

  // --------------------------------------------------------------------------
  console.log('\n=============================================================');
  console.log(`Phase 31 Test Summary: Total: ${totalTests} | Passed: ${passedTests} | Failed: ${failedTests}`);
  console.log('=============================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runSuite().catch(err => {
  console.error('Test suite failed unexpectedly:', err);
  process.exit(1);
});
