'use strict';

/**
 * EH Home — Phase 16 Backend Integration Tests
 * Account, Home, Membership, Ownership, Invitations, RBAC & Permissions
 */

const assert = require('assert');
const http = require('http');
const { createApp } = require('../src/app');

async function runTests() {
  console.log('=== RUNNING PHASE 16 ACCOUNT, HOME & ACCESS CONTROL TESTS ===\n');

  const app = createApp();
  const server = http.createServer(app.handleRequest);
  await new Promise(resolve => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;

  async function request(method, path, body = null, token = null) {
    return new Promise((resolve, reject) => {
      const parsedUrl = new URL(path, baseUrl);
      const headers = { 'Content-Type': 'application/json' };
      if (token) headers['Authorization'] = `Bearer ${token}`;

      const req = http.request(parsedUrl, { method, headers }, res => {
        let raw = '';
        res.on('data', chunk => (raw += chunk));
        res.on('end', () => {
          try {
            const data = JSON.parse(raw);
            resolve({ status: res.statusCode, body: data });
          } catch (e) {
            resolve({ status: res.statusCode, body: raw });
          }
        });
      });
      req.on('error', reject);
      if (body) req.write(JSON.stringify(body));
      req.end();
    });
  }

  try {
    // -------------------------------------------------------------
    // TEST 1: User Registration, Login & Session Management
    // -------------------------------------------------------------
    console.log('--- 1. Account Lifecycle, Profiles & Session Management ---');
    const userAEmail = `alice_${Date.now()}@example.com`;
    const userBEmail = `bob_${Date.now()}@example.com`;
    const userCEmail = `charlie_${Date.now()}@example.com`;

    const regA = await request('POST', '/api/v1/auth/register', { email: userAEmail, password: 'Password123!' });
    assert.strictEqual(regA.status, 201, 'User A should register successfully');
    const userAId = regA.body.data.id;

    const loginA = await request('POST', '/api/v1/auth/login', { email: userAEmail, password: 'Password123!' });
    assert.strictEqual(loginA.status, 200, 'User A should log in');
    const tokenA = loginA.body.data.accessToken;
    const refreshA = loginA.body.data.refreshToken;

    // Get Account Profile
    const meA = await request('GET', '/api/v1/account/me', null, tokenA);
    assert.strictEqual(meA.status, 200, 'User A can get profile');
    assert.strictEqual(meA.body.data.email, userAEmail);
    assert.strictEqual(meA.body.data.activeSessionsCount, 1);

    // Update Profile
    const updateProfileA = await request('PATCH', '/api/v1/account/profile', {
      fullName: 'Alice Developer',
      phoneNumber: '+1-555-0100',
      timezone: 'America/New_York'
    }, tokenA);
    assert.strictEqual(updateProfileA.status, 200, 'User A can update profile');
    assert.strictEqual(updateProfileA.body.data.fullName, 'Alice Developer');
    assert.strictEqual(updateProfileA.body.data.timezone, 'America/New_York');

    // List Sessions
    const sessionsA = await request('GET', '/api/v1/account/sessions', null, tokenA);
    assert.strictEqual(sessionsA.status, 200, 'Can list active sessions');
    assert.strictEqual(sessionsA.body.data.length, 1);

    // Change Password
    const changePw = await request('POST', '/api/v1/account/change-password', {
      oldPassword: 'Password123!',
      newPassword: 'NewPassword456!'
    }, tokenA);
    assert.strictEqual(changePw.status, 200, 'Password change succeeds');

    // Verify login with new password
    const loginANew = await request('POST', '/api/v1/auth/login', { email: userAEmail, password: 'NewPassword456!' });
    assert.strictEqual(loginANew.status, 200, 'Can login with new password');
    const tokenANew = loginANew.body.data.accessToken;

    console.log('[PASS] 1. Account Lifecycle, Profiles & Session Management');

    // -------------------------------------------------------------
    // TEST 2: Register User B and User C
    // -------------------------------------------------------------
    const regB = await request('POST', '/api/v1/auth/register', { email: userBEmail, password: 'Password123!' });
    const userBId = regB.body.data.id;
    const loginB = await request('POST', '/api/v1/auth/login', { email: userBEmail, password: 'Password123!' });
    const tokenB = loginB.body.data.accessToken;

    const regC = await request('POST', '/api/v1/auth/register', { email: userCEmail, password: 'Password123!' });
    const userCId = regC.body.data.id;
    const loginC = await request('POST', '/api/v1/auth/login', { email: userCEmail, password: 'Password123!' });
    const tokenC = loginC.body.data.accessToken;

    // -------------------------------------------------------------
    // TEST 3: Home Creation, Scoping & Metadata Management
    // -------------------------------------------------------------
    console.log('--- 2. Home Creation & Scoping ---');
    const homeCreate = await request('POST', '/api/v1/homes', {
      id: '0194fe23-7a1b-7890-a123-456789abc111',
      name: 'Alice Smart Villa',
      timezone: 'America/New_York',
      address: '123 Smart Ave'
    }, tokenANew);
    assert.strictEqual(homeCreate.status, 201, 'Home should be created');
    const homeId = homeCreate.body.data.id;

    // List Homes for User A
    const homesA = await request('GET', '/api/v1/homes', null, tokenANew);
    assert.strictEqual(homesA.status, 200);
    assert.strictEqual(homesA.body.data.length, 1);
    assert.strictEqual(homesA.body.data[0].role, 'OWNER');
    assert.strictEqual(homesA.body.data[0].permissions.canManageHome, true);
    assert.strictEqual(homesA.body.data[0].permissions.canDeleteHome, true);

    // User B has 0 homes
    const homesB = await request('GET', '/api/v1/homes', null, tokenB);
    assert.strictEqual(homesB.body.data.length, 0);

    // Get Home Details for User A
    const homeDetail = await request('GET', `/api/v1/homes/${homeId}`, null, tokenANew);
    assert.strictEqual(homeDetail.status, 200);
    assert.strictEqual(homeDetail.body.data.name, 'Alice Smart Villa');
    assert.strictEqual(homeDetail.body.data.memberCount, 1);

    // Update Home
    const updateHome = await request('PATCH', `/api/v1/homes/${homeId}`, { name: 'Alice Luxury Mansion' }, tokenANew);
    assert.strictEqual(updateHome.status, 200);

    console.log('[PASS] 2. Home Creation & Scoping');

    // -------------------------------------------------------------
    // TEST 4: Secure Invitations & Acceptance Flow
    // -------------------------------------------------------------
    console.log('--- 3. Invitations & Acceptance Flow ---');
    // Alice invites Bob as ADMIN
    const inviteBob = await request('POST', `/api/v1/homes/${homeId}/invitations`, {
      email: userBEmail,
      role: 'ADMIN'
    }, tokenANew);
    assert.strictEqual(inviteBob.status, 201, 'Invite created');
    const inviteCodeBob = inviteBob.body.data.invite_code;
    assert(inviteCodeBob.startsWith('inv_'), 'Invite code format is valid');

    // Duplicate invite prevention
    const dupInvite = await request('POST', `/api/v1/homes/${homeId}/invitations`, {
      email: userBEmail,
      role: 'ADMIN'
    }, tokenANew);
    assert.strictEqual(dupInvite.status, 400, 'Duplicate pending invite must fail');

    // Alice invites Charlie as VIEWER
    const inviteCharlie = await request('POST', `/api/v1/homes/${homeId}/invitations`, {
      email: userCEmail,
      role: 'VIEWER'
    }, tokenANew);
    assert.strictEqual(inviteCharlie.status, 201);
    const inviteCodeCharlie = inviteCharlie.body.data.invite_code;

    // Bob checks pending invitations
    const bobInvites = await request('GET', '/api/v1/invitations/pending', null, tokenB);
    assert.strictEqual(bobInvites.status, 200);
    assert.strictEqual(bobInvites.body.data.length, 1);
    assert.strictEqual(bobInvites.body.data[0].role, 'ADMIN');

    // Bob accepts invitation
    const acceptBob = await request('POST', `/api/v1/invitations/${inviteCodeBob}/accept`, null, tokenB);
    assert.strictEqual(acceptBob.status, 200, 'Bob accepts invite');
    assert.strictEqual(acceptBob.body.data.membership.role, 'ADMIN');

    // Single-use token: Bob cannot accept again
    const reAccept = await request('POST', `/api/v1/invitations/${inviteCodeBob}/accept`, null, tokenB);
    assert.strictEqual(reAccept.status, 400, 'Consumed invite cannot be accepted again');

    // Charlie accepts invitation as VIEWER
    const acceptCharlie = await request('POST', `/api/v1/invitations/${inviteCodeCharlie}/accept`, null, tokenC);
    assert.strictEqual(acceptCharlie.status, 200, 'Charlie accepts invite as VIEWER');

    // Verify 3 members in Home
    const members = await request('GET', `/api/v1/homes/${homeId}/members`, null, tokenANew);
    assert.strictEqual(members.status, 200);
    assert.strictEqual(members.body.data.length, 3);

    console.log('[PASS] 3. Invitations & Acceptance Flow');

    // -------------------------------------------------------------
    // TEST 5: RBAC & Capability-Aware Permissions Matrix
    // -------------------------------------------------------------
    console.log('--- 4. RBAC & Capability-Aware Permissions Matrix ---');

    // Seed Product Catalog Variant
    await app.services.db.insert('product_families', 'fam-switches', {
      id: 'fam-switches',
      name: 'EH Smart Switches',
      slug: 'switches'
    });
    await app.services.db.insert('products', 'prod-sw3x', {
      id: 'prod-sw3x',
      family_id: 'fam-switches',
      name: 'Smart Switch 3X',
      slug: 'smart-switch-3x'
    });
    await app.services.db.insert('product_variants', 'eh-smart-switch-3x', {
      id: 'eh-smart-switch-3x',
      product_id: 'prod-sw3x',
      name: '3X',
      sku_code: 'EH-SW3X',
      channel_count: 3,
      hardware_capabilities: ['power', 'relay', 'energy', 'voltage', 'current'],
      supported_firmware_families: ['esp32c6-switch-platform', 'esp32-switch-platform']
    });

    // Setup a device in the home
    await app.services.deviceService.registerDevice({
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      serialNumber: 'SN-PERM-01',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform'
    });
    await app.services.deviceService.assignDeviceToHome({
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      homeId,
      customName: 'Living Room Light'
    });

    // 1. OWNER (Alice) can control device
    const cmdAlice = await request('POST', '/api/v1/commands/send', {
      commandId: require('crypto').randomUUID(),
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      idempotencyKey: 'idem_alice_1',
      source: 'APP',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }, tokenANew);
    if (cmdAlice.status !== 202) console.log('cmdAlice error:', cmdAlice);
    assert.strictEqual(cmdAlice.status, 202, 'OWNER can control device (202 Accepted)');

    // 2. ADMIN (Bob) can control device
    const cmdBob = await request('POST', '/api/v1/commands/send', {
      commandId: require('crypto').randomUUID(),
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      channelIndex: 1,
      action: 'setPower',
      params: { power: false },
      idempotencyKey: 'idem_bob_1',
      source: 'APP',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }, tokenB);
    assert.strictEqual(cmdBob.status, 202, 'ADMIN can control device (202 Accepted)');

    // 3. VIEWER (Charlie) is DENIED device control (403)
    const cmdCharlie = await request('POST', '/api/v1/commands/send', {
      commandId: require('crypto').randomUUID(),
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      idempotencyKey: 'idem_charlie_1',
      source: 'APP',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }, tokenC);
    assert.strictEqual(cmdCharlie.status, 403, 'VIEWER cannot control devices (403 Forbidden)');

    // 4. ADMIN (Bob) cannot delete home (403)
    const deleteHomeBob = await request('DELETE', `/api/v1/homes/${homeId}`, null, tokenB);
    assert.strictEqual(deleteHomeBob.status, 403, 'ADMIN cannot delete home (403 Forbidden)');

    // 5. Member role update: Alice promotes Charlie from VIEWER to MEMBER
    const promoteCharlie = await request('PATCH', `/api/v1/homes/${homeId}/members/${userCId}/role`, {
      role: 'MEMBER'
    }, tokenANew);
    assert.strictEqual(promoteCharlie.status, 200, 'Owner can update member role');

    // Now Charlie (as MEMBER) CAN control device
    const cmdCharlieMember = await request('POST', '/api/v1/commands/send', {
      commandId: require('crypto').randomUUID(),
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      idempotencyKey: 'idem_charlie_2',
      source: 'APP',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }, tokenC);
    assert.strictEqual(cmdCharlieMember.status, 202, 'MEMBER can control devices (202 Accepted)');

    console.log('[PASS] 4. RBAC & Capability-Aware Permissions Matrix');

    // -------------------------------------------------------------
    // TEST 6: Ownership Transfer, Leave & Immediate Access Revocation
    // -------------------------------------------------------------
    console.log('--- 5. Ownership Transfer & Member Removal ---');

    // Alice transfers ownership to Bob
    const transfer = await request('POST', `/api/v1/homes/${homeId}/transfer-ownership`, {
      newOwnerId: userBId
    }, tokenANew);
    assert.strictEqual(transfer.status, 200, 'Ownership transferred successfully');

    // Now Bob is OWNER
    const homesBAfter = await request('GET', '/api/v1/homes', null, tokenB);
    assert.strictEqual(homesBAfter.body.data[0].role, 'OWNER');
    assert.strictEqual(homesBAfter.body.data[0].permissions.canDeleteHome, true);

    // Alice is now ADMIN
    const homesAAfter = await request('GET', '/api/v1/homes', null, tokenANew);
    assert.strictEqual(homesAAfter.body.data[0].role, 'ADMIN');
    assert.strictEqual(homesAAfter.body.data[0].permissions.canDeleteHome, false);

    // Bob removes Charlie from Home
    const removeCharlie = await request('DELETE', `/api/v1/homes/${homeId}/members/${userCId}`, null, tokenB);
    assert.strictEqual(removeCharlie.status, 200, 'Member removed');

    // Charlie immediately loses access to Home and Device
    const cmdCharlieRemoved = await request('POST', '/api/v1/commands/send', {
      commandId: require('crypto').randomUUID(),
      deviceId: '0194fe23-7a1b-7890-a123-456789abc100',
      channelIndex: 1,
      action: 'setPower',
      params: { power: false },
      idempotencyKey: 'idem_charlie_removed_1',
      source: 'APP',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }, tokenC);
    assert.strictEqual(cmdCharlieRemoved.status, 403, 'Removed member has zero device access (403 Forbidden)');

    // Alice leaves home
    const leaveAlice = await request('POST', `/api/v1/homes/${homeId}/leave`, null, tokenANew);
    assert.strictEqual(leaveAlice.status, 200, 'Alice leaves home');

    // Bob (sole owner) cannot leave without deleting or transferring
    const leaveBob = await request('POST', `/api/v1/homes/${homeId}/leave`, null, tokenB);
    assert.strictEqual(leaveBob.status, 400, 'Sole owner cannot leave without deleting home');

    console.log('[PASS] 5. Ownership Transfer & Member Removal');

    // -------------------------------------------------------------
    // TEST 7: Home Deletion Cascade
    // -------------------------------------------------------------
    console.log('--- 6. Home Deletion Cascade ---');
    const deleteHomeBobSuccess = await request('DELETE', `/api/v1/homes/${homeId}`, null, tokenB);
    assert.strictEqual(deleteHomeBobSuccess.status, 200, 'Owner can delete home');

    const checkHomeDeleted = await request('GET', `/api/v1/homes/${homeId}`, null, tokenB);
    assert.strictEqual(checkHomeDeleted.status, 403, 'Deleted home is no longer accessible');

    console.log('[PASS] 6. Home Deletion Cascade');

    console.log('===============================================================');
    console.log('  PHASE 16 TEST SUMMARY: 6 PASSED, 0 FAILED');
    console.log('===============================================================');
  } finally {
    server.close();
  }
}

if (require.main === module) {
  runTests().catch(err => {
    console.error('[FAIL] Phase 16 Test Suite Error:', err);
    process.exit(1);
  });
}

module.exports = { runTests };
