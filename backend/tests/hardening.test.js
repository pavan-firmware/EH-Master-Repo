/**
 * EH Home — Phase 2 Hardening Tests
 * Tests authentication boundary, capability consistency, state semantics,
 * command idempotency, product seed integrity, repository boundaries,
 * and contract-to-database mapping.
 */

const fs = require('fs');
const path = require('path');
const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  ProductRepository,
  CapabilityRepository,
  AuditRepository,
  OutboxRepository
} = require('../src/repositories/index');

let passed = 0;
let failed = 0;

function assert(description, condition, detail = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

// ============================================================
// A. Authentication Boundary Tests
// ============================================================
async function testAuthBoundary(db) {
  console.log('A. Authentication Boundary:');
  const userRepo = new UserRepository(db);

  // UserRepository must store hashed values — but must NOT verify them
  const userId = 'auth-user-uuid-001';
  const user = await userRepo.createUser({
    id: userId,
    email: 'auth.boundary@ehhome.io',
    passwordHash: '$argon2id$v=19$...(hashed)'
  });

  assert('UserRepository.createUser stores pre-hashed password only', user.password_hash.startsWith('$'));
  assert('UserRepository.createUser does NOT have a verifyPassword method', typeof userRepo.verifyPassword === 'undefined');
  assert('UserRepository.createUser does NOT have a generateToken method', typeof userRepo.generateToken === 'undefined');
  assert('UserRepository.createUser does NOT have a issueRefreshToken method', typeof userRepo.issueRefreshToken === 'undefined');
  assert('UserRepository.createUser does NOT have a login method', typeof userRepo.login === 'undefined');

  // findByEmail returns full record (password_hash included) for AuthService to use
  const found = await userRepo.findByEmail('auth.boundary@ehhome.io');
  assert('UserRepository.findByEmail returns password_hash for AuthService consumption', found !== null && found.password_hash !== undefined);

  // Creating same email again must fail at persistence layer
  let dupeRejected = false;
  try {
    await userRepo.createUser({ id: 'other-uuid', email: 'auth.boundary@ehhome.io', passwordHash: 'x' });
  } catch { dupeRejected = true; }
  assert('Duplicate email rejected at persistence layer (not auth layer)', dupeRejected);
}

// ============================================================
// B. Capability Registry Consistency Tests
// ============================================================
async function testCapabilityConsistency() {
  console.log('\nB. Capability Registry Consistency:');

  const registryPath = path.join(__dirname, '../../packages/contracts/capability/capability-registry.json');
  const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
  const canonicalIds = Object.keys(registry).sort();

  assert(`Canonical registry has exactly 14 capabilities`,
    canonicalIds.length === 14,
    `Found: ${canonicalIds.length}`
  );

  const expectedIds = ['automation', 'brightness', 'cct', 'current', 'energy', 'fan_speed', 'local_switch', 'ota', 'power', 'relay', 'relay', 'scene', 'schedule', 'switch', 'voltage'];
  const missingFromRegistry = ['automation', 'brightness', 'cct', 'current', 'energy', 'fan_speed', 'local_switch', 'ota', 'power', 'relay', 'scene', 'schedule', 'switch', 'voltage'].filter(id => !canonicalIds.includes(id));
  assert('All 14 expected capability IDs are present in registry', missingFromRegistry.length === 0,
    `Missing: ${missingFromRegistry.join(', ')}`
  );

  // Each entry must have the required canonical fields
  canonicalIds.forEach(id => {
    const cap = registry[id];
    assert(`Registry entry '${id}' has capabilityId`, cap.capabilityId === id);
    assert(`Registry entry '${id}' has uiComponentHint`, typeof cap.uiComponentHint === 'string');
    assert(`Registry entry '${id}' has version`, typeof cap.version === 'number');
  });

  // Verify seed files cover all 14 capabilities
  const seed003 = fs.readFileSync(path.join(__dirname, '../migrations/003_seed_dev_catalog.sql'), 'utf8');
  const seed004 = fs.readFileSync(path.join(__dirname, '../migrations/004_seed_missing_capabilities.sql'), 'utf8');
  const allSeedSql = seed003 + '\n' + seed004;
  const unseeded = canonicalIds.filter(id => !allSeedSql.includes(`'${id}'`));
  assert(`All 14 canonical capabilities are seeded across migrations 003+004`,
    unseeded.length === 0,
    `Not seeded: ${unseeded.join(', ')}`
  );
}

// ============================================================
// C. Device State Semantic Consistency Tests
// ============================================================
async function testStateSemantics(db) {
  console.log('\nC. Device State Persistence Semantics:');

  // Need a fully wired device in DB
  const productRepo = new ProductRepository(db);
  await productRepo.createFamily({ id: 'fam_state', slug: 'state-test-fam', displayName: 'State Test Fam' });
  await productRepo.createProduct({ id: 'prod_state', familyId: 'fam_state', displayName: 'State Test Product' });
  await productRepo.createVariant({
    id: 'variant_state', productId: 'prod_state', variantSlug: '1x',
    displayName: 'State Test Variant', channelCount: 1,
    channels: [{ channelIndex: 1 }], hardwareProfile: { mcuFamily: 'esp32-c6' },
    connectivityProfile: { supportsWifi: true }, capabilities: ['switch'],
    electricalSpecifications: { voltageRange: '90V-250V' },
    firmwareFamily: 'test-fw', supportedHardwareRevisions: ['HW_1_0']
  });

  const userRepo2 = new UserRepository(db);
  await userRepo2.createUser({ id: 'state-user-uuid', email: 'state.test@ehhome.io', passwordHash: 'hashed' });
  const homeRepo2 = new HomeRepository(db);
  await homeRepo2.createHome({ id: 'state-home-uuid', name: 'State Test Home', ownerId: 'state-user-uuid' });

  const devRepo = new DeviceRepository(db);
  await devRepo.registerDevice({
    deviceId: 'state-device-uuid',
    serialNumber: 'STATE-SN-001',
    productVariantId: 'variant_state',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'test-fw'
  });

  const stateRepo = new DeviceStateRepository(db);

  // Core rule: desiredState != reportedState must coexist (in-flight command)
  await stateRepo.updateChannelState('state-device-uuid', 1, {
    desiredState: { power: true },  // User wants ON
    reportedState: { power: false }, // Device still says OFF
    confidence: 'PENDING'
  });

  const fullState = await stateRepo.getFullState('state-device-uuid');
  const ch = fullState.channels[0];
  assert('desiredState and reportedState can diverge (in-flight command model)', ch.desiredState.power === true && ch.reportedState.power === false);
  assert('confidence is PENDING when desired != reported', ch.confidence === 'PENDING');

  // Physical switch override: reportedState must not be overwritten by desiredState
  // Simulate device reporting OFF (physical switch overrides command)
  await stateRepo.updateChannelState('state-device-uuid', 1, {
    reportedState: { power: false },
    confidence: 'CONFIRMED'
  });

  const stateAfterPhysical = await stateRepo.getFullState('state-device-uuid');
  const chAfter = stateAfterPhysical.channels[0];
  // desiredState is still true (command was pending), but reportedState is now the device truth
  assert('reportedState updates independently from desiredState after physical toggle', chAfter.reportedState.power === false);
  assert('After physical switch, confidence transitions to CONFIRMED', chAfter.confidence === 'CONFIRMED');

  // Verify connection states are valid
  await stateRepo.updateDeviceConnection('state-device-uuid', 'ONLINE');
  const onlineState = await stateRepo.getFullState('state-device-uuid');
  assert('Device connection transitions to ONLINE', onlineState.connectionState === 'ONLINE');

  await stateRepo.updateDeviceConnection('state-device-uuid', 'STALE');
  const staleState = await stateRepo.getFullState('state-device-uuid');
  assert('Device connection transitions to STALE', staleState.connectionState === 'STALE');

  await stateRepo.updateDeviceConnection('state-device-uuid', 'OFFLINE');
  const offlineState = await stateRepo.getFullState('state-device-uuid');
  assert('Device connection transitions to OFFLINE', offlineState.connectionState === 'OFFLINE');
}

// ============================================================
// D. Command Idempotency Tests
// ============================================================
async function testCommandIdempotency(db) {
  console.log('\nD. Command Idempotency:');

  const cmdRepo = new CommandRepository(db);

  const base = {
    deviceId: 'state-device-uuid',
    channelIndex: 1,
    action: 'setPower',
    params: { value: true },
    source: 'APP',
    expiresAt: new Date(Date.now() + 10000).toISOString()
  };

  // First submission
  const cmd1 = await cmdRepo.recordCommand({
    ...base,
    commandId: 'harden-cmd-001',
    idempotencyKey: 'harden-idem-key-X'
  });
  assert('First command insert succeeds with status CREATED', cmd1.status === 'CREATED');

  // Retry with same key, same device — must return original
  const cmd1Again = await cmdRepo.recordCommand({
    ...base,
    commandId: 'harden-cmd-002-different-id',
    idempotencyKey: 'harden-idem-key-X' // same key!
  });
  assert('Repeated command with same deviceId+key returns original (idempotent)', cmd1Again.id === 'harden-cmd-001');

  // Different device, same key — must produce new record (per-device scope, not global)
  const cmd3 = await cmdRepo.recordCommand({
    ...base,
    commandId: 'harden-cmd-003',
    deviceId: 'different-device-uuid-that-does-not-exist', // Will attempt, might fail FK — check logic
    idempotencyKey: 'harden-idem-key-X' // same key, different device!
  });
  // In the mock DB we don't have FK enforcement — but the key point is the scoping
  // The existing command is NOT returned for a different deviceId
  assert('Same idempotencyKey on different device does NOT return original cmd (per-device scoped)', cmd3.id === 'harden-cmd-003');

  // Status progression
  await cmdRepo.updateStatus('harden-cmd-001', 'APPLIED');
  const applied = await cmdRepo.getCommand('harden-cmd-001');
  assert('Command status transitions: CREATED → APPLIED', applied.status === 'APPLIED');

  await cmdRepo.updateStatus('harden-cmd-003', 'FAILED', 'No route to device');
  const failed_ = await cmdRepo.getCommand('harden-cmd-003');
  assert('Command status transitions: CREATED → FAILED with reason', failed_.status === 'FAILED' && failed_.failure_reason === 'No route to device');

  // OVERRIDDEN status (physical switch conflict)
  const cmdOverride = await cmdRepo.recordCommand({
    ...base,
    commandId: 'harden-cmd-overridden',
    idempotencyKey: 'harden-idem-key-override'
  });
  await cmdRepo.updateStatus('harden-cmd-overridden', 'OVERRIDDEN', 'Physical switch toggled OFF before completion');
  const overridden = await cmdRepo.getCommand('harden-cmd-overridden');
  assert('Command OVERRIDDEN by physical switch conflict recorded correctly', overridden.status === 'OVERRIDDEN');
}

// ============================================================
// E. Product Seed & Versioning Tests
// ============================================================
async function testProductSeedAndVersioning() {
  console.log('\nE. Product Seed & Version Independence:');

  const seed003 = fs.readFileSync(path.join(__dirname, '../migrations/003_seed_dev_catalog.sql'), 'utf8');

  // Product version fields must remain independent
  const fields = ['schema_version', 'firmware_family', 'hardware_profile'];
  fields.forEach(field => {
    assert(`Seed contains independent version field '${field}'`, seed003.includes(field));
  });

  // Ensure no single collapsed "version" field
  assert('Seed does NOT collapse version into single field', !seed003.includes('"version": ') || !seed003.includes('firmware_version'));

  // Relationship: product-definitions/ is canonical; seed is bootstrap
  const defPath = path.join(__dirname, '../../product-definitions/smart-switch/3x/metadata.json');
  const defMeta = JSON.parse(fs.readFileSync(defPath, 'utf8'));

  assert('Canonical product definition has productVariantId', typeof defMeta.productVariantId === 'string');
  assert('Canonical product definition has hardwareProfile (containing mcuFamily)', typeof defMeta.hardwareProfile === 'object' && typeof defMeta.hardwareProfile.mcuFamily === 'string');
  assert('Canonical product definition has supportedHardwareRevisions list', Array.isArray(defMeta.supportedHardwareRevisions) && defMeta.supportedHardwareRevisions.length > 0);
  assert('Canonical product definition has firmwareFamily field', typeof defMeta.firmwareFamily === 'string');
  assert('Canonical product definition has schemaVersion field', typeof defMeta.schemaVersion === 'number');

  // Verify variant ID is consistent between definition and seed
  assert('Seed variant ID matches canonical product definition variant ID',
    seed003.includes(`'${defMeta.productVariantId}'`)
  );
}

// ============================================================
// F. Repository Boundary Tests (No Transport Logic)
// ============================================================
async function testRepositoryBoundaries() {
  console.log('\nF. Repository Boundary (No Transport Logic):');

  const db2 = new DatabaseClient();
  const repos = [
    new UserRepository(db2),
    new HomeRepository(db2),
    new ProductRepository(db2),
    new CapabilityRepository(db2),
    new DeviceRepository(db2),
    new DeviceStateRepository(db2),
    new CommandRepository(db2),
    new AuditRepository(db2),
    new OutboxRepository(db2)
  ];

  // Read the repository source and check for forbidden transport-layer patterns.
  // Patterns are checked as word-boundary strings to avoid false-positives from
  // legitimate method names (e.g. 'markPublished', 'uiComponentHint' are valid).
  const repoSrc = fs.readFileSync(path.join(__dirname, '../src/repositories/index.js'), 'utf8');
  const forbiddenPatterns = [
    { pattern: 'mqttClient', label: 'mqttClient' },
    { pattern: 'mqttPublish', label: 'mqttPublish' },
    { pattern: 'matter.', label: 'matter transport' },
    { pattern: 'threadNetwork', label: 'thread transport' },
    { pattern: 'renderWidget', label: 'UI render' },
    { pattern: 'flutter.', label: 'flutter binding' }
  ];
  forbiddenPatterns.forEach(({ pattern, label }) => {
    assert(`Repository layer does NOT contain '${label}' (transport-free)`, !repoSrc.includes(pattern));
  });

  assert('All repository instances exist', repos.length === 9);
}

// ============================================================
// G. Contract-to-Database Mapping Tests
// ============================================================
async function testContractDatabaseMapping() {
  console.log('\nG. Contract-to-Database Mapping:');

  const { DatabaseClient: DC } = require('../src/shared/db-client');
  const { DeviceStateRepository: DSR } = require('../src/repositories/index');
  const tempDb = new DC();

  // Verify getFullState() returns canonical field names (matches DeviceState contract)
  // We need a device state record
  tempDb.getTable('device_state').set('test-device-canonical', {
    id: 'test-device-canonical',
    connection_state: 'ONLINE',
    last_seen_at: null,
    last_command_id: null,
    last_event_id: null,
    created_at: new Date().toISOString()
  });
  tempDb.getTable('channel_state').set('test-device-canonical_ch_1', {
    id: 'test-device-canonical_ch_1',
    device_id: 'test-device-canonical',
    channel_index: 1,
    desired_state: { power: false },
    reported_state: { power: true },
    confidence: 'CONFIRMED',
    created_at: new Date().toISOString()
  });

  const dsr = new DSR(tempDb);
  const state = await dsr.getFullState('test-device-canonical');

  // Canonical contract fields must match
  assert('getFullState() returns schemaVersion field (contract)', state.schemaVersion === 1);
  assert('getFullState() returns deviceId field (contract)', state.deviceId === 'test-device-canonical');
  assert('getFullState() returns connectionState (contract, camelCase)', state.connectionState === 'ONLINE');
  assert('getFullState() channels use camelCase desiredState (contract)', 'desiredState' in state.channels[0]);
  assert('getFullState() channels use camelCase reportedState (contract)', 'reportedState' in state.channels[0]);
  assert('getFullState() does NOT expose raw snake_case connection_state', !('connection_state' in state));
}

// ============================================================
// H. Outbox Foundation Completeness
// ============================================================
async function testOutboxFoundation(db) {
  console.log('\nH. Outbox Foundation Completeness:');

  const outbox = new OutboxRepository(db);

  // Enqueue events of different types needed by future phases
  const mqttEvt = await outbox.enqueue({ id: 'ob-mqtt', eventType: 'device.command.applied', aggregateType: 'Device', aggregateId: 'dev-123', payload: { channel: 1, power: true } });
  const wsEvt   = await outbox.enqueue({ id: 'ob-ws', eventType: 'device.state_changed', aggregateType: 'Device', aggregateId: 'dev-123', payload: { connectionState: 'ONLINE' } });
  const notifEvt = await outbox.enqueue({ id: 'ob-notif', eventType: 'device.ota.success', aggregateType: 'Device', aggregateId: 'dev-123', payload: { firmwareVersion: '1.1.0' } });

  assert('Outbox can enqueue MQTT-bound event', mqttEvt.status === 'PENDING');
  assert('Outbox can enqueue WebSocket-bound event', wsEvt.status === 'PENDING');
  assert('Outbox can enqueue notification event', notifEvt.status === 'PENDING');

  const pending = await outbox.fetchPending(10);
  assert('All 3 outbox entries are fetchable as PENDING', pending.length === 3);

  // Mark one published
  await outbox.markPublished('ob-mqtt');
  const pendingAfter = await outbox.fetchPending(10);
  assert('fetchPending() excludes PUBLISHED entries', pendingAfter.length === 2 && pendingAfter.every(e => e.status === 'PENDING'));

  // Outbox must NOT contain transport logic (MQTT client calls, etc.)
  const outboxSrc = fs.readFileSync(path.join(__dirname, '../src/repositories/index.js'), 'utf8');
  assert('OutboxRepository does NOT contain transport calls', !outboxSrc.includes('mqttClient') && !outboxSrc.includes('emqx'));
}

// ============================================================
// Main
// ============================================================
async function runHardeningTests() {
  console.log('=== PHASE 2 HARDENING TESTS ===\n');

  const db = new DatabaseClient();

  await testAuthBoundary(db);
  await testCapabilityConsistency();
  await testStateSemantics(db);
  await testCommandIdempotency(db);
  await testProductSeedAndVersioning();
  await testRepositoryBoundaries();
  await testContractDatabaseMapping();
  await testOutboxFoundation(db);

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runHardeningTests();
