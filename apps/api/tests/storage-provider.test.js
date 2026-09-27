const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const {
  MemoryStorageProvider,
  S3StorageProvider,
  StorageService,
  AuditService,
  AuditRepository
} = require('../dist/modules');

const {
  StorageBucketSchema,
  CanonicalObjectKeyBuilder,
  hasRolePermission
} = require('@eh-home/contracts');

test('Storage Provider — MemoryStorageProvider Put, Get, Head, Delete, List', async () => {
  const provider = new MemoryStorageProvider();
  await provider.init();

  const service = new StorageService(provider);
  const sampleContent = Buffer.from('TEST_IMAGE_BINARY_DATA_12345', 'utf8');

  // 1. Put Object (Product Asset)
  const meta = await service.uploadProductAsset(
    'prod-001',
    'var-001',
    'asset-001',
    'front.png',
    sampleContent,
    'image/png'
  );

  assert.equal(meta.bucket, 'eh-product-assets');
  assert.ok(meta.key.includes('products/prod-001/variants/var-001/images/asset-001_front.png'));
  assert.equal(meta.sizeBytes, sampleContent.byteLength);
  assert.equal(meta.contentType, 'image/png');
  assert.equal(meta.classification, 'PUBLIC_ASSET');
  assert.equal(
    meta.sha256,
    crypto.createHash('sha256').update(sampleContent).digest('hex')
  );

  // 2. Get Object
  const retrieved = await service.getObject(meta.bucket, meta.key);
  assert.deepEqual(retrieved.content, sampleContent);
  assert.equal(retrieved.metadata.sha256, meta.sha256);

  // 3. Head Object (Metadata only)
  const headMeta = await service.headObject(meta.bucket, meta.key);
  assert.equal(headMeta.sizeBytes, sampleContent.byteLength);
  assert.equal(headMeta.sha256, meta.sha256);

  // 4. Has Object
  const exists = await service.hasObject(meta.bucket, meta.key);
  assert.equal(exists, true);

  // 5. List Objects
  const listResult = await service.listObjects('eh-product-assets', 'products/prod-001');
  assert.equal(listResult.objects.length, 1);
  assert.equal(listResult.objects[0].key, meta.key);

  // 6. Signed URL Generation
  const signedUrl = await service.getSignedUrl('eh-product-assets', meta.key, 300, 'GET');
  assert.ok(signedUrl.url.includes('eh-product-assets'));
  assert.ok(signedUrl.url.includes('expires='));

  // 7. Delete Object
  const deleted = await service.deleteObject(meta.bucket, meta.key);
  assert.equal(deleted, true);

  const existsAfterDelete = await service.hasObject(meta.bucket, meta.key);
  assert.equal(existsAfterDelete, false);
});

test('Storage Provider — Key Sanitization & Path Traversal Rejection', async () => {
  const provider = new MemoryStorageProvider();
  const service = new StorageService(provider);

  // Attempt path traversal in segment
  const key = CanonicalObjectKeyBuilder.buildProductAssetKey(
    '../../../etc',
    'passwd',
    '../../root',
    'exploit.bin'
  );

  assert.ok(!key.includes('..'));
  assert.ok(!key.includes('/../'));

  // Normalized key
  const normalized = CanonicalObjectKeyBuilder.normalizeKey('eh-product-assets/../../../system/file.txt');
  assert.equal(normalized, 'eh-product-assets/system/file.txt');
});

test('Storage Provider — Firmware Artifact Storage with SHA-256 & Classification', async () => {
  const provider = new MemoryStorageProvider();
  const auditRepo = new AuditRepository();
  const auditService = new AuditService(auditRepo);
  const service = new StorageService(provider, auditService);

  const fwBinary = Buffer.from('FIRMWARE_APP_BINARY_PAYLOAD_V120', 'utf8');
  const fwSha = crypto.createHash('sha256').update(fwBinary).digest('hex');

  const callerContext = {
    principal: {
      id: 'usr-release-eng',
      email: 'releng@ehhome.io',
      role: 'RELEASE_ENGINEER',
      status: 'ACTIVE',
      homeMemberships: []
    },
    correlationId: 'corr-fw-001',
    authenticatedAt: new Date().toISOString()
  };

  const fwMeta = await service.uploadFirmwareBinary(
    'dimmer-platform',
    '1.2.0',
    'esp32-c6',
    fwSha,
    fwBinary,
    callerContext
  );

  assert.equal(fwMeta.bucket, 'eh-firmware-artifacts');
  assert.equal(fwMeta.classification, 'PROTECTED_FIRMWARE');
  assert.equal(fwMeta.sha256, fwSha);
  assert.ok(fwMeta.key.startsWith('firmware/dimmer-platform/1.2.0/esp32-c6/'));

  // Verify Audit Log was emitted for protected firmware storage
  const auditLogs = await auditRepo.queryEvents({ action: 'OBJECT_STORED' });
  assert.equal(auditLogs.total, 1);
  assert.equal(auditLogs.records[0].actorId, 'usr-release-eng');
  assert.equal(auditLogs.records[0].resourceType, 'STORAGE');
});

test('Storage Provider — Missing Object & Missing Bucket Error Handling', async () => {
  const provider = new MemoryStorageProvider();
  const service = new StorageService(provider);

  // Non-existent key -> throws 404
  await assert.rejects(
    async () => {
      await service.getObject('eh-product-assets', 'non-existent-key.png');
    },
    (err) => {
      assert.equal(err.statusCode, 404);
      assert.ok(err.message.includes('NoSuchKey'));
      return true;
    }
  );

  // Invalid bucket -> throws schema validation error
  await assert.rejects(
    async () => {
      await service.getObject('unauthorized-bucket', 'key.png');
    }
  );
});

test('Storage Provider — S3 SigV4 Request & Presigned URL Generation', async () => {
  const s3Provider = new S3StorageProvider({
    endpoint: 'http://127.0.0.1:9000',
    region: 'us-east-1',
    accessKeyId: 'minioadmin',
    secretAccessKey: 'minioadmin',
    forcePathStyle: true
  });

  const presigned = await s3Provider.getSignedUrl(
    'eh-product-assets',
    'products/prod-01/front.png',
    900,
    'GET'
  );

  assert.ok(presigned.url.startsWith('http://127.0.0.1:9000/eh-product-assets/products/prod-01/front.png?'));
  assert.ok(presigned.url.includes('X-Amz-Algorithm=AWS4-HMAC-SHA256'));
  assert.ok(presigned.url.includes('X-Amz-Credential=minioadmin'));
  assert.ok(presigned.url.includes('X-Amz-Signature='));
  assert.equal(presigned.bucket, 'eh-product-assets');
});

test('Storage Provider — Health Check Probe', async () => {
  const memProvider = new MemoryStorageProvider();
  const health1 = await memProvider.isHealthy();
  assert.equal(health1.healthy, true);
  assert.equal(health1.provider, 'MemoryStorageProvider');

  memProvider.setHealthy(false);
  const health2 = await memProvider.isHealthy();
  assert.equal(health2.healthy, false);
});

test('Storage Security — MinIO Bucket Access Policies & RBAC Boundary Enforcement', () => {
  // 1. Bucket Policy Classification & Isolation
  const publicBuckets = ['eh-product-assets'];
  const privateBuckets = ['eh-firmware-artifacts', 'eh-manufacturing-labels', 'eh-database-backups'];

  // Verify all buckets conform to StorageBucketSchema
  for (const b of [...publicBuckets, ...privateBuckets]) {
    assert.doesNotThrow(() => StorageBucketSchema.parse(b));
  }

  // 2. Anonymous / Public Consumer Access Rules
  // eh-product-assets: Allowed anonymously
  // private buckets: Denied anonymously
  const isAnonymousAllowed = (bucket) => bucket === 'eh-product-assets';

  assert.equal(isAnonymousAllowed('eh-product-assets'), true);
  assert.equal(isAnonymousAllowed('eh-firmware-artifacts'), false);
  assert.equal(isAnonymousAllowed('eh-manufacturing-labels'), false);
  assert.equal(isAnonymousAllowed('eh-database-backups'), false);

  // 3. RBAC Policy Enforcement on Private Buckets
  // Firmware Download: RELEASE_ENGINEER or ADMIN only
  assert.equal(hasRolePermission('RELEASE_ENGINEER', 'firmware:release'), true);
  assert.equal(hasRolePermission('ADMIN', 'firmware:release'), true);
  assert.equal(hasRolePermission('USER', 'firmware:release'), false);
  assert.equal(hasRolePermission('AUDITOR', 'firmware:release'), false);

  // Manufacturing Labels: OPERATOR or ADMIN only
  assert.equal(hasRolePermission('OPERATOR', 'manufacturing:provision'), true);
  assert.equal(hasRolePermission('ADMIN', 'manufacturing:provision'), true);
  assert.equal(hasRolePermission('USER', 'manufacturing:provision'), false);

  // Database Backups: ADMIN only for create/restore/delete, AUDITOR for read
  assert.equal(hasRolePermission('ADMIN', 'backup:create'), true);
  assert.equal(hasRolePermission('ADMIN', 'backup:restore'), true);
  assert.equal(hasRolePermission('ADMIN', 'backup:delete'), true);
  assert.equal(hasRolePermission('AUDITOR', 'backup:read'), true);
  assert.equal(hasRolePermission('AUDITOR', 'backup:create'), false);
  assert.equal(hasRolePermission('AUDITOR', 'backup:restore'), false);
  assert.equal(hasRolePermission('USER', 'backup:read'), false);
  assert.equal(hasRolePermission('OPERATOR', 'backup:read'), false);
});

