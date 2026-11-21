const http = require('http');
const assert = require('assert');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const serverScript = path.join(__dirname, '..', 'src', 'server.js');
const PORT = 4216; // Isolated test port

process.env.HUB_PORT = String(PORT);
const testDataDir = path.join(__dirname, 'test-data');
process.env.HUB_DATA_DIR = testDataDir;

if (fs.existsSync(testDataDir)) {
  try {
    fs.rmSync(testDataDir, { recursive: true, force: true });
  } catch (_) {}
}

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
  assert(infoRes.body.storageEngine === 'sqlite-wal' || infoRes.body.storageEngine === 'atomic-wal');
  console.log(`  ✓ GET /api/v1/hub/info passed (Storage Engine: ${infoRes.body.storageEngine})`);

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

  console.log('[Test 5] Testing POST /api/v1/routines (24/7 RAM Scheduler + Auto-Off duration)...');
  const routineRes = await request('POST', '/api/v1/routines', {
    name: 'Evening Porch Light',
    deviceId: 'test_dev_01',
    channel: 1,
    targetState: true,
    hour: 18,
    minute: 30,
    durationSec: 1, // 1-second auto-off for test
    criticalHardwareFallback: false,
  });
  assert.strictEqual(routineRes.statusCode, 200);
  assert.strictEqual(routineRes.body.status, 'ok');
  assert.strictEqual(routineRes.body.routine.name, 'Evening Porch Light');
  assert.strictEqual(routineRes.body.routine.durationSec, 1);
  const routineId = routineRes.body.routine.id;

  const listRoutinesRes = await request('GET', '/api/v1/routines');
  assert.strictEqual(listRoutinesRes.statusCode, 200);
  assert(Array.isArray(listRoutinesRes.body.routines));
  assert.strictEqual(listRoutinesRes.body.routines.length, 1);
  console.log('  ✓ POST & GET /api/v1/routines passed');

  console.log('[Test 6] Testing POST /api/v1/routines/trigger (Manual test run & Auto-Off timer)...');
  const triggerRes = await request('POST', '/api/v1/routines/trigger', { id: routineId });
  assert.strictEqual(triggerRes.statusCode, 200);
  assert.strictEqual(triggerRes.body.triggered, true);

  // Verify active auto-off countdown timer was armed
  const timersRes = await request('GET', '/api/v1/routines/timers');
  assert.strictEqual(timersRes.statusCode, 200);
  assert(Array.isArray(timersRes.body.activeTimers));
  assert(timersRes.body.activeTimers.length >= 1);
  console.log('  ✓ POST /api/v1/routines/trigger and Auto-Off timer armed');

  // Wait for 1.3s for countdown to expire and revert
  await new Promise(r => setTimeout(r, 1300));
  const timersAfterRes = await request('GET', '/api/v1/routines/timers');
  assert.strictEqual(timersAfterRes.statusCode, 200);
  assert.strictEqual(timersAfterRes.body.activeTimers.length, 0);
  console.log('  ✓ Auto-Off timer expired and cleaned up cleanly');

  console.log('[Test 7] Testing POST /api/v1/hub/time/sync...');
  const timeRes = await request('POST', '/api/v1/hub/time/sync');
  assert.strictEqual(timeRes.statusCode, 200);
  assert(typeof timeRes.body.epoch === 'number');
  console.log('  ✓ POST /api/v1/hub/time/sync passed');

  console.log('[Test 8] Testing GET /api/v1/hub/updates...');
  const updateRes = await request('GET', '/api/v1/hub/updates');
  assert.strictEqual(updateRes.statusCode, 200);
  assert.strictEqual(updateRes.body.hub.currentVersion, '1.1.0-plan1-sqlite');
  assert.strictEqual(updateRes.body.deviceOtaCache.enabled, true);
  console.log('  ✓ GET /api/v1/hub/updates passed');

  console.log('[Test 9] Testing 404 for unknown endpoint...');
  const notFoundRes = await request('GET', '/api/v1/unknown');
  assert.strictEqual(notFoundRes.statusCode, 404);
  console.log('  ✓ 404 handling passed');

  console.log('[Test 10] Testing POST /api/v1/hub/identify (Beacon)...');
  const identifyRes = await request('POST', '/api/v1/hub/identify');
  assert.strictEqual(identifyRes.statusCode, 200);
  assert.strictEqual(identifyRes.body.status, 'ok');
  console.log('  ✓ POST /api/v1/hub/identify passed');

  console.log('[Test 11] Testing POST /api/v1/hub/auth/verify (PIN check)...');
  const authRes = await request('POST', '/api/v1/hub/auth/verify', { pin: '842-109' });
  assert.strictEqual(authRes.statusCode, 200);
  assert.strictEqual(authRes.body.verified, true);
  const badAuthRes = await request('POST', '/api/v1/hub/auth/verify', { pin: '12' });
  assert.strictEqual(badAuthRes.statusCode, 401);
  console.log('  ✓ POST /api/v1/hub/auth/verify passed');

  console.log('[Test 12] Testing GET /api/v1/hub/storage/stats (Storage Diagnostics)...');
  const statsRes = await request('GET', '/api/v1/hub/storage/stats');
  assert.strictEqual(statsRes.statusCode, 200);
  assert.strictEqual(statsRes.body.status, 'ok');
  assert(statsRes.body.engine === 'sqlite-wal' || statsRes.body.engine === 'atomic-wal');
  assert.strictEqual(typeof statsRes.body.routinesCount, 'number');
  console.log(`  ✓ Storage stats verified (Engine: ${statsRes.body.engine})`);

  console.log('[Test 13] Testing DELETE /api/v1/routines...');
  const delRes = await request('DELETE', `/api/v1/routines?id=${routineId}`);
  assert.strictEqual(delRes.statusCode, 200);
  const listAfterDel = await request('GET', '/api/v1/routines');
  assert.strictEqual(listAfterDel.body.routines.length, 0);
  console.log('  ✓ DELETE /api/v1/routines passed');

  console.log('[Test 14] Testing POST /api/v1/hub/network/reset...');
  const netResetRes = await request('POST', '/api/v1/hub/network/reset');
  assert.strictEqual(netResetRes.statusCode, 200);
  console.log('  ✓ POST /api/v1/hub/network/reset passed');

  console.log('[Test 15] Testing POST /api/v1/hub/reboot...');
  const rebootRes = await request('POST', '/api/v1/hub/reboot');
  assert.strictEqual(rebootRes.statusCode, 200);
  console.log('  ✓ POST /api/v1/hub/reboot passed');

  console.log('[Test 16] Testing POST /api/v1/hub/factory-reset...');
  const factoryRes = await request('POST', '/api/v1/hub/factory-reset');
  assert.strictEqual(factoryRes.statusCode, 200);
  const infoAfterReset = await request('GET', '/api/v1/hub/info');
  assert.strictEqual(infoAfterReset.body.isLinked, false);
  console.log('  ✓ POST /api/v1/hub/factory-reset passed');

  console.log('\n[PASS] All 16 Hub Core Daemon & Storage Engine Tests Succeeded!\n');
}

runTests()
  .catch(err => {
    console.error('[FAIL]', err);
    process.exitCode = 1;
  })
  .finally(() => {
    child.kill('SIGTERM');
    try {
      if (fs.existsSync(testDataDir)) {
        fs.rmSync(testDataDir, { recursive: true, force: true });
      }
    } catch (_) {}
  });
