/**
 * EH Home — Phase 4 Domain Model, Services & API Test Suite
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  ProductRepository,
  CapabilityRepository,
  DeviceRepository,
  DeviceStateRepository,
  AuditRepository
} = require('../src/repositories');

const { HomeService } = require('../src/services/home.service');
const { FloorService } = require('../src/services/floor.service');
const { RoomService } = require('../src/services/room.service');
const { DeviceService } = require('../src/services/device.service');
const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { HomeDeviceApiRouter } = require('../src/api/home-device.router');

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

async function runPhase4Tests() {
  console.log('=== PHASE 4 DOMAIN MODEL & SERVICE INTEGRATION TESTS ===\n');

  // Initialize MemoryDB & Repositories
  const db = new DatabaseClient();
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const productRepo = new ProductRepository(db);
  const capRepo = new CapabilityRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const auditRepo = new AuditRepository(db);
  const catalogService = new ProductCatalogService();

  // Initialize Domain Services
  const homeService = new HomeService({ homeRepo, userRepo, auditRepo });
  const floorService = new FloorService({ roomRepo, homeRepo, auditRepo });
  const roomService = new RoomService({ roomRepo, homeRepo, deviceRepo, auditRepo });
  const deviceService = new DeviceService({
    deviceRepo,
    deviceStateRepo,
    homeRepo,
    roomRepo,
    auditRepo,
    productCatalogService: catalogService
  });

  const apiRouter = new HomeDeviceApiRouter({ homeService, floorService, roomService, deviceService });

  // Seed Base Users & Product Variants in DB
  await userRepo.createUser({ id: 'usr_owner_1', email: 'owner@ehhome.com', passwordHash: 'hash_1' });
  await userRepo.createUser({ id: 'usr_admin_1', email: 'admin@ehhome.com', passwordHash: 'hash_2' });
  await userRepo.createUser({ id: 'usr_member_1', email: 'member@ehhome.com', passwordHash: 'hash_3' });

  await productRepo.createFamily({ id: 'fam_switch', slug: 'smart_switch', displayName: 'Smart Switch Family' });
  await productRepo.createProduct({ id: 'prod_switch', familyId: 'fam_switch', displayName: 'EH Smart Switch' });
  await productRepo.createVariant({
    id: 'eh-smart-switch-3x',
    productId: 'prod_switch',
    variantSlug: '3x',
    displayName: 'EH Smart Switch 3X',
    channelCount: 3,
    channels: [
      { channelIndex: 1, defaultLabel: 'Channel 1', capabilities: ['switch', 'relay', 'energy'] },
      { channelIndex: 2, defaultLabel: 'Channel 2', capabilities: ['switch', 'relay', 'energy'] },
      { channelIndex: 3, defaultLabel: 'Channel 3', capabilities: ['switch', 'relay', 'energy'] }
    ],
    hardwareProfile: { mcuFamily: 'esp32-c6' },
    connectivityProfile: { supportsWifi: true },
    capabilities: ['switch', 'relay', 'energy', 'ota'],
    electricalSpecifications: {},
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0', 'HW_1_1']
  });

  // 1. Home & Membership Rules
  console.log('1. Home & Membership Domain Rules:');
  const home1 = await homeService.createHome({
    id: 'home_main',
    name: 'Villa Residence',
    ownerId: 'usr_owner_1'
  });
  assert('Home created with owner', home1.name === 'Villa Residence' && home1.owner_id === 'usr_owner_1');

  const members = await homeService.getHomeMembers('home_main');
  assert('Owner auto-added as OWNER member', members.length === 1 && members[0].role === 'OWNER');

  await homeService.addHomeMember({ id: 'mem_admin', homeId: 'home_main', userId: 'usr_admin_1', role: 'ADMIN' });
  const members2 = await homeService.getHomeMembers('home_main');
  assert('Admin member added successfully', members2.length === 2);

  // Sole owner protection rule
  let demoteFailed = false;
  try {
    await homeService.updateHomeMemberRole({ homeId: 'home_main', userId: 'usr_owner_1', newRole: 'MEMBER' });
  } catch (err) {
    demoteFailed = err.message.includes('sole OWNER');
  }
  assert('Demoting sole OWNER is rejected', demoteFailed);

  let removeFailed = false;
  try {
    await homeService.removeHomeMember({ homeId: 'home_main', userId: 'usr_owner_1' });
  } catch (err) {
    removeFailed = err.message.includes('sole OWNER');
  }
  assert('Removing sole OWNER is rejected', removeFailed);

  // 2. Floor & Room Domain Rules & Cross-Home Validation
  console.log('\n2. Floor & Room Domain Rules & Validation:');
  const home2 = await homeService.createHome({ id: 'home_beach', name: 'Beach House', ownerId: 'usr_owner_1' });
  const floor1 = await floorService.createFloor({ id: 'fl_g', homeId: 'home_main', name: 'Ground Floor', level: 0 });
  const floor2 = await floorService.createFloor({ id: 'fl_1', homeId: 'home_main', name: 'First Floor', level: 1 });
  const beachFloor = await floorService.createFloor({ id: 'fl_b1', homeId: 'home_beach', name: 'Main Deck', level: 0 });

  const floors = await floorService.listFloors('home_main');
  assert('Floors listed and ordered by level', floors.length === 2 && floors[0].level === 0 && floors[1].level === 1);

  const roomLiving = await roomService.createRoom({ id: 'rm_living', homeId: 'home_main', floorId: 'fl_g', name: 'Living Room' });
  assert('Room created under floor on same home', roomLiving.name === 'Living Room' && roomLiving.floor_id === 'fl_g');

  // Cross-home floor assignment rejection
  let crossHomeRoomFailed = false;
  try {
    await roomService.createRoom({ id: 'rm_invalid', homeId: 'home_main', floorId: 'fl_b1', name: 'Invalid Room' });
  } catch (err) {
    crossHomeRoomFailed = err.message.includes('not target home');
  }
  assert('Creating room with floor from another home is rejected', crossHomeRoomFailed);

  let crossHomeMoveFailed = false;
  try {
    await roomService.moveRoomWithinHome({ roomId: 'rm_living', newFloorId: 'fl_b1' });
  } catch (err) {
    crossHomeMoveFailed = err.message.includes('belongs to home');
  }
  assert('Moving room to floor of another home is rejected', crossHomeMoveFailed);

  // 3. Device Identity, Registration & Compatibility Validation
  console.log('\n3. Device Registration & Hardware Compatibility:');
  const validDev = await deviceService.registerDevice({
    deviceId: 'dev_sw_001',
    serialNumber: 'SN-SW-001',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareVersion: '1.2.0'
  });
  assert('Valid device registered with compatibility check', validDev.id === 'dev_sw_001');

  // Rejection: Invalid Hardware Revision
  let hwRevFailed = false;
  try {
    await deviceService.registerDevice({
      deviceId: 'dev_invalid_hw',
      serialNumber: 'SN-SW-002',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_9_9_UNSUPPORTED',
      firmwareFamily: 'esp32c6-switch-platform'
    });
  } catch (err) {
    hwRevFailed = err.message.includes('Hardware revision');
  }
  assert('Registration rejected for unsupported hardware revision', hwRevFailed);

  // Rejection: Incompatible Firmware Family
  let fwFamFailed = false;
  try {
    await deviceService.registerDevice({
      deviceId: 'dev_invalid_fw',
      serialNumber: 'SN-SW-003',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-fan-platform' // Mismatch!
    });
  } catch (err) {
    fwFamFailed = err.message.includes('Firmware family');
  }
  assert('Registration rejected for incompatible firmware family', fwFamFailed);

  // 4. Device Authorization / Home Assignment & Move Lifecycle
  console.log('\n4. Device Home Assignment & Move Lifecycle:');
  const auth1 = await deviceService.assignDeviceToHome({
    deviceId: 'dev_sw_001',
    homeId: 'home_main',
    roomId: 'rm_living',
    customName: 'Living Room Switch',
    channelLabels: { '1': 'Main Chandelier', '2': 'Ceiling Fan', '3': 'Accent Lights' },
    actorUserId: 'usr_owner_1'
  });
  assert('Device assigned to Home and Room', auth1.home_id === 'home_main' && auth1.room_id === 'rm_living');

  // Cross-home room device assignment rejection
  const dev2 = await deviceService.registerDevice({
    deviceId: 'dev_sw_002',
    serialNumber: 'SN-SW-004',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform'
  });

  let devCrossRoomFailed = false;
  try {
    await deviceService.assignDeviceToHome({
      deviceId: 'dev_sw_002',
      homeId: 'home_main',
      roomId: 'fl_b1', // Room doesn't exist or wrong home!
      customName: 'Bad Device'
    });
  } catch (err) {
    devCrossRoomFailed = err.message.length > 0;
  }
  assert('Assigning device to non-existent or cross-home room is rejected', devCrossRoomFailed);

  // Move device to another room
  const roomKitchen = await roomService.createRoom({ id: 'rm_kitchen', homeId: 'home_main', floorId: 'fl_g', name: 'Kitchen' });
  await deviceService.moveDeviceToRoom({ deviceId: 'dev_sw_001', newRoomId: 'rm_kitchen' });
  const updatedAuth = await deviceRepo.getDeviceAuthorization('dev_sw_001');
  assert('Device moved to new room within home', updatedAuth.room_id === 'rm_kitchen');

  // Unassign device from home (preserves physical device identity!)
  await deviceService.removeDeviceFromHome({ deviceId: 'dev_sw_001' });
  const unassignedAuth = await deviceRepo.getDeviceAuthorization('dev_sw_001');
  const physicalDevStillExists = await deviceRepo.getDevice('dev_sw_001');
  assert('Device unassigned from home but physical device record preserved', unassignedAuth === null && physicalDevStillExists !== null);

  // Re-assign to Home
  await deviceService.assignDeviceToHome({ deviceId: 'dev_sw_001', homeId: 'home_main', roomId: 'rm_living', customName: 'Living Switch' });

  // 5. Channel Renaming & Capability Configuration Override Protection
  console.log('\n5. Channel Renaming & Capability Override Rules:');
  await deviceService.renameChannel({ deviceId: 'dev_sw_001', channelIndex: 1, newName: 'Grand Chandelier' });
  const authRenamed = await deviceRepo.getDeviceAuthorization('dev_sw_001');
  assert('Channel 1 renamed', authRenamed.channel_labels['1'] === 'Grand Chandelier');

  // Channel index out of bounds check
  let channelOutOfBoundsFailed = false;
  try {
    await deviceService.renameChannel({ deviceId: 'dev_sw_001', channelIndex: 4, newName: 'NonExistent' });
  } catch (err) {
    channelOutOfBoundsFailed = err.message.includes('out of bounds');
  }
  assert('Channel index out of bounds rejected', channelOutOfBoundsFailed);

  // Hardware Capability Override Protection
  let capOverrideFailed = false;
  try {
    await deviceService.updateChannelConfiguration({
      deviceId: 'dev_sw_001',
      channelIndex: 1,
      configuration: { requestedCapabilities: ['cct', 'fan_speed'] } // cct is NOT supported by 3x switch!
    });
  } catch (err) {
    capOverrideFailed = err.message.includes('unsupported hardware capabilities');
  }
  assert('Enabling unsupported hardware capability (cct on switch) is rejected', capOverrideFailed);

  // 6. Resolved Device Summary API Mapping (Canonical Payload)
  console.log('\n6. Resolved Device Summary API Mapping:');
  const summary = await deviceService.getResolvedDeviceSummary('dev_sw_001');
  assert('Resolved device summary returned', summary !== null);
  assert('Summary has deviceId and serialNumber', summary.deviceId === 'dev_sw_001' && summary.serialNumber === 'SN-SW-001');
  assert('Summary has resolved roomName and floorId', summary.roomName === 'Living Room' && summary.floorId === 'fl_g');
  assert('Summary channel 1 has custom name Grand Chandelier', summary.channels[0].displayName === 'Grand Chandelier');
  assert('Summary integrates capability UI hints', summary.capabilityUiHints['switch'] === 'EHSwitchCard');

  // 7. API Router Integration & Endpoints
  console.log('\n7. Phase 4 API Router Endpoints:');
  const resHomes = await apiRouter.handle('GET', '/api/v1/homes');
  assert('GET /api/v1/homes returns 200 with home list', resHomes.status === 200 && resHomes.body.data.length >= 1);

  const resMembers = await apiRouter.handle('GET', '/api/v1/homes/home_main/members');
  assert('GET /api/v1/homes/:id/members returns 200 with members', resMembers.status === 200 && resMembers.body.data.length === 2);

  const resDevices = await apiRouter.handle('GET', '/api/v1/homes/home_main/devices');
  assert('GET /api/v1/homes/:id/devices returns 200 with device summaries', resDevices.status === 200 && resDevices.body.data.length >= 1);

  const resDevDetail = await apiRouter.handle('GET', '/api/v1/devices/dev_sw_001');
  assert('GET /api/v1/devices/:id returns 200 with resolved device detail', resDevDetail.status === 200 && resDevDetail.body.data.deviceId === 'dev_sw_001');

  // 8. Auditability Check
  console.log('\n8. Audit Log Recording Check:');
  const logs = await db.find('audit_logs', () => true);
  assert('Audit logs recorded for Phase 4 domain actions', logs && logs.length >= 8);
  const actions = logs.map(l => l.action);
  assert('Audit contains HOME_CREATED, FLOOR_CREATED, ROOM_CREATED, DEVICE_REGISTERED, DEVICE_ASSIGNED',
    actions.includes('HOME_CREATED') &&
    actions.includes('FLOOR_CREATED') &&
    actions.includes('ROOM_CREATED') &&
    actions.includes('DEVICE_REGISTERED') &&
    actions.includes('DEVICE_ASSIGNED')
  );

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runPhase4Tests();
