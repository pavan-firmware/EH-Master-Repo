'use strict';

/**
 * EH Home — Phase 8 Signed OTA & Compatibility Test Suite
 */

const assert = require('assert');
const { OtaService } = require('../src/services/ota.service');
const { SchemaValidator } = require('../../packages/contracts/validator');

console.log('\n================================================================');
console.log('       EH HOME — PHASE 8 SIGNED OTA TEST SUITE                  ');
console.log('================================================================\n');

let passCount = 0;
function test(name, fn) {
  try {
    fn();
    console.log(`  [PASS] ${name}`);
    passCount++;
  } catch (err) {
    console.error(`  [FAIL] ${name}:`, err.message);
    process.exit(1);
  }
}

const path = require('path');
const validator = new SchemaValidator();
validator.loadSchema(path.join(__dirname, '../../packages/contracts/ota/ota-manifest.schema.json'));
const otaService = new OtaService({ validator });

const VALID_MANIFEST_1_1 = {
  schemaVersion: 1,
  releaseId: "0194fe23-7a1b-7890-a123-456789111111",
  productVariantId: "eh-smart-switch-3x",
  hardwareRevision: "HW_1_0",
  version: "1.1.0",
  minFirmwareVersion: "1.0.0",
  binarySizeBytes: 1258291,
  sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  ed25519Signature: "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff",
  downloadUrl: "https://ota.ehhome.io/firmware/eh-switch-3x-v1.1.0.bin",
  releaseNotes: "Performance improvements",
  createdAt: new Date().toISOString()
};

const VALID_MANIFEST_2_0 = {
  schemaVersion: 1,
  releaseId: "0194fe23-7a1b-7890-a123-456789222222",
  productVariantId: "eh-smart-switch-3x",
  hardwareRevision: "HW_1_0",
  version: "2.0.0",
  minFirmwareVersion: "1.1.0", // Bridge version required
  binarySizeBytes: 1300000,
  sha256: "a3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  ed25519Signature: "22223344556677889900aabbccddeeff11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff",
  downloadUrl: "https://ota.ehhome.io/firmware/eh-switch-3x-v2.0.0.bin",
  releaseNotes: "Major architecture upgrade",
  createdAt: new Date().toISOString()
};

test('1. OTA Manifest Contract Validation (valid vs invalid)', () => {
  assert.strictEqual(validator.validate('OTAManifest', VALID_MANIFEST_1_1).valid, true);

  const invalid = { ...VALID_MANIFEST_1_1, sha256: "too-short" };
  assert.strictEqual(validator.validate('OTAManifest', invalid).valid, false);
});

test('2. Registering valid signed release', () => {
  const registered = otaService.registerRelease(VALID_MANIFEST_1_1);
  assert.strictEqual(registered.releaseId, VALID_MANIFEST_1_1.releaseId);
  otaService.registerRelease(VALID_MANIFEST_2_0);
});

test('3. Query update: 1.0.0 device receives 1.1.0 release', () => {
  const check = otaService.checkUpdate({
    productVariantId: "eh-smart-switch-3x",
    hardwareRevision: "HW_1_0",
    currentVersion: "1.0.0"
  });

  assert.strictEqual(check.updateAvailable, true);
  assert.strictEqual(check.release.version, "1.1.0"); // 2.0.0 is skipped because minFirmwareVersion is 1.1.0
});

test('4. Query update: 1.1.0 device receives 2.0.0 release', () => {
  const check = otaService.checkUpdate({
    productVariantId: "eh-smart-switch-3x",
    hardwareRevision: "HW_1_0",
    currentVersion: "1.1.0"
  });

  assert.strictEqual(check.updateAvailable, true);
  assert.strictEqual(check.release.version, "2.0.0");
});

test('5. Query update: 2.0.0 device has no pending updates', () => {
  const check = otaService.checkUpdate({
    productVariantId: "eh-smart-switch-3x",
    hardwareRevision: "HW_1_0",
    currentVersion: "2.0.0"
  });

  assert.strictEqual(check.updateAvailable, false);
  assert.strictEqual(check.release, null);
});

test('6. Hardware revision mismatch returns no updates', () => {
  const check = otaService.checkUpdate({
    productVariantId: "eh-smart-switch-3x",
    hardwareRevision: "HW_2_0", // No HW_2_0 release exists
    currentVersion: "1.0.0"
  });

  assert.strictEqual(check.updateAvailable, false);
});

console.log(`\n────────────────────────────────────────────────────────────`);
console.log(`  ALL ${passCount} PHASE 8 OTA TESTS PASSED ✅`);
console.log(`────────────────────────────────────────────────────────────\n`);
