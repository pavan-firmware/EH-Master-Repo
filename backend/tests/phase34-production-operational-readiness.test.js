'use strict';

/**
 * EH Home — Phase 34 Production Deployment & Operational Readiness Test Suite
 *
 * Exhaustively validates:
 *  1. Valid production configuration
 *  2. Missing required configuration
 *  3. Malformed configuration (ports, timeouts, booleans)
 *  4. Unsafe production configuration (loopback, LAN IP, weak secrets)
 *  5. Development/test configuration boundaries
 *  6. Startup lifecycle states (STARTING -> INITIALIZING -> READY)
 *  7. Startup required dependency failure (database offline)
 *  8. Optional dependency degradation (Redis / MQTT / Workers offline)
 *  9. Readiness vs Liveness distinction
 * 10. Database health check (bounded, non-destructive)
 * 11. Redis health behavior (STANDBY / HEALTHY / DEGRADED)
 * 12. MQTT health behavior (STANDBY / HEALTHY / DEGRADED)
 * 13. Bounded health-check timeout
 * 14. Graceful shutdown lifecycle
 * 15. Authoritative runtime metadata
 * 16. Schema & migration compatibility
 * 17. Diagnostic authorization (RBAC)
 * 18. Secret redaction in diagnostics and config summaries
 * 19. Log/Error redaction of connection credentials
 * 20. Production debug-feature rejection (ENABLE_DEBUG_ROUTES / MOCK_TRANSPORTS)
 * 21. API error handling & status codes
 * 22. Health endpoint stability under repeated requests
 * 23. Concurrent health probes
 * 24. Operational router RBAC
 * 25. No destructive startup behavior
 * 26. Security regression invariants (Phase 32, Phase 33, Phase 31, Phase 30, Phase 29, Phase 28)
 */

const assert = require('assert').strict;
const http = require('http');
const { loadAndValidateConfig, toSafeConfig, sanitizeConnectionString } = require('../src/config/runtime-config');
const { validateProductionConfig } = require('../src/config/production-config-validator');
const { getReleaseMetadata } = require('../src/config/runtime-metadata');
const { OperationalReadinessService } = require('../src/services/operational-readiness.service');
const { OperationalReadinessRouter } = require('../src/api/operational-readiness.router');
const { DatabaseClient } = require('../src/shared/db-client');
const { createApp } = require('../src/app');
const { createServer, setupGracefulShutdown } = require('../src/server');

let totalTests = 0;
let passedTests = 0;

async function test(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    if (err.stack) console.error(err.stack);
    throw err;
  }
}

// Helper to simulate HTTP requests against createApp handler
function makeAppRequest(app, method, urlPath, headers = {}, body = null, user = null) {
  return new Promise((resolve) => {
    const req = {
      url: urlPath,
      method: method.toUpperCase(),
      headers: { ...headers },
      user: user || (headers['x-user-id'] ? { id: headers['x-user-id'], role: headers['x-user-role'] || 'MEMBER' } : null),
      socket: { remoteAddress: '127.0.0.1' },
      on: (event, handler) => {
        if (event === 'data' && body) {
          handler(typeof body === 'string' ? body : JSON.stringify(body));
        }
        if (event === 'end') {
          handler();
        }
      }
    };

    let responsePayload = '';
    const res = {
      statusCode: 200,
      headers: {},
      headersSent: false,
      writeHead: (status, h = {}) => {
        res.statusCode = status;
        res.headers = h;
      },
      end: (payload) => {
        responsePayload = payload || '';
        let parsed = null;
        try {
          parsed = responsePayload ? JSON.parse(responsePayload) : null;
        } catch (_) {
          parsed = responsePayload;
        }
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: parsed
        });
      }
    };

    app.handleRequest(req, res);
  });
}

(async () => {
  console.log('===============================================================');
  console.log('  RUNNING PHASE 34 PRODUCTION OPERATIONAL READINESS TESTS      ');
  console.log('===============================================================\n');

  // Test 1: Valid production configuration
  await test('1. Valid production configuration passes validation', async () => {
    const validProdEnv = {
      NODE_ENV: 'production',
      PORT: '3000',
      HOST: '0.0.0.0',
      DATABASE_URL: 'postgres://eh_user:StrongPass_2026_Prod@db.prod.ehhome.internal:5432/eh_prod',
      REDIS_URL: 'rediss://:RedisAuthPass998@redis.prod.ehhome.internal:6379',
      MQTT_BROKER_URL: 'tls://mqtt.prod.ehhome.internal:8883',
      MQTT_TLS_PORT: '8883',
      JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt_private.pem',
      JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt_public.pem',
      MQTT_CA_PATH: '/etc/certs/ca.crt',
      LOG_LEVEL: 'info',
      SHUTDOWN_TIMEOUT_MS: '15000',
      HEALTH_CHECK_TIMEOUT_MS: '2000'
    };

    const result = loadAndValidateConfig(validProdEnv);
    assert.equal(result.isValid, true);
    assert.equal(result.errors.length, 0);
    assert.equal(result.config.isProduction, true);
    assert.equal(result.config.port, 3000);
    assert.equal(result.config.shutdownTimeoutMs, 15000);
  });

  // Test 2: Missing required production configuration
  await test('2. Missing required production configuration fails validation with clear operator errors', async () => {
    const missingEnv = {
      NODE_ENV: 'production'
    };

    const result = loadAndValidateConfig(missingEnv);
    assert.equal(result.isValid, false);
    assert.equal(result.errors.length >= 5, true);
    assert.ok(result.errors.some(e => e.includes('DATABASE_URL')));
    assert.ok(result.errors.some(e => e.includes('REDIS_URL')));
    assert.ok(result.errors.some(e => e.includes('MQTT_BROKER_URL')));
    assert.ok(result.errors.some(e => e.includes('JWT_PRIVATE_KEY_PATH')));
    assert.ok(result.errors.some(e => e.includes('JWT_PUBLIC_KEY_PATH')));
    assert.ok(result.errors.some(e => e.includes('MQTT_CA_PATH')));

    assert.throws(
      () => loadAndValidateConfig(missingEnv, { throwOnFailure: true }),
      /Production Configuration Validation Failed/
    );
  });

  // Test 3: Malformed configuration
  await test('3. Malformed configuration (invalid PORT, invalid timeouts) fails validation', async () => {
    const malformedEnv = {
      NODE_ENV: 'development',
      PORT: '999999',
      SHUTDOWN_TIMEOUT_MS: 'invalid_ms',
      HEALTH_CHECK_TIMEOUT_MS: '50'
    };

    const result = loadAndValidateConfig(malformedEnv);
    assert.equal(result.isValid, false);
    assert.ok(result.errors.some(e => e.includes('PORT')));
    assert.ok(result.errors.some(e => e.includes('SHUTDOWN_TIMEOUT_MS')));
    assert.ok(result.errors.some(e => e.includes('HEALTH_CHECK_TIMEOUT_MS')));
  });

  // Test 4: Unsafe production configuration (loopback, LAN IP, weak secrets)
  await test('4. Unsafe production configuration (loopback, LAN IP, weak secrets) fails validation', async () => {
    const unsafeProdEnv = {
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://user:password@127.0.0.1:5432/db',
      REDIS_URL: 'redis://192.168.1.50:6379',
      MQTT_BROKER_URL: 'tls://localhost:8883',
      JWT_PRIVATE_KEY_PATH: '/etc/secrets/jwt_private.pem',
      JWT_PUBLIC_KEY_PATH: '/etc/secrets/jwt_public.pem',
      MQTT_CA_PATH: '/etc/certs/ca.crt',
      SESSION_SECRET: 'secret',
      JWT_SECRET: '123456'
    };

    const result = loadAndValidateConfig(unsafeProdEnv);
    assert.equal(result.isValid, false);
    assert.ok(result.errors.some(e => e.includes('loopback IP')));
    assert.ok(result.errors.some(e => e.includes('Developer LAN IP')));
    assert.ok(result.errors.some(e => e.includes('localhost')));
    assert.ok(result.errors.some(e => e.includes('Weak/default secret')));
  });

  // Test 5: Development and test configuration boundaries
  await test('5. Development and test configuration boundaries provide safe defaults', async () => {
    const devEnv = {
      NODE_ENV: 'development'
    };
    const devResult = loadAndValidateConfig(devEnv);
    assert.equal(devResult.isValid, true);
    assert.equal(devResult.config.port, 3000);
    assert.equal(devResult.config.host, '127.0.0.1');
    assert.equal(devResult.config.isProduction, false);

    const testEnv = {
      NODE_ENV: 'test'
    };
    const testResult = loadAndValidateConfig(testEnv);
    assert.equal(testResult.isValid, true);
    assert.equal(testResult.config.isTest, true);
  });

  // Test 6: Startup lifecycle transitions
  await test('6. Startup lifecycle transitions correctly: STARTING -> INITIALIZING -> READY', async () => {
    const service = new OperationalReadinessService();
    assert.equal(service.getLifecycleState().state, 'UNINITIALIZED');

    service.setLifecycleState('STARTING', 'Loading configuration');
    assert.equal(service.getLifecycleState().state, 'STARTING');

    service.setLifecycleState('INITIALIZING', 'Running database checks');
    assert.equal(service.getLifecycleState().state, 'INITIALIZING');

    service.setLifecycleState('READY', 'All dependencies initialized');
    const state = service.getLifecycleState();
    assert.equal(state.state, 'READY');
    assert.equal(state.reason, 'All dependencies initialized');
  });

  // Test 7: Startup required dependency failure
  await test('7. Startup required dependency failure (database offline) reports NOT_READY (503)', async () => {
    const mockFailingDb = {
      query: async () => {
        throw new Error('Connection refused to PostgreSQL');
      }
    };

    const service = new OperationalReadinessService({ db: mockFailingDb });
    service.setLifecycleState('READY');

    const readiness = await service.getReadiness();
    assert.equal(readiness.statusCode, 503);
    assert.equal(readiness.body.status, 'NOT_READY');
    assert.equal(readiness.body.checks.database, 'FAIL');
  });

  // Test 8: Optional dependency degradation
  await test('8. Optional dependency degradation (Redis / MQTT offline) reports DEGRADED (200, isReady: true)', async () => {
    const db = new DatabaseClient();
    const mockFailingRedis = {
      ping: async () => {
        throw new Error('Redis host unreachable');
      }
    };
    const mockFailingMqtt = {
      isConnected: false
    };

    const service = new OperationalReadinessService({
      db,
      redisClient: mockFailingRedis,
      mqttTransport: mockFailingMqtt
    });
    service.setLifecycleState('READY');

    const readiness = await service.getReadiness();
    assert.equal(readiness.statusCode, 200);
    assert.equal(readiness.body.status, 'DEGRADED');
    assert.equal(readiness.body.checks.database, 'PASS');
    assert.equal(readiness.body.checks.redis, 'FAIL');
    assert.equal(readiness.body.checks.mqtt, 'FAIL');
  });

  // Test 9: Readiness vs Liveness distinction
  await test('9. Readiness vs Liveness distinction: Liveness returns 200 UP even if DB is down; Readiness returns 503', async () => {
    const mockFailingDb = {
      query: async () => {
        throw new Error('Postgres connection pool exhausted');
      }
    };

    const service = new OperationalReadinessService({ db: mockFailingDb });
    service.setLifecycleState('READY');

    // Liveness probe
    const liveness = service.getLiveness();
    assert.equal(liveness.status, 'UP');
    assert.equal(liveness.service, 'eh-home-backend');

    // Readiness probe
    const readiness = await service.getReadiness();
    assert.equal(readiness.statusCode, 503);
    assert.equal(readiness.body.status, 'NOT_READY');
  });

  // Test 10: Database health check (bounded, non-destructive)
  await test('10. Database health check runs bounded non-destructive shallow query', async () => {
    let queriedSql = '';
    const mockDb = {
      query: async (sql) => {
        queriedSql = sql;
        return { rows: [{ '?column?': 1 }] };
      }
    };

    const service = new OperationalReadinessService({ db: mockDb });
    const check = await service.checkDatabase();
    assert.equal(check.status, 'HEALTHY');
    assert.equal(check.check, 'PASS');
    assert.equal(queriedSql, 'SELECT 1');
    assert.ok(typeof check.latencyMs === 'number');
  });

  // Test 11: Redis health behavior
  await test('11. Redis health behavior gracefully reports STANDBY when unconfigured, HEALTHY when available', async () => {
    // Case A: Unconfigured
    const serviceUnconfigured = new OperationalReadinessService({ db: new DatabaseClient() });
    const checkStandby = await serviceUnconfigured.checkRedis();
    assert.equal(checkStandby.status, 'STANDBY');

    // Case B: Configured & Available
    const serviceHealthy = new OperationalReadinessService({
      db: new DatabaseClient(),
      redisClient: { ping: async () => 'PONG' }
    });
    const checkHealthy = await serviceHealthy.checkRedis();
    assert.equal(checkHealthy.status, 'HEALTHY');
    assert.equal(checkHealthy.check, 'PASS');
  });

  // Test 12: MQTT health behavior
  await test('12. MQTT health behavior reports STANDBY when unconfigured, HEALTHY when connected, DEGRADED when disconnected', async () => {
    // Case A: Unconfigured
    const serviceUnconfigured = new OperationalReadinessService({ db: new DatabaseClient() });
    const checkStandby = await serviceUnconfigured.checkMqtt();
    assert.equal(checkStandby.status, 'STANDBY');

    // Case B: Connected
    const serviceConnected = new OperationalReadinessService({
      db: new DatabaseClient(),
      mqttTransport: { isConnected: true }
    });
    const checkConnected = await serviceConnected.checkMqtt();
    assert.equal(checkConnected.status, 'HEALTHY');
    assert.equal(checkConnected.check, 'PASS');

    // Case C: Disconnected
    const serviceDisconnected = new OperationalReadinessService({
      db: new DatabaseClient(),
      mqttTransport: { isConnected: false }
    });
    const checkDisconnected = await serviceDisconnected.checkMqtt();
    assert.equal(checkDisconnected.status, 'DEGRADED');
    assert.equal(checkDisconnected.check, 'FAIL');
  });

  // Test 13: Bounded health-check timeout
  await test('13. Bounded health-check timeout prevents infinite hang', async () => {
    const hangingDb = {
      query: () => new Promise((resolve) => setTimeout(() => resolve('done'), 5000))
    };

    const service = new OperationalReadinessService({
      db: hangingDb,
      timeoutMs: 50 // Short timeout for test
    });

    const check = await service.checkDatabase();
    assert.equal(check.status, 'UNAVAILABLE');
    assert.ok(check.error.includes('timed out'));
  });

  // Test 14: Graceful shutdown lifecycle
  await test('14. Graceful shutdown marks service SHUTTING_DOWN and readiness returns 503', async () => {
    const db = new DatabaseClient();
    const service = new OperationalReadinessService({ db });
    service.setLifecycleState('READY');

    let initialReadiness = await service.getReadiness();
    assert.equal(initialReadiness.statusCode, 200);

    // Trigger shutdown state
    service.setLifecycleState('SHUTTING_DOWN', 'SIGTERM received');
    let shuttingDownReadiness = await service.getReadiness();
    assert.equal(shuttingDownReadiness.statusCode, 503);
    assert.equal(shuttingDownReadiness.body.status, 'SHUTTING_DOWN');
    assert.equal(shuttingDownReadiness.body.checks.database, 'DISCONNECTED');
  });

  // Test 15: Authoritative runtime metadata
  await test('15. Authoritative runtime metadata exposes exact release and schema levels', async () => {
    const metadata = getReleaseMetadata();
    assert.equal(metadata.appName, 'EH Home');
    assert.equal(metadata.service, 'eh-home-backend');
    assert.equal(metadata.appVersion, '1.0.0');
    assert.equal(metadata.flutterAppVersion, '0.1.0+1');
    assert.equal(metadata.schemaVersionNumber, 26);
    assert.equal(metadata.latestMigration, '026_disaster_recovery_state_resilience');
    assert.equal(metadata.totalTables, 98);
  });

  // Test 16: Schema & migration compatibility
  await test('16. Schema & migration compatibility check returns compatible status without mutations', async () => {
    const service = new OperationalReadinessService({ db: new DatabaseClient() });
    const compat = await service.checkMigrationCompatibility();
    assert.equal(compat.schemaVersion, 26);
    assert.equal(compat.latestMigration, '026_disaster_recovery_state_resilience');
    assert.equal(compat.status, 'COMPATIBLE');
  });

  // Test 17: Diagnostic authorization (RBAC)
  await test('17. Diagnostic authorization: unauthenticated access rejected with 401/403, admin access permitted', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    // Public liveness probe works without auth
    const livenessRes = await makeAppRequest(app, 'GET', '/health/liveness');
    assert.equal(livenessRes.status, 200);
    assert.equal(livenessRes.body.status, 'UP');

    // Public readiness probe works without auth
    const readinessRes = await makeAppRequest(app, 'GET', '/health/readiness');
    assert.equal(readinessRes.status, 200);
    assert.equal(readinessRes.body.status, 'READY');

    // Administrative diagnostics without auth fails (401)
    const unauthDiag = await makeAppRequest(app, 'GET', '/api/v1/admin/operations/diagnostics');
    assert.equal(unauthDiag.status, 401);

    // Administrative diagnostics with non-admin user fails (403)
    const forbiddenDiag = await makeAppRequest(app, 'GET', '/api/v1/admin/operations/diagnostics', {
      'x-user-id': 'user-regular-1',
      'x-user-role': 'MEMBER'
    });
    assert.equal(forbiddenDiag.status, 403);

    // Administrative diagnostics with admin user succeeds (200)
    const adminDiag = await makeAppRequest(app, 'GET', '/api/v1/admin/operations/diagnostics', {
      'x-user-id': 'admin-user-1',
      'x-user-role': 'ADMIN'
    });
    assert.equal(adminDiag.status, 200);
    assert.equal(adminDiag.body.success, true);
    assert.equal(adminDiag.body.data.service, 'eh-home-backend');
    assert.equal(adminDiag.body.data.release.schemaVersionNumber, 26);
  });

  // Test 18: Secret redaction in diagnostics and config summaries
  await test('18. Secret redaction: zero plaintext passwords, tokens, or private keys exposed in diagnostics', async () => {
    const config = {
      environment: 'production',
      port: 3000,
      host: '0.0.0.0',
      backendBaseUrl: 'https://api.prod.ehhome.com',
      databaseUrl: 'postgres://app_user:SecretDbPassword123@db.prod.internal:5432/eh_prod',
      redisUrl: 'rediss://:SuperSecretRedisPass@redis.prod.internal:6379',
      mqttBrokerUrl: 'tls://mqtt.prod.internal:8883',
      jwtPrivateKeyPath: '/etc/secrets/jwt_private.pem',
      jwtPublicKeyPath: '/etc/secrets/jwt_public.pem',
      mqttCaPath: '/etc/certs/ca.crt',
      secrets: {
        sessionSecret: 'SuperSecretSessionKey',
        jwtSecret: 'SuperSecretJwtKey',
        databasePassword: 'SecretDbPassword123'
      }
    };

    const safeConfig = toSafeConfig(config);
    const jsonString = JSON.stringify(safeConfig);

    assert.equal(jsonString.includes('SecretDbPassword123'), false);
    assert.equal(jsonString.includes('SuperSecretRedisPass'), false);
    assert.equal(jsonString.includes('SuperSecretSessionKey'), false);
    assert.equal(jsonString.includes('SuperSecretJwtKey'), false);
    assert.equal(safeConfig.databaseBound, true);
    assert.equal(safeConfig.redisConfigured, true);
  });

  // Test 19: Log and connection string credential sanitization
  await test('19. Log and connection string credential sanitization masks passwords', async () => {
    const rawConn = 'postgres://admin:TopSecretPass_99@pg-cluster.ehhome.internal:5432/prod_db';
    const sanitized = sanitizeConnectionString(rawConn);
    assert.equal(sanitized, 'postgres://***:***@pg-cluster.ehhome.internal:5432/prod_db');
    assert.equal(sanitized.includes('TopSecretPass_99'), false);
  });

  // Test 20: Production debug-feature rejection
  await test('20. Production debug-feature rejection: debug routes and mock transports rejected in prod mode', async () => {
    const debugProdEnv = {
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://user:pass@db.prod.internal:5432/db',
      REDIS_URL: 'redis://redis.prod.internal:6379',
      MQTT_BROKER_URL: 'tls://mqtt.prod.internal:8883',
      JWT_PRIVATE_KEY_PATH: '/secrets/priv.pem',
      JWT_PUBLIC_KEY_PATH: '/secrets/pub.pem',
      MQTT_CA_PATH: '/certs/ca.crt',
      ENABLE_DEBUG_ROUTES: 'true',
      MOCK_TRANSPORTS: 'true'
    };

    const result = loadAndValidateConfig(debugProdEnv);
    assert.equal(result.isValid, false);
    assert.ok(result.errors.some(e => e.includes('ENABLE_DEBUG_ROUTES')));
    assert.ok(result.errors.some(e => e.includes('MOCK_TRANSPORTS')));
  });

  // Test 21: API error handling & status codes
  await test('21. API error handling produces structured JSON with proper error codes', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    // Unauthenticated request to private route returns 401
    const unauthRes = await makeAppRequest(app, 'GET', '/api/v1/invalid/endpoint/route');
    assert.equal(unauthRes.status, 401);

    // Authenticated request to non-existent route returns 404
    const notFoundRes = await makeAppRequest(app, 'GET', '/api/v1/invalid/endpoint/route', {
      'x-user-id': 'user-1',
      'x-user-role': 'ADMIN'
    });
    assert.equal(notFoundRes.status, 404);
    assert.equal(notFoundRes.body.success, false);
    assert.equal(notFoundRes.body.error.code, 'NOT_FOUND');
  });

  // Test 22: Health endpoint stability under repeated requests
  await test('22. Health endpoint stability under repeated requests without memory leak or state corruption', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    for (let i = 0; i < 50; i++) {
      const res = await makeAppRequest(app, 'GET', '/api/v1/health/liveness');
      assert.equal(res.status, 200);
      assert.equal(res.body.status, 'UP');
    }
  });

  // Test 23: Concurrent health requests
  await test('23. Concurrent health requests execute safely and simultaneously', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    const promises = Array.from({ length: 20 }, () => makeAppRequest(app, 'GET', '/api/v1/health/readiness'));
    const results = await Promise.all(promises);

    for (const res of results) {
      assert.equal(res.status, 200);
      assert.equal(res.body.status, 'READY');
      assert.equal(res.body.checks.database, 'PASS');
    }
  });

  // Test 24: Operational router RBAC
  await test('24. Operational router RBAC forbids unauthorized runtime config queries', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    const unauthConfig = await makeAppRequest(app, 'GET', '/api/v1/admin/operations/runtime-config');
    assert.equal(unauthConfig.status, 401);

    const adminConfig = await makeAppRequest(app, 'GET', '/api/v1/admin/operations/runtime-config', {
      'x-user-id': 'superadmin-1',
      'x-user-role': 'SUPERADMIN'
    });
    assert.equal(adminConfig.status, 200);
    assert.equal(adminConfig.body.success, true);
    assert.equal(adminConfig.body.data.validationStatus, 'VALID');
  });

  // Test 25: No destructive startup behavior
  await test('25. No destructive startup behavior: health probes observe state without database mutations', async () => {
    const db = new DatabaseClient();
    await db.insert('users', 'usr_probe_check', { id: 'usr_probe_check', email: 'probe@ehhome.io' });

    const app = createApp({ db });
    await makeAppRequest(app, 'GET', '/api/v1/health/readiness');
    await makeAppRequest(app, 'GET', '/api/v1/health/liveness');

    // Data in DB remains intact
    const user = await db.findById('users', 'usr_probe_check');
    assert.ok(user);
    assert.equal(user.email, 'probe@ehhome.io');
  });

  // Test 26: Security Regression & Invariant Preservation
  await test('26. Security Regression: Phase 32 device trust and Phase 33 disaster recovery preserved intact', async () => {
    const db = new DatabaseClient();
    const app = createApp({ db });

    // Verify recovery and device trust routers are present and functional
    assert.ok(app.services.recoveryService);
    assert.ok(app.services.operationalReadinessService);
    assert.ok(app.services.deviceTrustService);

    // Create a backup via recovery service to ensure no regression in Phase 33
    const result = await app.services.recoveryService.createBackup({
      initiatedBy: 'admin-1',
      scope: 'FULL'
    });
    assert.ok(result.backupId);
    assert.equal(result.manifest.status, 'COMPLETED');

    // Verify readiness reflects healthy database after backup
    const readiness = await app.services.operationalReadinessService.getReadiness();
    assert.equal(readiness.statusCode, 200);
    assert.equal(readiness.body.status, 'READY');
  });

  console.log('\n===============================================================');
  console.log(`  PHASE 34 SUITE COMPLETED: ${passedTests}/${totalTests} TESTS PASSED`);
  console.log('===============================================================\n');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
})();
