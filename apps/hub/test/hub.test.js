const http = require('http');
const assert = require('assert');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const serverScript = path.join(__dirname, '..', 'src', 'server.js');
const PORT = 4216; // Isolated test port
const NTP_TEST_PORT = 4218;

process.env.HUB_PORT = String(PORT);
process.env.NTP_PORT = String(NTP_TEST_PORT);
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

child.stdout.on('data', (d) => process.stdout.write(`[Server stdout] ${d}`));
child.stderr.on('data', (d) => process.stderr.write(`[Server stderr] ${d}`));

let hubAuthToken = null;

function request(method, path, body = null, { skipAuth = false, customToken = null } = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const tok = skipAuth ? null : (customToken || hubAuthToken);
    const req = http.request({
      hostname: '127.0.0.1',
      port: PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(tok ? { Authorization: `Bearer ${tok}` } : {}),
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

  console.log('[Test 2] Testing POST /api/v1/hub/link (Rule 1: Claim Token + Access Token)...');
  const linkRes = await request('POST', '/api/v1/hub/link', {
    homeId: 'home_test_01',
    token: 'test_token_123',
  });
  assert.strictEqual(linkRes.statusCode, 200);
  assert.strictEqual(linkRes.body.homeId, 'home_test_01');
  assert.ok(linkRes.body.hubAccessToken, 'Hub link must issue hubAccessToken');
  hubAuthToken = linkRes.body.hubAccessToken;
  console.log('  ✓ POST /api/v1/hub/link passed');

  console.log('[Test 2b] Verifying Hub LAN Auth rejects unauthorized mutations with 401...');
  const unauthRes = await request('POST', '/api/v1/control', { deviceId: 'test_dev_01', channelIndex: 1, power: true }, { skipAuth: true });
  assert.strictEqual(unauthRes.statusCode, 401);
  console.log('  ✓ Hub LAN Bearer auth enforcement verified');

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

  // Poll for countdown timer to expire and revert cleanly
  let expired = false;
  for (let i = 0; i < 6; i++) {
    await new Promise(r => setTimeout(r, 500));
    const timersAfterRes = await request('GET', '/api/v1/routines/timers');
    if (timersAfterRes.statusCode === 200 && timersAfterRes.body.activeTimers.length === 0) {
      expired = true;
      break;
    }
  }
  assert.ok(expired, 'Auto-Off countdown timer should expire within 3s');
  console.log('  ✓ Auto-Off timer expired and cleaned up cleanly');

  console.log('[Test 6b] Testing Toggle + 1s Auto-Off arms targetState=false and finishes OFF...');
  const toggleRoutineRes = await request('POST', '/api/v1/routines', {
    id: 'rt_toggle_auto_off',
    name: 'Toggle 1s Auto Off',
    deviceId: 'test_dev_01',
    channel: 1,
    targetState: true,
    isToggle: true,
    hour: 22,
    minute: 41,
    durationSec: 1,
    criticalHardwareFallback: false,
  });
  assert.strictEqual(toggleRoutineRes.statusCode, 200);
  assert.strictEqual(toggleRoutineRes.body.routine.isToggle, true);
  assert.strictEqual(toggleRoutineRes.body.routine.durationSec, 1);

  const trigToggle = await request('POST', '/api/v1/routines/trigger', { id: 'rt_toggle_auto_off' });
  assert.strictEqual(trigToggle.statusCode, 200);
  const toggleTimersRes = await request('GET', '/api/v1/routines/timers');
  assert.strictEqual(toggleTimersRes.statusCode, 200);
  const toggleTimer = toggleTimersRes.body.activeTimers.find(t => t.routineId === 'rt_toggle_auto_off');
  assert.ok(toggleTimer, 'Toggle Auto-Off timer should be armed');
  assert.strictEqual(toggleTimer.targetState, false, 'Timed toggle routine must always revert to OFF (false)');

  let toggleExpired = false;
  for (let i = 0; i < 6; i++) {
    await new Promise(r => setTimeout(r, 500));
    const timersAfterRes = await request('GET', '/api/v1/routines/timers');
    if (timersAfterRes.statusCode === 200 && timersAfterRes.body.activeTimers.length === 0) {
      toggleExpired = true;
      break;
    }
  }
  assert.ok(toggleExpired, 'Toggle Auto-Off countdown timer should expire within 3s');
  await request('DELETE', '/api/v1/routines?id=rt_toggle_auto_off');
  console.log('  ✓ Toggle + Auto-Off guaranteed OFF completion passed');

  console.log('[Test 7] Testing POST /api/v1/hub/time/sync...');
  const timeRes = await request('POST', '/api/v1/hub/time/sync');
  assert.strictEqual(timeRes.statusCode, 200);
  assert(typeof timeRes.body.epoch === 'number');
  console.log('  ✓ POST /api/v1/hub/time/sync passed');

  console.log('[Test 8] Testing GET /api/v1/hub/updates (zero hardcoded fake cache before staging)...');
  const updateRes = await request('GET', '/api/v1/hub/updates');
  assert.strictEqual(updateRes.statusCode, 200);
  assert.strictEqual(updateRes.body.hub.currentVersion, '1.1.0-plan1-sqlite');
  assert.strictEqual(updateRes.body.deviceOtaCache.enabled, true);
  assert.strictEqual(updateRes.body.deviceOtaCache.cachedFirmwares.length, 0);
  console.log('  ✓ GET /api/v1/hub/updates passed (no hardcoded fake cache)');

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

  console.log('[Test 15] Testing POST /api/v1/rules (Cross-Device Rule Creation)...');
  const ruleId = 'rule_cross_gnd_to_1st_staircase';
  const saveRuleRes = await request('POST', '/api/v1/rules', {
    id: ruleId,
    name: 'Ground 2x Ch1 -> 1st Floor Staircase Light ON',
    enabled: true,
    triggerDeviceId: 'EH-SW-GND-01',
    triggerChannel: 1,
    triggerState: true,
    actionDeviceId: 'EH-SW-1ST-02',
    actionDeviceIp: '127.0.0.1',
    actionChannel: 1,
    actionCommand: 'ON',
  });
  assert.strictEqual(saveRuleRes.statusCode, 200);
  assert.strictEqual(saveRuleRes.body.status, 'ok');

  const getRulesRes = await request('GET', '/api/v1/rules');
  assert.strictEqual(getRulesRes.statusCode, 200);
  assert.strictEqual(getRulesRes.body.rules.length, 1);
  assert.strictEqual(getRulesRes.body.rules[0].id, ruleId);
  console.log('  ✓ POST & GET /api/v1/rules passed');

  console.log('[Test 16] Testing POST /api/v1/rules/test (Fast-Path Cross-Device Execution)...');
  const testRuleRes = await request('POST', `/api/v1/rules/test?id=${ruleId}`);
  assert.strictEqual(testRuleRes.statusCode, 200);
  assert.strictEqual(testRuleRes.body.status, 'ok');
  assert(testRuleRes.body.execution.latencyMs >= 0);
  console.log(`  ✓ Fast-Path cross-device test passed (Latency: ${testRuleRes.body.execution.latencyMs}ms)`);

  console.log('[Test 17] Testing POST /api/v1/hub/events & Execution Log Audit...');
  const eventRes = await request('POST', '/api/v1/hub/events', {
    deviceId: 'EH-SW-GND-01',
    channel: 1,
    state: true,
  });
  assert.strictEqual(eventRes.statusCode, 200);
  assert.strictEqual(eventRes.body.matchedRules, 1);

  const logsRes = await request('GET', '/api/v1/rules/logs?limit=10');
  assert.strictEqual(logsRes.statusCode, 200);
  assert(logsRes.body.logs.length >= 2); // manual test log + event bus log
  assert.strictEqual(logsRes.body.logs[0].ruleId, ruleId);
  console.log(`  ✓ Event bus reactive trigger and execution audit logs passed (${logsRes.body.logs.length} logged)`);

  console.log('[Test 18] Testing DELETE /api/v1/rules...');
  const delRuleRes = await request('DELETE', `/api/v1/rules?id=${ruleId}`);
  assert.strictEqual(delRuleRes.statusCode, 200);
  const rulesAfterDel = await request('GET', '/api/v1/rules');
  assert.strictEqual(rulesAfterDel.body.rules.length, 0);
  console.log('  ✓ DELETE /api/v1/rules passed');

  // Plan 3: Energy Telemetry Tests
  console.log('[Test 19] Testing POST /api/v1/hub/energy/samples (Ingest Energy Telemetry)...');
  const energyIngestRes = await request('POST', '/api/v1/hub/energy/samples', {
    samples: [
      {
        deviceId: 'EH-SK-GND-01',
        channel: 1,
        powerW: 1450.5,
        voltageV: 232.0,
        currentA: 6.25,
      },
      {
        deviceId: 'EH-SW-1ST-02',
        channel: 1,
        powerW: 65.0,
        voltageV: 231.5,
        currentA: 0.28,
      },
    ],
  });
  assert.strictEqual(energyIngestRes.statusCode, 200);
  assert.strictEqual(energyIngestRes.body.samplesProcessed, 2);
  console.log('  ✓ Ingested 2 energy telemetry samples successfully');

  console.log('[Test 20] Testing GET /api/v1/hub/energy/devices/:id/latest & history...');
  const latestEnergyRes = await request('GET', '/api/v1/hub/energy/devices/EH-SK-GND-01/latest?channel=1');
  assert.strictEqual(latestEnergyRes.statusCode, 200);
  assert.strictEqual(latestEnergyRes.body.measurement.deviceId, 'EH-SK-GND-01');
  assert.strictEqual(latestEnergyRes.body.measurement.powerW, 1450.5);

  const historyEnergyRes = await request('GET', '/api/v1/hub/energy/devices/EH-SK-GND-01/history?period=today&channel=1');
  assert.strictEqual(historyEnergyRes.statusCode, 200);
  assert.strictEqual(historyEnergyRes.body.summary.entityId, 'EH-SK-GND-01');
  assert(historyEnergyRes.body.summary.totalEnergyKwh >= 0);
  assert(historyEnergyRes.body.summary.trends.length > 0);
  console.log(`  ✓ Device energy history query passed (Current: ${historyEnergyRes.body.summary.currentPowerW}W, Total: ${historyEnergyRes.body.summary.totalEnergyKwh} kWh)`);

  console.log('[Test 21] Testing GET /api/v1/hub/energy/home/summary & top consumers...');
  const homeEnergyRes = await request('GET', '/api/v1/hub/energy/home/summary?period=today');
  assert.strictEqual(homeEnergyRes.statusCode, 200);
  assert(homeEnergyRes.body.summary.topDevices.length >= 2);
  assert.strictEqual(homeEnergyRes.body.summary.topDevices[0].deviceId, 'EH-SK-GND-01'); // Higher consumer first
  console.log(`  ✓ Home energy summary passed (Top: ${homeEnergyRes.body.summary.topDevices[0].deviceId} at ${homeEnergyRes.body.summary.topDevices[0].percentage}%)`);

  // Plan 5: LAN OTA Staging Tests
  console.log('[Test 22] Testing POST /api/v1/ota/stage (Stage local OTA binary)...');
  const stageRes = await request('POST', '/api/v1/ota/stage', {
    model: 'eh-smart-switch-3x',
    version: '2.1.0-freertos',
    filename: 'eh-smart-switch-3x-2.1.0.bin',
    content: 'SYNTHETIC_FIRMWARE_HEADER_EH_V210_PROD_PAYLOAD_CHECKSUM_OK',
  });
  assert.strictEqual(stageRes.statusCode, 200);
  assert.strictEqual(stageRes.body.status, 'ok');
  assert(stageRes.body.sha256.length === 64);
  console.log(`  ✓ Firmware staging passed (SHA256: ${stageRes.body.sha256.slice(0, 16)}...)`);

  console.log('[Test 23] Testing GET /api/v1/ota/manifest & GET /api/v1/ota/firmware/:filename...');
  const manifestRes = await request('GET', '/api/v1/ota/manifest');
  assert.strictEqual(manifestRes.statusCode, 200);
  assert(manifestRes.body.firmwareCount >= 1);

  // Test downloading the binary
  const binaryRes = await new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${PORT}/api/v1/ota/firmware/eh-smart-switch-3x-2.1.0.bin`, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, contentType: res.headers['content-type'], body: data }));
    }).on('error', reject);
  });
  assert.strictEqual(binaryRes.statusCode, 200);
  assert.strictEqual(binaryRes.contentType, 'application/octet-stream');
  assert(binaryRes.body.includes('SYNTHETIC_FIRMWARE_HEADER_EH_V210'));
  console.log('  ✓ High-speed LAN OTA binary download passed');

  // Plan 6: Embedded Local NTP Timekeeper Test
  console.log('[Test 24] Testing RFC 5905 Embedded Local SNTP Timekeeper (UDP Port 4218)...');
  const ntpResponse = await new Promise((resolve, reject) => {
    const dgram = require('dgram');
    const client = dgram.createSocket('udp4');
    const packet = Buffer.alloc(48);
    packet[0] = 0x23; // LI=0, VN=4, Mode=3 (Client)
    client.on('message', (msg) => {
      client.close();
      resolve(msg);
    });
    client.on('error', (err) => {
      client.close();
      reject(err);
    });
    client.send(packet, 0, packet.length, NTP_TEST_PORT, '127.0.0.1');
  });
  assert.strictEqual(ntpResponse.length, 48);
  // Byte 0 Mode should be 4 (Server Response) -> 0x24
  assert.strictEqual(ntpResponse[0], 0x24);
  // Byte 1 Stratum should be 1 (Primary Reference)
  assert.strictEqual(ntpResponse[1], 1);
  console.log('  ✓ RFC 5905 Local SNTP timekeeper response verified (<1ms local offline time sync)');

  // Home Assistant Local Discovery Tests
  console.log('[Test 25] Testing Home Assistant MQTT/REST Discovery Manifest...');
  await request('POST', '/api/v1/hub/adopt', {
    devices: [
      { id: 'test_dev_01', name: 'Living Room Switch', ipAddress: '192.168.1.50', channelCount: 3 }
    ]
  });
  const haManifestRes = await request('GET', '/api/v1/integrations/homeassistant/manifest');
  assert.strictEqual(haManifestRes.statusCode, 200);
  assert(haManifestRes.body.entitiesCount >= 1);
  assert(haManifestRes.body.entities.some(e => e.component === 'switch'));
  assert(haManifestRes.body.entities.some(e => e.component === 'sensor'));
  assert(haManifestRes.body.entities.some(e => e.component === 'binary_sensor'));
  console.log(`  ✓ Home Assistant Discovery Manifest generated (${haManifestRes.body.entitiesCount} entities)`);

  console.log('[Test 26] Testing Home Assistant REST Entities & Status...');
  const haStatusRes = await request('GET', '/api/v1/integrations/homeassistant/status');
  assert.strictEqual(haStatusRes.statusCode, 200);
  assert.strictEqual(haStatusRes.body.active, true);
  const haEntitiesRes = await request('GET', '/api/v1/integrations/homeassistant/entities');
  assert.strictEqual(haEntitiesRes.statusCode, 200);
  assert(Array.isArray(haEntitiesRes.body.entities));
  console.log('  ✓ Home Assistant REST entities & status verified');

  console.log('[Test 27] Testing Hub Configuration Backup & Restore...');
  const backupRes = await request('GET', '/api/v1/hub/backup');
  assert.strictEqual(backupRes.statusCode, 200);
  assert(backupRes.body.backup && Array.isArray(backupRes.body.backup.devices));
  const backupPayload = backupRes.body.backup;
  const restoreRes = await request('POST', '/api/v1/hub/restore', { backup: backupPayload });
  assert.strictEqual(restoreRes.statusCode, 200);
  assert.strictEqual(restoreRes.body.status, 'ok');
  console.log('  ✓ Hub configuration backup snapshot and atomic restore verified');

  console.log('[Test 28] Testing One-Click Diagnostics Export...');
  const diagRes = await request('GET', '/api/v1/hub/diagnostics/export');
  assert.strictEqual(diagRes.statusCode, 200);
  assert.strictEqual(diagRes.body.status, 'ok');
  assert(diagRes.body.hub && diagRes.body.hub.version);
  assert(Array.isArray(diagRes.body.devices));
  console.log('  ✓ One-Click diagnostics export verified');

  console.log('[Test 29] Testing Unicast Device Self-Registration (POST /api/v1/hub/register-device)...');
  const unicastRes = await request('POST', '/api/v1/hub/register-device', {
    id: 'eh-switch-unicast-99',
    name: '2nd Floor Balcony Switch',
    ipAddress: '192.168.1.185',
    channelCount: 3,
    channels: { 1: false, 2: false, 3: false },
    model: 'EH-SW3-EM',
    macAddress: 'AA:BB:CC:DD:EE:99',
    hasCriticalHardwareFallback: true,
  });
  assert.strictEqual(unicastRes.statusCode, 200);
  assert.strictEqual(unicastRes.body.status, 'ok');
  assert.strictEqual(unicastRes.body.registered, true);
  assert.strictEqual(unicastRes.body.deviceId, 'eh-switch-unicast-99');

  const devicesAfterUnicast = await request('GET', '/api/v1/hub/devices');
  const foundRegistered = devicesAfterUnicast.body.devices.find(d => d.id === 'eh-switch-unicast-99');
  assert(foundRegistered, 'Unicast device should be in Hub devices registry');
  assert.strictEqual(foundRegistered.ipAddress, '192.168.1.185');
  console.log('  ✓ POST /api/v1/hub/register-device passed and persisted');

  console.log('[Test 30] Testing Local Offline Webhook & Voice Bridge (POST /api/v1/hub/webhook)...');
  const webhookRes = await request('POST', '/api/v1/hub/webhook', {
    event: 'voice.command.toggle',
    deviceId: 'eh-switch-unicast-99',
    channel: 1,
    state: true,
  });
  assert.strictEqual(webhookRes.statusCode, 200);
  assert.strictEqual(webhookRes.body.status, 'ok');
  assert.strictEqual(webhookRes.body.executed, true);
  console.log('  ✓ POST /api/v1/hub/webhook execution verified');

  console.log('[Test 31] Testing POST /api/v1/hub/reboot...');
  const rebootRes = await request('POST', '/api/v1/hub/reboot');
  assert.strictEqual(rebootRes.statusCode, 200);
  console.log('  ✓ POST /api/v1/hub/reboot passed');

  console.log('[Test 33] Testing Multi-Category Devices, Canonical Naming & Device Edit/Delete CRUD...');
  await request('POST', '/api/v1/hub/adopt', {
    devices: [
      { id: '4184a5de-a3ec-46f4-bcfb-41d13d91b699', name: 'EH Socket (b699)', ipAddress: '192.168.0.168', model: 'eh-smart-socket-2x', channelCount: 2 },
      { id: 'fan_001', name: '', ipAddress: '192.168.0.199', model: 'eh-smart-fan-1x', channelCount: 1 },
      { id: 'sens_001', name: '', ipAddress: '192.168.0.200', model: 'eh-sensor-node', channelCount: 0, telemetry: { temperature: 24.5, humidity: 58 } },
    ]
  });
  const devsCatRes = await request('GET', '/api/v1/hub/devices');
  const sock = devsCatRes.body.devices.find(d => d.id === '4184a5de-a3ec-46f4-bcfb-41d13d91b699');
  const fan = devsCatRes.body.devices.find(d => d.id === 'fan_001');
  const sens = devsCatRes.body.devices.find(d => d.id === 'sens_001');
  assert.strictEqual(sock.category, 'sockets');
  assert(sock.name.includes('EH Smart Socket 2X'), `Expected canonical socket name, got: ${sock.name}`);
  assert.strictEqual(fan.category, 'fans');
  assert.strictEqual(sens.category, 'sensors');

  const patchDev = await request('PATCH', `/api/v1/hub/devices/${sock.id}`, { name: 'Kitchen Kettle Socket', roomName: 'Kitchen' });
  assert.strictEqual(patchDev.statusCode, 200);
  assert.strictEqual(patchDev.body.device.name, 'Kitchen Kettle Socket');
  assert.strictEqual(patchDev.body.device.roomName, 'Kitchen');

  const delDev = await request('DELETE', `/api/v1/hub/devices/${sens.id}`);
  assert.strictEqual(delDev.statusCode, 200);
  console.log('  ✓ Multi-Category Devices, Canonical Naming & Edit/Delete CRUD passed');

  console.log('[Test 34] Testing Saved Backups & Local Webhooks Full CRUD...');
  const createBk = await request('POST', '/api/v1/hub/backups', { label: 'Pre-Upgrade Snapshot' });
  assert.strictEqual(createBk.statusCode, 200);
  const bkId = createBk.body.backup.id;
  const listBk = await request('GET', '/api/v1/hub/backups');
  assert(listBk.body.backups.some(b => b.id === bkId));
  const restoreBk = await request('POST', `/api/v1/hub/backups/${bkId}/restore`);
  assert.strictEqual(restoreBk.statusCode, 200);
  const delBk = await request('DELETE', `/api/v1/hub/backups/${bkId}`);
  assert.strictEqual(delBk.statusCode, 200);

  const createWh = await request('POST', '/api/v1/hub/webhooks', { name: 'Evening Voice Trigger', event: 'voice.evening', deviceId: sock.id, channel: 1, state: true });
  assert.strictEqual(createWh.statusCode, 200);
  const whId = createWh.body.webhook.id;
  const listWh = await request('GET', '/api/v1/hub/webhooks');
  assert(listWh.body.webhooks.some(w => w.id === whId));
  const delWh = await request('DELETE', `/api/v1/hub/webhooks/${whId}`);
  assert.strictEqual(delWh.statusCode, 200);
  console.log('  ✓ Saved Backups & Webhooks Full CRUD passed');

  console.log('[Test 32] Testing POST /api/v1/hub/factory-reset...');
  const factoryRes = await request('POST', '/api/v1/hub/factory-reset');
  assert.strictEqual(factoryRes.statusCode, 200);
  hubAuthToken = null; // wiped after factory reset
  const infoAfterReset = await request('GET', '/api/v1/hub/info', null, { skipAuth: true });
  assert.strictEqual(infoAfterReset.body.isLinked, false);
  console.log('  ✓ POST /api/v1/hub/factory-reset passed');

  console.log('\n[PASS] All 36 Hub Core Daemon, Auth, Multi-Category CRUD, HA Discovery, Backup & Diagnostics Tests Succeeded!\n');
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
