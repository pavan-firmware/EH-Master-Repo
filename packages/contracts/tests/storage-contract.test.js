const test = require('node:test');
const assert = require('node:assert/strict');
const {
  StorageBucketSchema,
  CANONICAL_BUCKETS,
  ObjectClassificationSchema,
  StorageObjectMetadataSchema,
  BackupManifestSchema,
  CanonicalObjectKeyBuilder,
  ROLE_PERMISSIONS_MAP,
  hasRolePermission
} = require('../dist');

test('Storage Contracts — Canonical Buckets', () => {
  assert.equal(CANONICAL_BUCKETS.length, 4);
  assert.ok(StorageBucketSchema.safeParse('eh-product-assets').success);
  assert.ok(StorageBucketSchema.safeParse('eh-firmware-artifacts').success);
  assert.ok(StorageBucketSchema.safeParse('eh-manufacturing-labels').success);
  assert.ok(StorageBucketSchema.safeParse('eh-database-backups').success);
  assert.ok(!StorageBucketSchema.safeParse('random-bucket').success);
});

test('Storage Contracts — Data Classification', () => {
  assert.ok(ObjectClassificationSchema.safeParse('PUBLIC_ASSET').success);
  assert.ok(ObjectClassificationSchema.safeParse('PROTECTED_FIRMWARE').success);
  assert.ok(ObjectClassificationSchema.safeParse('MANUFACTURING_DATA').success);
  assert.ok(ObjectClassificationSchema.safeParse('DATABASE_BACKUP').success);
  assert.ok(ObjectClassificationSchema.safeParse('AUDIT_EXPORT').success);
  assert.ok(!ObjectClassificationSchema.safeParse('UNKNOWN_CLASSIFICATION').success);
});

test('Storage Contracts — Object Key Sanitization & Path Traversal Prevention', () => {
  // Reject path traversal and illegal characters
  const sanitized = CanonicalObjectKeyBuilder.sanitizeSegment('../../../etc/passwd');
  assert.ok(!sanitized.includes('..'));
  assert.ok(!sanitized.includes('/'));

  // Normalize key
  const normalized = CanonicalObjectKeyBuilder.normalizeKey('products//var-01/../images///file.png');
  assert.equal(normalized, 'products/var-01/images/file.png');
});

test('Storage Contracts — Canonical Key Builders', () => {
  const productKey = CanonicalObjectKeyBuilder.buildProductAssetKey(
    'prod_123',
    'var_456',
    'asset_789',
    'front.png'
  );
  assert.equal(productKey, 'products/prod_123/variants/var_456/images/asset_789_front.png');

  const fwKey = CanonicalObjectKeyBuilder.buildFirmwareKey(
    'dimmer-touch-v1',
    '1.2.0',
    'ESP32_S3',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  );
  assert.equal(
    fwKey,
    'firmware/dimmer-touch-v1/1.2.0/ESP32_S3/e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.bin'
  );

  const labelKey = CanonicalObjectKeyBuilder.buildLabelKey('dev-999', 'qr-token-abc');
  assert.equal(labelKey, 'labels/dev-999/qr-token-abc.pdf');

  const backupKey = CanonicalObjectKeyBuilder.buildBackupKey(
    '2026-09-27T10:00:00.000Z',
    '1.0.0',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  );
  assert.ok(backupKey.startsWith('backups/2026-09-27T10-00-00-000Z_v1.0.0_e3b0c44298fc.json'));
});

test('Storage Contracts — Backup Manifest Validation', () => {
  const validManifest = {
    backupId: 'bk_20260927_001',
    timestamp: '2026-09-27T12:00:00.000Z',
    schemaVersion: '1.0.0',
    migrationVersion: '0015_part15',
    sourceDatabase: 'eh_home_master',
    tableCount: 18,
    rowCount: 2450,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    sizeBytes: 1048576,
    format: 'JSON_SNAPSHOT',
    checksumVerified: true,
    tablesIncluded: ['products', 'devices', 'firmware_binaries', 'audit_logs']
  };
  const parseRes = BackupManifestSchema.safeParse(validManifest);
  assert.ok(parseRes.success);

  // Invalid SHA-256
  const invalidManifest = { ...validManifest, sha256: 'invalid_hash' };
  assert.ok(!BackupManifestSchema.safeParse(invalidManifest).success);
});

test('Storage Contracts — RBAC Storage & Backup Permissions', () => {
  // ADMIN has full access
  assert.ok(hasRolePermission('ADMIN', 'storage:read'));
  assert.ok(hasRolePermission('ADMIN', 'storage:write'));
  assert.ok(hasRolePermission('ADMIN', 'storage:delete'));
  assert.ok(hasRolePermission('ADMIN', 'backup:create'));
  assert.ok(hasRolePermission('ADMIN', 'backup:restore'));

  // RELEASE_ENGINEER has storage read/write for binaries, no backup restore
  assert.ok(hasRolePermission('RELEASE_ENGINEER', 'storage:read'));
  assert.ok(hasRolePermission('RELEASE_ENGINEER', 'storage:write'));
  assert.ok(!hasRolePermission('RELEASE_ENGINEER', 'backup:restore'));

  // OPERATOR has storage read/write for labels/assets, no backup permissions
  assert.ok(hasRolePermission('OPERATOR', 'storage:read'));
  assert.ok(!hasRolePermission('OPERATOR', 'backup:create'));

  // AUDITOR has storage:read, backup:read, no write/restore
  assert.ok(hasRolePermission('AUDITOR', 'storage:read'));
  assert.ok(hasRolePermission('AUDITOR', 'backup:read'));
  assert.ok(!hasRolePermission('AUDITOR', 'storage:write'));
  assert.ok(!hasRolePermission('AUDITOR', 'backup:restore'));

  // SERVICE has storage:read, storage:write, backup:create, backup:read, no backup:restore
  assert.ok(hasRolePermission('SERVICE', 'storage:read'));
  assert.ok(hasRolePermission('SERVICE', 'backup:create'));
  assert.ok(!hasRolePermission('SERVICE', 'backup:restore'));

  // USER has no storage/backup permissions
  assert.ok(!hasRolePermission('USER', 'storage:read'));
  assert.ok(!hasRolePermission('USER', 'backup:create'));
});
