const test = require('node:test');
const assert = require('node:assert/strict');
const { buildApp } = require('../dist/app');
const { MemoryStorageProvider } = require('../dist/modules');

process.env.NODE_ENV = 'test';

test('Storage & Backup Routes — HTTP API Integration with RBAC and Readiness Probe', async () => {

  const storageProvider = new MemoryStorageProvider();
  await storageProvider.init();

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: { logger: false },
    storageProvider
  });


  const adminToken = 'Bearer token-admin-01';
  const operatorToken = 'Bearer token-operator-01';
  const userToken = 'Bearer token-user-01';

  // Seed Principals in Security Repository
  const secService = app.securityService || app.__defaultSecurityService;
  const secRepo = secService.getRepository();

  await secRepo.savePrincipal({
    id: 'admin-01',
    email: 'admin@ehhome.io',
    role: 'ADMIN',
    status: 'ACTIVE',
    homeMemberships: []
  });
  await secRepo.savePrincipal({
    id: 'operator-01',
    email: 'operator@ehhome.io',
    role: 'OPERATOR',
    status: 'ACTIVE',
    homeMemberships: []
  });
  await secRepo.savePrincipal({
    id: 'user-01',
    email: 'user@ehhome.io',
    role: 'USER',
    status: 'ACTIVE',
    homeMemberships: []
  });

  // 1. Health & Readiness Endpoints
  const healthRes = await app.inject({ method: 'GET', url: '/health' });
  assert.equal(healthRes.statusCode, 200);
  assert.equal(JSON.parse(healthRes.payload).status, 'UP');

  const readyRes = await app.inject({ method: 'GET', url: '/ready' });
  assert.equal(readyRes.statusCode, 200);
  assert.equal(JSON.parse(readyRes.payload).status, 'READY');
  assert.equal(JSON.parse(readyRes.payload).dependencies.storage, 'HEALTHY');

  // 2. Storage Upload: POST /api/v1/storage/upload (ADMIN & OPERATOR allowed, USER forbidden)
  const userUploadRes = await app.inject({
    method: 'POST',
    url: '/api/v1/storage/upload',
    headers: { authorization: userToken },
    payload: {
      bucket: 'eh-product-assets',
      key: 'products/prod-01/front.png',
      content: 'IMAGE_CONTENT_SAMPLE'
    }
  });
  assert.equal(userUploadRes.statusCode, 403);

  const adminUploadRes = await app.inject({
    method: 'POST',
    url: '/api/v1/storage/upload',
    headers: { authorization: adminToken },
    payload: {
      bucket: 'eh-product-assets',
      key: 'products/prod-01/front.png',
      content: 'IMAGE_CONTENT_SAMPLE',
      contentType: 'image/png'
    }
  });
  assert.equal(adminUploadRes.statusCode, 201);
  const uploadPayload = JSON.parse(adminUploadRes.payload);
  assert.equal(uploadPayload.success, true);
  assert.equal(uploadPayload.metadata.bucket, 'eh-product-assets');

  // 3. Storage Get Object: GET /api/v1/storage/object/:bucket/* (Public asset accessible anonymously)
  const getAssetRes = await app.inject({
    method: 'GET',
    url: '/api/v1/storage/object/eh-product-assets/products/prod-01/front.png'
  });
  assert.equal(getAssetRes.statusCode, 200);
  assert.equal(getAssetRes.payload, 'IMAGE_CONTENT_SAMPLE');

  // 4. Presigned URL: POST /api/v1/storage/signed-url
  const signedUrlRes = await app.inject({
    method: 'POST',
    url: '/api/v1/storage/signed-url',
    headers: { authorization: adminToken },
    payload: {
      bucket: 'eh-product-assets',
      key: 'products/prod-01/front.png',
      action: 'GET'
    }
  });
  assert.equal(signedUrlRes.statusCode, 200);
  const signedPayload = JSON.parse(signedUrlRes.payload);
  assert.ok(signedPayload.url.includes('eh-product-assets'));

  // 5. Database Backup Creation: POST /api/v1/backups/create (ADMIN allowed, OPERATOR/USER forbidden)
  const opBackupRes = await app.inject({
    method: 'POST',
    url: '/api/v1/backups/create',
    headers: { authorization: operatorToken }
  });
  assert.equal(opBackupRes.statusCode, 403);

  const adminBackupRes = await app.inject({
    method: 'POST',
    url: '/api/v1/backups/create',
    headers: { authorization: adminToken }
  });
  assert.equal(adminBackupRes.statusCode, 201);
  const backupPayload = JSON.parse(adminBackupRes.payload);
  assert.ok(backupPayload.manifest);
  assert.ok(backupPayload.manifest.backupId);

  // 6. List Backups: GET /api/v1/backups
  const listBackupsRes = await app.inject({
    method: 'GET',
    url: '/api/v1/backups',
    headers: { authorization: adminToken }
  });
  assert.equal(listBackupsRes.statusCode, 200);
  const listPayload = JSON.parse(listBackupsRes.payload);
  assert.equal(listPayload.totalCount, 1);

  // 7. Verify Backup: POST /api/v1/backups/:backupId/verify
  const verifyRes = await app.inject({
    method: 'POST',
    url: `/api/v1/backups/${backupPayload.manifest.backupId}/verify`,
    headers: { authorization: adminToken }
  });
  assert.equal(verifyRes.statusCode, 200);
  const verifyPayload = JSON.parse(verifyRes.payload);
  assert.equal(verifyPayload.valid, true);

  // 8. Restore Backup: POST /api/v1/backups/:backupId/restore (ADMIN allowed, USER forbidden)
  const userRestoreRes = await app.inject({
    method: 'POST',
    url: `/api/v1/backups/${backupPayload.manifest.backupId}/restore`,
    headers: { authorization: userToken }
  });
  assert.equal(userRestoreRes.statusCode, 403);

  const adminRestoreRes = await app.inject({
    method: 'POST',
    url: `/api/v1/backups/${backupPayload.manifest.backupId}/restore`,
    headers: { authorization: adminToken }
  });
  assert.equal(adminRestoreRes.statusCode, 200);
  const restorePayload = JSON.parse(adminRestoreRes.payload);
  assert.equal(restorePayload.success, true);
  assert.equal(restorePayload.integrityVerified, true);

  await app.close();
});
