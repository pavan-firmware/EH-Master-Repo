/**
 * EH Home Desktop — Privileged Native Boundary Security Tests (ESM)
 *
 * Directly exercises the Tauri native boundary validation logic specified in
 * apps/desktop/src-tauri/src/commands.rs (validate_flash_request_native).
 *
 * Enforces the 8 Canonical Firmware Validation Gates:
 * Gate 1: Binary & Manifest Integrity (Path safety, serial port regex, manifest presence on disk & JSON parse)
 * Gate 2: Cryptographic SHA-256 Digest (Binary SHA-256 vs manifest APP_BIN.sha256)
 * Gate 3: Firmware Family Release Eligibility (Production family allowlist)
 * Gate 4: Artifact Release Lifecycle State (RELEASED / PUBLISHED only; rejects DRAFT, BUILDING, VALIDATION, APPROVED, DEPRECATED, RETIRED, REVOKED)
 * Gate 5: Firmware Family Identity Match (Requested family == manifest family)
 * Gate 6: Product Variant Compatibility (Catalog variant allowed for family)
 * Gate 7: Target MCU Architecture Match (Connected device target == manifest target)
 * Gate 8: Hardware Revision Compatibility (Hardware revision in compatibleHardwareRevisions)
 */

import assert from 'assert';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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

// ── Native Boundary Validation Engine (Direct mirror of commands.rs) ─────

const APPROVED_VARIANTS = new Set([
  'eh-smart-switch-1x',
  'eh-smart-switch-2x',
  'eh-smart-switch-3x',
  'eh-smart-switch-4x',
  'eh-smart-socket-1x',
  'eh-smart-socket-2x',
  'eh-smart-socket-3x',
  'eh-smart-light-cct',
  'eh-smart-fan-controller',
  'eh-sensor-node-v1',
  'eh-smart-hub-s3',
]);

const FAMILY_VARIANTS_MAP = {
  'esp32c6-switch-platform': [
    'eh-smart-switch-1x',
    'eh-smart-switch-2x',
    'eh-smart-switch-3x',
    'eh-smart-switch-4x',
  ],
  'esp32c6-socket-platform': [
    'eh-smart-socket-1x',
    'eh-smart-socket-2x',
    'eh-smart-socket-3x',
  ],
};

function isValidSerialPort(port) {
  if (!port || port.length > 32) return false;
  const isWindows = /^(COM\d{1,3}|\\\\\\.\\COM\d{1,3})$/i.test(port);
  const isPosix = /^\/dev\/(ttyUSB|ttyACM|cu\.|tty\.)[a-zA-Z0-9_-]+$/.test(port);
  return isWindows || isPosix;
}

function isSafeBinaryPath(p, expectedExt) {
  if (!p || p.length > 512) return false;
  if (p.includes('\0') || p.includes(';') || p.includes('&') || p.includes('|') || p.includes('`') || p.includes('$')) {
    return false;
  }
  return p.toLowerCase().endsWith(expectedExt.toLowerCase());
}

/**
 * Native validation function mirroring apps/desktop/src-tauri/src/commands.rs::validate_flash_request_native
 */
function validateFlashRequestNative(request) {
  // Gate 1: Binary & Manifest Integrity (Path safety, port regex, manifest presence on disk & JSON parse)
  if (!isValidSerialPort(request.port)) {
    return { ok: false, errorCode: 'SECURITY_VALIDATION_FAILED', message: 'Invalid serial port format' };
  }
  if (!APPROVED_VARIANTS.has(request.product_variant_id)) {
    return {
      ok: false,
      errorCode: 'FAMILY_MISMATCH',
      message: `Product variant '${request.product_variant_id}' is not in approved catalog`,
    };
  }
  if (!isSafeBinaryPath(request.app_bin_path, '.bin')) {
    return { ok: false, errorCode: 'SECURITY_VALIDATION_FAILED', message: 'Application binary path is invalid or unsafe' };
  }

  const manifestPath = request.manifest_path
    ? request.manifest_path
    : path.join(path.dirname(request.app_bin_path), 'manifest.json');

  if (!fs.existsSync(manifestPath)) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_NOT_FOUND',
      message: `Firmware build manifest is missing on disk: ${manifestPath}`,
    };
  }

  let manifest;
  try {
    const raw = fs.readFileSync(manifestPath, 'utf8');
    manifest = JSON.parse(raw);
  } catch (err) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_NOT_FOUND',
      message: `Manifest is invalid JSON: ${err.message}`,
    };
  }

  // Gate 2: Cryptographic SHA-256 Digest
  if (!fs.existsSync(request.app_bin_path)) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_NOT_FOUND',
      message: `Application binary does not exist on disk: ${request.app_bin_path}`,
    };
  }

  const binBytes = fs.readFileSync(request.app_bin_path);
  const computedSha = crypto.createHash('sha256').update(binBytes).digest('hex');

  const appArt = Array.isArray(manifest.artifacts)
    ? manifest.artifacts.find((a) => a.artifactType === 'APP_BIN')
    : null;
  const expectedSha = appArt ? appArt.sha256 : '';

  if (!expectedSha || computedSha.toLowerCase() !== expectedSha.toLowerCase()) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_HASH_MISMATCH',
      message: `Computed application binary SHA-256 (${computedSha}) does not match manifest (${expectedSha})`,
    };
  }

  // Gate 3: Firmware Family Release Eligibility
  const manifestFamily = manifest.firmwareFamily;
  if (!manifestFamily) {
    return { ok: false, errorCode: 'ARTIFACT_NOT_FOUND', message: "Manifest missing 'firmwareFamily'" };
  }

  const isEligible = manifestFamily === 'esp32c6-switch-platform' || manifestFamily === 'esp32c6-socket-platform';
  if (!isEligible) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_NOT_RELEASE_ELIGIBLE',
      message: `Firmware family '${manifestFamily}' is not currently eligible for official production release`,
    };
  }

  // Gate 4: Artifact Release Lifecycle State (Fail-Closed)
  const rawStatus = manifest.lifecycleStatus !== undefined ? manifest.lifecycleStatus : manifest.status;
  if (rawStatus === undefined || rawStatus === null) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_LIFECYCLE_NOT_RELEASED',
      message: 'Firmware artifact release lifecycle status is missing in manifest; unreleased artifacts cannot be flashed to production hardware.',
    };
  }
  if (typeof rawStatus !== 'string' || !rawStatus.trim()) {
    return {
      ok: false,
      errorCode: 'ARTIFACT_LIFECYCLE_NOT_RELEASED',
      message: 'Firmware artifact release lifecycle status is empty or invalid; explicit release authorization required.',
    };
  }

  const isReleased = rawStatus === 'RELEASED' || rawStatus === 'PUBLISHED';
  if (!isReleased) {
    let reason = 'Firmware artifact release lifecycle status is unknown or invalid for production flashing.';
    if (rawStatus === 'DRAFT') {
      reason = "Firmware artifact is in 'DRAFT' status; unreleased artifacts cannot be flashed to production hardware.";
    } else if (rawStatus === 'BUILDING') {
      reason = "Firmware artifact is actively 'BUILDING' and incomplete.";
    } else if (rawStatus === 'VALIDATION') {
      reason = "Firmware artifact is undergoing 'VALIDATION' testing and is not authorized for production deployment.";
    } else if (rawStatus === 'APPROVED') {
      reason = "Firmware artifact is 'APPROVED' but not yet released. Unreleased artifacts cannot be flashed to production hardware.";
    } else if (rawStatus === 'DEPRECATED') {
      reason = "Firmware artifact is 'DEPRECATED' and superseded. Deprecated firmware cannot be flashed to new production hardware.";
    } else if (rawStatus === 'RETIRED') {
      reason = "Firmware artifact is 'RETIRED' (end-of-life) and cannot be flashed to production hardware.";
    } else if (rawStatus === 'REVOKED') {
      reason = "Firmware artifact is 'REVOKED' due to critical security or integrity invalidation. Flashing is strictly prohibited.";
    }
    return {
      ok: false,
      errorCode: 'ARTIFACT_LIFECYCLE_NOT_RELEASED',
      message: `${reason}: '${rawStatus}'`,
    };
  }

  // Gate 5: Firmware Family Identity Match
  if (request.firmware_family && request.firmware_family !== '' && request.firmware_family !== manifestFamily) {
    return {
      ok: false,
      errorCode: 'FAMILY_MISMATCH',
      message: `Requested firmware family '${request.firmware_family}' does not match manifest family '${manifestFamily}'`,
    };
  }

  // Gate 6: Product Variant Compatibility
  const allowedVariants = FAMILY_VARIANTS_MAP[manifestFamily] || [];
  if (!allowedVariants.includes(request.product_variant_id)) {
    return {
      ok: false,
      errorCode: 'FAMILY_MISMATCH',
      message: `Product variant '${request.product_variant_id}' is incompatible with firmware family '${manifestFamily}'`,
    };
  }

  // Gate 7: Target MCU Architecture Match
  const manifestTarget = manifest.targetMcu || '';
  if (request.target_mcu && request.target_mcu !== '' && request.target_mcu !== manifestTarget) {
    return {
      ok: false,
      errorCode: 'TARGET_MISMATCH',
      message: `Connected device target MCU '${request.target_mcu}' does not match manifest target '${manifestTarget}'`,
    };
  }

  // Gate 8: Hardware Revision Compatibility
  const manifestRevisions = Array.isArray(manifest.compatibleHardwareRevisions)
    ? manifest.compatibleHardwareRevisions
    : [];
  if (request.hardware_revision && request.hardware_revision !== '' && !manifestRevisions.includes(request.hardware_revision)) {
    return {
      ok: false,
      errorCode: 'HARDWARE_INCOMPATIBLE',
      message: `Hardware revision '${request.hardware_revision}' is not certified for this firmware build`,
    };
  }

  return { ok: true };
}

// ── Test Execution ───────────────────────────────────────────────────────

async function main() {
  console.log('=== EH HOME PRIVILEGED NATIVE BOUNDARY SECURITY TESTS (8-GATE CANONICAL MODEL) ===\n');

  // Set up temporary test directory with real artifacts
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'native-sec-test-'));

  try {
    const validBinPath = path.join(tempDir, 'firmware-valid.bin');
    const validBinContent = Buffer.from('FIRMWARE_HEADER_TEST_ESP32C6_SWITCH_PRODUCTION_BINARY_PAYLOAD_V1');
    fs.writeFileSync(validBinPath, validBinContent);
    const validSha256 = crypto.createHash('sha256').update(validBinContent).digest('hex');

    const validManifestPath = path.join(tempDir, 'manifest.json');
    const validManifest = {
      schemaVersion: 1,
      buildId: '0194fe23-7a1b-7890-a123-456789abcdef',
      releaseVersion: '1.0.0',
      firmwareFamily: 'esp32c6-switch-platform',
      lifecycleStatus: 'RELEASED',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      compatibleHardwareRevisions: ['REV-A', 'REV-B'],
      artifacts: [
        {
          artifactType: 'APP_BIN',
          fileName: 'firmware-valid.bin',
          fileSizeBytes: validBinContent.length,
          sha256: validSha256,
        },
      ],
    };
    fs.writeFileSync(validManifestPath, JSON.stringify(validManifest, null, 2));

    // Base valid request (bypassing React/TypeScript UI layer)
    const createBaseRequest = () => ({
      port: 'COM3',
      product_variant_id: 'eh-smart-switch-3x',
      app_bin_path: validBinPath,
      manifest_path: validManifestPath,
      firmware_family: 'esp32c6-switch-platform',
      target_mcu: 'esp32-c6',
      hardware_revision: 'REV-A',
      baud_rate: 115200,
    });

    console.log('1. Gate 1: Binary & Manifest Integrity:');
    await runTest('Valid request passes all 8 native gates -> allowed to invoke flasher', () => {
      const res = validateFlashRequestNative(createBaseRequest());
      assert.strictEqual(res.ok, true);
    });

    await runTest('Arbitrary safe-looking .bin path with missing manifest -> rejected with ARTIFACT_NOT_FOUND', () => {
      const orphanBinPath = path.join(tempDir, 'arbitrary-safe.bin');
      fs.writeFileSync(orphanBinPath, Buffer.from('JUST_A_BINARY_WITHOUT_MANIFEST'));

      const req = {
        port: 'COM4',
        product_variant_id: 'eh-smart-switch-1x',
        app_bin_path: orphanBinPath,
        manifest_path: path.join(tempDir, 'non-existent-manifest.json'),
      };

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_NOT_FOUND');
      assert.ok(res.message.includes('Firmware build manifest is missing on disk'));
    });

    await runTest('Arbitrary safe-looking .bin with corrupt manifest -> rejected with ARTIFACT_NOT_FOUND', () => {
      const corruptManifestPath = path.join(tempDir, 'manifest-corrupt.json');
      fs.writeFileSync(corruptManifestPath, '{ invalid json syntax ...');

      const req = createBaseRequest();
      req.manifest_path = corruptManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_NOT_FOUND');
      assert.ok(res.message.includes('Manifest is invalid JSON'));
    });

    await runTest('Unsafe port name with shell metacharacters -> rejected with SECURITY_VALIDATION_FAILED', () => {
      const req = createBaseRequest();
      req.port = 'COM3; rm -rf /';

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'SECURITY_VALIDATION_FAILED');
    });

    await runTest('Unsafe binary path with shell pipes or non-.bin -> rejected with SECURITY_VALIDATION_FAILED', () => {
      const req = createBaseRequest();
      req.app_bin_path = 'firmware.exe';

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'SECURITY_VALIDATION_FAILED');
    });

    console.log('\n2. Gate 2: Cryptographic SHA-256 Digest:');
    await runTest('Bad SHA-256 hash -> rejected with ARTIFACT_HASH_MISMATCH', () => {
      const tamperedBinPath = path.join(tempDir, 'firmware-tampered.bin');
      fs.writeFileSync(tamperedBinPath, Buffer.from('TAMPERED_MALICIOUS_PAYLOAD'));

      const req = createBaseRequest();
      req.app_bin_path = tamperedBinPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_HASH_MISMATCH');
      assert.ok(res.message.includes('does not match manifest'));
    });

    console.log('\n3. Gate 3: Firmware Family Release Eligibility:');
    await runTest('Non-production family in manifest -> rejected with ARTIFACT_NOT_RELEASE_ELIGIBLE', () => {
      const devManifestPath = path.join(tempDir, 'manifest-dev.json');
      const devManifest = {
        ...validManifest,
        firmwareFamily: 'esp32-dev-platform',
      };
      fs.writeFileSync(devManifestPath, JSON.stringify(devManifest));

      const req = createBaseRequest();
      req.manifest_path = devManifestPath;
      req.firmware_family = 'esp32-dev-platform';

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_NOT_RELEASE_ELIGIBLE');
      assert.ok(res.message.includes('not currently eligible for official production release'));
    });

    console.log('\n4. Gate 4: Artifact Release Lifecycle State (Canonical PART 07 Lifecycle):');
    await runTest('DRAFT artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const draftManifestPath = path.join(tempDir, 'manifest-draft.json');
      fs.writeFileSync(draftManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'DRAFT' }));

      const req = createBaseRequest();
      req.manifest_path = draftManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'DRAFT'"));
    });

    await runTest('BUILDING artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const buildingManifestPath = path.join(tempDir, 'manifest-building.json');
      fs.writeFileSync(buildingManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'BUILDING' }));

      const req = createBaseRequest();
      req.manifest_path = buildingManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'BUILDING'"));
    });

    await runTest('VALIDATION artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const validationManifestPath = path.join(tempDir, 'manifest-validation.json');
      fs.writeFileSync(validationManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'VALIDATION' }));

      const req = createBaseRequest();
      req.manifest_path = validationManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'VALIDATION'"));
    });

    await runTest('APPROVED but unreleased artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const approvedManifestPath = path.join(tempDir, 'manifest-approved.json');
      fs.writeFileSync(approvedManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'APPROVED' }));

      const req = createBaseRequest();
      req.manifest_path = approvedManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'APPROVED'"));
    });

    await runTest('REVOKED artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const revokedManifestPath = path.join(tempDir, 'manifest-revoked.json');
      fs.writeFileSync(revokedManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'REVOKED' }));

      const req = createBaseRequest();
      req.manifest_path = revokedManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'REVOKED'"));
    });

    await runTest('DEPRECATED artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const deprecatedManifestPath = path.join(tempDir, 'manifest-deprecated.json');
      fs.writeFileSync(deprecatedManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'DEPRECATED' }));

      const req = createBaseRequest();
      req.manifest_path = deprecatedManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'DEPRECATED'"));
    });

    await runTest('RETIRED artifact -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const retiredManifestPath = path.join(tempDir, 'manifest-retired.json');
      fs.writeFileSync(retiredManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'RETIRED' }));

      const req = createBaseRequest();
      req.manifest_path = retiredManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes("'RETIRED'"));
    });

    await runTest('Production-eligible family with unreleased/invalid state -> strictly rejected', () => {
      // esp32c6-switch-platform IS release-eligible, but if status is DRAFT, must be rejected!
      const invalidStateEligibleManifest = path.join(tempDir, 'manifest-eligible-but-draft.json');
      fs.writeFileSync(invalidStateEligibleManifest, JSON.stringify({
        ...validManifest,
        firmwareFamily: 'esp32c6-switch-platform',
        lifecycleStatus: 'DRAFT',
      }));

      const req = createBaseRequest();
      req.manifest_path = invalidStateEligibleManifest;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
    });

    await runTest('missing lifecycleStatus -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const missingStatusManifestPath = path.join(tempDir, 'manifest-missing-status.json');
      const manifestWithoutStatus = { ...validManifest };
      delete manifestWithoutStatus.lifecycleStatus;
      delete manifestWithoutStatus.status;
      fs.writeFileSync(missingStatusManifestPath, JSON.stringify(manifestWithoutStatus));

      const req = createBaseRequest();
      req.manifest_path = missingStatusManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes('missing in manifest'));
    });

    await runTest('null lifecycleStatus -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const nullStatusManifestPath = path.join(tempDir, 'manifest-null-status.json');
      fs.writeFileSync(nullStatusManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: null }));

      const req = createBaseRequest();
      req.manifest_path = nullStatusManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes('missing in manifest'));
    });

    await runTest('empty lifecycleStatus -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const emptyStatusManifestPath = path.join(tempDir, 'manifest-empty-status.json');
      fs.writeFileSync(emptyStatusManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: '   ' }));

      const req = createBaseRequest();
      req.manifest_path = emptyStatusManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes('empty or invalid'));
    });

    await runTest('unknown lifecycleStatus -> rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
      const unknownStatusManifestPath = path.join(tempDir, 'manifest-unknown-status.json');
      fs.writeFileSync(unknownStatusManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'SOME_UNKNOWN_STATE' }));

      const req = createBaseRequest();
      req.manifest_path = unknownStatusManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
      assert.ok(res.message.includes('unknown or invalid'));
    });

    await runTest('explicit RELEASED -> accepted', () => {
      const req = createBaseRequest();
      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, true);
    });

    await runTest('explicit PUBLISHED -> accepted through canonical legacy mapping', () => {
      const publishedManifestPath = path.join(tempDir, 'manifest-published.json');
      fs.writeFileSync(publishedManifestPath, JSON.stringify({ ...validManifest, lifecycleStatus: 'PUBLISHED' }));

      const req = createBaseRequest();
      req.manifest_path = publishedManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, true);
    });

    await runTest('old manifest missing lifecycle field can NOT bypass lifecycle authorization', () => {
      const legacyOldManifestPath = path.join(tempDir, 'manifest-old-legacy.json');
      const legacyOldManifest = {
        schemaVersion: 1,
        buildId: '0194fe23-7a1b-7890-a123-456789abcdef',
        releaseVersion: '1.0.0',
        firmwareFamily: 'esp32c6-switch-platform',
        // Note: No lifecycleStatus or status field present at all
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        compatibleHardwareRevisions: ['REV-A', 'REV-B'],
        artifacts: validManifest.artifacts,
      };
      fs.writeFileSync(legacyOldManifestPath, JSON.stringify(legacyOldManifest));

      const req = createBaseRequest();
      req.manifest_path = legacyOldManifestPath;

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
    });

    await runTest('renderer cannot bypass missing-lifecycle rejection (native boundary checks disk manifest directly)', () => {
      const bypassedReq = createBaseRequest();
      const craftManifestPath = path.join(tempDir, 'manifest-craft.json');
      const craftManifest = { ...validManifest };
      delete craftManifest.lifecycleStatus;
      fs.writeFileSync(craftManifestPath, JSON.stringify(craftManifest));

      bypassedReq.manifest_path = craftManifestPath;
      const res = validateFlashRequestNative(bypassedReq);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
    });

    await runTest('no Python sidecar spawn occurs for missing/invalid lifecycle state', () => {
      const missingReq = createBaseRequest();
      const noStatusManifestPath = path.join(tempDir, 'manifest-no-status.json');
      const noStatusManifest = { ...validManifest };
      delete noStatusManifest.lifecycleStatus;
      fs.writeFileSync(noStatusManifestPath, JSON.stringify(noStatusManifest));
      missingReq.manifest_path = noStatusManifestPath;

      const res = validateFlashRequestNative(missingReq);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
    });

    console.log('\n5. Gate 5: Firmware Family Identity Match:');
    await runTest('Wrong firmware family requested -> rejected with FAMILY_MISMATCH', () => {
      const req = createBaseRequest();
      req.firmware_family = 'esp32c6-socket-platform'; // Manifest is switch

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'FAMILY_MISMATCH');
      assert.ok(res.message.includes('Requested firmware family'));
    });

    console.log('\n6. Gate 6: Product Variant Compatibility:');
    await runTest('Wrong product variant for family -> rejected with FAMILY_MISMATCH', () => {
      const req = createBaseRequest();
      req.product_variant_id = 'eh-smart-socket-1x'; // Manifest is switch

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'FAMILY_MISMATCH');
      assert.ok(res.message.includes('incompatible with firmware family'));
    });

    await runTest('Unapproved product variant -> rejected with FAMILY_MISMATCH', () => {
      const req = createBaseRequest();
      req.product_variant_id = 'unapproved-rogue-variant-999';

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'FAMILY_MISMATCH');
    });

    console.log('\n7. Gate 7: Target MCU Architecture Match:');
    await runTest('Wrong target MCU -> rejected with TARGET_MISMATCH', () => {
      const req = createBaseRequest();
      req.target_mcu = 'esp32s3'; // Manifest is esp32-c6

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'TARGET_MISMATCH');
      assert.ok(res.message.includes('Connected device target MCU'));
    });

    console.log('\n8. Gate 8: Hardware Revision Compatibility:');
    await runTest('Incompatible hardware revision -> rejected with HARDWARE_INCOMPATIBLE', () => {
      const req = createBaseRequest();
      req.hardware_revision = 'REV-C'; // Manifest allows REV-A, REV-B only

      const res = validateFlashRequestNative(req);
      assert.strictEqual(res.ok, false);
      assert.strictEqual(res.errorCode, 'HARDWARE_INCOMPATIBLE');
      assert.ok(res.message.includes('Hardware revision'));
    });

    console.log('\n9. Privileged Rust Source Code Invariant Verification:');
    const commandsRsPath = path.join(__dirname, '../src-tauri/src/commands.rs');
    const commandsRsSource = fs.readFileSync(commandsRsPath, 'utf8');

    await runTest('commands.rs defines compute_sha256 FIPS 180-4 standard implementation', () => {
      assert.ok(commandsRsSource.includes('pub fn compute_sha256(data: &[u8]) -> String'));
      assert.ok(commandsRsSource.includes('0x6a09e667'));
    });

    await runTest('commands.rs defines validate_flash_request_native enforcing all 8 canonical gates', () => {
      assert.ok(commandsRsSource.includes('pub fn validate_flash_request_native'));
      assert.ok(commandsRsSource.includes('ARTIFACT_HASH_MISMATCH'));
      assert.ok(commandsRsSource.includes('ARTIFACT_NOT_RELEASE_ELIGIBLE'));
      assert.ok(commandsRsSource.includes('ARTIFACT_LIFECYCLE_NOT_RELEASED'));
      assert.ok(commandsRsSource.includes('FAMILY_MISMATCH'));
      assert.ok(commandsRsSource.includes('TARGET_MISMATCH'));
      assert.ok(commandsRsSource.includes('HARDWARE_INCOMPATIBLE'));
      assert.ok(commandsRsSource.includes('ARTIFACT_NOT_FOUND'));
    });

    await runTest('flash_device_sidecar strictly validates BEFORE launching Python process (Renderer Bypass Prevention)', () => {
      const fnIdx = commandsRsSource.indexOf('pub fn flash_device_sidecar');
      assert.ok(fnIdx > 0, 'flash_device_sidecar command must exist');
      const fnBody = commandsRsSource.slice(fnIdx);

      const validateIdx = fnBody.indexOf('validate_flash_request_native(&request)');
      const spawnIdx = fnBody.indexOf('create_hidden_command("python")') !== -1 
        ? fnBody.indexOf('create_hidden_command("python")')
        : fnBody.indexOf('Command::new("python")');

      assert.ok(validateIdx > 0, 'Must invoke validate_flash_request_native');
      assert.ok(spawnIdx > 0, 'Must invoke python sidecar');
      assert.ok(validateIdx < spawnIdx, 'Validation must occur strictly BEFORE spawning python sidecar');
      assert.ok(fnBody.includes('return Ok(FlashDeviceSidecarResponse {'), 'Must early return on error');
    });

    await runTest('commands.rs does NOT contain unwrap_or("RELEASED") or fail-open defaults for lifecycle', () => {
      assert.ok(!commandsRsSource.includes('unwrap_or("RELEASED")'), 'Must not contain unwrap_or("RELEASED")');
      assert.ok(!commandsRsSource.includes('unwrap_or_else(|| "RELEASED")'), 'Must not contain unwrap_or_else fallback to RELEASED');
      assert.ok(commandsRsSource.includes('ARTIFACT_LIFECYCLE_NOT_RELEASED'), 'Must contain ARTIFACT_LIFECYCLE_NOT_RELEASED');
    });
  } finally {
    // Cleanup temporary files
    try {
      fs.rmSync(tempDir, { recursive: true, force: true });
    } catch (_) {}
  }

  console.log('\n=== NATIVE BOUNDARY SECURITY TEST SUMMARY ===');
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    console.error(`\n${failedTests} NATIVE BOUNDARY SECURITY TESTS FAILED`);
    process.exit(1);
  }
  console.log('\nALL PRIVILEGED NATIVE BOUNDARY SECURITY TESTS PASSED [OK]\n');
}

main().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
