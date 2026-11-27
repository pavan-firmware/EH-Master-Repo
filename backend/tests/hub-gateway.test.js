'use strict';

/**
 * Cloud <-> Pi Smart Hub Gateway Service & Router Test Suite
 */

const assert = require('assert');
const { EventEmitter } = require('events');
const { HubGatewayService } = require('../src/services/hub-gateway.service');
const { HubApiRouter } = require('../src/api/hub.router');

async function run() {
  console.log('Running Cloud <-> Hub Gateway Tests...');

  const eventBus = new EventEmitter();
  const publishedEvents = [];
  eventBus.on('device.state', (evt) => publishedEvents.push(evt));

  const mockFirmwareRepo = {
    async findAll() {
      return [
        {
          id: 'fw_01',
          deviceModel: 'eh-smart-socket-2x',
          version: '2.2.0',
          status: 'PUBLISHED',
          downloadUrl: 'https://ota.ehhome.example/eh-smart-socket-2x-2.2.0.bin',
        },
        {
          id: 'fw_02',
          deviceModel: 'eh-smart-switch-3x',
          version: '2.3.0-rc1',
          status: 'DRAFT',
        },
      ];
    },
  };

  const gateway = new HubGatewayService({ eventBus, firmwareRepo: mockFirmwareRepo });
  const router = new HubApiRouter(gateway);

  // 1. Register Hub validation & registration
  const badReg = await router.handle('POST', '/api/v1/hubs/register', { homeId: 'home_01' });
  assert.strictEqual(badReg.status, 400);

  const reg = await router.handle('POST', '/api/v1/hubs/register', {
    hubId: 'hub_pi_01',
    homeId: 'home_01',
    hostname: 'eh-hub.local',
    version: '1.1.0-plan1-sqlite',
    ipAddress: '192.168.0.12',
    devicesCount: 2,
  });
  assert.strictEqual(reg.status, 200);
  assert.strictEqual(reg.body.success, true);
  assert.ok(reg.body.hub.hubSecret && reg.body.hub.hubSecret.length >= 24);
  console.log('  [PASS] 1. Hub registration & secret generation');

  // 2. List registered Hubs by homeId
  const list = await router.handle('GET', '/api/v1/hubs', {}, { homeId: 'home_01' });
  assert.strictEqual(list.status, 200);
  assert.strictEqual(list.body.hubs.length, 1);
  assert.strictEqual(list.body.hubs[0].hubId, 'hub_pi_01');
  assert.strictEqual(list.body.hubs[0].online, true);
  console.log('  [PASS] 2. List registered Hubs per home');

  // 3. Queue remote commands & verify live SSE push
  const sseFrames = [];
  const fakeSseRes = { write: (chunk) => sseFrames.push(chunk) };
  const unsubscribe = gateway.subscribeStream('hub_pi_01', fakeSseRes);

  const cmdRes = await router.handle('POST', '/api/v1/hubs/hub_pi_01/commands', {
    type: 'ROUTINE_UPSERT',
    payload: { id: 'rt_remote_01', name: 'Away Evening Porch' },
  });
  assert.strictEqual(cmdRes.status, 202);
  assert.strictEqual(sseFrames.length, 1);
  assert.ok(sseFrames[0].includes('event: hub.dispatch'));
  assert.ok(sseFrames[0].includes('rt_remote_01'));
  unsubscribe();
  console.log('  [PASS] 3. Cloud -> Hub queued dispatch & live SSE stream push');

  // 4. Reconcile Hub offline state, execution logs & energy + drain queued dispatches + published OTA releases
  const syncRes = await router.handle('POST', '/api/v1/hubs/hub_pi_01/sync', {
    devices: [
      { id: 'dev_b699', online: true, channels: { 1: true, 2: false } },
      { id: 'dev_aa30', online: false, channels: { 1: false } },
    ],
    executionLogs: [
      {
        id: 'log_offline_1',
        ruleId: 'rule_1',
        ruleName: 'Hallway Trigger',
        status: 'SUCCESS_FAST_PATH_UDP',
        latencyMs: 3,
      },
    ],
    energySamples: [{ deviceId: 'dev_b699', powerW: 120.5 }],
  });
  assert.strictEqual(syncRes.status, 200);
  assert.strictEqual(syncRes.body.reconciledDevicesCount, 2);
  assert.strictEqual(syncRes.body.ingestedLogsCount, 1);
  assert.strictEqual(syncRes.body.ingestedEnergySamplesCount, 1);
  assert.strictEqual(syncRes.body.dispatches.length, 1);
  assert.strictEqual(syncRes.body.otaReleases.length, 1);
  assert.strictEqual(syncRes.body.otaReleases[0].deviceModel, 'eh-smart-socket-2x');
  assert.strictEqual(publishedEvents.length, 2);
  console.log('  [PASS] 4. Offline state/logs/energy reconciliation + OTA release list');

  // 5. Fetch offline audit logs & verify pending queue was drained
  const logsRes = await router.handle('GET', '/api/v1/hubs/hub_pi_01/logs');
  assert.strictEqual(logsRes.status, 200);
  assert.strictEqual(logsRes.body.logs.length, 1);
  assert.strictEqual(logsRes.body.logs[0].id, 'log_offline_1');

  const secondSync = await router.handle('POST', '/api/v1/hubs/hub_pi_01/sync', { devices: [] });
  assert.strictEqual(secondSync.body.dispatches.length, 0);
  console.log('  [PASS] 5. Offline audit log retrieval & queue drain idempotency');

  console.log('\n[PASS] All Cloud <-> Hub Gateway Tests Passed!');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
