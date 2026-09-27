/**
 * EH Home API — Part 14 RBAC, Security & Immutable Audit Test Suite
 */

const assert = require('assert');
const { buildApp } = require('../dist/app');
const {
  UserRoleSchema,
  HomeRoleSchema,
  PermissionSchema,
  PrincipalStatusSchema,
  hasRolePermission,
  hasHomeRolePermission,
  evaluateAuthorization,
  assertNoSecretsInAuditPayload
} = require('@eh-home/contracts');
const {
  SecurityRepository,
  SecurityService,
  AuditRepository,
  AuditService
} = require('../dist/modules');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

async function runTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  [PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

async function main() {
  console.log('=== EH HOME PART 14: RBAC / SECURITY / AUDIT TEST SUITE ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: { logger: false }
  });

  const secRepo = new SecurityRepository(app);
  const secService = new SecurityService(secRepo);

  const auditRepo = new AuditRepository(app);
  const auditService = new AuditService(auditRepo);

  app.decorate('securityRepository', secRepo);
  app.decorate('securityService', secService);
  app.decorate('auditRepository', auditRepo);
  app.decorate('auditService', auditService);

  await app.ready();

  // Seed Canonical Test Principals
  const ADMIN_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000001',
    email: 'admin@ehhome.io',
    role: 'ADMIN',
    status: 'ACTIVE',
    homeMemberships: []
  };

  const OPERATOR_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000002',
    email: 'operator@ehhome.io',
    role: 'OPERATOR',
    status: 'ACTIVE',
    homeMemberships: []
  };

  const RELEASE_ENG_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000003',
    email: 'release@ehhome.io',
    role: 'RELEASE_ENGINEER',
    status: 'ACTIVE',
    homeMemberships: []
  };

  const AUDITOR_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000004',
    email: 'auditor@ehhome.io',
    role: 'AUDITOR',
    status: 'ACTIVE',
    homeMemberships: []
  };

  const STANDARD_USER_A = {
    id: '0194fe23-7a1b-7890-a123-000000000005',
    email: 'usera@ehhome.io',
    role: 'USER',
    status: 'ACTIVE',
    homeMemberships: [
      { homeId: 'home-alpha', role: 'OWNER' },
      { homeId: 'home-beta', role: 'MEMBER' }
    ]
  };

  const STANDARD_USER_B = {
    id: '0194fe23-7a1b-7890-a123-000000000006',
    email: 'userb@ehhome.io',
    role: 'USER',
    status: 'ACTIVE',
    homeMemberships: [
      { homeId: 'home-gamma', role: 'OWNER' },
      { homeId: 'home-alpha', role: 'VIEWER' }
    ]
  };

  const DISABLED_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000007',
    email: 'disabled@ehhome.io',
    role: 'USER',
    status: 'DISABLED',
    homeMemberships: []
  };

  const REVOKED_USER = {
    id: '0194fe23-7a1b-7890-a123-000000000008',
    email: 'revoked@ehhome.io',
    role: 'USER',
    status: 'REVOKED',
    homeMemberships: []
  };

  const SERVICE_PRINCIPAL = {
    id: '0194fe23-7a1b-7890-a123-000000000009',
    email: 'daemon@system.ehhome.io',
    role: 'SERVICE',
    status: 'ACTIVE',
    homeMemberships: []
  };

  secService.setAuditService(auditService);

  secRepo.seedPrincipal(ADMIN_USER);
  secRepo.seedPrincipal(OPERATOR_USER);
  secRepo.seedPrincipal(RELEASE_ENG_USER);
  secRepo.seedPrincipal(AUDITOR_USER);
  secRepo.seedPrincipal(STANDARD_USER_A);
  secRepo.seedPrincipal(STANDARD_USER_B);
  secRepo.seedPrincipal(DISABLED_USER);
  secRepo.seedPrincipal(REVOKED_USER);
  secRepo.seedPrincipal(SERVICE_PRINCIPAL);

  // ── 1. AUTHENTICATION & PRINCIPAL VERIFICATION ───────────────────────────
  console.log('1. Authentication & Principal Status:');

  await runTest('T01 Valid principal Bearer token authenticates successfully', async () => {
    const ctx = await secService.authenticate({ authHeader: `Bearer ${ADMIN_USER.id}` });
    assert.strictEqual(ctx.principal.id, ADMIN_USER.id);
    assert.strictEqual(ctx.principal.role, 'ADMIN');
  });

  await runTest('T02 Missing Authorization header fails closed (401 UNAUTHENTICATED)', async () => {
    await assert.rejects(async () => {
      await secService.authenticate({});
    }, (err) => err.statusCode === 401 && err.errorCode === 'UNAUTHENTICATED');
  });

  await runTest('T03 Malformed Authorization header fails closed (401 INVALID_AUTH_FORMAT)', async () => {
    await assert.rejects(async () => {
      await secService.authenticate({ authHeader: 'Basic dXNlcjpwYXNz' });
    }, (err) => err.statusCode === 401 && err.errorCode === 'INVALID_AUTH_FORMAT');
  });

  await runTest('T04 Unknown principal ID fails closed (401 UNKNOWN_PRINCIPAL)', async () => {
    await assert.rejects(async () => {
      await secService.authenticate({ authHeader: 'Bearer non-existent-user-id' });
    }, (err) => err.statusCode === 401 && err.errorCode === 'UNKNOWN_PRINCIPAL');
  });

  await runTest('T05 Administratively DISABLED principal is denied (403 PRINCIPAL_DISABLED)', async () => {
    await assert.rejects(async () => {
      await secService.authenticate({ authHeader: `Bearer ${DISABLED_USER.id}` });
    }, (err) => err.statusCode === 403 && err.errorCode === 'PRINCIPAL_DISABLED');
  });

  await runTest('T06 Security REVOKED principal is denied (403 PRINCIPAL_REVOKED)', async () => {
    await assert.rejects(async () => {
      await secService.authenticate({ authHeader: `Bearer ${REVOKED_USER.id}` });
    }, (err) => err.statusCode === 403 && err.errorCode === 'PRINCIPAL_REVOKED');
  });

  // ── 2. ROLE-BASED ACCESS CONTROL (RBAC) ───────────────────────────────────
  console.log('\n2. Role-Based Access Control & Default-Deny:');

  const adminCtx = await secService.authenticate({ authHeader: `Bearer ${ADMIN_USER.id}` });
  const opCtx = await secService.authenticate({ authHeader: `Bearer ${OPERATOR_USER.id}` });
  const relEngCtx = await secService.authenticate({ authHeader: `Bearer ${RELEASE_ENG_USER.id}` });
  const auditorCtx = await secService.authenticate({ authHeader: `Bearer ${AUDITOR_USER.id}` });
  const userACtx = await secService.authenticate({ authHeader: `Bearer ${STANDARD_USER_A.id}` });

  await runTest('T07 Platform ADMIN possesses universal platform permissions', () => {
    assert.strictEqual(secService.authorize(adminCtx, 'firmware:approve').authorized, true);
    assert.strictEqual(secService.authorize(adminCtx, 'firmware:release').authorized, true);
    assert.strictEqual(secService.authorize(adminCtx, 'ota:authorize').authorized, true);
    assert.strictEqual(secService.authorize(adminCtx, 'manufacturing:pack').authorized, true);
    assert.strictEqual(secService.authorize(adminCtx, 'user:manage_roles').authorized, true);
    assert.strictEqual(secService.authorize(adminCtx, 'security:admin').authorized, true);
  });

  await runTest('T08 RELEASE_ENGINEER authorized for firmware & OTA, denied for manufacturing & user admin', () => {
    assert.strictEqual(secService.authorize(relEngCtx, 'firmware:approve').authorized, true);
    assert.strictEqual(secService.authorize(relEngCtx, 'firmware:release').authorized, true);
    assert.strictEqual(secService.authorize(relEngCtx, 'ota:authorize').authorized, true);
    assert.strictEqual(secService.authorize(relEngCtx, 'manufacturing:pack').authorized, false);
    assert.strictEqual(secService.authorize(relEngCtx, 'user:manage_roles').authorized, false);
    assert.strictEqual(secService.authorize(relEngCtx, 'security:admin').authorized, false);
  });

  await runTest('T09 OPERATOR authorized for manufacturing & packing, denied for firmware approval & security', () => {
    assert.strictEqual(secService.authorize(opCtx, 'manufacturing:provision').authorized, true);
    assert.strictEqual(secService.authorize(opCtx, 'manufacturing:qc').authorized, true);
    assert.strictEqual(secService.authorize(opCtx, 'manufacturing:pack').authorized, true);
    assert.strictEqual(secService.authorize(opCtx, 'manufacturing:inventory').authorized, true);
    assert.strictEqual(secService.authorize(opCtx, 'firmware:approve').authorized, false);
    assert.strictEqual(secService.authorize(opCtx, 'firmware:release').authorized, false);
    assert.strictEqual(secService.authorize(opCtx, 'security:admin').authorized, false);
  });

  await runTest('T10 AUDITOR authorized for audit & read-only, denied for all write & mutation operations', () => {
    assert.strictEqual(secService.authorize(auditorCtx, 'audit:read').authorized, true);
    assert.strictEqual(secService.authorize(auditorCtx, 'device:read').authorized, true);
    assert.strictEqual(secService.authorize(auditorCtx, 'firmware:read').authorized, true);
    assert.strictEqual(secService.authorize(auditorCtx, 'device:write').authorized, false);
    assert.strictEqual(secService.authorize(auditorCtx, 'firmware:write').authorized, false);
    assert.strictEqual(secService.authorize(auditorCtx, 'manufacturing:pack').authorized, false);
  });

  await runTest('T11 Standard USER denied from manufacturing, firmware release & administrative operations', () => {
    assert.strictEqual(secService.authorize(userACtx, 'manufacturing:pack').authorized, false);
    assert.strictEqual(secService.authorize(userACtx, 'firmware:approve').authorized, false);
    assert.strictEqual(secService.authorize(userACtx, 'user:manage_roles').authorized, false);
    assert.strictEqual(secService.authorize(userACtx, 'security:admin').authorized, false);
  });

  await runTest('T12 Unknown permission / role fails closed (Default-Deny)', () => {
    assert.strictEqual(secService.authorize(null, 'device:read').authorized, false);
    assert.strictEqual(secService.authorize(undefined, 'device:read').authorized, false);
    assert.strictEqual(hasRolePermission('UNKNOWN_ROLE', 'device:read'), false);
  });

  // ── 3. RESOURCE-LEVEL & OWNERSHIP AUTHORIZATION ─────────────────────────
  console.log('\n3. Resource-Level Authorization & Device Ownership:');

  const DEVICE_1 = '0194fe23-7a1b-7890-a123-111111111111';
  const DEVICE_2 = '0194fe23-7a1b-7890-a123-222222222222';

  await runTest('T13 Unclaimed device can be claimed by authenticated user into their home', async () => {
    const claimRes = await secService.claimDevice(userACtx, DEVICE_1, 'home-alpha', 'Living Room Switch');
    assert.strictEqual(claimRes.deviceId, DEVICE_1);
    assert.strictEqual(claimRes.claimedByUserId, STANDARD_USER_A.id);
    assert.strictEqual(claimRes.homeId, 'home-alpha');
  });

  await runTest('T14 Claiming an already claimed device is rejected', async () => {
    await assert.rejects(async () => {
      await secService.claimDevice(userACtx, DEVICE_1, 'home-alpha');
    }, /already claimed/);
  });

  await runTest('T15 Cross-owner attack: User B cannot unclaim User A\'s device (403 CROSS_OWNER_DENIED)', async () => {
    const userBCtx = await secService.authenticate({ authHeader: `Bearer ${STANDARD_USER_B.id}` });
    await assert.rejects(async () => {
      await secService.unclaimDevice(userBCtx, DEVICE_1);
    }, (err) => err.statusCode === 403 && err.errorCode === 'CROSS_OWNER_DENIED');
  });

  await runTest('T16 Cross-owner attack: User B cannot transfer User A\'s device (403 CROSS_OWNER_DENIED)', async () => {
    const userBCtx = await secService.authenticate({ authHeader: `Bearer ${STANDARD_USER_B.id}` });
    await assert.rejects(async () => {
      await secService.transferDeviceOwnership(userBCtx, DEVICE_1, STANDARD_USER_B.id, 'home-gamma');
    }, (err) => err.statusCode === 403 && err.errorCode === 'CROSS_OWNER_DENIED');
  });

  await runTest('T17 Device owner can transfer device to another user and home', async () => {
    const transferRes = await secService.transferDeviceOwnership(
      userACtx,
      DEVICE_1,
      STANDARD_USER_B.id,
      'home-gamma'
    );
    assert.strictEqual(transferRes.newOwnerId, STANDARD_USER_B.id);
    assert.strictEqual(transferRes.targetHomeId, 'home-gamma');

    // Verify ownership moved to User B
    const ownership = await secRepo.getDeviceOwnership(DEVICE_1);
    assert.strictEqual(ownership.claimedByUserId, STANDARD_USER_B.id);
    assert.strictEqual(ownership.assignedHomeId, 'home-gamma');
  });

  await runTest('T18 Home-level scoping: Member in Home Alpha can control devices, but rejected for non-member Home Gamma', () => {
    // User A is a member of home-alpha and home-beta
    assert.strictEqual(secService.authorize(userACtx, 'device:control', { homeId: 'home-alpha' }).authorized, true);
    assert.strictEqual(secService.authorize(userACtx, 'device:control', { homeId: 'home-beta' }).authorized, true);

    // User A is NOT a member of home-gamma -> REJECTED
    assert.strictEqual(secService.authorize(userACtx, 'device:control', { homeId: 'home-gamma' }).authorized, false);
  });

  await runTest('T19 Home-level role: VIEWER can read home but is denied device:control', () => {
    // User B is a VIEWER in home-alpha
    const userBCtx = {
      principal: STANDARD_USER_B,
      authenticatedAt: new Date().toISOString()
    };
    assert.strictEqual(secService.authorize(userBCtx, 'home:read', { homeId: 'home-alpha' }).authorized, true);
    assert.strictEqual(secService.authorize(userBCtx, 'device:control', { homeId: 'home-alpha' }).authorized, false);
  });

  // ── 4. PRIVILEGED MANUFACTURING & ADMINISTRATIVE OPERATIONS ──────────────
  console.log('\n4. Privileged Administrative & Manufacturing Operations:');

  await runTest('T20 User role change requires user:manage_roles (Admin succeeds, Operator fails)', async () => {
    // Admin changes User A role to OPERATOR
    const updated = await secService.updateUserRole(adminCtx, STANDARD_USER_A.id, 'OPERATOR');
    assert.strictEqual(updated.role, 'OPERATOR');

    // Operator attempting role change is rejected
    await assert.rejects(async () => {
      await secService.updateUserRole(opCtx, STANDARD_USER_A.id, 'ADMIN');
    }, (err) => err.statusCode === 403);

    // Revert role back to USER
    await secService.updateUserRole(adminCtx, STANDARD_USER_A.id, 'USER');
  });

  await runTest('T21 User security status change requires security:admin (Admin succeeds, Release Eng fails)', async () => {
    // Admin disables a user
    const updated = await secService.updateUserStatus(adminCtx, STANDARD_USER_A.id, 'DISABLED');
    assert.strictEqual(updated.status, 'DISABLED');

    // Release Engineer attempting status change is rejected
    await assert.rejects(async () => {
      await secService.updateUserStatus(relEngCtx, STANDARD_USER_A.id, 'ACTIVE');
    }, (err) => err.statusCode === 403);

    // Revert status back to ACTIVE
    await secService.updateUserStatus(adminCtx, STANDARD_USER_A.id, 'ACTIVE');
  });

  await runTest('T22 Device revocation requires device:revoke (Admin succeeds, User fails)', async () => {
    // Seed Device 2
    secRepo.seedDevice(DEVICE_2, { deviceId: DEVICE_2, deviceClaimStatus: 'CLAIMED', claimedByUserId: STANDARD_USER_A.id });

    // Admin revokes Device 2
    const revoked = await secService.revokeDevice(adminCtx, DEVICE_2, 'Compromised cryptographic key');
    assert.strictEqual(revoked.status, 'REVOKED');

    // Standard User attempting device revocation is rejected
    await assert.rejects(async () => {
      await secService.revokeDevice(userACtx, DEVICE_2);
    }, (err) => err.statusCode === 403);
  });

  // ── 5. IMMUTABLE AUDIT LOGGING & ZERO SECRETS ─────────────────────────────
  console.log('\n5. Immutable Security Audit Logging:');

  await runTest('T23 Security audit event logging emits sequence-numbered immutable record', async () => {
    const event = await auditService.logSecurityEvent({
      actorId: ADMIN_USER.id,
      actorEmail: ADMIN_USER.email,
      actorRole: ADMIN_USER.role,
      action: 'FIRMWARE_RELEASE_APPROVED',
      resourceType: 'FIRMWARE_RELEASE',
      resourceId: '0194fe23-7a1b-7890-a123-456789111111',
      outcome: 'SUCCESS',
      severity: 'INFO',
      metadata: { firmwareFamily: 'esp32c6-switch-platform', version: '1.2.0' }
    });

    assert.ok(event.id);
    assert.ok(event.sequenceNumber >= 1);
    assert.strictEqual(event.action, 'FIRMWARE_RELEASE_APPROVED');
    assert.strictEqual(event.outcome, 'SUCCESS');
  });

  await runTest('T24 Audit logging enforces Zero-Secret Invariant (Rejects passwords, private keys & tokens)', async () => {
    // Payload with password rejected
    await assert.rejects(async () => {
      await auditService.logSecurityEvent({
        actorId: ADMIN_USER.id,
        action: 'AUTH_LOGIN_SUCCESS',
        resourceType: 'USER',
        outcome: 'SUCCESS',
        metadata: { password: 'cleartext_password' }
      });
    }, /Security Violation/);

    // Payload with private key rejected
    await assert.rejects(async () => {
      await auditService.logSecurityEvent({
        actorId: ADMIN_USER.id,
        action: 'CREDENTIAL_ROTATED',
        resourceType: 'DEVICE_CREDENTIAL',
        outcome: 'SUCCESS',
        metadata: { key: '-----BEGIN PRIVATE KEY-----\nMIIE...' }
      });
    }, /Security Violation/);

    // Payload with token rejected
    await assert.rejects(async () => {
      await auditService.logSecurityEvent({
        actorId: ADMIN_USER.id,
        action: 'AUTH_LOGIN_SUCCESS',
        resourceType: 'USER',
        outcome: 'SUCCESS',
        metadata: { accessToken: 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9' }
      });
    }, /Security Violation/);
  });

  await runTest('T25 Audit query requires audit:read permission and supports filtering & pagination', async () => {
    // Log several events
    await auditService.logSecurityEvent({
      actorId: OPERATOR_USER.id,
      action: 'PACKING_VERIFIED',
      resourceType: 'PACKAGING_RECORD',
      resourceId: 'carton-101',
      outcome: 'SUCCESS',
      metadata: { count: 10 }
    });

    await auditService.logSecurityEvent({
      actorId: USER_ID_ANON = '0194fe23-7a1b-7890-a123-000000000099',
      action: 'AUTH_LOGIN_FAILED',
      resourceType: 'USER',
      outcome: 'DENIED',
      failureReason: 'Invalid credentials'
    });

    // Query all events
    const all = await auditService.queryAuditEvents({ limit: 10, offset: 0 }, auditorCtx);
    assert.ok(all.total >= 3);
    assert.ok(all.records.length >= 3);

    // Filter by outcome
    const deniedEvents = await auditService.queryAuditEvents({ outcome: 'DENIED' }, auditorCtx);
    assert.ok(deniedEvents.records.every((e) => e.outcome === 'DENIED'));

    // Filter by action
    const packingEvents = await auditService.queryAuditEvents({ action: 'PACKING_VERIFIED' }, auditorCtx);
    assert.strictEqual(packingEvents.records[0].action, 'PACKING_VERIFIED');
  });

  // ── 6. HTTP SECURITY & AUDIT ROUTES INTEGRATION ───────────────────────────
  console.log('\n6. HTTP Security & Audit Routes Integration:');

  await runTest('T26 GET /api/v1/security/me returns authenticated principal & permissions', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/security/me',
      headers: { authorization: `Bearer ${ADMIN_USER.id}` }
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.data.principal.id, ADMIN_USER.id);
    assert.ok(Array.isArray(body.data.permissions));
  });

  await runTest('T27 GET /api/v1/security/roles returns canonical role matrices', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/security/roles'
    });
    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.data.platformRoles.ADMIN);
    assert.ok(body.data.homeRoles.OWNER);
  });

  await runTest('T28 PATCH /api/v1/security/users/:id/role (401 unauth, 403 forbidden, 200 success)', async () => {
    // 1. Unauthenticated -> 401
    const resUnauth = await app.inject({
      method: 'PATCH',
      url: `/api/v1/security/users/${STANDARD_USER_A.id}/role`,
      payload: { role: 'OPERATOR' }
    });
    assert.strictEqual(resUnauth.statusCode, 401);

    // 2. Operator caller -> 403
    const resForbidden = await app.inject({
      method: 'PATCH',
      url: `/api/v1/security/users/${STANDARD_USER_A.id}/role`,
      headers: { authorization: `Bearer ${OPERATOR_USER.id}` },
      payload: { role: 'ADMIN' }
    });
    assert.strictEqual(resForbidden.statusCode, 403);

    // 3. Admin caller -> 200
    const resSuccess = await app.inject({
      method: 'PATCH',
      url: `/api/v1/security/users/${STANDARD_USER_A.id}/role`,
      headers: { authorization: `Bearer ${ADMIN_USER.id}` },
      payload: { role: 'OPERATOR' }
    });
    assert.strictEqual(resSuccess.statusCode, 200);
  });

  await runTest('T29 GET /api/v1/audit/events (401 unauth, 403 operator, 200 auditor)', async () => {
    // 1. Unauthenticated -> 401
    const resUnauth = await app.inject({
      method: 'GET',
      url: '/api/v1/audit/events'
    });
    assert.strictEqual(resUnauth.statusCode, 401);

    // 2. Operator caller (lacks audit:read) -> 403
    const resForbidden = await app.inject({
      method: 'GET',
      url: '/api/v1/audit/events',
      headers: { authorization: `Bearer ${OPERATOR_USER.id}` }
    });
    assert.strictEqual(resForbidden.statusCode, 403);

    // 3. Auditor caller -> 200
    const resSuccess = await app.inject({
      method: 'GET',
      url: '/api/v1/audit/events',
      headers: { authorization: `Bearer ${AUDITOR_USER.id}` }
    });
    assert.strictEqual(resSuccess.statusCode, 200);
    const body = JSON.parse(resSuccess.body);
    assert.ok(Array.isArray(body.data));
  });

  // ── 7. SERVICE ROLE LEAST-PRIVILEGE RBAC & SCOPE TESTS ──────────────────
  console.log('\n7. SERVICE Role Least-Privilege RBAC & Scopes:');

  await runTest('T30 SERVICE role explicit least-privilege positive permissions', async () => {
    const allowed = [
      'product:read',
      'hardware:read',
      'firmware:read',
      'ota:read',
      'ota:execute',
      'device:read',
      'device:write',
      'device:control',
      'manufacturing:inventory',
      'audit:read'
    ];
    for (const perm of allowed) {
      assert.strictEqual(hasRolePermission('SERVICE', perm), true, `SERVICE must have ${perm}`);
    }
  });

  await runTest('T31 SERVICE role explicit negative permissions fail closed', async () => {
    const denied = [
      'user:read',
      'user:write',
      'user:manage_roles',
      'security:admin',
      'firmware:approve',
      'firmware:release',
      'firmware:revoke',
      'ota:authorize',
      'manufacturing:provision',
      'manufacturing:qc',
      'manufacturing:pack',
      'manufacturing:print',
      'device:claim',
      'device:unclaim',
      'device:transfer',
      'device:revoke',
      'device:quarantine',
      'home:read',
      'home:write',
      'home:delete',
      'home:manage_members'
    ];
    for (const perm of denied) {
      assert.strictEqual(hasRolePermission('SERVICE', perm), false, `SERVICE must NOT have ${perm}`);
    }
  });

  await runTest('T32 SERVICE principal attempting unassigned admin API fails closed (403)', async () => {
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/security/users/${STANDARD_USER_A.id}/role`,
      headers: { authorization: `Bearer ${SERVICE_PRINCIPAL.id}` },
      payload: { role: 'OPERATOR' }
    });
    assert.strictEqual(res.statusCode, 403);
  });

  // ── 8. HOME ROLE CANONICAL AUDIT ──────────────────────────────────────────
  console.log('\n8. Home Role Canonical Naming & Separation:');

  await runTest('T33 HomeRoleSchema strictly distinguishes OWNER, HOME_ADMIN, MEMBER, GUEST, VIEWER from platform ADMIN', async () => {
    const validHomeRoles = ['OWNER', 'HOME_ADMIN', 'MEMBER', 'GUEST', 'VIEWER'];
    for (const role of validHomeRoles) {
      assert.doesNotThrow(() => HomeRoleSchema.parse(role));
    }
    // Platform ADMIN must NOT parse as a home role
    assert.throws(() => HomeRoleSchema.parse('ADMIN'));
  });

  // ── 9. SECURITY & AUDIT EVENT PERSISTENCE COVERAGE ────────────────────────
  console.log('\n9. Security & Audit Event Coverage:');

  await runTest('T34 Privileged user role update generates USER_ROLE_CHANGED audit record', async () => {
    const adminCtx = { principal: ADMIN_USER, authenticatedAt: new Date().toISOString() };
    await secService.updateUserRole(adminCtx, STANDARD_USER_B.id, 'OPERATOR');
    const { records } = await auditService.queryAuditEvents({ action: 'USER_ROLE_CHANGED' });
    assert.ok(records.length > 0);
    assert.strictEqual(records[0].actorId, ADMIN_USER.id);
    assert.strictEqual(records[0].action, 'USER_ROLE_CHANGED');
    assert.strictEqual(records[0].outcome, 'SUCCESS');
  });

  await runTest('T35 Device lifecycle operations generate DEVICE_CLAIMED, UNCLAIMED, TRANSFERRED, REVOKED audit records', async () => {
    const userACtx = { principal: STANDARD_USER_A, authenticatedAt: new Date().toISOString() };
    const adminCtx = { principal: ADMIN_USER, authenticatedAt: new Date().toISOString() };

    // Claim
    const devId = 'dev-audit-100';
    await secService.claimDevice(userACtx, devId, 'home-alpha', 'Smart Light');

    // Transfer
    await secService.transferDeviceOwnership(userACtx, devId, STANDARD_USER_B.id, 'home-gamma');

    // Revoke (Admin)
    await secService.revokeDevice(adminCtx, devId, 'Security compromise');

    const { records } = await auditService.queryAuditEvents({ resourceId: devId });
    assert.ok(records.length >= 3);
    const actions = records.map((r) => r.action);
    assert.ok(actions.includes('DEVICE_CLAIMED'));
    assert.ok(actions.includes('DEVICE_TRANSFERRED'));
    assert.ok(actions.includes('DEVICE_REVOKED'));
  });

  await runTest('T36 Cross-owner device unclaim generates DENIED audit record with CROSS_OWNER_DENIED', async () => {
    const userACtx = { principal: STANDARD_USER_A, authenticatedAt: new Date().toISOString() };
    const userBCtx = { principal: STANDARD_USER_B, authenticatedAt: new Date().toISOString() };
    const devId = 'dev-audit-cross-owner';

    // Claim by User A
    await secService.claimDevice(userACtx, devId, 'home-alpha', 'Owner A Light');

    // User B attempts to unclaim User A's device -> fails
    try {
      await secService.unclaimDevice(userBCtx, devId);
      assert.fail('Should have thrown cross-owner error');
    } catch (err) {
      assert.strictEqual(err.errorCode, 'CROSS_OWNER_DENIED');
    }

    const { records } = await auditService.queryAuditEvents({
      action: 'DEVICE_UNCLAIMED',
      outcome: 'DENIED'
    });
    assert.ok(records.length > 0);
    assert.strictEqual(records[0].actorId, userBCtx.principal.id);
    assert.strictEqual(records[0].errorCode, 'CROSS_OWNER_DENIED');
  });

  await runTest('T37 Firmware & OTA lifecycle audit events logging', async () => {
    await auditService.logSecurityEvent({
      actorId: RELEASE_ENG_USER.id,
      actorRole: 'RELEASE_ENGINEER',
      action: 'FIRMWARE_RELEASE_APPROVED',
      resourceType: 'FIRMWARE_RELEASE',
      resourceId: 'rel-v2.1.0',
      outcome: 'SUCCESS',
      metadata: { version: '2.1.0' }
    });

    await auditService.logSecurityEvent({
      actorId: RELEASE_ENG_USER.id,
      actorRole: 'RELEASE_ENGINEER',
      action: 'OTA_JOB_AUTHORIZED',
      resourceType: 'OTA_JOB',
      resourceId: 'job-ota-100',
      outcome: 'SUCCESS',
      metadata: { targetVersion: '2.1.0', targetMcu: 'esp32-c6' }
    });

    await auditService.logSecurityEvent({
      actorId: RELEASE_ENG_USER.id,
      actorRole: 'RELEASE_ENGINEER',
      action: 'OTA_JOB_REJECTED',
      resourceType: 'OTA_JOB',
      resourceId: 'job-ota-101',
      outcome: 'DENIED',
      failureReason: 'ARTIFACT_NOT_RELEASED'
    });

    const { records } = await auditService.queryAuditEvents({ resourceType: 'OTA_JOB' });
    assert.strictEqual(records.length, 2);
  });

  await runTest('T38 Manufacturing & QC audit events logging', async () => {
    await auditService.logSecurityEvent({
      actorId: OPERATOR_USER.id,
      actorRole: 'OPERATOR',
      action: 'FACTORY_PROVISIONED',
      resourceType: 'DEVICE',
      resourceId: 'dev-mfg-001',
      outcome: 'SUCCESS',
      metadata: { batchId: 'batch-2026-01' }
    });

    await auditService.logSecurityEvent({
      actorId: OPERATOR_USER.id,
      actorRole: 'OPERATOR',
      action: 'QC_TEST_OVERRIDDEN',
      resourceType: 'BATCH',
      resourceId: 'qc-run-99',
      outcome: 'WARNING',
      severity: 'WARNING',
      metadata: { reason: 'Visual re-inspection pass' }
    });

    const { records } = await auditService.queryAuditEvents({ action: 'QC_TEST_OVERRIDDEN' });
    assert.strictEqual(records.length, 1);
    assert.strictEqual(records[0].severity, 'WARNING');
  });

  await runTest('T39 Authentication & Security violation events logging', async () => {
    await auditService.logSecurityEvent({
      actorId: 'anonymous',
      action: 'AUTH_LOGIN_FAILED',
      resourceType: 'USER',
      outcome: 'FAILED',
      failureReason: 'INVALID_CREDENTIALS',
      clientIp: '192.168.1.50'
    });

    await auditService.logSecurityEvent({
      actorId: REVOKED_USER.id,
      action: 'AUTH_REVOKED_ATTEMPT',
      resourceType: 'USER',
      outcome: 'DENIED',
      severity: 'CRITICAL',
      failureReason: 'PRINCIPAL_REVOKED'
    });

    const { records } = await auditService.queryAuditEvents({ action: 'AUTH_REVOKED_ATTEMPT' });
    assert.strictEqual(records.length, 1);
    assert.strictEqual(records[0].severity, 'CRITICAL');
  });

  await runTest('T40 Audit atomicity & zero-secret assertion strictly fails closed on secrets', async () => {
    await assert.rejects(
      async () => {
        await auditService.logSecurityEvent({
          actorId: ADMIN_USER.id,
          action: 'SECURITY_POLICY_CHANGED',
          resourceType: 'SYSTEM',
          outcome: 'SUCCESS',
          metadata: {
            policy: 'mfa_enforced',
            userPasswordHash: 'secret$hash123'
          }
        });
      },
      /Security Violation/
    );
  });

  // ── SUMMARY ───────────────────────────────────────────────────────────────
  console.log(`\n=== PART 14 TEST SUITE SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL PART 14 RBAC, SECURITY & AUDIT TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
