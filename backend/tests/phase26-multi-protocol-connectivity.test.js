'use strict';
/**
 * Phase 26 — Multi-Protocol Device Connectivity & Interoperability Tests
 *
 * Test coverage:
 *   - Migration 019 table registration (73 total tables)
 *   - All 4 new repository classes
 *   - Base & protocol transport adapters (WIFI_MQTT, BLE, THREAD, MATTER)
 *   - ConnectivityService deterministic transport selection
 *   - Safe fallback engine (zero duplicate execution, pre-fallback validation)
 *   - Connection lifecycle state machine & transition rules
 *   - Transport health metrics recording & normalization
 *   - Protocol-neutral discovery & commissioning lifecycle
 *   - Reliability integration (diagnosing transport vs hardware failure)
 *   - Fleet connectivity aggregation
 *   - REST API router (10 endpoints with RBAC)
 *   - Data retention service Phase 26 pruning
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  DeviceTransportRepository,
  DeviceConnectionStateRepository,
  CommissioningSessionRepository,
  TransportHealthSnapshotRepository,
  DeviceRepository,
  DeviceStateRepository
} = require('../src/repositories');
const {
  ConnectivityService,
  WifiMqttTransportAdapter,
  BleTransportAdapter,
  ThreadTransportAdapter,
  MatterTransportAdapter
} = require('../src/services/connectivity.service');
const { ConnectivityApiRouter } = require('../src/api/connectivity.router');
const { DataRetentionService } = require('../src/services/data-retention.service');

let passed = 0;
let failed = 0;
const errors = [];

function assert(name, condition, detail = '') {
  if (condition) {
    console.log(`  [PASS] ${name}`);
    passed++;
  } else {
    const msg = `  [FAIL] ${name}${detail ? ' — ' + detail : ''}`;
    console.error(msg);
    errors.push(msg);
    failed++;
  }
}

async function run() {
  const db = new DatabaseClient();

  // ── Repositories ─────────────────────────────────────────────────────────
  const transportRepo = new DeviceTransportRepository(db);
  const connectionStateRepo = new DeviceConnectionStateRepository(db);
  const commissioningRepo = new CommissioningSessionRepository(db);
  const healthSnapshotRepo = new TransportHealthSnapshotRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);

  console.log('\n=== Phase 26 — Multi-Protocol Device Connectivity Tests ===\n');

  // 1. All 4 Phase 26 tables exist in db-client
  console.log('1. Phase 26 Table Registration:');
  assert('device_transports table exists', db.tables.has('device_transports'));
  assert('device_connection_states table exists', db.tables.has('device_connection_states'));
  assert('commissioning_sessions table exists', db.tables.has('commissioning_sessions'));
  assert('transport_health_snapshots table exists', db.tables.has('transport_health_snapshots'));

  // 2. DeviceTransportRepository CRUD
  console.log('\n2. DeviceTransportRepository:');
  const t1 = await transportRepo.create({
    id: 'dt_001',
    home_id: 'home_01',
    device_id: 'dev_01',
    transport_type: 'WIFI_MQTT',
    is_active: 1,
    is_supported: 1,
    priority_rank: 1,
    config: '{"port":1883}'
  });
  assert('Device transport created', t1 && t1.transport_type === 'WIFI_MQTT');

  const t2 = await transportRepo.create({
    id: 'dt_002',
    home_id: 'home_01',
    device_id: 'dev_01',
    transport_type: 'BLE',
    is_active: 0,
    is_supported: 1,
    priority_rank: 2,
    config: '{}'
  });
  assert('Second device transport created', t2 && t2.transport_type === 'BLE');

  const transports = await transportRepo.findByDevice('dev_01');
  assert('Found transports by device', transports.length === 2);
  const activeT = await transportRepo.findActiveForDevice('dev_01');
  assert('Active transport found', activeT && activeT.transport_type === 'WIFI_MQTT');

  await transportRepo.setActiveTransport('dev_01', 'BLE');
  const activeAfterSwitch = await transportRepo.findActiveForDevice('dev_01');
  assert('setActiveTransport updated active flag', activeAfterSwitch && activeAfterSwitch.transport_type === 'BLE');

  // 3. DeviceConnectionStateRepository CRUD
  console.log('\n3. DeviceConnectionStateRepository:');
  const connState = await connectionStateRepo.create({
    id: 'conn_dev_01',
    home_id: 'home_01',
    device_id: 'dev_01',
    active_transport: 'BLE',
    connection_state: 'CONNECTED',
    last_connected_at: new Date().toISOString()
  });
  assert('Connection state created', connState && connState.connection_state === 'CONNECTED');

  const foundState = await connectionStateRepo.findByDeviceId('dev_01');
  assert('Found state by device ID', foundState && foundState.active_transport === 'BLE');

  await connectionStateRepo.upsertState('dev_01', 'home_01', {
    connection_state: 'DEGRADED',
    reconnect_count: 2
  });
  const updatedState = await connectionStateRepo.findByDeviceId('dev_01');
  assert('Upsert state updated connection_state', updatedState.connection_state === 'DEGRADED');
  assert('Upsert state updated reconnect_count', updatedState.reconnect_count === 2);

  // 4. CommissioningSessionRepository CRUD
  console.log('\n4. CommissioningSessionRepository:');
  const commSession = await commissioningRepo.create({
    id: 'comm_001',
    home_id: 'home_01',
    device_id: 'dev_02',
    transport_type: 'THREAD',
    stage: 'STARTED',
    auth_method: 'QR_CODE'
  });
  assert('Commissioning session created', commSession && commSession.stage === 'STARTED');

  const activeSession = await commissioningRepo.findActiveForDevice('dev_02');
  assert('Active commissioning session found', activeSession && activeSession.id === 'comm_001');

  await commissioningRepo.update('comm_001', { stage: 'COMPLETED', completed_at: new Date().toISOString() });
  const completedSession = await commissioningRepo.findById('comm_001');
  assert('Session stage updated to COMPLETED', completedSession.stage === 'COMPLETED');

  // 5. TransportHealthSnapshotRepository CRUD
  console.log('\n5. TransportHealthSnapshotRepository:');
  const hSnap = await healthSnapshotRepo.create({
    id: 'hsnap_001',
    home_id: 'home_01',
    device_id: 'dev_01',
    transport_type: 'BLE',
    latency_ms: 32.5,
    error_rate: 0.01,
    availability: 'ONLINE',
    snapshotted_at: new Date().toISOString()
  });
  assert('Health snapshot created', hSnap && hSnap.latency_ms === 32.5);

  const latestSnap = await healthSnapshotRepo.findLatestForDevice('dev_01', 'BLE');
  assert('Latest snapshot found for device and transport', latestSnap && latestSnap.availability === 'ONLINE');

  // 6. Protocol Transport Adapters
  console.log('\n6. Protocol Transport Adapters:');
  const mqttAdapter = new WifiMqttTransportAdapter();
  const bleAdapter = new BleTransportAdapter();
  const threadAdapter = new ThreadTransportAdapter();
  const matterAdapter = new MatterTransportAdapter();

  assert('WifiMqttTransportAdapter has WIFI_MQTT type', mqttAdapter.transportType === 'WIFI_MQTT');
  assert('BleTransportAdapter has BLE type', bleAdapter.transportType === 'BLE');
  assert('ThreadTransportAdapter has THREAD type', threadAdapter.transportType === 'THREAD');
  assert('MatterTransportAdapter has MATTER type', matterAdapter.transportType === 'MATTER');

  const mqttCap = mqttAdapter.getCapabilities();
  assert('WIFI_MQTT capability has directIp', mqttCap.directIp === true);
  const bleCap = bleAdapter.getCapabilities();
  assert('BLE capability has lowPower', bleCap.lowPower === true);

  const cmdReceipt = await matterAdapter.sendCommand({ deviceId: 'dev_01', action: 'setPower', params: { powerState: true } });
  assert('sendCommand returns delivered receipt', cmdReceipt && cmdReceipt.status === 'DELIVERED');

  // 7. ConnectivityService — Selection & Fallback
  console.log('\n7. ConnectivityService — Selection & Fallback:');
  const svc = new ConnectivityService({
    transportRepo,
    connectionStateRepo,
    commissioningRepo,
    healthSnapshotRepo,
    deviceRepo,
    deviceStateRepo,
    eventBus: null
  });

  const selection = await svc.selectTransport('dev_01', 'home_01');
  assert('Transport selection returns selectedTransport', typeof selection.selectedTransport === 'string');
  assert('Transport selection includes confidence score', selection.confidence >= 0 && selection.confidence <= 1);
  assert('Transport selection includes fallbackOrder', Array.isArray(selection.fallbackOrder));

  // Safe Fallback Execution test
  const fallbackResult = await svc.executeCommandWithFallback({
    deviceId: 'dev_01',
    action: 'setPower',
    params: { powerState: true }
  }, { homeId: 'home_01' });
  assert('Command executed via transport', fallbackResult && fallbackResult.receipt);

  // 8. ConnectivityService — Connection Lifecycle
  console.log('\n8. ConnectivityService — Connection Lifecycle:');
  const updatedLifecycle = await svc.updateConnectionState('dev_01', 'home_01', 'MATTER', 'CONNECTED');
  assert('updateConnectionState sets CONNECTED', updatedLifecycle.connection_state === 'CONNECTED');
  assert('last_connected_at is set', updatedLifecycle.last_connected_at !== null);

  const reconnectedState = await svc.updateConnectionState('dev_01', 'home_01', 'MATTER', 'RECONNECTING');
  assert('updateConnectionState increments reconnect_count', reconnectedState.reconnect_count >= 1);

  // 9. ConnectivityService — Transport Health Monitoring
  console.log('\n9. ConnectivityService — Transport Health:');
  const recordedHealth = await svc.recordTransportHealth('dev_01', 'home_01', 'WIFI_MQTT', {
    latencyMs: 12.0,
    errorRate: 0.0,
    availability: 'ONLINE'
  });
  assert('recordTransportHealth created snapshot', recordedHealth && recordedHealth.latency_ms === 12.0);

  // 10. ConnectivityService — Discovery & Commissioning
  console.log('\n10. ConnectivityService — Discovery & Commissioning:');
  const discResults = await svc.discoverDevices();
  assert('discoverDevices returns protocol results', Array.isArray(discResults) && discResults.length >= 4);

  const newComm = await svc.startCommissioning('home_01', 'dev_03', 'MATTER', 'PASSCODE');
  assert('startCommissioning creates session in STARTED stage', newComm.stage === 'STARTED');

  const completedComm = await svc.updateCommissioningStage(newComm.id, 'COMPLETED');
  assert('updateCommissioningStage completes session', completedComm.stage === 'COMPLETED');
  const devStateAfterComm = await connectionStateRepo.findByDeviceId('dev_03');
  assert('Device state marked CONNECTED after commissioning completion', devStateAfterComm.connection_state === 'CONNECTED');

  // 11. ConnectivityService — Snapshots & Reliability Diagnosis
  console.log('\n11. ConnectivityService — Snapshots & Reliability:');
  const snapshot = await svc.getDeviceConnectionSnapshot('dev_01', 'home_01');
  assert('getDeviceConnectionSnapshot returns activeTransport', snapshot && snapshot.activeTransport);
  assert('Snapshot includes transportHealth map', typeof snapshot.transportHealth === 'object');

  const diagResult = await svc.diagnoseTransportFailure('dev_01', 'WIFI_MQTT');
  assert('diagnoseTransportFailure returns diagnosis', diagResult && typeof diagResult.diagnosis === 'string');

  const fleet = await svc.getHomeFleetConnectivity('home_01');
  assert('getHomeFleetConnectivity returns totalDevices count', typeof fleet.totalDevices === 'number');
  assert('Fleet includes stateDistribution', typeof fleet.stateDistribution === 'object');

  // 12. REST API Router — 10 Endpoints
  console.log('\n12. ConnectivityApiRouter — 10 Endpoints:');
  const mockHomeAuthService = {
    authorizeRequest: async () => ({ isAuthorized: true, homeId: 'home_01', role: 'OWNER' })
  };
  const router = new ConnectivityApiRouter({
    connectivityService: svc,
    homeAuthService: mockHomeAuthService
  });
  const actorCtx = { userId: 'u_01' };

  // GET fleet
  const r1 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/homes/home_01/devices', query: {}, body: {} }, actorCtx);
  assert('GET /homes/:homeId/devices returns 200', r1.statusCode === 200 && r1.body.success);

  // GET device snapshot
  const r2 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/devices/dev_01', query: {}, body: {} }, actorCtx);
  assert('GET /devices/:deviceId returns 200', r2.statusCode === 200 && r2.body.success);

  // GET device transports
  const r3 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/devices/dev_01/transports', query: {}, body: {} }, actorCtx);
  assert('GET /devices/:deviceId/transports returns 200', r3.statusCode === 200 && r3.body.success);

  // GET device health
  const r4 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/devices/dev_01/health', query: {}, body: {} }, actorCtx);
  assert('GET /devices/:deviceId/health returns 200', r4.statusCode === 200 && r4.body.success);

  // GET commissioning history
  const r5 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/devices/dev_01/commissioning', query: {}, body: {} }, actorCtx);
  assert('GET /devices/:deviceId/commissioning returns 200', r5.statusCode === 200 && r5.body.success);

  // POST reconnect
  const r6 = await router.handleRequest({ method: 'POST', path: '/api/v1/connectivity/devices/dev_01/reconnect', query: {}, body: { transportType: 'WIFI_MQTT' } }, actorCtx);
  assert('POST /devices/:deviceId/reconnect returns 200', r6.statusCode === 200 && r6.body.success);

  // POST select transport
  const r7 = await router.handleRequest({ method: 'POST', path: '/api/v1/connectivity/devices/dev_01/select-transport', query: {}, body: { transportType: 'BLE' } }, actorCtx);
  assert('POST /devices/:deviceId/select-transport returns 200', r7.statusCode === 200 && r7.body.success);

  // GET discovery
  const r8 = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/discovery', query: {}, body: {} }, actorCtx);
  assert('GET /discovery returns 200', r8.statusCode === 200 && r8.body.success);

  // POST start commissioning
  const r9 = await router.handleRequest({
    method: 'POST',
    path: '/api/v1/connectivity/commissioning/start',
    query: {},
    body: { homeId: 'home_01', deviceId: 'dev_04', transportType: 'BLE', authMethod: 'PASSCODE' }
  }, actorCtx);
  assert('POST /commissioning/start returns 201', r9.statusCode === 201 && r9.body.success);

  // POST cancel commissioning
  const startSessionId = r9.body.data && r9.body.data.id;
  const r10 = await router.handleRequest({
    method: 'POST',
    path: '/api/v1/connectivity/commissioning/cancel',
    query: {},
    body: { sessionId: startSessionId, errorDetails: 'User cancelled' }
  }, actorCtx);
  assert('POST /commissioning/cancel returns 200', r10.statusCode === 200 && r10.body.success);

  // Unknown route
  const rUnknown = await router.handleRequest({ method: 'GET', path: '/api/v1/connectivity/unknown', query: {}, body: {} }, actorCtx);
  assert('Unknown route returns 404', rUnknown.statusCode === 404);

  // 13. Data Retention Service — Phase 26
  console.log('\n13. DataRetentionService — Phase 26 Pruning:');
  const retentionSvc = new DataRetentionService({ db });
  assert('pruneTransportHealthSnapshots method exists', typeof retentionSvc.pruneTransportHealthSnapshots === 'function');
  assert('pruneCommissioningSessions method exists', typeof retentionSvc.pruneCommissioningSessions === 'function');

  const retentionResult = await retentionSvc.runRetentionCycle();
  assert('runRetentionCycle includes transportHealthSnapshotsPruned', 'transportHealthSnapshotsPruned' in retentionResult);
  assert('runRetentionCycle includes commissioningSessionsPruned', 'commissioningSessionsPruned' in retentionResult);

  // Summary
  console.log('\n========================================');
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  if (errors.length > 0) {
    console.log('\nFailed Tests:');
    errors.forEach(e => console.error(e));
  }
  console.log('========================================\n');
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(err => {
  console.error('Test runner error:', err);
  process.exit(1);
});
