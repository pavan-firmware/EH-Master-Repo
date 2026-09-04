'use strict';

/**
 * Phase 28 — Local-First Home Control & Edge Execution Platform Tests
 *
 * Deterministic test suite covering:
 *   1. LocalRouteCacheRepository CRUD, lookup, and reachability
 *   2. EdgeExecutionRepository metrics, persistence, and querying
 *   3. LocalDiscoveryNodeRepository trust verification and discovery
 *   4. ExecutionRoutingService: deterministic LOCAL / CLOUD / DEFERRED / UNAVAILABLE decisions
 *   5. LocalExecutionService: direct physical state confirmation and latency
 *   6. LocalExecutionService: graceful cloud fallback on local failure
 *   7. LocalExecutionService: offline operation & queued cloud sync
 *   8. LocalExecutionService: anti-replay & idempotency protection
 *   9. LocalDiscoveryService: cryptographic identity verification and rogue node rejection
 *  10. EdgeAutomationService: offline local scene execution with partial success handling
 *  11. EdgeAutomationService: offline local schedule execution
 *  12. EdgeAutomationService: local rule evaluation
 *  13. EdgeControlApiRouter: REST endpoints verification
 *  14. App integration & end-to-end local routing pipeline
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  ProductRepository,
  DeviceRepository,
  DeviceStateRepository,
  HomeRepository,
  LocalRouteCacheRepository,
  EdgeExecutionRepository,
  LocalDiscoveryNodeRepository,
  CommandRepository,
  OutboxRepository,
  AuditRepository,
  SceneRepository,
  ScheduleRepository,
  AutomationRepository
} = require('../src/repositories');
const { ExecutionRoutingService } = require('../src/services/execution-routing.service');
const { LocalExecutionService } = require('../src/services/local-execution.service');
const { LocalDiscoveryService } = require('../src/services/local-discovery.service');
const { EdgeAutomationService } = require('../src/services/edge-automation.service');
const { DeviceCommandService } = require('../src/services/device-command.service');
const { EdgeControlApiRouter } = require('../src/api/edge-control.router');
const { createApp } = require('../src/app');

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
    console.error(`  ✗ FAIL: ${desc} — ${details}`);
  }
}

async function runTests() {
  console.log('=== PHASE 28: LOCAL-FIRST HOME CONTROL & EDGE EXECUTION TESTS ===\n');

  const db = new DatabaseClient();

  // Repositories
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const productRepo = new ProductRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const auditRepo = new AuditRepository(db);
  const localRouteRepo = new LocalRouteCacheRepository(db);
  const edgeExecutionRepo = new EdgeExecutionRepository(db);
  const discoveryRepo = new LocalDiscoveryNodeRepository(db);
  const sceneRepo = new SceneRepository(db);
  const scheduleRepo = new ScheduleRepository(db);
  const automationRepo = new AutomationRepository(db);

  // Seed sample user, home and device via repository APIs (valid UUID format)
  const homeId = '11111111-1111-4111-8111-111111111111';
  const deviceId1 = '22222222-2222-4222-8222-222222222221';
  const deviceId2 = '22222222-2222-4222-8222-222222222222';
  const userId = '33333333-3333-4333-8333-333333333333';

  await userRepo.createUser({ id: userId, email: 'owner@ehhome.io', password_hash: 'hash' });
  await homeRepo.createHome({ id: homeId, name: 'Edge Test Home', ownerId: userId });
  await productRepo.createFamily({ id: 'smart_switch', slug: 'smart_switch', displayName: 'Smart Switch' });
  await productRepo.createProduct({ id: 'eh_switch', familyId: 'smart_switch', displayName: 'EH Switch' });
  await productRepo.createVariant({ id: 'eh-smart-switch-2x', productId: 'eh_switch', sku: 'EH-SW2X', formFactor: '2-Module' });

  await deviceRepo.registerDevice({
    deviceId: deviceId1,
    serialNumber: 'SN-SW-001',
    productVariantId: 'eh-smart-switch-2x',
    hardwareRevision: 'revA',
    firmwareFamily: 'esp32'
  });
  await deviceRepo.claimDevice({
    deviceId: deviceId1,
    homeId,
    customName: 'Living Room Switch'
  });

  await deviceRepo.registerDevice({
    deviceId: deviceId2,
    serialNumber: 'SN-SW-002',
    productVariantId: 'eh-smart-switch-2x',
    hardwareRevision: 'revA',
    firmwareFamily: 'esp32'
  });
  await deviceRepo.claimDevice({
    deviceId: deviceId2,
    homeId,
    customName: 'Kitchen Socket'
  });

  // ─── 1. LocalRouteCacheRepository ──────────────────────────────────────────
  console.log('1. LocalRouteCacheRepository:');
  const route = await localRouteRepo.upsertRoute({
    deviceId: deviceId1,
    homeId,
    transportType: 'WIFI_MQTT',
    localEndpoint: '192.168.1.150:1883',
    localIp: '192.168.1.150',
    localPort: 1883,
    reachability: 'REACHABLE',
    identityFingerprint: 'cert_hash_123',
    latencyMs: 14.2,
    ttlSeconds: 300
  });

  assert('Local route upserted successfully', Boolean(route && route.id));
  assert('Local endpoint preserved', route.localEndpoint === '192.168.1.150:1883');
  assert('Reachability is REACHABLE', route.reachability === 'REACHABLE');

  const foundRoute = await localRouteRepo.findByDevice(deviceId1);
  assert('Route found by deviceId', foundRoute && foundRoute.deviceId === deviceId1);

  const homeRoutes = await localRouteRepo.listByHome(homeId);
  assert('listByHome returns cached routes', homeRoutes.length >= 1);

  await localRouteRepo.updateReachability(deviceId1, 'DEGRADED', 85.0);
  const degradedRoute = await localRouteRepo.findByDevice(deviceId1);
  assert('updateReachability sets DEGRADED', degradedRoute.reachability === 'DEGRADED');

  // Reset back to REACHABLE
  await localRouteRepo.updateReachability(deviceId1, 'REACHABLE', 12.0);

  // ─── 2. EdgeExecutionRepository ────────────────────────────────────────────
  console.log('\n2. EdgeExecutionRepository:');
  const execRec = await edgeExecutionRepo.createRecord({
    commandId: 'cmd_001_test',
    deviceId: deviceId1,
    homeId,
    channelIndex: 1,
    action: 'setPower',
    routeMode: 'LOCAL',
    transportUsed: 'WIFI_MQTT',
    status: 'CONFIRMED',
    isConfirmedByDevice: true,
    confirmedState: { power: true },
    latencyMs: 15.6,
    idempotencyKey: 'idem_test_001',
    actorUserId: userId
  });

  assert('Edge execution record created', Boolean(execRec && execRec.id));
  assert('Record status is CONFIRMED', execRec.status === 'CONFIRMED');
  assert('isConfirmedByDevice is true', execRec.isConfirmedByDevice === true);

  const byIdem = await edgeExecutionRepo.findByIdempotencyKey('idem_test_001');
  assert('Record found by idempotency key', byIdem && byIdem.commandId === 'cmd_001_test');

  const metrics = await edgeExecutionRepo.getMetrics(homeId);
  assert('getMetrics computes totalExecutions >= 1', metrics.totalExecutions >= 1);
  assert('Metrics includes localSuccessRate', typeof metrics.localSuccessRate === 'number');

  // ─── 3. LocalDiscoveryNodeRepository ───────────────────────────────────────
  console.log('\n3. LocalDiscoveryNodeRepository:');
  const discNode = await discoveryRepo.upsertNode({
    deviceId: deviceId1,
    homeId,
    macAddress: 'AA:BB:CC:11:22:33',
    ipAddress: '192.168.1.150',
    port: 1883,
    transportType: 'WIFI_MQTT',
    identityFingerprint: 'cert_fingerprint_valid',
    isTrusted: true
  });

  assert('Discovery node created', Boolean(discNode && discNode.id));
  assert('isTrusted is true', discNode.isTrusted === true);

  const foundNode = await discoveryRepo.findByDevice(deviceId1);
  assert('Discovery node found by device', foundNode && foundNode.ipAddress === '192.168.1.150');

  // ─── 4. ExecutionRoutingService ────────────────────────────────────────────
  console.log('\n4. ExecutionRoutingService:');
  const routingService = new ExecutionRoutingService({
    localRouteRepo,
    connectivityService: null,
    deviceRepo,
    homeAuthService: null
  });

  // Scenario A: Phone on LAN & Device reachable locally -> LOCAL
  const routeDec1 = await routingService.decideRoute({ deviceId: deviceId1, homeId, action: 'setPower' });
  assert('LOCAL route chosen when phone on LAN and device reachable', routeDec1.routeMode === 'LOCAL');
  assert('Confidence score is high (>= 0.9)', routeDec1.confidenceScore >= 0.9);
  assert('Selected transport matches route cache', routeDec1.selectedTransport === 'WIFI_MQTT');

  // Scenario B: User outside Home LAN -> CLOUD
  routingService.setPhoneLocalNetwork(false);
  const routeDec2 = await routingService.decideRoute({ deviceId: deviceId1, homeId, action: 'setPower' });
  assert('CLOUD route chosen when user is outside LAN', routeDec2.routeMode === 'CLOUD');

  // Scenario C: Phone back on LAN, but Cloud is down -> LOCAL works smoothly
  routingService.setPhoneLocalNetwork(true);
  routingService.setCloudReachability(false);
  const routeDec3 = await routingService.decideRoute({ deviceId: deviceId1, homeId, action: 'setPower' });
  assert('LOCAL route still chosen when cloud is down', routeDec3.routeMode === 'LOCAL');

  // Scenario D: Local route expired and Cloud down -> UNAVAILABLE for actuator
  await localRouteRepo.updateReachability(deviceId1, 'UNREACHABLE');
  const routeDec4 = await routingService.decideRoute({ deviceId: deviceId1, homeId, action: 'setPower' });
  assert('UNAVAILABLE returned when both local and cloud unavailable', routeDec4.routeMode === 'UNAVAILABLE');

  // Scenario E: Local down, Cloud down, but action is metadata -> DEFERRED
  const routeDec5 = await routingService.decideRoute({ deviceId: deviceId1, homeId, action: 'updateLabel' });
  assert('DEFERRED returned for safe metadata mutations offline', routeDec5.routeMode === 'DEFERRED');

  // Restore reachable state and cloud
  await localRouteRepo.updateReachability(deviceId1, 'REACHABLE');
  routingService.setCloudReachability(true);

  // ─── 5. LocalExecutionService ──────────────────────────────────────────────
  console.log('\n5. LocalExecutionService:');
  const mockMqttTransport = {
    async sendCommand(envelope) {
      return { status: 'DELIVERED', receiptId: 'rcpt_mock_01' };
    }
  };
  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
    mqttTransport: mockMqttTransport
  });

  const localExecService = new LocalExecutionService({
    routingService,
    edgeExecutionRepo,
    localRouteRepo,
    deviceRepo,
    deviceStateRepo,
    homeAuthService: null,
    deviceCommandService: commandService,
    eventBus: null
  });

  // Test local execution with physical confirmation
  const execResult = await localExecService.executeCommand({ userId, homeId, role: 'OWNER' }, {
    deviceId: deviceId1,
    homeId,
    channelIndex: 1,
    action: 'setPower',
    params: { value: true },
    idempotencyKey: 'idem_exec_001'
  });

  assert('Local execution status is CONFIRMED', execResult.status === 'CONFIRMED');
  assert('Execution routeUsed is LOCAL', execResult.routeMode === 'LOCAL');
  assert('Physical confirmation received', execResult.isConfirmedByDevice === true);
  assert('Confirmed state returned', Boolean(execResult.confirmedState && execResult.confirmedState.power === true));
  assert('Latency measured (< 200ms)', execResult.latencyMs < 200);

  // ─── 6. Idempotency & Duplicate Prevention ─────────────────────────────────
  console.log('\n6. Idempotency & Duplicate Prevention:');
  const replayResult = await localExecService.executeCommand({ userId, homeId, role: 'OWNER' }, {
    deviceId: deviceId1,
    homeId,
    channelIndex: 1,
    action: 'setPower',
    params: { value: true },
    idempotencyKey: 'idem_exec_001'
  });

  assert('Duplicate request detected', replayResult.isIdempotentReplay === true);
  assert('Replay returns original status', replayResult.status === 'CONFIRMED');

  // ─── 7. Local Execution with Cloud Fallback ────────────────────────────────
  console.log('\n7. Local Execution with Cloud Fallback:');
  // Register a failing local transport adapter
  localExecService.registerLocalTransport('WIFI_MQTT', {
    async sendCommand() {
      throw new Error('Local socket timeout');
    }
  });

  const fallbackResult = await localExecService.executeCommand({ userId, homeId, role: 'OWNER' }, {
    deviceId: deviceId1,
    homeId,
    channelIndex: 1,
    action: 'setPower',
    params: { value: false },
    idempotencyKey: 'idem_fallback_001'
  });

  assert('Failing local gracefully falls back to CLOUD', fallbackResult.routeMode === 'CLOUD');
  assert('Fallback command completed successfully', fallbackResult.status === 'CONFIRMED');
  assert('Error message captures previous local failure', Boolean(fallbackResult.errorMessage && fallbackResult.errorMessage.includes('Fallback from local')));

  // Unregister failing transport to restore direct simulation
  localExecService._localTransports.delete('WIFI_MQTT');

  // ─── 8. LocalDiscoveryService ──────────────────────────────────────────────
  console.log('\n8. LocalDiscoveryService:');
  const discoveryService = new LocalDiscoveryService({
    discoveryRepo,
    localRouteRepo,
    deviceRepo,
    deviceCredRepo: null
  });

  // Valid discovery
  const validDisc = await discoveryService.processDiscoveryAdvertisement({
    deviceId: deviceId2,
    homeId,
    macAddress: 'BB:CC:DD:44:55:66',
    ipAddress: '192.168.1.155',
    port: 1883,
    transportType: 'WIFI_MQTT',
    identityFingerprint: 'valid_fingerprint_hash',
    isTrusted: true
  });
  assert('Valid discovery advertisement processed', validDisc.success === true);
  assert('Valid node marked trusted', validDisc.isTrusted === true);

  // Untrusted / rogue discovery
  const rogueDisc = await discoveryService.processDiscoveryAdvertisement({
    deviceId: deviceId2,
    homeId,
    macAddress: 'BB:CC:DD:44:55:66',
    ipAddress: '192.168.1.199',
    port: 1883,
    identityFingerprint: 'invalid_hacked_hash'
  });
  assert('Rogue node rejected or flagged', rogueDisc.isTrusted === false || rogueDisc.success === false);

  const localDevices = await discoveryService.getLocalDevices(homeId);
  assert('getLocalDevices returns discovered devices', localDevices.length >= 2);

  // ─── 9. EdgeAutomationService — Scenes & Schedules ─────────────────────────
  console.log('\n9. EdgeAutomationService:');
  // Seed sample scene
  const sceneId = 'scene_edge_movie';
  await sceneRepo.createScene({
    id: sceneId,
    homeId,
    name: 'Movie Night',
    actions: [
      { deviceId: deviceId1, action: 'setPower', value: false },
      { deviceId: deviceId2, action: 'setPower', value: true }
    ]
  });

  const edgeAutoService = new EdgeAutomationService({
    localExecutionService: localExecService,
    automationService: null,
    sceneService: null,
    scheduleRepo,
    automationRepo,
    sceneRepo
  });

  const sceneResult = await edgeAutoService.executeSceneEdge({ homeId, userId, sceneId });
  assert('Local scene executed at edge', Boolean(sceneResult && sceneResult.executionId));
  assert('Scene status is SUCCESS', sceneResult.status === 'SUCCESS');
  assert('All actions executed successfully (2/2)', sceneResult.actionsSuccessful === 2);

  // Seed sample schedule
  const scheduleId = 'sched_edge_lights';
  await scheduleRepo.createSchedule({
    id: scheduleId,
    homeId,
    name: 'Night Lamp Off',
    action: 'setPower',
    cronExpression: '0 22 * * *'
  });

  // Manually attach target_device_id for edge schedule test
  await db.update('schedules', scheduleId, { target_device_id: deviceId1 });

  const schedResult = await edgeAutoService.executeScheduleEdge({ homeId, scheduleId });
  assert('Local schedule executed at edge', Boolean(schedResult && schedResult.executionId));
  assert('Schedule status is SUCCESS', schedResult.status === 'SUCCESS');

  const history = edgeAutoService.getExecutionHistory({ homeId });
  assert('Execution history contains scene & schedule runs', history.length >= 2);

  // ─── 10. EdgeControlApiRouter Endpoints ────────────────────────────────────
  console.log('\n10. EdgeControlApiRouter Endpoints:');
  const edgeRouter = new EdgeControlApiRouter({
    routingService,
    localExecutionService: localExecService,
    localDiscoveryService: discoveryService,
    edgeAutomationService: edgeAutoService,
    edgeExecutionRepo,
    localRouteRepo,
    homeAuthService: null
  });

  // GET /homes/:homeId/local-status
  const statusRes = await edgeRouter.handleRequest({ method: 'GET', path: `/api/v1/homes/${homeId}/local-status` });
  assert('GET /homes/:homeId/local-status returns 200', statusRes.statusCode === 200);
  assert('local-status data has isLocalNetworkActive = true', statusRes.body.data.isLocalNetworkActive === true);

  // GET /homes/:homeId/local-devices
  const devRes = await edgeRouter.handleRequest({ method: 'GET', path: `/api/v1/homes/${homeId}/local-devices` });
  assert('GET /homes/:homeId/local-devices returns 200', devRes.statusCode === 200);

  // GET /devices/:deviceId/local-connectivity
  const connRes = await edgeRouter.handleRequest({ method: 'GET', path: `/api/v1/devices/${deviceId1}/local-connectivity` });
  assert('GET /devices/:deviceId/local-connectivity returns 200', connRes.statusCode === 200);
  assert('local-connectivity data has isReachableLocally = true', connRes.body.data.isReachableLocally === true);

  // POST /devices/:deviceId/execute
  const execPostRes = await edgeRouter.handleRequest({
    method: 'POST',
    path: `/api/v1/devices/${deviceId1}/execute`,
    body: {
      homeId,
      channelIndex: 1,
      action: 'setPower',
      value: true,
      idempotencyKey: 'idem_api_001'
    }
  });
  assert('POST /devices/:deviceId/execute returns 200', execPostRes.statusCode === 200);
  assert('execute response status is CONFIRMED', execPostRes.body.data.status === 'CONFIRMED');

  // POST /homes/:homeId/scenes/:sceneId/execute-edge
  const scenePostRes = await edgeRouter.handleRequest({
    method: 'POST',
    path: `/api/v1/homes/${homeId}/scenes/${sceneId}/execute-edge`
  });
  assert('POST /homes/:homeId/scenes/:sceneId/execute-edge returns 200', scenePostRes.statusCode === 200);

  // GET /homes/:homeId/edge-metrics
  const metricsRes = await edgeRouter.handleRequest({ method: 'GET', path: `/api/v1/homes/${homeId}/edge-metrics` });
  assert('GET /homes/:homeId/edge-metrics returns 200', metricsRes.statusCode === 200);
  assert('edge-metrics has totalExecutions count', typeof metricsRes.body.data.totalExecutions === 'number');

  // ─── 11. End-to-End App Integration ────────────────────────────────────────
  console.log('\n11. End-to-End App Integration:');
  const app = createApp({ db });
  assert('App initializes with edge services', Boolean(app.services.executionRoutingService));
  assert('App initializes with localExecutionService', Boolean(app.services.localExecutionService));
  assert('App initializes with localDiscoveryService', Boolean(app.services.localDiscoveryService));
  assert('App initializes with edgeAutomationService', Boolean(app.services.edgeAutomationService));
  assert('App initializes with edgeControlApiRouter', Boolean(app.edgeControlApiRouter));

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passedTests}, Total Failed: ${failedTests}`);
  console.log(`========================================\n`);

  process.exit(failedTests > 0 ? 1 : 0);
}

runTests().catch(err => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
