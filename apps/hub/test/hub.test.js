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

async function runTests() {
  console.log('[Test] Waiting for Hub daemon to start on port', PORT);
  await new Promise(r => setTimeout(r, 800));

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

  console.log('[Test 4] Testing 404 for unknown endpoint...');
  const notFoundRes = await request('GET', '/api/v1/unknown');
  assert.strictEqual(notFoundRes.statusCode, 404);
  console.log('  ✓ 404 handling passed');

  console.log('\n[PASS] All 4 Hub Core Daemon Tests Succeeded!\n');
}

runTests()
  .catch(err => {
    console.error('[FAIL]', err);
    process.exitCode = 1;
  })
  .finally(() => {
    child.kill('SIGTERM');
  });

