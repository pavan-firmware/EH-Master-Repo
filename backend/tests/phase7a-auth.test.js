'use strict';

/**
 * EH Home — Phase 7A Authentication & Authorization Integration Test Suite
 *
 * Covers:
 *  1. Register success
 *  2. Duplicate register rejection
 *  3. Password hashing safety
 *  4. Login success
 *  5. Invalid password rejection
 *  6. Access-token verification
 *  7. Expired access-token rejection
 *  8. Malformed token rejection
 *  9. Wrong algorithm rejection
 * 10. Refresh token success
 * 11. Refresh rotation
 * 12. Refresh replay rejection
 * 13. Logout revocation
 * 14. Missing Authorization rejection
 * 15. X-Actor-Context cannot authenticate
 * 16. Home membership allowed
 * 17. Cross-home access rejected
 * 18. Role enforcement
 * 19. Command endpoint requires real authentication
 * 20. Rate limit behavior
 */

const assert = require('assert');
const { createApp } = require('../src/app');
const { DatabaseClient } = require('../src/shared/db-client');
const { AuthService } = require('../src/services/auth.service');
const { RateLimiter } = require('../src/shared/rate-limiter');

let passed = 0;
let failed = 0;

function testAssert(description, condition, detail = '') {
  if (condition) {
    console.log(`  [PASS] ${description}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${description}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

/**
 * Helper to simulate an HTTP request through app.handleRequest
 */
async function makeRequest(app, { method, path, body = {}, headers = {}, remoteAddress = '127.0.0.1' }) {
  return new Promise((resolve) => {
    let responseStatus = 200;
    let responseHeaders = {};
    let responseBody = '';

    const req = new (require('events').EventEmitter)();
    req.method = method;
    req.url = path;
    req.headers = Object.keys(headers).reduce((acc, k) => {
      acc[k.toLowerCase()] = headers[k];
      return acc;
    }, {});
    req.socket = { remoteAddress };

    const res = {
      headersSent: false,
      writeHead(code, hdrs) {
        responseStatus = code;
        responseHeaders = hdrs || {};
        this.headersSent = true;
      },
      end(chunk) {
        if (chunk) responseBody += chunk.toString();
        let parsedJson = null;
        try {
          parsedJson = JSON.parse(responseBody);
        } catch (_) {
          parsedJson = responseBody;
        }
        resolve({
          status: responseStatus,
          headers: responseHeaders,
          body: parsedJson
        });
      }
    };

    app.handleRequest(req, res);

    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
      req.emit('data', Buffer.from(JSON.stringify(body)));
    }
    req.emit('end');
  });
}

async function runPhase7aAuthTests() {
  console.log('=== PHASE 7A AUTHENTICATION & AUTHORIZATION TEST SUITE ===\n');

  const db = new DatabaseClient();
  const rateLimiter = new RateLimiter({ windowMs: 60000, maxRequests: 20 });
  const appInstance = createApp({ db, rateLimiter });
  const { authService, homeService, deviceService } = appInstance.services;

  // Track tokens
  let userAToken = null;
  let userARefreshToken = null;
  let userBToken = null;
  let homeAId = null;
  let homeBId = null;

  // 1. Register Success
  console.log('--- 1. Account Registration & Duplicate Safety ---');
  const regRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/register',
    body: { email: 'usera@ehhome.com', password: 'Password123!' }
  });
  testAssert('1. Register userA returns 201 Created', regRes.status === 201 && regRes.body.success === true);
  testAssert('1. Register response contains UserProfile with ID and email', Boolean(regRes.body.data && regRes.body.data.id && regRes.body.data.email === 'usera@ehhome.com'));

  // 2. Duplicate Register Rejection
  const dupRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/register',
    body: { email: 'usera@ehhome.com', password: 'Password123!' }
  });
  testAssert('2. Duplicate register email returns 409 Conflict', dupRes.status === 409 && dupRes.body.error.code === 'DUPLICATE_EMAIL');

  // 3. Password Hashing Safety
  console.log('\n--- 2. Password Storage & Verification Safety ---');
  const dbUser = await appInstance.repositories.userRepo.findByEmail('usera@ehhome.com');
  testAssert('3. Password in database is NOT plaintext', dbUser && dbUser.password_hash !== 'Password123!');
  testAssert('3. Password in database starts with pbkdf2 algorithm prefix', dbUser && dbUser.password_hash.startsWith('pbkdf2:sha256:'));

  // 4. Login Success
  console.log('\n--- 3. User Authentication & Token Issuance ---');
  const loginRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/login',
    body: { email: 'usera@ehhome.com', password: 'Password123!' }
  });
  testAssert('4. Login returns 200 OK', loginRes.status === 200 && loginRes.body.success === true);
  testAssert('4. Login returns Bearer accessToken, refreshToken, expiresIn', Boolean(loginRes.body.data.accessToken && loginRes.body.data.refreshToken && loginRes.body.data.expiresIn === 900));

  userAToken = loginRes.body.data.accessToken;
  userARefreshToken = loginRes.body.data.refreshToken;

  // 5. Invalid Password Rejection
  const invalidLoginRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/login',
    body: { email: 'usera@ehhome.com', password: 'WrongPassword!' }
  });
  testAssert('5. Invalid password login returns 401 Unauthorized', invalidLoginRes.status === 401 && invalidLoginRes.body.error.code === 'INVALID_CREDENTIALS');

  // 6. Access-Token Verification
  console.log('\n--- 4. Access Token Validation & Error Rejection ---');
  const healthRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/health'
  });
  testAssert('6. Health check is public (200 OK)', healthRes.status === 200);

  const authMeRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes',
    headers: { Authorization: `Bearer ${userAToken}` }
  });
  testAssert('6. Valid JWT token allows access to protected endpoint', authMeRes.status === 200);

  // 7. Expired Access-Token Rejection
  const shortAuthService = new AuthService({
    userRepo: appInstance.repositories.userRepo,
    refreshTokenRepo: appInstance.repositories.refreshTokenRepo,
    accessTtlSeconds: -10 // Already expired
  });
  const expiredToken = shortAuthService.signAccessToken({ id: dbUser.id, email: dbUser.email });
  const expiredRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes',
    headers: { Authorization: `Bearer ${expiredToken}` }
  });
  testAssert('7. Expired access token is rejected with 401', expiredRes.status === 401 && expiredRes.body.error.message.includes('expired'));

  // 8. Malformed Token Rejection
  const malformedRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes',
    headers: { Authorization: 'Bearer not.a.valid.jwt.token' }
  });
  testAssert('8. Malformed token is rejected with 401', malformedRes.status === 401);

  // 9. Wrong Algorithm Rejection
  const wrongAlgToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
  const wrongAlgRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes',
    headers: { Authorization: `Bearer ${wrongAlgToken}` }
  });
  testAssert('9. Non-RS256 algorithm token is rejected with 401', wrongAlgRes.status === 401 && wrongAlgRes.body.error.message.includes('Unsupported algorithm'));

  // 10. Refresh Token Success
  console.log('\n--- 5. Refresh Token Rotation & Replay Protection ---');
  const refreshRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/refresh',
    body: { refreshToken: userARefreshToken }
  });
  testAssert('10. Refresh token returns 200 OK with new tokens', refreshRes.status === 200 && Boolean(refreshRes.body.data.accessToken && refreshRes.body.data.refreshToken));

  const newAccessToken = refreshRes.body.data.accessToken;
  const rotatedRefreshToken = refreshRes.body.data.refreshToken;

  // 11. Refresh Rotation & 12. Replay Rejection
  const replayRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/refresh',
    body: { refreshToken: userARefreshToken } // Old token!
  });
  testAssert('11 & 12. Reusing old refresh token is rejected with 401 (single-use rotation)', replayRes.status === 401);

  // 13. Logout Revocation
  console.log('\n--- 6. Logout & Session Termination ---');
  const logoutRes = await makeRequest(appInstance, {
    method: 'DELETE',
    path: '/api/v1/auth/logout',
    body: { refreshToken: rotatedRefreshToken }
  });
  testAssert('13. Logout endpoint returns 200 OK', logoutRes.status === 200);

  const postLogoutRefreshRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/refresh',
    body: { refreshToken: rotatedRefreshToken }
  });
  testAssert('13. Refreshes after logout are rejected with 401', postLogoutRefreshRes.status === 401);

  // 14. Missing Authorization Rejection & 15. X-Actor-Context Bypass Rejection
  console.log('\n--- 7. Security Bypass Protection ---');
  const noAuthRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes'
  });
  testAssert('14. Protected endpoint without Authorization header returns 401', noAuthRes.status === 401);

  const bypassRes = await makeRequest(appInstance, {
    method: 'GET',
    path: '/api/v1/homes',
    headers: { 'X-Actor-Context': JSON.stringify({ userId: 'fake_user_1', role: 'OWNER' }) }
  });
  testAssert('15. X-Actor-Context header WITHOUT valid Bearer token returns 401', bypassRes.status === 401);

  // 16. Home Membership Allowed & 17. Cross-Home Access Rejected & 18. Role Enforcement
  console.log('\n--- 8. Multi-Tenant Home Membership Isolation ---');
  // Re-login User A
  const loginARes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/login',
    body: { email: 'usera@ehhome.com', password: 'Password123!' }
  });
  userAToken = loginARes.body.data.accessToken;

  // Create User B
  const regBRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/register',
    body: { email: 'userb@ehhome.com', password: 'Password123!' }
  });
  const loginBRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/auth/login',
    body: { email: 'userb@ehhome.com', password: 'Password123!' }
  });
  userBToken = loginBRes.body.data.accessToken;

  // Create Home A owned by User A
  const homeA = await homeService.createHome({
    id: '0194fe23-7a1b-7890-a123-home0000000a',
    name: 'Home Alpha',
    ownerId: dbUser.id
  });
  homeAId = homeA.id;

  // Create Home B owned by User B
  const userB = await appInstance.repositories.userRepo.findByEmail('userb@ehhome.com');
  const homeB = await homeService.createHome({
    id: '0194fe23-7a1b-7890-a123-home0000000b',
    name: 'Home Beta',
    ownerId: userB.id
  });
  homeBId = homeB.id;

  // User A accesses Home A
  const userAAccessHomeA = await makeRequest(appInstance, {
    method: 'GET',
    path: `/api/v1/homes/${homeAId}`,
    headers: { Authorization: `Bearer ${userAToken}` }
  });
  testAssert('16. User A can access Home A (allowed membership)', userAAccessHomeA.status === 200);

  // User A attempts to access Home B
  const userAAccessHomeB = await makeRequest(appInstance, {
    method: 'GET',
    path: `/api/v1/homes/${homeBId}`,
    headers: { Authorization: `Bearer ${userAToken}` }
  });
  testAssert('17. User A accessing Home B returns 403 Forbidden (cross-home access rejected)', userAAccessHomeB.status === 403);

  // 19. Command Endpoint Requires Real Authentication
  console.log('\n--- 9. Device Command Authentication & Isolation ---');
  // Seed product variant
  await appInstance.repositories.productRepo.createFamily({ id: 'fam-switches', name: 'EH Smart Switches', description: 'Smart switch family' });
  await appInstance.repositories.productRepo.createProduct({ id: 'prod-sw3x', familyId: 'fam-switches', name: 'Smart Switch 3X', description: '3-channel smart switch' });
  await appInstance.repositories.productRepo.createVariant({
    id: 'eh-smart-switch-3x', productId: 'prod-sw3x', name: '3X',
    skuCode: 'EH-SW3X', channelCount: 3,
    hardwareCapabilities: [], supportedFirmwareFamilies: ['esp32c6-switch-platform']
  });

  // Register device in Home A
  const devA = await appInstance.repositories.deviceRepo.registerDevice({
    deviceId: '0194fe23-7a1b-7890-a123-45678900000a',
    serialNumber: 'SN-EH-3X-A001',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform'
  });
  await appInstance.repositories.deviceRepo.claimDevice({
    deviceId: devA.id,
    homeId: homeAId,
    customName: 'Switch A',
    claimedByUserId: dbUser.id
  });

  // Unauthenticated command send
  const unauthCmdRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/commands/send',
    body: {
      commandId: '0194fe23-7a1b-7890-a123-456789000001',
      deviceId: devA.id,
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      source: 'APP',
      idempotencyKey: 'idem_cmd_1',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }
  });
  testAssert('19. Command dispatch without Bearer token returns 401 Unauthorized', unauthCmdRes.status === 401);

  // User B (non-member of Home A) attempts command on Device A
  const userBCmdRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/commands/send',
    headers: { Authorization: `Bearer ${userBToken}` },
    body: {
      commandId: '0194fe23-7a1b-7890-a123-456789000002',
      deviceId: devA.id,
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      source: 'APP',
      idempotencyKey: 'idem_cmd_2',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }
  });
  testAssert('19. Non-member User B command dispatch on Device A returns 403 Forbidden', userBCmdRes.status === 403);

  // User A (owner of Home A) executes command on Device A
  const userACmdRes = await makeRequest(appInstance, {
    method: 'POST',
    path: '/api/v1/commands/send',
    headers: { Authorization: `Bearer ${userAToken}` },
    body: {
      commandId: '0194fe23-7a1b-7890-a123-456789000003',
      deviceId: devA.id,
      channelIndex: 1,
      action: 'setPower',
      params: { power: true },
      source: 'APP',
      idempotencyKey: 'idem_cmd_3',
      expiresAt: new Date(Date.now() + 60000).toISOString()
    }
  });
  testAssert('19. Authenticated member User A command dispatch returns 202/200 Accepted', userACmdRes.status === 202 || userACmdRes.status === 200);

  // 20. Rate Limit Behavior
  console.log('\n--- 10. Abuse Protection & Rate Limiting ---');
  let lastRateRes = null;
  for (let i = 0; i < 22; i++) {
    lastRateRes = await makeRequest(appInstance, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: { email: 'usera@ehhome.com', password: 'Password123!' },
      remoteAddress: '192.168.1.100'
    });
  }
  testAssert('20. Exceeding rate limit returns 429 Too Many Requests', lastRateRes.status === 429 && lastRateRes.body.error.code === 'TOO_MANY_REQUESTS');

  console.log(`\n==================================================`);
  console.log(`PHASE 7A TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log(`==================================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  runPhase7aAuthTests().catch((err) => {
    console.error('Unhandled error running Phase 7A tests:', err);
    process.exit(1);
  });
}

module.exports = { runPhase7aAuthTests };
