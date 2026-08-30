'use strict';

/**
 * EH Home — MQTT HTTP Authorizer Unit Tests (Phase 13)
 *
 * Validates the complete certificate-bound authorization matrix.
 */

const assert = require('assert').strict;
const { evaluateMqttAuthorization } = require('../src/services/mqtt-http-authorizer.service');

const DEV_A = '0194fe23-7a1b-7890-a123-456789abcdef';
const DEV_B = '0194fe23-7a1b-7890-b456-123456fedcba';

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passed++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failed++;
  }
}

console.log('=== RUNNING MQTT HTTP AUTHORIZER UNIT TESTS ===\n');

test('1. Device A cert → Device A commands subscribe → ALLOW', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_A,
    topic: `eh/v1/devices/${DEV_A}/commands`,
    action: 'subscribe'
  });
  assert.equal(res.result, 'allow');
});

test('2. Device A cert → Device A state publish → ALLOW', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_A,
    topic: `eh/v1/devices/${DEV_A}/state`,
    action: 'publish'
  });
  assert.equal(res.result, 'allow');
});

test('3. Device A cert → Device B state publish → DENY', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_A,
    topic: `eh/v1/devices/${DEV_B}/state`,
    action: 'publish'
  });
  assert.equal(res.result, 'deny');
});

test('4. Device B cert → Device A state publish → DENY', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_B,
    clientid: DEV_B,
    topic: `eh/v1/devices/${DEV_A}/state`,
    action: 'publish'
  });
  assert.equal(res.result, 'deny');
});

test('5. Device A cert + spoofed Device B clientId → Device B state publish → DENY', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_B,
    topic: `eh/v1/devices/${DEV_B}/state`,
    action: 'publish'
  });
  assert.equal(res.result, 'deny');
});

test('6. Device A cert + spoofed Device B clientId → Device B commands subscribe → DENY', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_B,
    topic: `eh/v1/devices/${DEV_B}/commands`,
    action: 'subscribe'
  });
  assert.equal(res.result, 'deny');
});

test('7. Device A cert → Device A telemetry subscribe → DENY (Devices only publish telemetry)', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_A,
    topic: `eh/v1/devices/${DEV_A}/telemetry`,
    action: 'subscribe'
  });
  assert.equal(res.result, 'deny');
});

test('8. Admin user → wildcard topic → ALLOW', () => {
  const res = evaluateMqttAuthorization({
    username: 'admin',
    topic: '#',
    action: 'subscribe'
  });
  assert.equal(res.result, 'allow');
});

test('9. Backend service client → wildcard topic → ALLOW', () => {
  const res = evaluateMqttAuthorization({
    clientid: 'backend_core_service',
    topic: 'eh/v1/devices/+/events',
    action: 'subscribe'
  });
  assert.equal(res.result, 'allow');
});

test('10. Malformed / Non-canonical topic → DENY', () => {
  const res = evaluateMqttAuthorization({
    cert_common_name: DEV_A,
    clientid: DEV_A,
    topic: 'custom/unauthorized/path',
    action: 'publish'
  });
  assert.equal(res.result, 'deny');
});

console.log(`\n========================================`);
console.log(`AUTHORIZER TESTS: ${passed} PASSED, ${failed} FAILED`);
console.log(`========================================\n`);

if (failed > 0) process.exit(1);
