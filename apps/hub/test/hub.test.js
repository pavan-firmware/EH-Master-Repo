const http = require('http');
const assert = require('assert');
const { spawn } = require('child_process');
const path = require('path');

const serverScript = path.join(__dirname, '..', 'src', 'server.js');
const PORT = 4215; // Isolated test port

process.env.HUB_PORT = String(PORT);
process.env.HUB_DATA_DIR = path.join(__dirname, 'test-data');

const child = spawn(process.execPath, [serverScript], {
  env: process.env,
  stdio: 'pipe',
});

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
      },
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          body: JSON.parse(data || '{}'),
        });
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function waitForReady() {
  for (let i = 0; i < 20; i++) {
    try {
      const res = await request('GET', '/api/v1/hub/info');
      if (res.statusCode === 200) return;
    } catch (_) {
      await new Promise(r => setTimeout(r, 200));
    }
  }
  throw new Error('Hub daemon failed to become ready in time');
}

async function runTests() {
  console.log('[Test] Waiting for Hub daemon to start on port', PORT);
  await waitForReady();

  console.log('[Test 1] Testing GET /api/v1/hub/info...');
  const infoRes = await request('GET', '/api/v1/hub/info');
  assert.strictEqual(infoRes.statusCode, 200);
  assert.strictEqual(infoRes.body.status, 'ok');
  assert.strictEqual(typeof infoRes.body.latencyMs, 'number');
  assert.strictEqual(infoRes.body.overlayFs, true);
  console.log('  ✓ GET /api/v1/hub/info passed');

  console.log('[Test 2] Testing POST /api/v1/hub/link (Rule 1: Claim Token)...');
  const linkRes = await request('POST', '/api/v1/hub/link', {
    homeId: 'home_test_01',
    token: 'test_token_123',
  });
  assert.strictEqual(linkRes.statusCode, 200);
  assert.strictEqual(linkRes.body.homeId, 'home_test_01');
  console.log('  ✓ POST /api/v1/hub/link passed');

  console.log('[Test 3] Testing GET /api/v1/hub/devices...');
  const devRes = await request('GET', '/api/v1/hub/devices');
  assert.strictEqual(devRes.statusCode, 200);
  assert(Array.isArray(devRes.body.devices));
  console.log('  ✓ GET /api/v1/hub/devices passed');

  console.log('[Test 4] Testing POST /api/v1/control (Actuator proxy)...');
  const controlRes = await request('POST', '/api/v1/control', {
    deviceId: 'test_dev_01',
    channelIndex: 1,
    power: true,
  });
  assert.strictEqual(controlRes.statusCode, 200);
  assert.strictEqual(controlRes.body.status, 'ok');
  console.log('  ✓ POST /api/v1/control passed');

  console.log('[Test 5] Testing POST /api/v1/routines (24/7 RAM Scheduler)...');
  const routineRes = await request('POST', '/api/v1/routines', {
    name: 'Evening Porch Light',
    deviceId: 'test_dev_01',
    channel: 1,
    targetState: true,
    hour: 18,
    minute: 30,
    criticalHardwareFallback: false,
  });
  assert.strictEqual(routineRes.statusCode, 200);
  assert.strictEqual(routineRes.body.status, 'ok');
  assert.strictEqual(routineRes.body.routine.name, 'Evening Porch Light');
  const routineId = routineRes.body.routine.id;

  const listRoutinesRes = await request('GET', '/api/v1/routines');
  assert.strictEqual(listRoutinesRes.statusCode, 200);
  assert(Array.isArray(listRoutinesRes.body.routines));
  assert.strictEqual(listRoutinesRes.body.routines.length, 1);
  console.log('  ✓ POST & GET /api/v1/routines passed');

  console.log('[Test 6] Testing POST /api/v1/routines/trigger (Manual test run)...');
  const triggerRes = await request('POST', '/api/v1/routines/trigger', { id: routineId });
  assert.strictEqual(triggerRes.statusCode, 200);
  assert.strictEqual(triggerRes.body.triggered, true);
  console.log('  ✓ POST /api/v1/routines/trigger passed');

  console.log('[Test 7] Testing POST /api/v1/hub/time/sync...');
  const timeRes = await request('POST', '/api/v1/hub/time/sync');
  assert.strictEqual(timeRes.statusCode, 200);
  assert(typeof timeRes.body.epoch === 'number');
  console.log('  ✓ POST /api/v1/hub/time/sync passed');

  console.log('[Test 8] Testing 404 for unknown endpoint...');
  const notFoundRes = await request('GET', '/api/v1/unknown');
  assert.strictEqual(notFoundRes.statusCode, 404);
  console.log('  ✓ 404 handling passed');

  console.log('\n[PASS] All 8 Hub Core Daemon Tests Succeeded!\n');
}

runTests()
  .catch(err => {
    console.error('[FAIL]', err);
    process.exitCode = 1;
  })
  .finally(() => {
    child.kill('SIGTERM');
  });

