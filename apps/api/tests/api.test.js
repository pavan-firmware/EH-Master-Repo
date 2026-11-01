/**
 * EH Home API Foundation Automated Test Suite
 *
 * Validates:
 * - Application bootstrap without opening a real network port
 * - Liveness (/health) and Readiness (/ready) checks (healthy & failure paths)
 * - Request ID generation and propagation
 * - Versioned API routing (/api/v1/system/*)
 * - Input validation and structured error contracts
 * - 404 Route Not Found handling
 * - Information leakage prevention
 */

const assert = require('assert');
const { buildApp } = require('../dist/app');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

async function runTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

async function main() {
  console.log('=== EH HOME FASTIFY API FOUNDATION TESTS ===\n');

  // ── 1. BOOTSTRAP & HEALTH (LIVENESS) ──────────────────────────────────
  console.log('1. Application Bootstrap & Liveness:');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  // Attach a mock pingDb function for testing readiness states
  let mockDbHealthy = true;
  app.decorate('pingDb', async () => mockDbHealthy);

  await app.ready();

  await runTest('Fastify app instantiates without opening network port', async () => {
    assert.ok(app);
    assert.strictEqual(typeof app.inject, 'function');
  });

  await runTest('GET /health returns 200 UP without requiring database', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health',
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.status, 'UP');
    assert.strictEqual(typeof body.uptimeSeconds, 'number');
    assert.ok(body.timestamp);
  });

  // ── 2. READINESS CHECK ────────────────────────────────────────────────
  console.log('\n2. Readiness Check (Dependency Validation):');

  await runTest('GET /ready returns 200 when database is healthy', async () => {
    mockDbHealthy = true;
    const res = await app.inject({
      method: 'GET',
      url: '/ready',
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.status, 'READY');
    assert.strictEqual(body.dependencies.database, 'HEALTHY');
  });

  await runTest('GET /ready returns 503 when database is unavailable', async () => {
    mockDbHealthy = false;
    const res = await app.inject({
      method: 'GET',
      url: '/ready',
    });
    assert.strictEqual(res.statusCode, 503);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.status, 'DOWN');
    assert.strictEqual(body.dependencies.database, 'UNAVAILABLE');
  });

  // ── 3. REQUEST CORRELATION & ID ───────────────────────────────────────
  console.log('\n3. Request Correlation & ID:');

  await runTest('Generates UUID request ID when none provided', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health',
    });
    const header = res.headers['x-request-id'];
    assert.ok(header, 'x-request-id header must exist');
    assert.ok(/^[a-zA-Z0-9_-]{8,64}$/.test(header), 'x-request-id must be valid format');
  });

  await runTest('Propagates valid incoming x-request-id', async () => {
    const customId = 'trace-client-123456';
    const res = await app.inject({
      method: 'GET',
      url: '/health',
      headers: {
        'x-request-id': customId,
      },
    });
    assert.strictEqual(res.headers['x-request-id'], customId);
  });

  // ── 4. API VERSIONING & SYSTEM MODULE ─────────────────────────────────
  console.log('\n4. API Versioning & System Module (/api/v1/system):');

  await runTest('GET /api/v1/system/info returns system status', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/system/info',
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.service, 'eh-home-api');
    assert.strictEqual(body.data.version, '1.0.0');
  });

  await runTest('POST /api/v1/system/echo accepts valid payload', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/system/echo',
      payload: {
        message: 'EH Home Modular Monolith',
        metadata: { client: 'test-runner' },
      },
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.echo, 'EH Home Modular Monolith');
    assert.strictEqual(body.data.metadata.client, 'test-runner');
  });

  // ── 5. ERROR HANDLING & SECURITY ENVELOPE ─────────────────────────────
  console.log('\n5. Error Handling & Security Envelopes:');

  await runTest('Malformed request body rejected with 400 and structured error', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/system/echo',
      payload: {
        message: '', // Violation: min length 1
      },
    });
    assert.strictEqual(res.statusCode, 400);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'VALIDATION_ERROR');
    assert.ok(body.error.details);
    assert.ok(body.meta.requestId);
  });

  await runTest('Unknown route returns 404 with structured error', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/unknown-endpoint-xyz',
    });
    assert.strictEqual(res.statusCode, 404);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.schemaVersion, 1);
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.error.code, 'ROUTE_NOT_FOUND');
    assert.ok(body.error.message.includes('ROUTE_NOT_FOUND') || body.error.message.includes('does not exist'));
  });

  await runTest('Error responses do not leak stack traces or internal secrets', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/system/echo',
      payload: {
        invalidKey: 123,
      },
    });
    const bodyStr = res.body;
    assert.strictEqual(bodyStr.includes('node_modules'), false);
    assert.strictEqual(bodyStr.includes('Error:'), false);
    assert.strictEqual(bodyStr.includes('password'), false);
  });

  await app.close();

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== API FOUNDATION TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL API FOUNDATION TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
