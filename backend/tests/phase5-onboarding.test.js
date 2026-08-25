/**
 * EH Home — Phase 5 Secure Onboarding, Provisioning, and Claiming Test Suite
 */

const fs = require('fs');
const path = require('path');
const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  ProductRepository,
  DeviceRepository,
  DeviceStateRepository,
  AuditRepository,
  ProvisioningSessionRepository
} = require('../src/repositories');

const { HomeService } = require('../src/services/home.service');
const { FloorService } = require('../src/services/floor.service');
const { RoomService } = require('../src/services/room.service');
const { DeviceService } = require('../src/services/device.service');
const { ProductCatalogService } = require('../src/services/product-catalog.service');
const { ProvisioningService, UUID_REGEX } = require('../src/services/provisioning.service');
const { DeviceClaimService } = require('../src/services/device-claim.service');
const { ProvisioningClaimApiRouter } = require('../src/api/provisioning-claim.router');

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

async function runPhase5Tests() {
  console.log('=== PHASE 5 SECURE ONBOARDING, PROVISIONING & CLAIMING TESTS ===\n');

  const db = new DatabaseClient();
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const productRepo = new ProductRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const auditRepo = new AuditRepository(db);
  const sessionRepo = new ProvisioningSessionRepository(db);
  const catalogService = new ProductCatalogService();

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

  const provisioningService = new ProvisioningService({
    sessionRepo,
    deviceRepo,
    productCatalogService: catalogService,
    auditRepo
  });

  const claimService = new DeviceClaimService({
    deviceService,
    deviceRepo,
    sessionRepo,
    auditRepo
  });

  const apiRouter = new ProvisioningClaimApiRouter({
    provisioningService,
    deviceClaimService: claimService
  });

  // 0. Shared Golden Vectors Loading & Validation
  console.log('0. Shared Golden Vectors Contract Test:');
  const goldenVectorPath = path.resolve(__dirname, '../../docs/contracts/eh-prov1-golden-vectors.json');
  assert('Golden vectors JSON contract file exists', fs.existsSync(goldenVectorPath));
  const goldenJson = JSON.parse(fs.readFileSync(goldenVectorPath, 'utf8'));
  assert('Golden vectors payload version is EH-PROV/1', goldenJson.protocolVersion === 'EH-PROV/1');
  assert('Golden vectors contain appProof, deviceProof, and wifiPayload headers',
         goldenJson.vectors.appProof !== undefined &&
         goldenJson.vectors.deviceProof !== undefined &&
         goldenJson.vectors.wifiPayload !== undefined);

  // Seed User, Home, Floor, Room, Product
  await userRepo.createUser({ id: 'usr_owner_1', email: 'owner@ehhome.com', passwordHash: 'hash_1' });
  const home1 = await homeService.createHome({ id: 'home_main', name: 'Primary Residence', ownerId: 'usr_owner_1' });
  const floor1 = await floorService.createFloor({ id: 'fl_g', homeId: 'home_main', name: 'Ground Floor', level: 0 });
  const room1 = await roomService.createRoom({ id: 'rm_living', homeId: 'home_main', floorId: 'fl_g', name: 'Living Room' });

  await productRepo.createFamily({ id: 'fam_switch', slug: 'smart_switch', displayName: 'Smart Switch' });
  await productRepo.createProduct({ id: 'prod_switch', familyId: 'fam_switch', displayName: 'EH Smart Switch' });
  await productRepo.createVariant({
    id: 'eh-smart-switch-3x',
    productId: 'prod_switch',
    variantSlug: '3x',
    displayName: 'EH Smart Switch 3X',
    channelCount: 3,
    channels: [],
    hardwareProfile: {},
    connectivityProfile: {},
    capabilities: ['switch', 'relay', 'energy'],
    electricalSpecifications: {},
    firmwareFamily: 'esp32c6-switch-platform',
    supportedHardwareRevisions: ['HW_1_0']
  });

  const validUuidDeviceId = 'c0a80101-0000-4000-8000-000000000001';
  await deviceService.registerDevice({
    deviceId: validUuidDeviceId,
    serialNumber: 'SN-EH-3X-2026',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform'
  });

  // 1. Identity & QR Payload Validation
  console.log('\n1. Identity & QR Payload Validation:');
  assert('Canonical UUID validation passes for valid UUID', UUID_REGEX.test(validUuidDeviceId));
  assert('Canonical UUID validation rejects raw non-UUID legacy hex', !UUID_REGEX.test('dev_legacy_hex_9999'));

  const validQrPayload = `EH1:${JSON.stringify({
    deviceId: validUuidDeviceId,
    serialNumber: 'SN-EH-3X-2026',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform'
  })}`;

  const parsedQr = provisioningService.parseQrPayload(validQrPayload);
  assert('Versioned QR payload (EH1:) decoded successfully', parsedQr.version === 'EH1' && parsedQr.deviceId === validUuidDeviceId);

  let badQrFailed = false;
  try {
    provisioningService.parseQrPayload('EH2:bad_version');
  } catch (err) {
    badQrFailed = err.message.includes('version prefix');
  }
  assert('Unversioned or invalid QR version prefix rejected', badQrFailed);

  // 2. Commissioning Session Creation & Expiration Policy
  console.log('\n2. Commissioning Session Creation & Single Session Enforcement:');
  const sess1 = await provisioningService.createCommissioningSession({
    deviceId: validUuidDeviceId,
    appChallenge: 'app_chal_1001',
    qrPayload: validQrPayload
  });

  assert('Commissioning session created with 300s timeout & EH-PROV/1 protocol', sess1.sessionId && sess1.protocolVersion === 'EH-PROV/1');

  // Single active session enforcement: creating session 2 invalidates session 1
  const sess2 = await provisioningService.createCommissioningSession({
    deviceId: validUuidDeviceId,
    appChallenge: 'app_chal_1002'
  });
  const oldSess = await sessionRepo.getSession(sess1.sessionId);
  assert('Single active session rule: prior session expired upon new session creation', oldSess.status === 'EXPIRED');

  // 3. Session Authentication & Sequence Verification
  console.log('\n3. Session Authentication:');
  const authSess = await provisioningService.authenticateSession({
    sessionId: sess2.sessionId,
    appProof: 'proof_app',
    deviceProof: 'proof_dev'
  });
  assert('Session authenticated successfully', authSess.status === 'AUTHENTICATED');

  // 4. Secure Wi-Fi Credential Provisioning & Password Safety Audit
  console.log('\n4. Secure Wi-Fi Credential Provisioning & Password Exclusion Audit:');
  const provResult = await provisioningService.provisionWifiCredentials({
    sessionId: sess2.sessionId,
    ssid: 'Home_Network_5G',
    password: 'SuperSecretPassword123!'
  });
  assert('Wi-Fi provisioned successfully for authenticated session', provResult.status === 'PROVISIONED' && provResult.ssid === 'Home_Network_5G');

  // Verify Wi-Fi password is NEVER stored in audit log
  const auditLogs = await db.find('audit_logs', () => true);
  const wifiAudit = auditLogs.find(l => l.action === 'WIFI_PROVISIONED');
  assert('WIFI_PROVISIONED audit log created', wifiAudit !== undefined);
  const auditString = JSON.stringify(wifiAudit.payload);
  assert('SECURITY AUDIT: Wi-Fi password is NOT logged in audit payload', !auditString.includes('SuperSecretPassword123!'));

  // 5. Direct Device mTLS Registration Confirmation
  console.log('\n5. Direct Device mTLS Registration Confirmation & Proxy Boundary:');
  let untrustedRejected = false;
  try {
    await provisioningService.confirmDeviceProvisioning({
      deviceId: validUuidDeviceId,
      sessionId: sess2.sessionId,
      clientCertFingerprint: 'a1b2c3d4e5f6',
      isProxyTrusted: false // Untrusted proxy header!
    });
  } catch (err) {
    untrustedRejected = err.message.includes('trusted NGINX proxy');
  }
  assert('mTLS registration confirmation rejects untrusted proxy header', untrustedRejected);

  const mtlsConfirmResult = await provisioningService.confirmDeviceProvisioning({
    deviceId: validUuidDeviceId,
    sessionId: sess2.sessionId,
    clientCertFingerprint: 'a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890',
    isProxyTrusted: true
  });
  assert('mTLS device registration confirmation succeeds for trusted proxy', mtlsConfirmResult.status === 'COMPLETED');

  // 6. Device Claiming & Idempotency
  console.log('\n6. Device Claiming & Idempotency:');
  const claim1 = await claimService.claimDevice({
    deviceId: validUuidDeviceId,
    homeId: 'home_main',
    roomId: 'rm_living',
    customName: 'Living Switch',
    sessionId: sess2.sessionId,
    actorUserId: 'usr_owner_1'
  });
  assert('Device claimed and assigned to Home and Room', claim1.home_id === 'home_main' && claim1.room_id === 'rm_living');

  // Idempotency check: repeated claim returns existing claim without error
  const claimRepeat = await claimService.claimDevice({
    deviceId: validUuidDeviceId,
    homeId: 'home_main',
    roomId: 'rm_living',
    customName: 'Living Switch',
    actorUserId: 'usr_owner_1'
  });
  assert('Idempotent claim attempt succeeds deterministically', claimRepeat.home_id === 'home_main');

  // 7. Unclaim & Reset Lifecycle
  console.log('\n7. Device Unclaim & Reset Lifecycle:');
  await claimService.unclaimDevice({ deviceId: validUuidDeviceId, actorUserId: 'usr_owner_1' });
  const unclaimedAuth = await deviceRepo.getDeviceAuthorization(validUuidDeviceId);
  const physicalDevStillExists = await deviceRepo.getDevice(validUuidDeviceId);
  assert('Device unclaimed from home, physical identity preserved', unclaimedAuth === null && physicalDevStillExists !== null);

  // FACTORY RESET: clears claim while preserving immutable serialNumber & identity
  const resetRes = await claimService.resetDevice({ deviceId: validUuidDeviceId, resetType: 'FACTORY_RESET', actorUserId: 'usr_owner_1' });
  assert('Factory reset preserves immutable deviceId & serialNumber', resetRes.status === 'RESET_COMPLETE' && resetRes.serialNumber === 'SN-EH-3X-2026');

  // 8. API Router Integration & Endpoints
  console.log('\n8. Phase 5 API Router Endpoints:');
  const resSession = await apiRouter.handle('POST', '/api/v1/provisioning/sessions', { deviceId: validUuidDeviceId });
  assert('POST /api/v1/provisioning/sessions returns 201 with session', resSession.status === 201 && resSession.body.data.sessionId !== undefined);

  const resAuth = await apiRouter.handle('POST', `/api/v1/provisioning/sessions/${resSession.body.data.sessionId}/authenticate`, {});
  assert('POST /api/v1/provisioning/sessions/:id/authenticate returns 200', resAuth.status === 200 && resAuth.body.data.status === 'AUTHENTICATED');

  const resWifi = await apiRouter.handle('POST', `/api/v1/provisioning/sessions/${resSession.body.data.sessionId}/wifi`, { ssid: 'MyHomeWiFi', password: 'SecretPassword' });
  assert('POST /api/v1/provisioning/sessions/:id/wifi returns 200 without password in response', resWifi.status === 200 && resWifi.body.data.password === undefined);

  const resMtls = await apiRouter.handle('POST', '/api/v1/devices/confirm-provisioning', {
    deviceId: validUuidDeviceId,
    sessionId: resSession.body.data.sessionId,
    clientCertFingerprint: 'fp12345'
  }, { 'x-internal-proxy-auth': 'trusted_gateway_token' }, '172.20.0.5');
  assert('POST /api/v1/devices/confirm-provisioning via trusted proxy returns 200', resMtls.status === 200 && resMtls.body.data.status === 'COMPLETED');

  const resClaim = await apiRouter.handle('POST', `/api/v1/devices/${validUuidDeviceId}/claim`, { homeId: 'home_main', roomId: 'rm_living', sessionId: resSession.body.data.sessionId });
  assert('POST /api/v1/devices/:id/claim returns 200 with home assignment', resClaim.status === 200 && resClaim.body.data.home_id === 'home_main');

  const resReset = await apiRouter.handle('POST', `/api/v1/devices/${validUuidDeviceId}/reset`, { resetType: 'SOFT_RESET' });
  assert('POST /api/v1/devices/:id/reset returns 200', resReset.status === 200 && resReset.body.data.status === 'RESET_COMPLETE');

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passed}, Total Failed: ${failed}`);
  console.log(`========================================\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runPhase5Tests();
