'use strict';

/**
 * EH Home — Local OTA Binary Serving & Validation Test Suite
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');

const { createApp } = require('../src/app');
const { FirmwareReleaseService } = require('../src/services/firmware-release.service');

async function runTests() {
  console.log('=== Running Local OTA Serving & Scheme Validation Tests ===\n');

  // ---------------------------------------------------------------------------
  // Test 1: URL Scheme & Local Private Subnet Validation
  // ---------------------------------------------------------------------------
  console.log('Test 1: FirmwareReleaseService.validateArtifact URL scheme checks');
  const mockRepo = { createRelease: () => {} };
  const service = new FirmwareReleaseService({ firmwareRepo: mockRepo });

  const dummySha = crypto.createHash('sha256').update('test').digest('hex'); // 64 hex
  const dummySig = crypto.createHash('sha512').update('test').digest('hex'); // 128 hex

  const baseManifest = {
    productVariantId: 'esp32c6-switch-4x',
    version: '1.0.1',
    sha256: dummySha,
    ed25519Signature: dummySig,
    binarySizeBytes: 1024 * 100,
    releaseChannel: 'production'
  };

  // Local HTTP IPs should pass
  assert.strictEqual(service.validateArtifact({ ...baseManifest, downloadUrl: 'http://192.168.0.227:3000/bin' }).valid, true);
  assert.strictEqual(service.validateArtifact({ ...baseManifest, downloadUrl: 'http://10.0.0.12:3000/bin' }).valid, true);
  assert.strictEqual(service.validateArtifact({ ...baseManifest, downloadUrl: 'http://localhost:3000/bin' }).valid, true);
  assert.strictEqual(service.validateArtifact({ ...baseManifest, downloadUrl: 'http://127.0.0.1:3000/bin' }).valid, true);
  assert.strictEqual(service.validateArtifact({ ...baseManifest, downloadUrl: 'https://cdn.eh-home.com/bin' }).valid, true);

  // Non-local insecure HTTP should be rejected
  const nonLocalRes = service.validateArtifact({ ...baseManifest, downloadUrl: 'http://insecure-public-server.com/bin' });
  assert.strictEqual(nonLocalRes.valid, false);
  assert.ok(nonLocalRes.error.includes('downloadUrl must use secure HTTPS protocol'));
  console.log('  PASS: Local subnets allowed, insecure public HTTP rejected.');

  // ---------------------------------------------------------------------------
  // Test 2: Local Binary Serving Endpoint (GET /api/v1/ota/binaries/:filename)
  // ---------------------------------------------------------------------------
  console.log('\nTest 2: Raw Binary Streaming Endpoint');
  const firmwareDir = path.resolve(__dirname, '../var/firmware');
  fs.mkdirSync(firmwareDir, { recursive: true });
  const manifestFile = path.join(firmwareDir, 'releases.json');
  if (fs.existsSync(manifestFile)) {
    try { fs.unlinkSync(manifestFile); } catch (_) {}
  }

  const testBinName = `test_fw_${Date.now()}.bin`;
  const testBinPath = path.join(firmwareDir, testBinName);
  const testPayload = Buffer.from('ANTIGRAVITY_ESP32_FIRMWARE_PAYLOAD_BYTE_STREAM');
  fs.writeFileSync(testBinPath, testPayload);

  const app = createApp({ db: null, startWorkers: false });
  const server = http.createServer((req, res) => app.handleRequest(req, res));

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  try {
    // 2a. Request non-existent binary
    const res404 = await makeRequest(`http://127.0.0.1:${port}/api/v1/ota/binaries/missing_non_existent.bin`);
    assert.strictEqual(res404.statusCode, 404);
    assert.ok(res404.body.includes('not found'));
    console.log('  PASS: 404 returned for non-existent binary.');

    // 2b. Request valid existing binary
    const res200 = await makeRequest(`http://127.0.0.1:${port}/api/v1/ota/binaries/${testBinName}`);
    assert.strictEqual(res200.statusCode, 200);
    assert.strictEqual(res200.headers['content-type'], 'application/octet-stream');
    assert.strictEqual(parseInt(res200.headers['content-length'], 10), testPayload.length);
    assert.strictEqual(res200.rawBuffer.toString('utf8'), testPayload.toString('utf8'));
    console.log(`  PASS: Binary served cleanly with Content-Type application/octet-stream (${testPayload.length} bytes).`);

    // -------------------------------------------------------------------------
    // Test 3: End-to-end Release Registration and Update Check
    // -------------------------------------------------------------------------
    console.log('\nTest 3: End-to-end Release Registration & Compatibility Check');
    const regPayload = {
      productVariantId: 'esp32c6-switch-4x',
      version: '2.0.0',
      downloadUrl: `http://192.168.0.227:${port}/api/v1/ota/binaries/${testBinName}`,
      sha256: dummySha,
      ed25519Signature: dummySig,
      binarySizeBytes: testPayload.length,
      releaseChannel: 'production',
      releaseNotes: 'Phase 50 production release test'
    };

    const regRes = await makeRequest(`http://127.0.0.1:${port}/api/v1/ota/releases`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(regPayload)
    });
    assert.strictEqual(regRes.statusCode, 201);
    const regJson = JSON.parse(regRes.body);
    assert.strictEqual(regJson.success, true);
    console.log('  PASS: Registered release manifest via POST /api/v1/ota/releases.');

    // Check for update from running version 1.0.0
    const checkRes = await makeRequest(`http://127.0.0.1:${port}/api/v1/ota/check?productVariantId=esp32c6-switch-4x&currentVersion=1.0.0`);
    assert.strictEqual(checkRes.statusCode, 200);
    const checkJson = JSON.parse(checkRes.body);
    assert.strictEqual(checkJson.success, true);
    assert.strictEqual(checkJson.data.updateAvailable, true);
    assert.strictEqual(checkJson.data.release.version, '2.0.0');
    assert.strictEqual(checkJson.data.release.downloadUrl, regPayload.downloadUrl);
    console.log('  PASS: Update check verified (updateAvailable: true, target version 2.0.0).');

  } finally {
    // Cleanup
    if (fs.existsSync(testBinPath)) fs.unlinkSync(testBinPath);
    await new Promise((resolve) => server.close(resolve));
  }

  console.log('\n ALL 3 LOCAL OTA TESTS PASSED SUCCESSFULLY!');
}

function makeRequest(urlStr, options = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlStr);
    const reqOpts = {
      hostname: parsed.hostname,
      port: parsed.port,
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: options.headers || {}
    };

    const req = http.request(reqOpts, (res) => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const rawBuffer = Buffer.concat(chunks);
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          rawBuffer,
          body: rawBuffer.toString('utf8')
        });
      });
    });

    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

runTests().catch(err => {
  console.error('\n Test Failure:', err);
  process.exit(1);
});
