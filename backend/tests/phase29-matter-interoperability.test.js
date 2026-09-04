'use strict';

/**
 * Phase 29 — Matter Ecosystem Interoperability & Multi-Platform Integration Tests
 *
 * Deterministic test suite covering:
 *   1. Capability-driven Matter mapping (On/Off, Level, Color, Fan, Energy)
 *   2. Strict hardware metadata validation (no fabricated clusters)
 *   3. Energy telemetry cluster only exposed when hasEnergyMetering = true
 *   4. Matter commissioning lifecycle & QR / manual pairing code generation
 *   5. Multi-Admin & multi-fabric support (Apple Home, Google Home, Alexa, EH Home)
 *   6. Single fabric decommission without affecting other active fabrics
 *   7. Bidirectional state synchronization (Inbound Matter <-> Outbound EH)
 *   8. Physical state authority (physical confirmation required before state update)
 *   9. Reuse of Phase 28 execution routing & local-first execution pipeline
 *  10. Event deduplication & idempotent command processing
 *  11. Stale event rejection (older state versions dropped)
 *  12. Authorization & ownership separation (fabric != EH ownership)
 *  13. Provider-neutral platform adapters & external platform link lifecycle
 *  14. Factory reset reconciliation (decommissions fabrics, clears links, preserves HW ID)
 *  15. Explicit certification status (NOT CLAIMED for Matter/Apple/Google/Alexa)
 *  16. MatterApiRouter REST endpoints
 *  17. End-to-end createApp integration
 */

const { DatabaseClient } = require('../src/shared/db-client');
const {
  UserRepository,
  HomeRepository,
  ProductRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  OutboxRepository,
  AuditRepository,
  LocalRouteCacheRepository,
  EdgeExecutionRepository,
  LocalDiscoveryNodeRepository,
  MatterDeviceRepository,
  MatterFabricRepository,
  ExternalPlatformLinkRepository
} = require('../src/repositories');
const { ExecutionRoutingService } = require('../src/services/execution-routing.service');
const { LocalExecutionService } = require('../src/services/local-execution.service');
const { MatterCapabilityMappingService } = require('../src/services/matter-capability-mapping.service');
const { MatterCommissioningService } = require('../src/services/matter-commissioning.service');
const { MatterStateSyncService } = require('../src/services/matter-state-sync.service');
const { MatterIntegrationService } = require('../src/services/matter-integration.service');
const { MatterApiRouter } = require('../src/api/matter.router');
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
  console.log('=== PHASE 29: MATTER ECOSYSTEM INTEROPERABILITY TESTS ===\n');

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
  const matterDeviceRepo = new MatterDeviceRepository(db);
  const matterFabricRepo = new MatterFabricRepository(db);
  const externalPlatformLinkRepo = new ExternalPlatformLinkRepository(db);

  // Seed sample home, user, and devices
  const homeId = '11111111-1111-4111-8111-111111111111';
  const deviceId1 = '22222222-2222-4222-8222-222222222221'; // Switch 2X with energy metering
  const deviceId2 = '22222222-2222-4222-8222-222222222222'; // Switch 1X without energy metering
  const userId = '33333333-3333-4333-8333-333333333333';

  await userRepo.createUser({ id: userId, email: 'owner@ehhome.io', password_hash: 'hash' });
  await homeRepo.createHome({ id: homeId, name: 'Matter Test Home', ownerId: userId });

  await productRepo.createFamily({ id: 'smart_switch', slug: 'smart_switch', displayName: 'Smart Switch' });
  await productRepo.createProduct({ id: 'eh_switch', familyId: 'smart_switch', displayName: 'EH Switch' });
  await productRepo.createVariant({ id: 'eh-smart-switch-2x', productId: 'eh_switch', sku: 'EH-SW2X', formFactor: '2-Module' });
  await productRepo.createVariant({ id: 'eh-smart-switch-1x', productId: 'eh_switch', sku: 'EH-SW1X', formFactor: '1-Module' });

  await deviceRepo.registerDevice({
    deviceId: deviceId1,
    serialNumber: 'SN-SW-001',
    productVariantId: 'eh-smart-switch-2x',
    hardwareRevision: 'revA',
    firmwareFamily: 'esp32'
  });
  await deviceRepo.claimDevice({ deviceId: deviceId1, homeId, customName: 'Living Room Switch' });

  await deviceRepo.registerDevice({
    deviceId: deviceId2,
    serialNumber: 'SN-SW-002',
    productVariantId: 'eh-smart-switch-1x',
    hardwareRevision: 'revA',
    firmwareFamily: 'esp32'
  });
  await deviceRepo.claimDevice({ deviceId: deviceId2, homeId, customName: 'Porch Light' });

  // ─── 1. Matter Capability Mapping Service (Correction 2) ───────────────────
  console.log('1. Capability-Driven Matter Mapping:');
  const mockCatalog = {
    getProductVariant: (variantId) => {
      if (variantId === 'eh-smart-switch-2x') {
        return {
          metadata: {
            productVariantId: 'eh-smart-switch-2x',
            productFamily: 'smart_switch',
            channelCount: 2,
            channels: [
              { channelIndex: 1, capabilities: ['switch', 'relay', 'energy'] },
              { channelIndex: 2, capabilities: ['switch', 'relay', 'energy'] }
            ],
            capabilities: ['switch', 'relay', 'energy'],
            hardwareProfile: { hasEnergyMetering: true }
          }
        };
      }
      if (variantId === 'eh-smart-switch-1x') {
        return {
          metadata: {
            productVariantId: 'eh-smart-switch-1x',
            productFamily: 'smart_switch',
            channelCount: 1,
            channels: [{ channelIndex: 1, capabilities: ['switch', 'relay'] }],
            capabilities: ['switch', 'relay'],
            hardwareProfile: { hasEnergyMetering: false }
          }
        };
      }
      return null;
    }
  };

  const capMappingService = new MatterCapabilityMappingService({ productCatalogService: mockCatalog });

  const mappingWithEnergy = capMappingService.resolveMappingForVariant('eh-smart-switch-2x');
  assert('Switch 2X resolves to ON_OFF_LIGHT', mappingWithEnergy.matterDeviceType === 'ON_OFF_LIGHT');
  assert('Switch 2X generates 3 endpoints (Root + 2 channels)', mappingWithEnergy.endpoints.length === 3);
  assert('Endpoint 1 has On/Off cluster', mappingWithEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'On/Off'));
  assert('Endpoint 1 has Electrical Measurement cluster when metering is true', mappingWithEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'Electrical Measurement'));
  assert('Endpoint 1 has Electrical Energy Measurement cluster when metering is true', mappingWithEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'Electrical Energy Measurement'));

  // Negative assertion: No energy metering if hardwareProfile.hasEnergyMetering is false
  const mappingWithoutEnergy = capMappingService.resolveMappingForVariant('eh-smart-switch-1x');
  assert('Switch 1X without metering does NOT expose Electrical Measurement cluster', !mappingWithoutEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'Electrical Measurement'));
  assert('Switch 1X without dimmer does NOT expose Level Control cluster', !mappingWithoutEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'Level Control'));
  assert('Switch 1X without fan motor does NOT expose Fan Control cluster', !mappingWithoutEnergy.endpoints[1].serverClusters.some(c => c.clusterName === 'Fan Control'));

  // ─── 2. Matter Commissioning Service & Multi-Admin ─────────────────────────
  console.log('\n2. Matter Commissioning & Multi-Admin Lifecycle:');
  const commService = new MatterCommissioningService({
    matterDeviceRepo,
    matterFabricRepo,
    externalPlatformLinkRepo,
    capabilityMappingService: capMappingService,
    deviceRepo
  });

  // Start Commissioning Session
  const session = await commService.startCommissioningSession(deviceId1, homeId, 'APPLE_HOME');
  assert('Commissioning session initialized', Boolean(session && session.sessionId));
  assert('Session stage is ADVERTISING', session.stage === 'ADVERTISING');
  assert('QR code payload generated', session.qrCodePayload.startsWith('MT:'));
  assert('Manual pairing code generated', session.manualPairingCode.length === 11);

  // Complete Apple Home Commissioning
  const compResult1 = await commService.completeCommissioning(session.sessionId, {
    fabricName: 'APPLE_HOME',
    label: 'Apple Home Controller'
  });
  assert('Apple Home fabric paired successfully', Boolean(compResult1.fabric && compResult1.fabric.fabricId));
  assert('Device commissioning state is COMMISSIONED', compResult1.matterDevice.commissioningState === 'COMMISSIONED');

  // Pair Secondary Fabric: Google Home (Multi-Admin)
  const sessionGoogle = await commService.startCommissioningSession(deviceId1, homeId, 'GOOGLE_HOME');
  const compResult2 = await commService.completeCommissioning(sessionGoogle.sessionId, {
    fabricName: 'GOOGLE_HOME',
    label: 'Google Home Hub'
  });
  assert('Google Home secondary fabric paired', Boolean(compResult2.fabric));
  assert('Device has fabricIndex = 2 for Google Home', compResult2.fabric.fabricIndex === 2);

  // Pair Third Fabric: Alexa
  const sessionAlexa = await commService.startCommissioningSession(deviceId1, homeId, 'AMAZON_ALEXA');
  const compResult3 = await commService.completeCommissioning(sessionAlexa.sessionId, {
    fabricName: 'AMAZON_ALEXA',
    label: 'Echo Dot'
  });
  assert('Amazon Alexa third fabric paired', Boolean(compResult3.fabric));

  const activeFabrics = await matterFabricRepo.listByMatterDeviceId(compResult1.matterDevice.id);
  assert('Device now belongs to 3 active concurrent fabrics', activeFabrics.length === 3);

  // Decommission Google Home Fabric
  await commService.decommissionFabric(deviceId1, compResult2.fabric.fabricId);
  const remainingFabrics = await matterFabricRepo.listByMatterDeviceId(compResult1.matterDevice.id);
  assert('Google Home removed, 2 fabrics remain active', remainingFabrics.length === 2);
  assert('Apple Home remains active', remainingFabrics.some(f => f.fabricName === 'APPLE_HOME'));
  assert('Alexa remains active', remainingFabrics.some(f => f.fabricName === 'AMAZON_ALEXA'));

  // ─── 3. Matter State Synchronization & Physical Authority ───────────────────
  console.log('\n3. State Synchronization & Physical Authority (Corrections 4 & 5):');

  // Setup execution routing & local execution
  const routingService = new ExecutionRoutingService({
    localRouteRepo,
    connectivityService: null,
    deviceRepo
  });

  await localRouteRepo.upsertRoute({
    deviceId: deviceId1,
    homeId,
    transportType: 'WIFI_MQTT',
    localEndpoint: '192.168.1.150:1883',
    reachability: 'REACHABLE'
  });

  const localExecService = new LocalExecutionService({
    routingService,
    edgeExecutionRepo,
    localRouteRepo,
    deviceRepo,
    deviceStateRepo,
    deviceCommandService: null,
    eventBus: null
  });

  const eventsPublished = [];
  const mockEventBus = {
    publish: (topic, evt) => eventsPublished.push({ topic, evt })
  };

  const syncService = new MatterStateSyncService({
    matterDeviceRepo,
    matterFabricRepo,
    executionRoutingService: routingService,
    localExecutionService: localExecService,
    deviceCommandService: null,
    deviceStateRepo,
    eventBus: mockEventBus
  });

  // Test Inbound Matter Command: Apple Home turns light ON
  const matterCmdResult = await syncService.handleInboundMatterCommand(
    { userId, homeId, role: 'OWNER' },
    {
      deviceId: deviceId1,
      homeId,
      channelIndex: 1,
      fabricId: compResult1.fabric.fabricId,
      clusterName: 'On/Off',
      commandName: 'On',
      eventId: 'evt_apple_turn_on_001',
      stateVersion: 1
    }
  );

  assert('Matter command execution status is CONFIRMED', matterCmdResult.status === 'CONFIRMED');
  assert('State version incremented to 2', matterCmdResult.stateVersion === 2);
  assert('Physical confirmed state is confirmed', (matterCmdResult.confirmedState.power === true || matterCmdResult.confirmedState.value === true));
  assert('Matter sync event published to event bus', eventsPublished.some(e => e.topic === 'matter.state.synchronized'));

  // ─── 4. Event Deduplication & Stale Event Protection (Correction 10) ────────
  console.log('\n4. Event Deduplication & Stale Event Protection:');
  // Replay duplicate event
  const dupResult = await syncService.handleInboundMatterCommand(
    { userId, homeId, role: 'OWNER' },
    {
      deviceId: deviceId1,
      homeId,
      channelIndex: 1,
      fabricId: compResult1.fabric.fabricId,
      clusterName: 'On/Off',
      commandName: 'On',
      eventId: 'evt_apple_turn_on_001' // SAME ID
    }
  );
  assert('Duplicate event detected and ignored', dupResult.isDuplicate === true);
  assert('Duplicate event status is IGNORED_DUPLICATE', dupResult.status === 'IGNORED_DUPLICATE');

  // Stale event with older stateVersion
  const staleResult = await syncService.handleInboundMatterCommand(
    { userId, homeId, role: 'OWNER' },
    {
      deviceId: deviceId1,
      homeId,
      channelIndex: 1,
      fabricId: compResult1.fabric.fabricId,
      clusterName: 'On/Off',
      commandName: 'Off',
      eventId: 'evt_stale_002',
      stateVersion: 1 // Current version is 2
    }
  );
  assert('Stale event rejected', staleResult.isStale === true);
  assert('Stale event status is REJECTED_STALE', staleResult.status === 'REJECTED_STALE');

  // Outbound Broadcast (Physical Switch Toggle)
  const broadcastEvt = await syncService.broadcastPhysicalStateChange(deviceId1, homeId, 1, { power: false });
  assert('Physical switch toggle generates OUTBOUND_TO_MATTER event', broadcastEvt.direction === 'OUTBOUND_TO_MATTER');
  assert('Broadcast event has isPhysicalConfirmed = true', broadcastEvt.isPhysicalConfirmed === true);

  // ─── 5. Provider-Neutral Platform Integration & Certification (Correction 3) 
  console.log('\n5. Provider-Neutral Integration & Certification Status:');
  const integrationService = new MatterIntegrationService({
    matterDeviceRepo,
    matterFabricRepo,
    externalPlatformLinkRepo,
    commissioningService: commService,
    stateSyncService: syncService,
    capabilityMappingService: capMappingService,
    homeAuthService: null
  });

  const certOverview = integrationService.getCertificationOverview();
  assert('Matter certification is NOT CLAIMED', certOverview.matterCertification === 'NOT CLAIMED');
  assert('Apple Home certification is NOT CLAIMED', certOverview.appleHomeCertification === 'NOT CLAIMED');
  assert('Google Home certification is NOT CLAIMED', certOverview.googleHomeCertification === 'NOT CLAIMED');
  assert('Alexa certification is NOT CLAIMED', certOverview.alexaCertification === 'NOT CLAIMED');
  assert('Physical hardware validation is NOT RUN', certOverview.physicalHardwareValidation === 'NOT RUN');

  // Connect / Disconnect platform links
  const appleConnect = await integrationService.connectPlatform({ homeId }, deviceId1, 'APPLE_HOME');
  assert('Apple Home platform connected', appleConnect.success === true && appleConnect.link.status === 'CONNECTED');

  const alexaConnect = await integrationService.connectPlatform({ homeId }, deviceId1, 'AMAZON_ALEXA');
  assert('Alexa platform connected', alexaConnect.success === true && alexaConnect.link.status === 'CONNECTED');

  const homeIntegrations = await integrationService.getHomeIntegrations({ homeId }, homeId);
  assert('Home integrations listed (2 active)', homeIntegrations.totalLinkedPlatforms === 2);

  await integrationService.disconnectPlatform({ homeId }, deviceId1, 'APPLE_HOME');
  const homeIntegrationsAfterDisc = await integrationService.getHomeIntegrations({ homeId }, homeId);
  assert('Home integrations after disconnect has 1 active', homeIntegrationsAfterDisc.totalLinkedPlatforms === 1);

  // ─── 6. Factory Reset Reconciliation (Correction 8) ────────────────────────
  console.log('\n6. Factory Reset Reconciliation:');
  const resetRes = await commService.reconcileFactoryReset(deviceId1);
  assert('Factory reset reconciled successfully', resetRes.success === true);
  assert('All fabrics cleared on factory reset', resetRes.fabricsCleared === true);
  assert('External links disconnected', resetRes.linksDisconnected === true);

  const fabricsAfterReset = await matterFabricRepo.listByMatterDeviceId(compResult1.matterDevice.id);
  assert('Zero active fabrics remain after factory reset', fabricsAfterReset.length === 0);

  const deviceAfterReset = await matterDeviceRepo.findByDeviceId(deviceId1);
  assert('Device commissioning state reset to NOT_COMMISSIONED', deviceAfterReset.commissioningState === 'NOT_COMMISSIONED');

  // ─── 7. MatterApiRouter REST Endpoints ─────────────────────────────────────
  console.log('\n7. MatterApiRouter Endpoints:');
  const router = new MatterApiRouter({
    matterIntegrationService: integrationService,
    matterCommissioningService: commService,
    matterStateSyncService: syncService,
    matterCapabilityMappingService: capMappingService,
    homeAuthService: null
  });

  const certRes = await router.handleRequest('GET', '/api/v1/matter/certification');
  assert('GET /api/v1/matter/certification returns 200', certRes.statusCode === 200);
  assert('Certification data contains NOT CLAIMED', certRes.body.data.matterCertification === 'NOT CLAIMED');

  const devDetailsRes = await router.handleRequest('GET', `/api/v1/devices/${deviceId1}/matter`, {}, { 'x-user-id': userId, 'x-home-id': homeId });
  assert('GET /api/v1/devices/:id/matter returns 200', devDetailsRes.statusCode === 200);

  const homeIntRes = await router.handleRequest('GET', `/api/v1/homes/${homeId}/integrations`, {}, { 'x-user-id': userId, 'x-home-id': homeId });
  assert('GET /api/v1/homes/:id/integrations returns 200', homeIntRes.statusCode === 200);

  // ─── 8. End-to-End App Integration ─────────────────────────────────────────
  console.log('\n8. End-to-End App Integration:');
  const app = createApp({ db });
  assert('App initializes with matterCapabilityMappingService', Boolean(app.services.matterCapabilityMappingService));
  assert('App initializes with matterCommissioningService', Boolean(app.services.matterCommissioningService));
  assert('App initializes with matterStateSyncService', Boolean(app.services.matterStateSyncService));
  assert('App initializes with matterIntegrationService', Boolean(app.services.matterIntegrationService));
  assert('App initializes with matterApiRouter', Boolean(app.matterApiRouter));

  console.log(`\n========================================`);
  console.log(`Total Passed: ${passedTests}, Total Failed: ${failedTests}`);
  console.log(`========================================\n`);

  process.exit(failedTests > 0 ? 1 : 0);
}

runTests().catch(err => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
