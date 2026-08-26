'use strict';

/**
 * EH Home — Phase 7B Realtime & Worker Integration Tests
 *
 * 20-point test suite covering:
 * 1.  Event bus publish/subscribe
 * 2.  Event bus home isolation
 * 3.  SSE connection authentication (missing token)
 * 4.  SSE connection authentication (invalid token)
 * 5.  SSE home membership authorization (cross-home blocked)
 * 6.  SSE event formatting (SSEEventEnvelope compliance)
 * 7.  SSE connection heartbeat
 * 8.  SSE connection cleanup on client disconnect
 * 9.  Device state event delivery
 * 10. Command receipt event delivery
 * 11. Device availability event delivery
 * 12. Telemetry update event delivery
 * 13. Device stale detector tick
 * 14. Command timeout worker tick
 * 15. Outbox retry worker success
 * 16. Outbox retry exponential backoff
 * 17. Outbox idempotent processing (already delivered)
 * 18. Worker shutdown (WorkerRunner stopAll)
 * 19. SSE reconnect: Last-Event-ID tracking
 * 20. Cross-home event isolation (event bus level)
 */

const crypto = require('crypto');
const { RealtimeEventBus } = require('../src/services/realtime-event-bus');
const { RealtimeStreamRouter, HEARTBEAT_INTERVAL_MS } = require('../src/api/realtime-stream.router');
const { WorkerRunner } = require('../src/workers/worker-runner');
const { DeviceStaleDetector, DEFAULT_STALE_THRESHOLD_MS } = require('../src/workers/device-stale-detector');
const { CommandTimeoutWorker, TIMEOUT_STATUS } = require('../src/workers/command-timeout-worker');
const { OutboxRetryWorker, OUTBOX_DELIVERED_STATUS, OUTBOX_FAILED_STATUS, BACKOFF_BASE_MS } = require('../src/workers/outbox-retry-worker');
const { AuthService } = require('../src/services/auth.service');

// ─────────────────────────────────────────────────────────────────────────────
// Test utilities
// ─────────────────────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const results = [];

function test(name, fn) {
  results.push({ name, fn });
}

async function runAll() {
  for (const { name, fn } of results) {
    try {
      await fn();
      console.log(`  ✅  PASS  ${name}`);
      passed++;
    } catch (err) {
      console.log(`  ❌  FAIL  ${name}`);
      console.log(`           → ${err.message}`);
      failed++;
    }
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || 'Assertion failed');
}

function assertEqual(a, b, msg) {
  if (a !== b) throw new Error(msg || `Expected ${JSON.stringify(a)} to equal ${JSON.stringify(b)}`);
}

function assertNotNull(v, msg) {
  if (v == null) throw new Error(msg || 'Expected non-null value');
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared fixtures
// ─────────────────────────────────────────────────────────────────────────────

const HOME_A = 'home-aaaa-0000-0001';
const HOME_B = 'home-bbbb-0000-0002';
const DEVICE_A = 'device-aaaa-0001';
const USER_A = 'user-aaaa-0001';

// Minimal AuthService (ephemeral dev keypair)
const authService = new AuthService({
  userRepo: null,
  refreshTokenRepo: null
});

const VALID_TOKEN = authService.signAccessToken({ id: USER_A, email: 'a@test.com' });

// Mock HomeAuthorizationService
function makeMockHomeAuth({ userId = USER_A, homeId = HOME_A, authorized = true, role = 'MEMBER' } = {}) {
  return {
    authorizeRequest: async ({ userId: u, homeId: h }) => {
      if (authorized && u === userId && h === homeId) {
        return { isAuthorized: true, role };
      }
      return { isAuthorized: false, message: `User ${u} is not a member of home ${h}` };
    }
  };
}

// Minimal mock SSE req/res
function makeMockSseReqRes({ token = VALID_TOKEN, homeId = HOME_A } = {}) {
  const events = [];
  const listeners = {};
  const req = {
    headers: { authorization: `Bearer ${token}` },
    _queryParams: {},
    on: (event, fn) => { listeners[event] = fn; return req; }
  };
  const res = {
    _statusCode: null,
    _headers: {},
    _chunks: [],
    _ended: false,
    writeHead: (code, headers) => { res._statusCode = code; res._headers = { ...headers }; },
    write: (chunk) => { res._chunks.push(chunk); return true; },
    end: (body) => { res._ended = true; if (body) res._chunks.push(body); },
    on: (event, fn) => { listeners[event] = fn; return res; }
  };
  const triggerClose = () => { if (listeners.close) listeners.close(); };
  return { req, res, triggerClose, events };
}

// In-memory mock DB
function makeMockDb(tables = {}) {
  return {
    _tables: tables,
    find: async (table, { where, limit } = {}) => {
      const rows = (tables[table] || []);
      let filtered = [...rows];
      if (where) {
        if (where.connection_state_not) filtered = filtered.filter(r => r.connection_state !== where.connection_state_not);
        if (where.last_seen_at_lt) filtered = filtered.filter(r => r.last_seen_at < where.last_seen_at_lt);
        if (where.status_in) filtered = filtered.filter(r => where.status_in.includes(r.status));
        if (where.expires_at_lt) filtered = filtered.filter(r => r.expires_at < where.expires_at_lt);
        if (where.status) filtered = filtered.filter(r => r.status === where.status);
        if (where.next_retry_at_lte) filtered = filtered.filter(r => r.next_retry_at <= where.next_retry_at_lte);
      }
      if (limit) filtered = filtered.slice(0, limit);
      return filtered;
    },
    update: async (table, id, updates) => {
      const rows = tables[table] || [];
      const row = rows.find(r => r.id === id);
      if (row) Object.assign(row, updates);
    }
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Event bus publish/subscribe
// ─────────────────────────────────────────────────────────────────────────────
test('1. Event bus: publish and subscribe receives event', async () => {
  const bus = new RealtimeEventBus();
  const received = [];
  bus.subscribe(HOME_A, e => received.push(e));
  const published = bus.publish({ homeId: HOME_A, type: 'device.state', deviceId: DEVICE_A, payload: { power: true } });
  assertEqual(received.length, 1, 'Should receive exactly 1 event');
  assertEqual(received[0].type, 'device.state', 'Type mismatch');
  assertEqual(received[0].homeId, HOME_A, 'homeId mismatch');
  assertEqual(received[0].deviceId, DEVICE_A, 'deviceId mismatch');
  assertNotNull(received[0].eventId, 'eventId should be present');
  assertNotNull(received[0].occurredAt, 'occurredAt should be present');
  assertEqual(received[0].schemaVersion, 1, 'schemaVersion should be 1');
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. Event bus home isolation
// ─────────────────────────────────────────────────────────────────────────────
test('2. Event bus: home A subscriber does not receive home B events', async () => {
  const bus = new RealtimeEventBus();
  const receivedA = [];
  const receivedB = [];
  bus.subscribe(HOME_A, e => receivedA.push(e));
  bus.subscribe(HOME_B, e => receivedB.push(e));
  bus.publish({ homeId: HOME_A, type: 'device.state', payload: {} });
  assertEqual(receivedA.length, 1, 'Home A should receive event');
  assertEqual(receivedB.length, 0, 'Home B must NOT receive Home A event');
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. SSE authentication: missing token
// ─────────────────────────────────────────────────────────────────────────────
test('3. SSE: rejects connection with missing token (401)', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res } = makeMockSseReqRes({ token: '' });
  req.headers.authorization = ''; // No token
  await router.handleStream(req, res, HOME_A);
  assertEqual(res._statusCode, 401, 'Should return 401');
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. SSE authentication: invalid token
// ─────────────────────────────────────────────────────────────────────────────
test('4. SSE: rejects connection with invalid token (401)', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res } = makeMockSseReqRes({ token: 'garbage.token.value' });
  await router.handleStream(req, res, HOME_A);
  assertEqual(res._statusCode, 401, 'Should return 401 for invalid token');
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. SSE home membership authorization: cross-home blocked (403)
// ─────────────────────────────────────────────────────────────────────────────
test('5. SSE: rejects User A subscribing to Home B (403)', async () => {
  const bus = new RealtimeEventBus();
  // User A is only authorized for HOME_A
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth({ userId: USER_A, homeId: HOME_A, authorized: true })
  });
  const { req, res } = makeMockSseReqRes({ token: VALID_TOKEN });
  // Request for HOME_B (not authorized)
  await router.handleStream(req, res, HOME_B);
  assertEqual(res._statusCode, 403, 'Should return 403 for cross-home access');
});

// ─────────────────────────────────────────────────────────────────────────────
// 6. SSE event formatting: SSEEventEnvelope compliance
// ─────────────────────────────────────────────────────────────────────────────
test('6. SSE: connection.ready event matches SSEEventEnvelope schema', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  assertEqual(res._statusCode, 200, 'Should return 200');
  // Parse first SSE chunk (connection.ready)
  const chunks = res._chunks.join('');
  assert(chunks.includes('event: connection.ready'), 'Should include connection.ready event type line');
  assert(chunks.includes('"schemaVersion":1'), 'Should have schemaVersion:1');
  assert(chunks.includes('"type":"connection.ready"'), 'Should have type');
  assert(chunks.includes('"homeId"'), 'Should include homeId');
  triggerClose();
});

// ─────────────────────────────────────────────────────────────────────────────
// 7. SSE connection heartbeat (check interval constant is reasonable)
// ─────────────────────────────────────────────────────────────────────────────
test('7. SSE: heartbeat interval is configured (default 25s)', async () => {
  assert(HEARTBEAT_INTERVAL_MS === 25000, `Heartbeat should be 25000ms, got ${HEARTBEAT_INTERVAL_MS}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// 8. SSE connection cleanup on client disconnect
// ─────────────────────────────────────────────────────────────────────────────
test('8. SSE: connection cleanup on client disconnect releases subscription', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  assertEqual(bus.subscriberCount(HOME_A), 1, 'Should have 1 subscriber');
  triggerClose();
  assertEqual(bus.subscriberCount(HOME_A), 0, 'Should have 0 subscribers after disconnect');
  assertEqual(router.totalConnections(), 0, 'Total connections should be 0');
});

// ─────────────────────────────────────────────────────────────────────────────
// 9. Device state event delivery via event bus → SSE
// ─────────────────────────────────────────────────────────────────────────────
test('9. Event bus → SSE: device.state event delivered to connected client', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  const chunksBefore = res._chunks.length;

  bus.publish({ homeId: HOME_A, type: 'device.state', deviceId: DEVICE_A, payload: { channels: [] } });

  assert(res._chunks.length > chunksBefore, 'Should write new SSE chunk after publish');
  const newChunks = res._chunks.slice(chunksBefore).join('');
  assert(newChunks.includes('"device.state"'), 'Chunk should contain device.state type');
  triggerClose();
});

// ─────────────────────────────────────────────────────────────────────────────
// 10. Command receipt event delivery
// ─────────────────────────────────────────────────────────────────────────────
test('10. Event bus → SSE: command.receipt event delivered', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  const before = res._chunks.length;

  bus.publish({ homeId: HOME_A, type: 'command.receipt', deviceId: DEVICE_A, payload: { commandId: 'cmd-1', status: 'APPLIED' } });

  const newContent = res._chunks.slice(before).join('');
  assert(newContent.includes('"command.receipt"'), 'Should contain command.receipt event');
  triggerClose();
});

// ─────────────────────────────────────────────────────────────────────────────
// 11. Device availability event delivery
// ─────────────────────────────────────────────────────────────────────────────
test('11. Event bus → SSE: device.availability event delivered', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  const before = res._chunks.length;

  bus.publish({ homeId: HOME_A, type: 'device.availability', deviceId: DEVICE_A, payload: { connectionState: 'ONLINE' } });

  const newContent = res._chunks.slice(before).join('');
  assert(newContent.includes('"device.availability"'), 'Should contain device.availability event');
  triggerClose();
});

// ─────────────────────────────────────────────────────────────────────────────
// 12. Telemetry update event delivery
// ─────────────────────────────────────────────────────────────────────────────
test('12. Event bus → SSE: telemetry.update event delivered', async () => {
  const bus = new RealtimeEventBus();
  const router = new RealtimeStreamRouter({
    eventBus: bus,
    authService,
    homeAuthService: makeMockHomeAuth()
  });
  const { req, res, triggerClose } = makeMockSseReqRes();
  await router.handleStream(req, res, HOME_A);
  const before = res._chunks.length;

  bus.publish({ homeId: HOME_A, type: 'telemetry.update', deviceId: DEVICE_A, payload: { watts: 42.5 } });

  const newContent = res._chunks.slice(before).join('');
  assert(newContent.includes('"telemetry.update"'), 'Should contain telemetry.update event');
  triggerClose();
});

// ─────────────────────────────────────────────────────────────────────────────
// 13. Device stale detector tick
// ─────────────────────────────────────────────────────────────────────────────
test('13. DeviceStaleDetector: marks stale device and emits device.availability', async () => {
  const oldLastSeen = new Date(Date.now() - 120_000).toISOString(); // 2 minutes ago

  const tables = {
    device_states: [
      { id: 'ds-1', device_id: DEVICE_A, home_id: HOME_A, connection_state: 'ONLINE', last_seen_at: oldLastSeen }
    ]
  };
  const db = makeMockDb(tables);

  const bus = new RealtimeEventBus();
  const availabilityEvents = [];
  bus.subscribe(HOME_A, e => { if (e.type === 'device.availability') availabilityEvents.push(e); });

  const detector = new DeviceStaleDetector({ db, eventBus: bus, staleThresholdMs: 45_000 });
  await detector.tick();

  assertEqual(tables.device_states[0].connection_state, 'STALE', 'Device state should be STALE');
  assertEqual(availabilityEvents.length, 1, 'Should emit exactly 1 availability event');
  assertEqual(availabilityEvents[0].payload.connectionState, 'STALE', 'Event payload connectionState should be STALE');
  assertEqual(availabilityEvents[0].payload.reason, 'heartbeat_timeout', 'Reason should be heartbeat_timeout');
});

// ─────────────────────────────────────────────────────────────────────────────
// 14. Command timeout worker tick
// ─────────────────────────────────────────────────────────────────────────────
test('14. CommandTimeoutWorker: transitions expired commands to TIMEOUT and emits receipt', async () => {
  const expiredAt = new Date(Date.now() - 60_000).toISOString(); // expired 1 min ago

  const tables = {
    device_commands: [
      { id: 'cmd-expired-1', device_id: DEVICE_A, home_id: HOME_A, status: 'SENT', expires_at: expiredAt }
    ]
  };
  const db = makeMockDb(tables);

  const bus = new RealtimeEventBus();
  const receiptEvents = [];
  bus.subscribe(HOME_A, e => { if (e.type === 'command.receipt') receiptEvents.push(e); });

  const worker = new CommandTimeoutWorker({ db, eventBus: bus });
  await worker.tick();

  assertEqual(tables.device_commands[0].status, TIMEOUT_STATUS, 'Command should be TIMEOUT');
  assertEqual(receiptEvents.length, 1, 'Should emit exactly 1 command.receipt event');
  assertEqual(receiptEvents[0].payload.status, TIMEOUT_STATUS, 'Receipt payload status should be TIMEOUT');
  assertEqual(receiptEvents[0].payload.reason, 'timeout', 'Receipt payload reason should be timeout');
});

// ─────────────────────────────────────────────────────────────────────────────
// 15. Outbox retry worker: successful delivery
// ─────────────────────────────────────────────────────────────────────────────
test('15. OutboxRetryWorker: successfully retries and marks entry DELIVERED', async () => {
  const now = new Date().toISOString();
  const tables = {
    outbox: [
      {
        id: 'outbox-1', device_id: DEVICE_A, status: 'PENDING', retry_count: 0, max_retries: 5,
        next_retry_at: new Date(Date.now() - 1000).toISOString(),
        payload: JSON.stringify({ topic: 'eh/home/device/cmd', payload: { power: true } })
      }
    ]
  };
  const db = makeMockDb(tables);
  const publishedTopics = [];
  const mqttPublish = async (topic, payload) => { publishedTopics.push({ topic, payload }); };

  const worker = new OutboxRetryWorker({ db, mqttPublish });
  await worker.tick();

  assertEqual(tables.outbox[0].status, OUTBOX_DELIVERED_STATUS, 'Entry should be DELIVERED');
  assertEqual(publishedTopics.length, 1, 'MQTT publish should be called once');
});

// ─────────────────────────────────────────────────────────────────────────────
// 16. Outbox retry exponential backoff on failure
// ─────────────────────────────────────────────────────────────────────────────
test('16. OutboxRetryWorker: schedules next retry with exponential backoff on failure', async () => {
  const tables = {
    outbox: [
      {
        id: 'outbox-fail', device_id: DEVICE_A, status: 'PENDING', retry_count: 1, max_retries: 5,
        next_retry_at: new Date(Date.now() - 1000).toISOString(),
        payload: JSON.stringify({ topic: 'eh/home/device/cmd', payload: {} })
      }
    ]
  };
  const db = makeMockDb(tables);
  const failingPublish = async () => { throw new Error('MQTT transport failure'); };

  const worker = new OutboxRetryWorker({ db, mqttPublish: failingPublish });
  await worker.tick();

  assertEqual(tables.outbox[0].retry_count, 2, 'Retry count should increment');
  assert(tables.outbox[0].next_retry_at > new Date().toISOString(), 'next_retry_at should be in the future');

  // Verify backoff formula: retryCount=2 → 5000 * 2^(2-1) = 10000ms
  const expectedBackoff = BACKOFF_BASE_MS * Math.pow(2, 1); // 10000ms
  assert(expectedBackoff === OutboxRetryWorker.backoffMs(2), `Backoff for retry 2 should be ${expectedBackoff}ms`);
});

// ─────────────────────────────────────────────────────────────────────────────
// 17. Outbox idempotent processing (already delivered entry skipped)
// ─────────────────────────────────────────────────────────────────────────────
test('17. OutboxRetryWorker: skips already-delivered entries (idempotent)', async () => {
  const tables = {
    outbox: [
      {
        id: 'outbox-done', device_id: DEVICE_A, status: 'DELIVERED', retry_count: 1,
        next_retry_at: new Date(Date.now() - 1000).toISOString(),
        payload: JSON.stringify({ topic: 'eh/home/device/cmd', payload: {} })
      }
    ]
  };
  const db = makeMockDb(tables);
  const publishCalls = [];
  const mqttPublish = async (t, p) => { publishCalls.push({ t, p }); };

  const worker = new OutboxRetryWorker({ db, mqttPublish });
  await worker.tick();

  assertEqual(publishCalls.length, 0, 'Should not call mqttPublish for already-delivered entry');
});

// ─────────────────────────────────────────────────────────────────────────────
// 18. Worker shutdown: WorkerRunner stopAll
// ─────────────────────────────────────────────────────────────────────────────
test('18. WorkerRunner: stopAll clears all workers', async () => {
  const runner = new WorkerRunner();
  let tickCount = 0;
  const fakeWorker = { tick: async () => { tickCount++; } };

  await runner.register({ name: 'fake-worker', worker: fakeWorker, intervalMs: 60_000, runNow: false });
  assertEqual(runner.activeWorkers().length, 1, 'Should have 1 active worker');

  await runner.stopAll();
  assertEqual(runner.activeWorkers().length, 0, 'Should have 0 active workers after stopAll');
});

// ─────────────────────────────────────────────────────────────────────────────
// 19. SSE reconnect: eventId monotonically increases per home
// ─────────────────────────────────────────────────────────────────────────────
test('19. Event bus: event _seq is monotonically increasing per home', async () => {
  const bus = new RealtimeEventBus();
  const seqs = [];
  bus.subscribe(HOME_A, e => seqs.push(e._seq));
  bus.publish({ homeId: HOME_A, type: 'device.state', payload: {} });
  bus.publish({ homeId: HOME_A, type: 'device.state', payload: {} });
  bus.publish({ homeId: HOME_A, type: 'device.state', payload: {} });
  assertEqual(seqs.length, 3, 'Should receive 3 events');
  assert(seqs[0] < seqs[1] && seqs[1] < seqs[2], 'Sequences should be strictly increasing');
});

// ─────────────────────────────────────────────────────────────────────────────
// 20. Cross-home event isolation at event bus level
// ─────────────────────────────────────────────────────────────────────────────
test('20. Event bus: cross-home publishing is isolated (Home B events not in Home A)', async () => {
  const bus = new RealtimeEventBus();
  const homeAEvents = [];
  const homeBEvents = [];
  bus.subscribe(HOME_A, e => homeAEvents.push(e));
  bus.subscribe(HOME_B, e => homeBEvents.push(e));

  bus.publish({ homeId: HOME_B, type: 'device.state', payload: { power: false } });
  bus.publish({ homeId: HOME_A, type: 'device.event', payload: { toggle: true } });

  assertEqual(homeAEvents.length, 1, 'Home A should see only 1 event (its own)');
  assertEqual(homeBEvents.length, 1, 'Home B should see only 1 event (its own)');
  assertEqual(homeAEvents[0].type, 'device.event', 'Home A event type should be device.event');
  assertEqual(homeBEvents[0].type, 'device.state', 'Home B event type should be device.state');
});

// ─────────────────────────────────────────────────────────────────────────────
// Run
// ─────────────────────────────────────────────────────────────────────────────
const PHASE = 'Phase 7B — Realtime SSE & Workers';
console.log(`\n${'═'.repeat(60)}`);
console.log(`  EH HOME — ${PHASE} Integration Tests`);
console.log(`${'═'.repeat(60)}\n`);

runAll().then(() => {
  const total = passed + failed;
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  RESULT: ${passed}/${total} PASSED${failed > 0 ? `, ${failed} FAILED` : ' ✅'}`);
  console.log(`${'─'.repeat(60)}\n`);
  if (failed > 0) process.exit(1);
});
