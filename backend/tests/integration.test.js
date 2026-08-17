const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  ProductRepository,
  CapabilityRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  EventRepository,
  AuditRepository,
  OutboxRepository
} = require('../src/repositories/index');

let passed = 0;
let failed = 0;

function assert(description, condition, details = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description} ${details}`);
    failed++;
  }
}

async function runIntegrationTests() {
  console.log('=== BACKEND DATABASE & REPOSITORY INTEGRATION TESTS ===\n');

  const db = new DatabaseClient();

  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const productRepo = new ProductRepository(db);
  const capRepo = new CapabilityRepository(db);
  const devRepo = new DeviceRepository(db);
  const stateRepo = new DeviceStateRepository(db);
  const cmdRepo = new CommandRepository(db);
  const eventRepo = new EventRepository(db);
  const auditRepo = new AuditRepository(db);
  const outboxRepo = new OutboxRepository(db);

  // 1. User & Identity Integration
  console.log('1. User & Identity Domain:');
  const userId = '11111111-1111-1111-1111-111111111111';
  const user = await userRepo.createUser({
    id: userId,
    email: 'test.owner@ehhome.io',
    passwordHash: '$2b$12$e0M2/3r...'
  });
  assert('User created with relational fields', user.email === 'test.owner@ehhome.io');

  let duplicateUserFailed = false;
  try {
    await userRepo.createUser({ id: '22222222-2222-2222-2222-222222222222', email: 'test.owner@ehhome.io', passwordHash: 'hash' });
  } catch (e) {
    duplicateUserFailed = true;
  }
  assert('Unique email constraint enforced', duplicateUserFailed);

  // 2. Home & Membership Integration
  console.log('\n2. Home & Membership Domain:');
  const homeId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const home = await homeRepo.createHome({
    id: homeId,
    name: 'Green Villa',
    timezone: 'Asia/Kolkata',
    ownerId: userId
  });
  assert('Home created with owner', home.name === 'Green Villa');
  const memberships = await homeRepo.getMembershipsForUser(userId);
  assert('Owner membership auto-created with role OWNER', memberships.length === 1 && memberships[0].role === 'OWNER');

  // 3. Floors & Rooms
  console.log('\n3. Floors & Rooms Domain:');
  const floorId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  await roomRepo.createFloor({ id: floorId, homeId, name: 'Ground Floor', level: 0 });
  const roomId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const room = await roomRepo.createRoom({ id: roomId, homeId, floorId, name: 'Living Room', iconKey: 'sofa' });
  assert('Room created and assigned to floor and home', room.name === 'Living Room' && room.floor_id === floorId);

  // 4. Product Catalog & Capabilities
  console.log('\n4. Product Catalog & Capabilities Domain:');
  await productRepo.createFamily({ id: 'smart_switch', slug: 'smart-switch', displayName: 'Smart Switches' });
  await productRepo.createProduct({ id: 'eh-smart-switch', familyId: 'smart_switch', displayName: 'EH Smart Switch' });
  const variant = await productRepo.createVariant({
    id: 'eh-smart-switch-3x',
    productId: 'eh-smart-switch',
    variantSlug: '3x',
    displayName: 'EH Smart Switch 3X',
    channelCount: 3,
    channels: [{ channelIndex: 1 }, { channelIndex: 2 }, { channelIndex: 3 }],
    hardwareProfile: { mcuFamily: 'esp32-c6' },
    connectivityProfile: { supportsWifi: true },
    capabilities: ['switch', 'relay', 'energy', 'ota'],
    electricalSpecifications: { voltageRange: '90V-250V AC' },
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0']
  });
  assert('Product variant created with 3 channels and metadata', variant.channel_count === 3);

  // 5. Device Registration & Claiming
  console.log('\n5. Device Identity & Claiming Domain:');
  const deviceId = '0194fe23-7a1b-7890-a123-456789abcdef';
  const dev = await devRepo.registerDevice({
    deviceId,
    serialNumber: 'EH-SW3X-2026W12-00891',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.0.0'
  });
  assert('Device registered and initialized with 3 channel states', dev.serial_number === 'EH-SW3X-2026W12-00891');

  const claim = await devRepo.claimDevice({
    deviceId,
    homeId,
    roomId,
    customName: 'Hall Lights Switchboard',
    channelLabels: { "1": "Chandelier", "2": "Fan", "3": "Spotlights" },
    claimedByUserId: userId
  });
  assert('Device claimed into Home and Room with channel labels', claim.custom_name === 'Hall Lights Switchboard');

  // 6. Device State & State Decoupling
  console.log('\n6. Device State Domain:');
  await stateRepo.updateDeviceConnection(deviceId, 'ONLINE');
  await stateRepo.updateChannelState(deviceId, 1, {
    desiredState: { power: true },
    reportedState: { power: false },
    confidence: 'CONFIRMED'
  });
  const fullState = await stateRepo.getFullState(deviceId);
  assert('Full state retrieved with ONLINE connection', fullState.connectionState === 'ONLINE');
  assert('Decoupled channel state preserves desired ON vs reported OFF', fullState.channels[0].desiredState.power === true && fullState.channels[0].reportedState.power === false);

  // 7. Command Persistence & Idempotency
  console.log('\n7. Command Persistence & Idempotency Domain:');
  const cmd1 = await cmdRepo.recordCommand({
    commandId: 'cmd-001-uuid',
    deviceId,
    channelIndex: 1,
    action: 'setPower',
    params: { value: true },
    idempotencyKey: 'idem_key_unique_123',
    source: 'APP',
    expiresAt: new Date(Date.now() + 10000).toISOString()
  });
  assert('Command recorded with status CREATED', cmd1.status === 'CREATED');

  // Idempotent retry
  const cmd1Retry = await cmdRepo.recordCommand({
    commandId: 'cmd-002-uuid',
    deviceId,
    channelIndex: 1,
    action: 'setPower',
    params: { value: true },
    idempotencyKey: 'idem_key_unique_123', // Same key!
    source: 'APP',
    expiresAt: new Date(Date.now() + 10000).toISOString()
  });
  assert('Idempotent command receipt returns original without duplicating', cmd1Retry.id === 'cmd-001-uuid');

  await cmdRepo.updateStatus('cmd-001-uuid', 'APPLIED');
  const cmdApplied = await cmdRepo.getCommand('cmd-001-uuid');
  assert('Command status updated to APPLIED with completedAt', cmdApplied.status === 'APPLIED' && cmdApplied.completed_at !== null);

  // 8. Event Persistence & Monotonic Ordering
  console.log('\n8. Event Persistence Domain:');
  await eventRepo.recordEvent({
    eventId: 'evt-001-uuid',
    deviceId,
    channelIndex: 1,
    eventType: 'switch.changed',
    source: 'PHYSICAL_SWITCH',
    payload: { power: true },
    sequenceNumber: 101,
    timestamp: '2026-03-01T12:00:00.010Z'
  });
  await eventRepo.recordEvent({
    eventId: 'evt-002-uuid',
    deviceId,
    channelIndex: 1,
    eventType: 'switch.changed',
    source: 'PHYSICAL_SWITCH',
    payload: { power: false },
    sequenceNumber: 102,
    timestamp: '2026-03-01T12:00:05.000Z'
  });
  const events = await eventRepo.getEventsByDevice(deviceId);
  assert('Events recorded and sorted descending by sequenceNumber', events.length === 2 && events[0].sequence_number === 102);

  // 9. Outbox & Audit Persistence
  console.log('\n9. Audit & Outbox Domain:');
  const auditEntry = await auditRepo.log({
    id: 'audit-001-uuid',
    actorUserId: userId,
    deviceId,
    homeId,
    action: 'DEVICE_CLAIMED',
    payload: { customName: 'Hall Lights Switchboard' }
  });
  assert('Audit log written with actor and home context', auditEntry.action === 'DEVICE_CLAIMED');

  const outboxEntry = await outboxRepo.enqueue({
    id: 'outbox-001-uuid',
    eventType: 'device.state_changed',
    aggregateType: 'Device',
    aggregateId: deviceId,
    payload: { channel: 1, power: true }
  });
  assert('Outbox entry enqueued with status PENDING', outboxEntry.status === 'PENDING');

  const pending = await outboxRepo.fetchPending(10);
  assert('Pending outbox items fetched', pending.length === 1 && pending[0].id === 'outbox-001-uuid');

  await outboxRepo.markPublished('outbox-001-uuid');
  const pendingAfter = await outboxRepo.fetchPending(10);
  assert('Outbox item marked PUBLISHED', pendingAfter.length === 0);

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runIntegrationTests();
