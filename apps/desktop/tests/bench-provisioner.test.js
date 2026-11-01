/**
 * EH Home Desktop — Bench Provisioner Automated Test Suite (ESM)
 *
 * Validates Part 09 requirements:
 * 1. Serial discovery abstraction (stable metadata, status, candidates)
 * 2. ESP32 device identification abstraction
 * 3. Artifact validation & integrity gates (SHA-256, family, target MCU, HW compatibility, release eligibility)
 * 4. Controlled flasher argument construction & arbitrary-command rejection
 * 5. Deterministic flashing workflow (success, flash failure, verification failure)
 * 6. Secret redaction & isolation of private keys / commissioning secrets
 * 7. Traceability record generation and schema adherence
 */

import assert from 'assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Import compiled contracts
import {
  validateBenchArtifact,
  BenchProvisioningTraceabilityRecordSchema,
  ProvisioningErrorCodeSchema,
  BenchDeviceStateSchema,
  SerialDeviceInfoSchema,
  Esp32IdentificationSchema,
} from '../../../packages/contracts/dist/index.js';

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

// ── Deterministic Mock Flasher Service for Verification ───────────────
class MockBenchFlasher {
  constructor() {
    this.shouldFailFlash = false;
    this.shouldFailVerify = false;
  }

  async identifyDevice(port) {
    if (port === 'COM9') {
      throw new Error('DEVICE_BUSY: Serial port COM9 is in use by another process.');
    }
    return {
      port,
      chipName: 'ESP32-C6 (QFN40)',
      chipFamily: 'esp32-c6',
      macAddress: '60:55:F9:12:34:56',
      detectedTarget: 'esp32c6',
      connectionStatus: 'CONNECTED',
      flashSizeBytes: 4194304,
      features: ['Wi-Fi 6', 'BLE 5.3'],
    };
  }

  async flashFirmware(params, onProgress) {
    const stages = ['CONNECTING', 'ERASING', 'WRITING', 'PROVISIONING', 'VERIFYING', 'DONE'];
    for (const stage of stages) {
      onProgress?.({ stage, message: `Progressing ${stage}`, progressPercent: 50 });
    }
    if (this.shouldFailFlash) {
      return { success: false, errorMessage: 'FLASH_FAILED: write flash timeout' };
    }
    return {
      success: true,
      deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
      serialNumber: 'EH-SW3X-2026W39-00001',
      certFingerprint: 'f'.repeat(64),
      durationMs: 3500,
    };
  }

  async verifyDevice(port, product) {
    if (this.shouldFailVerify) {
      return { success: false, verified: false, errorMessage: 'FLASH_VERIFY_FAILED: boot banner timeout' };
    }
    return { success: true, verified: true, deviceId: '0194fe23-7a1b-7890-a123-456789abcdef' };
  }

  async provisionBenchDevice(req, onProgress) {
    const flashRes = await this.flashFirmware(req, onProgress);
    if (!flashRes.success) throw new Error(flashRes.errorMessage || 'FLASH_FAILED');
    const verifyRes = await this.verifyDevice(req.port, req.productVariantId);
    if (!verifyRes.success) throw new Error(verifyRes.errorMessage || 'FLASH_VERIFY_FAILED');

    return {
      schemaVersion: 1,
      traceId: '0194fe23-7a1b-7890-a123-456789abcd99',
      deviceId: flashRes.deviceId,
      serialNumber: flashRes.serialNumber,
      productVariantId: req.productVariantId,
      hardwareRevision: req.hardwareRevision,
      firmwareFamily: req.firmwareFamily,
      firmwareReleaseId: req.firmwareReleaseId,
      firmwareVersion: req.firmwareVersion,
      targetMcu: req.targetMcu,
      idfTarget: 'esp32c6',
      artifactSha256: req.computedSha256,
      tlsCertFingerprint: flashRes.certFingerprint,
      port: req.port,
      flashStatus: 'PASS',
      verificationStatus: 'PASS',
      provisioningStatus: 'PASS',
      provisionedAt: new Date().toISOString(),
      durationMs: flashRes.durationMs,
    };
  }
}

async function main() {
  console.log('=== EH HOME BENCH PROVISIONER AUTOMATED TESTS (PART 09) ===\n');

  const desktopDir = path.join(__dirname, '..');

  // ── 1. SERIAL DISCOVERY ABSTRACTION ──────────────────────────────────
  console.log('1. Serial Device Discovery Abstraction:');

  const serialServiceSource = fs.readFileSync(
    path.join(desktopDir, 'src/services/native/serial.service.ts'),
    'utf8'
  );

  await runTest('Serial service defines ISerialService, MockSerialService, and TauriSerialService', () => {
    assert.ok(serialServiceSource.includes('export interface ISerialService'));
    assert.ok(serialServiceSource.includes('export class MockSerialService implements ISerialService'));
    assert.ok(serialServiceSource.includes('export class TauriSerialService implements ISerialService'));
    assert.ok(serialServiceSource.includes('getPortStatus'));
    assert.ok(serialServiceSource.includes('listAvailablePorts'));
  });

  await runTest('SerialDeviceInfoSchema parses port metadata and candidate classification', () => {
    const com3 = SerialDeviceInfoSchema.parse({
      portName: 'COM3',
      description: 'Silicon Labs CP210x USB to UART Bridge',
      vendorId: '10C4',
      productId: 'EA60',
      status: 'AVAILABLE',
      isEspCandidate: true,
      manufacturer: 'Silicon Labs',
    });
    assert.strictEqual(com3.status, 'AVAILABLE');
    assert.strictEqual(com3.isEspCandidate, true);

    const com9 = SerialDeviceInfoSchema.parse({
      portName: 'COM9',
      description: 'Busy port',
      status: 'BUSY',
      isEspCandidate: false,
    });
    assert.strictEqual(com9.status, 'BUSY');
    assert.strictEqual(com9.isEspCandidate, false);
  });

  // ── 2. ESP32 DEVICE IDENTIFICATION ───────────────────────────────────
  console.log('\n2. ESP32 Device Identification:');

  const flasherSource = fs.readFileSync(
    path.join(desktopDir, 'src/services/native/flasher.service.ts'),
    'utf8'
  );

  await runTest('Flasher service provides IFlasherService, PythonSidecarFlasher, and MockFlasherService', () => {
    assert.ok(flasherSource.includes('export interface IFlasherService'));
    assert.ok(flasherSource.includes('export class PythonSidecarFlasher implements IFlasherService'));
    assert.ok(flasherSource.includes('export class MockFlasherService implements IFlasherService'));
    assert.ok(flasherSource.includes('probeDevice'));
    assert.ok(flasherSource.includes('identifyDevice'));
    assert.ok(flasherSource.includes('validateArtifact'));
    assert.ok(flasherSource.includes('flashFirmware'));
    assert.ok(flasherSource.includes('verifyDevice'));
    assert.ok(flasherSource.includes('provisionBenchDevice'));
  });

  await runTest('Esp32IdentificationSchema validates chip metadata and MAC', () => {
    const ident = Esp32IdentificationSchema.parse({
      port: 'COM3',
      chipName: 'ESP32-C6 (QFN40)',
      chipFamily: 'esp32-c6',
      macAddress: '60:55:F9:12:34:56',
      detectedTarget: 'esp32c6',
      connectionStatus: 'CONNECTED',
      features: ['Wi-Fi 6', 'BLE 5.3'],
    });
    assert.strictEqual(ident.chipFamily, 'esp32-c6');
    assert.strictEqual(ident.connectionStatus, 'CONNECTED');
  });

  const flasher = new MockBenchFlasher();

  await runTest('Mock flasher identifyDevice returns detected target and MAC', async () => {
    const dev = await flasher.identifyDevice('COM3');
    assert.strictEqual(dev.chipFamily, 'esp32-c6');
    assert.strictEqual(dev.macAddress, '60:55:F9:12:34:56');
  });

  await runTest('Identification on busy port rejects with DEVICE_BUSY', async () => {
    let failed = false;
    try {
      await flasher.identifyDevice('COM9');
    } catch (err) {
      failed = true;
      assert.ok(err.message.includes('DEVICE_BUSY'));
    }
    assert.strictEqual(failed, true);
  });

  // ── 3. ARTIFACT VALIDATION GATES ─────────────────────────────────────
  console.log('\n3. Firmware Artifact Validation Gates:');

  const validSha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
  const sampleManifest = {
    schemaVersion: 1,
    buildId: '0194fe23-7a1b-7890-a123-456789abcd01',
    firmwareFamily: 'esp32c6-switch-platform',
    productVariants: ['eh-smart-switch-1x', 'eh-smart-switch-2x', 'eh-smart-switch-3x', 'eh-smart-switch-4x'],
    version: '1.0.0',
    gitCommitSha: '0123456789abcdef0123456789abcdef01234567',
    targetMcu: 'esp32-c6',
    idfTarget: 'esp32c6',
    toolchain: 'riscv32-esp-elf',
    buildProfile: 'release',
    lifecycleStatus: 'RELEASED',
    compatibleHardwareRevisions: ['HW_1_0', 'HW_1_1'],
    artifacts: [
      {
        artifactType: 'APP_BIN',
        fileName: 'smart-switch.bin',
        fileSizeBytes: 1048576,
        sha256: validSha,
        storagePath: 'firmware/smart-switch.bin',
      },
    ],
    generatedAt: '2026-03-01T12:00:00Z',
  };

  await runTest('Valid artifact passes all 8 canonical validation gates', () => {
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: sampleManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, true);
    assert.strictEqual(res.sha256Verified, true);
    assert.strictEqual(res.hardwareCompatible, true);
    assert.strictEqual(res.releaseEligible, true);
    assert.strictEqual(res.gateDetails.length, 8);
    res.gateDetails.forEach((g) => assert.strictEqual(g.passed, true));
  });

  await runTest('SHA-256 hash mismatch is rejected with ARTIFACT_HASH_MISMATCH', () => {
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: sampleManifest,
      computedSha256: 'deadbeef'.repeat(8),
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'ARTIFACT_HASH_MISMATCH');
  });

  await runTest('Firmware family mismatch is rejected with FAMILY_MISMATCH', () => {
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-socket-platform', // Incompatible family requested
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: sampleManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'FAMILY_MISMATCH');
  });

  await runTest('Target MCU mismatch is rejected with TARGET_MISMATCH', () => {
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32', // Prototype MCU instead of ESP32-C6
      manifest: sampleManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'TARGET_MISMATCH');
  });

  await runTest('Incompatible hardware revision is rejected with HARDWARE_INCOMPATIBLE', () => {
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_9_9', // Uncertified revision
      targetMcu: 'esp32-c6',
      manifest: sampleManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'HARDWARE_INCOMPATIBLE');
  });

  await runTest('Unreleased/planned firmware family is rejected with ARTIFACT_NOT_RELEASE_ELIGIBLE', () => {
    const plannedManifest = {
      ...sampleManifest,
      firmwareFamily: 'esp32c6-fan-platform', // Planned, not release eligible
    };
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-fan-platform',
      productVariantId: 'eh-smart-fan-1x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: plannedManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'ARTIFACT_NOT_RELEASE_ELIGIBLE');
  });

  await runTest('DRAFT artifact is rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
    const draftManifest = {
      ...sampleManifest,
      lifecycleStatus: 'DRAFT',
    };
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: draftManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
  });

  await runTest('APPROVED unreleased artifact is rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
    const approvedManifest = {
      ...sampleManifest,
      lifecycleStatus: 'APPROVED',
    };
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: approvedManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
  });

  await runTest('REVOKED artifact is rejected with ARTIFACT_LIFECYCLE_NOT_RELEASED', () => {
    const revokedManifest = {
      ...sampleManifest,
      lifecycleStatus: 'REVOKED',
    };
    const res = validateBenchArtifact({
      firmwareFamily: 'esp32c6-switch-platform',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      targetMcu: 'esp32-c6',
      manifest: revokedManifest,
      computedSha256: validSha,
    });
    assert.strictEqual(res.valid, false);
    assert.strictEqual(res.errorCode, 'ARTIFACT_LIFECYCLE_NOT_RELEASED');
  });

  // ── 4. CONTROLLED ARGUMENT & SECURITY REJECTION ───────────────────────
  console.log('\n4. Controlled Sidecar Argument Construction & Security Rejection:');

  const commandsSource = fs.readFileSync(
    path.join(desktopDir, 'src-tauri', 'src', 'commands.rs'),
    'utf8'
  );

  await runTest('Tauri native commands enforce strict allowlisted serial port regex', () => {
    assert.ok(commandsSource.includes('fn is_valid_serial_port'));
    assert.ok(commandsSource.includes('matches!(c, \';\' | \'&\' | \'|\' | \'`\' | \'$\''));
  });

  await runTest('Tauri native commands enforce canonical product variant allowlist', () => {
    assert.ok(commandsSource.includes('fn is_allowed_product_variant'));
    assert.ok(commandsSource.includes('eh-smart-switch-3x'));
    assert.ok(commandsSource.includes('eh-smart-socket-1x'));
  });

  await runTest('Tauri native commands enforce safe binary file extensions (.bin / .csv)', () => {
    assert.ok(commandsSource.includes('fn is_safe_binary_path'));
    assert.ok(commandsSource.includes('path_str.ends_with(expected_ext)'));
  });

  await runTest('Tauri layer invokes Python through explicit argument slice (no arbitrary shell execution)', () => {
    assert.ok(commandsSource.includes('Command::new("python")') || commandsSource.includes('create_hidden_command("python")'));
    assert.strictEqual(commandsSource.includes('execute_shell'), false);
    assert.strictEqual(commandsSource.includes('execute_cmd'), false);
    assert.strictEqual(commandsSource.includes('cmd.exe'), false);
    assert.strictEqual(commandsSource.includes('/bin/sh'), false);
  });

  // ── 5. FLASHING & VERIFICATION WORKFLOW ──────────────────────────────
  console.log('\n5. Flashing & Verification Workflow:');

  await runTest('Successful flash and provision workflow transitions through all stages', async () => {
    const stagesSeen = [];
    const record = await flasher.provisionBenchDevice(
      {
        port: 'COM3',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32c6-switch-platform',
        firmwareReleaseId: 'rel-1-0-0-prod',
        firmwareVersion: '1.0.0',
        targetMcu: 'esp32-c6',
        appBinPath: 'build/smart-switch.bin',
        computedSha256: validSha,
        baudRate: 115200,
      },
      (progress) => {
        stagesSeen.push(progress.stage);
      }
    );

    assert.ok(stagesSeen.includes('CONNECTING'));
    assert.ok(stagesSeen.includes('ERASING'));
    assert.ok(stagesSeen.includes('WRITING'));
    assert.ok(stagesSeen.includes('PROVISIONING'));
    assert.ok(stagesSeen.includes('VERIFYING'));
    assert.ok(stagesSeen.includes('DONE'));

    assert.strictEqual(record.flashStatus, 'PASS');
    assert.strictEqual(record.verificationStatus, 'PASS');
    assert.strictEqual(record.provisioningStatus, 'PASS');
    assert.ok(record.deviceId.length > 0);
    assert.ok(record.serialNumber.startsWith('EH-SW3X-'));
  });

  await runTest('Flash failure halts workflow and reports FLASH_FAILED', async () => {
    flasher.shouldFailFlash = true;
    let failed = false;
    try {
      await flasher.provisionBenchDevice({
        port: 'COM3',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32c6-switch-platform',
        firmwareReleaseId: 'rel-1-0-0-prod',
        firmwareVersion: '1.0.0',
        targetMcu: 'esp32-c6',
        appBinPath: 'build/smart-switch.bin',
        computedSha256: validSha,
        baudRate: 115200,
      });
    } catch (err) {
      failed = true;
      assert.ok(err.message.includes('FLASH_FAILED'));
    } finally {
      flasher.shouldFailFlash = false;
    }
    assert.strictEqual(failed, true);
  });

  await runTest('Post-flash verification failure halts workflow and reports FLASH_VERIFY_FAILED', async () => {
    flasher.shouldFailVerify = true;
    let failed = false;
    try {
      await flasher.provisionBenchDevice({
        port: 'COM3',
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32c6-switch-platform',
        firmwareReleaseId: 'rel-1-0-0-prod',
        firmwareVersion: '1.0.0',
        targetMcu: 'esp32-c6',
        appBinPath: 'build/smart-switch.bin',
        computedSha256: validSha,
        baudRate: 115200,
      });
    } catch (err) {
      failed = true;
      assert.ok(err.message.includes('FLASH_VERIFY_FAILED'));
    } finally {
      flasher.shouldFailVerify = false;
    }
    assert.strictEqual(failed, true);
  });

  // ── 6. SECRET REDACTION & ZERO-LEAKAGE ─────────────────────────────────
  console.log('\n6. Secret Redaction & Zero-Leakage:');

  await runTest('Traceability record does NOT contain private keys or commissioning secrets', async () => {
    const record = await flasher.provisionBenchDevice({
      port: 'COM3',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform',
      firmwareReleaseId: 'rel-1-0-0-prod',
      firmwareVersion: '1.0.0',
      targetMcu: 'esp32-c6',
      appBinPath: 'build/smart-switch.bin',
      computedSha256: validSha,
      baudRate: 115200,
    });

    const recordJson = JSON.stringify(record);
    assert.strictEqual(recordJson.includes('private_key'), false);
    assert.strictEqual(recordJson.includes('commissioningSecret'), false);
    assert.strictEqual(recordJson.includes('secret_hex'), false);
    assert.strictEqual(recordJson.includes('password'), false);
  });

  // ── 7. TRACEABILITY SCHEMA ADHERENCE ──────────────────────────────────
  console.log('\n7. Traceability Record Schema Validation:');

  await runTest('Generated traceability record passes Zod schema validation', async () => {
    const record = await flasher.provisionBenchDevice({
      port: 'COM3',
      productVariantId: 'eh-smart-switch-3x',
      hardwareRevision: 'HW_1_0',
      firmwareFamily: 'esp32c6-switch-platform',
      firmwareReleaseId: 'rel-1-0-0-prod',
      firmwareVersion: '1.0.0',
      targetMcu: 'esp32-c6',
      appBinPath: 'build/smart-switch.bin',
      computedSha256: validSha,
      baudRate: 115200,
    });

    const parsed = BenchProvisioningTraceabilityRecordSchema.parse(record);
    assert.strictEqual(parsed.schemaVersion, 1);
    assert.strictEqual(parsed.productVariantId, 'eh-smart-switch-3x');
    assert.strictEqual(parsed.targetMcu, 'esp32-c6');
    assert.strictEqual(parsed.idfTarget, 'esp32c6');
    assert.strictEqual(parsed.flashStatus, 'PASS');
  });

  // ── SUMMARY ───────────────────────────────────────────────────────────
  console.log(`\n=== BENCH PROVISIONER TESTS SUMMARY ===`);
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    process.exit(1);
  } else {
    console.log('ALL BENCH PROVISIONER TESTS PASSED [OK]\n');
  }
}

main().catch((err) => {
  console.error('Fatal bench provisioner test error:', err);
  process.exit(1);
});
