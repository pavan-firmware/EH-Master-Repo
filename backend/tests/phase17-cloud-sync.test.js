'use strict';

/**
 * EH Home — Phase 17 Cloud Sync, Backup, Restore, Offline Reconciliation & Data Lifecycle Tests
 */

const assert = require('assert');
const http = require('http');
const { createApp } = require('../src/app');
const { DatabaseClient } = require('../src/shared/db-client');

let server;
let baseUrl;
let app;

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(url, { method, headers }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(data);
        } catch {
          parsed = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: parsed });
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log('=== RUNNING PHASE 17 CLOUD SYNC & DATA LIFECYCLE TESTS ===\n');

  const db = new DatabaseClient();
  app = createApp({ db });
  server = http.createServer((req, res) => app.handleRequest(req, res));

  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  baseUrl = `http://127.0.0.1:${port}`;

  try {
    // -------------------------------------------------------------
    // Setup Base Product Catalog
    // -------------------------------------------------------------
    await db.insert('product_families', 'fam-switches', {
      id: 'fam-switches',
      name: 'EH Smart Switches',
      slug: 'switches'
    });
    await db.insert('products', 'prod-sw3x', {
      id: 'prod-sw3x',
      family_id: 'fam-switches',
      name: 'Smart Switch 3X',
      slug: 'smart-switch-3x'
    });
    await db.insert('product_variants', 'eh-smart-switch-3x', {
      id: 'eh-smart-switch-3x',
      product_id: 'prod-sw3x',
      name: '3X',
      sku_code: 'EH-SW3X',
      channel_count: 3,
      hardware_capabilities: ['power', 'relay', 'energy', 'voltage', 'current'],
      supported_firmware_families: ['esp32c6-switch-platform', 'esp32-switch-platform']
    });

    // -------------------------------------------------------------
    // TEST 1: Bootstrap Sync & Cloud Restore
    // -------------------------------------------------------------
    console.log('--- 1. Bootstrap Sync & Cloud Restore ---');

    // Register & Login User Alice
    const regAlice = await request('POST', '/api/v1/auth/register', {
      email: 'alice.sync@example.com',
      password: 'StrongPassword123!',
      fullName: 'Alice Sync'
    });
    assert.strictEqual(regAlice.status, 201, 'Alice registers');
    const userAId = regAlice.body.data.id;

    const loginAlice = await request('POST', '/api/v1/auth/login', {
      email: 'alice.sync@example.com',
      password: 'StrongPassword123!'
    });
    assert.strictEqual(loginAlice.status, 200, 'Alice logs in');
    const tokenA = loginAlice.body.data.accessToken;

    // Create Home A ("Skyline Villa")
    const homeRes = await request('POST', '/api/v1/homes', {
      name: 'Skyline Villa',
      timezone: 'America/New_York',
      address: '100 Skyline Blvd'
    }, tokenA);
    assert.strictEqual(homeRes.status, 201, 'Home created');
    const homeAId = homeRes.body.data.id;

    // Create Rooms
    const room1 = await request('POST', `/api/v1/homes/${homeAId}/rooms`, {
      name: 'Living Room',
      displayOrder: 1
    }, tokenA);
    if (!room1.body || !room1.body.data) console.log('room1 error:', room1);
    assert.strictEqual(room1.status, 201);
    const room1Id = room1.body.data.id;

    const room2 = await request('POST', `/api/v1/homes/${homeAId}/rooms`, {
      name: 'Master Bed',
      displayOrder: 2
    }, tokenA);
    assert.strictEqual(room2.status, 201);
    const room2Id = room2.body.data.id;

    // Register & Claim Device
    const devId = '0194fe23-7a1b-7890-a123-456789abc101';
    await app.services.deviceService.registerDevice({
      deviceId: devId,
      serialNumber: 'SN-SYNC-01',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform'
    });
    await app.services.deviceService.assignDeviceToHome({
      deviceId: devId,
      homeId: homeAId,
      roomId: room1Id,
      customName: 'Ceiling Fan'
    });

    // Create Scene & Automation
    const sceneRes = await request('POST', `/api/v1/homes/${homeAId}/scenes`, {
      name: 'Night Mode',
      actions: [{ deviceId: devId, channelIndex: 1, action: 'setPower', params: { power: false } }]
    }, tokenA);
    assert.strictEqual(sceneRes.status, 201);
    const sceneId = sceneRes.body.data.id;

    const autoRes = await request('POST', `/api/v1/homes/${homeAId}/automations`, {
      name: 'Morning Routine',
      triggerType: 'SCHEDULE',
      triggerConfig: { time: '07:00' },
      conditions: [],
      actions: [{ deviceId: devId, channelIndex: 1, action: 'setPower', params: { power: true } }]
    }, tokenA);
    assert.strictEqual(autoRes.status, 201);

    // Simulate App Data Clear / Fresh Device Restore
    const bootstrap = await request('GET', `/api/v1/sync/bootstrap?homeId=${homeAId}&clientDeviceId=pixel_phone`, null, tokenA);
    assert.strictEqual(bootstrap.status, 200, 'Bootstrap sync succeeds');
    const bundle = bootstrap.body.data;

    assert.strictEqual(bundle.schemaVersion, 1);
    assert.strictEqual(bundle.user.email, 'alice.sync@example.com');
    assert.strictEqual(bundle.homes.length, 1);
    assert.strictEqual(bundle.homes[0].id, homeAId);
    assert.strictEqual(bundle.homes[0].name, 'Skyline Villa');
    assert.strictEqual(bundle.rooms.length, 2);
    assert.strictEqual(bundle.devices.length, 1);
    assert.strictEqual(bundle.devices[0].id, devId, 'Preserves original physical device UUID');
    assert.strictEqual(bundle.devices[0].customName, 'Ceiling Fan');
    assert.strictEqual(bundle.devices[0].roomId, room1Id);
    assert.strictEqual(bundle.scenes.length, 1);
    assert.strictEqual(bundle.automations.length, 1);

    console.log('[PASS] 1. Bootstrap Sync & Cloud Restore');

    // -------------------------------------------------------------
    // TEST 2: Offline Pending Metadata Mutations & Reconciliation
    // -------------------------------------------------------------
    console.log('--- 2. Offline Pending Mutations & Reconciliation ---');

    const mutations = [
      {
        mutationId: 'mut_01_create_room',
        entityType: 'room',
        mutationType: 'create',
        payload: { name: 'Guest Lounge', displayOrder: 3 },
        clientTimestamp: new Date().toISOString()
      },
      {
        mutationId: 'mut_02_rename_device',
        entityType: 'device',
        entityId: devId,
        mutationType: 'update',
        payload: { customName: 'Chandelier' },
        clientTimestamp: new Date().toISOString()
      },
      {
        mutationId: 'mut_03_move_device',
        entityType: 'device',
        entityId: devId,
        mutationType: 'update',
        payload: { roomId: room2Id },
        clientTimestamp: new Date().toISOString()
      },
      {
        mutationId: 'mut_04_rename_home',
        entityType: 'home',
        mutationType: 'update',
        payload: { name: 'Skyline Penthouse' },
        clientTimestamp: new Date().toISOString()
      },
      {
        mutationId: 'mut_05_update_profile',
        entityType: 'profile',
        mutationType: 'update',
        payload: { timezone: 'America/Chicago' },
        clientTimestamp: new Date().toISOString()
      }
    ];

    const reconcileRes = await request('POST', '/api/v1/sync/reconcile', {
      homeId: homeAId,
      mutations
    }, tokenA);

    assert.strictEqual(reconcileRes.status, 200, 'Reconciliation succeeds');
    const recResult = reconcileRes.body.data;
    assert.strictEqual(recResult.totalMutations, 5);
    assert.strictEqual(recResult.acceptedCount, 5);
    assert.strictEqual(recResult.rejectedCount, 0);
    assert.strictEqual(recResult.conflictCount, 0);

    // Verify DB state updated
    const updatedHome = await db.findById('homes', homeAId);
    assert.strictEqual(updatedHome.name, 'Skyline Penthouse');

    const updatedDevAuth = await app.repositories.deviceRepo.getDeviceAuthorization(devId);
    assert.strictEqual(updatedDevAuth.custom_name, 'Chandelier');
    assert.strictEqual(updatedDevAuth.room_id, room2Id);

    const updatedProfile = await db.findById('user_profiles', userAId);
    assert.strictEqual(updatedProfile.timezone, 'America/Chicago');

    console.log('[PASS] 2. Offline Pending Mutations & Reconciliation');

    // -------------------------------------------------------------
    // TEST 3: Role-based Guarding & Conflict Resolution
    // -------------------------------------------------------------
    console.log('--- 3. Role-based Guarding & Conflict Resolution ---');

    // Register & Login User Bob & Invite as VIEWER
    const regBob = await request('POST', '/api/v1/auth/register', {
      email: 'bob.viewer@example.com',
      password: 'StrongPassword123!'
    });
    const userBId = regBob.body.data.id;

    const loginBob = await request('POST', '/api/v1/auth/login', {
      email: 'bob.viewer@example.com',
      password: 'StrongPassword123!'
    });
    assert.strictEqual(loginBob.status, 200, 'Bob logs in');
    const tokenB = loginBob.body.data.accessToken;

    const inviteRes = await request('POST', `/api/v1/homes/${homeAId}/invitations`, {
      email: 'bob.viewer@example.com',
      role: 'VIEWER'
    }, tokenA);
    const inviteCode = inviteRes.body.data.invite_code || inviteRes.body.data.inviteCode;
    const acceptRes = await request('POST', `/api/v1/invitations/${inviteCode}/accept`, {}, tokenB);
    assert.strictEqual(acceptRes.status, 200, 'Bob accepts invitation');

    // Bob tries to mutate home name (Forbidden for VIEWER)
    const bobMutations = [
      {
        mutationId: 'mut_bob_01',
        entityType: 'home',
        mutationType: 'update',
        payload: { name: 'Bob Hacked Home' },
        clientTimestamp: new Date().toISOString()
      },
      {
        mutationId: 'mut_bob_02_invalid_room',
        entityType: 'device',
        entityId: devId,
        mutationType: 'update',
        payload: { roomId: 'non_existent_room_uuid' },
        clientTimestamp: new Date().toISOString()
      }
    ];

    const bobReconcile = await request('POST', '/api/v1/sync/reconcile', {
      homeId: homeAId,
      mutations: bobMutations
    }, tokenB);

    assert.strictEqual(bobReconcile.status, 200);
    assert.strictEqual(bobReconcile.body.data.rejectedCount, 2, 'Viewer mutations rejected by RBAC');

    console.log('[PASS] 3. Role-based Guarding & Conflict Resolution');

    // -------------------------------------------------------------
    // TEST 4: Multi-Home Isolation
    // -------------------------------------------------------------
    console.log('--- 4. Multi-Home Isolation ---');

    const homeBRes = await request('POST', '/api/v1/homes', {
      name: 'Beach Villa',
      timezone: 'America/Los_Angeles'
    }, tokenA);
    const homeBId = homeBRes.body.data.id;

    // Bootstrap for Home B
    const bootstrapB = await request('GET', `/api/v1/sync/bootstrap?homeId=${homeBId}`, null, tokenA);
    assert.strictEqual(bootstrapB.status, 200);
    assert.strictEqual(bootstrapB.body.data.devices.length, 0, 'Home B has 0 devices from Home A');
    assert.strictEqual(bootstrapB.body.data.rooms.length, 0, 'Home B has 0 rooms from Home A');

    console.log('[PASS] 4. Multi-Home Isolation');

    // -------------------------------------------------------------
    // TEST 5: Secret-Free Data Export
    // -------------------------------------------------------------
    console.log('--- 5. Secret-Free Data Export ---');

    const exportUser = await request('GET', '/api/v1/sync/export', null, tokenA);
    assert.strictEqual(exportUser.status, 200);
    const exportData = exportUser.body.data;

    assert.strictEqual(exportData.scope, 'USER');
    assert.strictEqual(exportData.user.email, 'alice.sync@example.com');
    assert.strictEqual(exportData.homes.length, 2);

    // Verify zero secret leakage in entire export payload
    const exportStr = JSON.stringify(exportData);
    assert.strictEqual(exportStr.includes('password_hash'), false, 'Zero password_hash in export');
    assert.strictEqual(exportStr.includes('token_hash'), false, 'Zero token_hash in export');
    assert.strictEqual(exportStr.includes('private_key'), false, 'Zero private_key in export');
    assert.strictEqual(exportStr.includes('credentials'), false, 'Zero credentials in export');

    console.log('[PASS] 5. Secret-Free Data Export');

    // -------------------------------------------------------------
    // TEST 6: Data Retention & Policy Pruning
    // -------------------------------------------------------------
    console.log('--- 6. Data Retention & Policy Pruning ---');

    // Seed old notification (>35 days old)
    const oldDate = new Date(Date.now() - 35 * 24 * 60 * 60 * 1000).toISOString();
    await db.insert('notifications', 'notif_old_01', {
      user_id: userAId,
      home_id: homeAId,
      category: 'SYSTEM',
      title: 'Old alert',
      body: 'Old event',
      read: true,
      created_at: oldDate
    });

    // Seed recent notification (<2 days old)
    await db.insert('notifications', 'notif_recent_01', {
      user_id: userAId,
      home_id: homeAId,
      category: 'SECURITY',
      title: 'Recent alert',
      body: 'Recent event',
      read: false,
      created_at: new Date().toISOString()
    });

    const retentionResult = await app.services.dataRetentionService.runRetentionCycle({
      notificationDays: 30
    });

    assert.strictEqual(retentionResult.notificationsPruned >= 1, true, 'Pruned old notification');
    const remainingNotifs = await db.find('notifications', n => n.user_id === userAId);
    assert.strictEqual(remainingNotifs.some(n => n.id === 'notif_old_01'), false, 'Old notification deleted');
    assert.strictEqual(remainingNotifs.some(n => n.id === 'notif_recent_01'), true, 'Recent notification preserved');

    console.log('[PASS] 6. Data Retention & Policy Pruning');

    // -------------------------------------------------------------
    // TEST 7: Home Deletion Lifecycle Cascade
    // -------------------------------------------------------------
    console.log('--- 7. Home Deletion Lifecycle Cascade ---');

    const deleteHomeB = await request('DELETE', `/api/v1/homes/${homeBId}`, null, tokenA);
    assert.strictEqual(deleteHomeB.status, 200, 'Home B deleted');

    const checkHomeB = await db.findById('homes', homeBId);
    assert.strictEqual(checkHomeB, null, 'Home B record removed');

    console.log('[PASS] 7. Home Deletion Lifecycle Cascade');

    console.log('===============================================================');
    console.log('  PHASE 17 TEST SUMMARY: 7 PASSED, 0 FAILED');
    console.log('===============================================================');
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

runTests().catch(err => {
  console.error('[FAIL] Phase 17 Test Suite Error:', err);
  if (server) server.close();
  process.exit(1);
});
