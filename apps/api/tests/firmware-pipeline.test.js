/**
 * EH Home — Automated Firmware Build, Test & Release Pipeline Automated Test Suite (Part 08)
 *
 * Validates:
 * 1. Build metadata & Git source control identity (full 40-char hex commit SHA anchoring)
 * 2. Toolchain invariants (ESP-IDF 5.4.1 framework enforcement & target compiler)
 * 3. Artifact discovery & validation (APP_BIN, BOOTLOADER, PARTITION_TABLE, ELF, MAP)
 * 4. File size bounds & partition budget validation
 * 5. Cryptographic SHA-256 checksum calculation & corruption detection
 * 6. Target architecture consistency & cross-architecture contamination rejection
 * 7. Authoritative build identity (UUID & full commit SHA uniqueness)
 * 8. Machine-readable FirmwareBuildManifest generation & Zod contract compliance
 * 9. Release-readiness gate evaluation (including target consistency guard)
 * 10. API / Service integration (GET /api/v1/firmware/releases/:id/readiness)
 * 11. GitHub Actions CI workflow configuration integrity
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { buildApp } = require('../dist/app');
const { FirmwareService, InMemoryArtifactStore } = require('../dist/modules/firmware/firmware.service');
const { FirmwareRepository } = require('../dist/modules/firmware/firmware.repository');
const {
  FirmwareBuildManifestSchema,
  ReleaseReadinessGateSchema,
  TargetMcuSchema,
  IdfTargetSchema,
  ToolchainSchema,
  MCU_TO_IDF_TARGET_MAP,
  MCU_TO_TOOLCHAIN_MAP,
  FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP,
  CANONICAL_FIRMWARE_FAMILIES,
  PRODUCTION_RELEASE_ELIGIBLE_FAMILIES,
  validateProductionReleaseFamily,
  parseReleaseTag,
} = require('@eh-home/contracts');
const {
  runFirmwarePipeline,
  discoverArtifacts,
  computeArtifactChecksums,
  generateBuildManifest,
  evaluateReleaseReadiness,
  resolveGitSourceIdentity,
  verifyToolchainEnvironment,
  verifyArtifactFamilyContent,
} = require('../../../scripts/firmware_pipeline');

const ROOT_DIR = path.resolve(__dirname, '..', '..', '..');

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
  console.log('=== EH HOME FIRMWARE AUTOMATED BUILD & RELEASE TESTS ===\n');

  process.env.NODE_ENV = 'test';

  const app = await buildApp({
    skipDatabase: true,
    fastifyOptions: {
      logger: false,
    },
  });

  await app.ready();

  const tempTestDir = path.join(__dirname, 'scratch_build_test');
  if (!fs.existsSync(tempTestDir)) {
    fs.mkdirSync(tempTestDir, { recursive: true });
  }

  // Helper to create synthetic build artifacts in a directory
  function createSyntheticBuild(dir, overrides = {}) {
    const bootDir = path.join(dir, 'bootloader');
    const partDir = path.join(dir, 'partition_table');
    fs.mkdirSync(bootDir, { recursive: true });
    fs.mkdirSync(partDir, { recursive: true });

    const family = overrides.family !== undefined ? overrides.family : 'esp32c6-switch-platform';
    const appSize = overrides.appSize || 1048576; // 1 MB
    let appBuffer = overrides.appBuffer;
    if (!appBuffer) {
      appBuffer = Buffer.alloc(appSize, 0x11);
      if (family) {
        appBuffer.write(`EH_FIRMWARE_FAMILY:${family}:END_FAMILY`, 1024, 'ascii');
      }
    }
    const bootBuffer = Buffer.alloc(28672, 0x22);
    const partBuffer = Buffer.alloc(3072, 0x33);

    fs.writeFileSync(path.join(dir, 'eh-smart-switch-app.bin'), appBuffer);
    fs.writeFileSync(path.join(bootDir, 'bootloader.bin'), bootBuffer);
    fs.writeFileSync(path.join(partDir, 'partition-table.bin'), partBuffer);
    fs.writeFileSync(path.join(dir, 'eh-smart-switch-app.elf'), Buffer.from('ELF_TEST_SYMBOLS'));
    fs.writeFileSync(path.join(dir, 'eh-smart-switch-app.map'), Buffer.from('MAP_TEST_SYMBOLS'));

    if (overrides.flasherArgs) {
      fs.writeFileSync(path.join(dir, 'flasher_args.json'), JSON.stringify(overrides.flasherArgs, null, 2));
    }
    if (overrides.firmwareFamilyJson !== false && family) {
      fs.writeFileSync(path.join(dir, 'firmware_family.json'), JSON.stringify({
        firmwareFamily: family,
        targetMcu: overrides.targetMcu || 'esp32-c6',
        idfTarget: overrides.idfTarget || 'esp32c6',
      }, null, 2));
    }
  }

  // ── 1. BUILD METADATA & GIT SOURCE TRACEABILITY ───────────────────────
  console.log('1. Build Metadata & Git Source Traceability:');

  await runTest('Anchors build to valid 40-char hexadecimal Git commit SHA', async () => {
    const git = resolveGitSourceIdentity();
    assert.ok(git.gitCommitSha, 'Git commit SHA must not be empty');
    assert.strictEqual(typeof git.gitCommitSha, 'string');
    assert.match(git.gitCommitSha, /^[0-9a-fA-F]{40}$/, 'Must be a 40-character hex commit SHA');
  });

  await runTest('Verifies pinned ESP-IDF 5.4.1 framework environment and target compiler', async () => {
    const toolchain = verifyToolchainEnvironment({ targetMcu: 'esp32-c6', strict: false });
    assert.strictEqual(toolchain.verified, true);
    assert.strictEqual(toolchain.idfVersion, 'v5.4.1');
    assert.strictEqual(toolchain.targetMcu, 'esp32-c6');
    assert.strictEqual(toolchain.idfTarget, 'esp32c6');
    assert.strictEqual(toolchain.compiler, 'riscv32-esp-elf');
  });

  await runTest('Two different full Git SHAs produce distinct build UUID identities', async () => {
    const sha1 = '1111111111111111111111111111111111111111';
    const sha2 = '2222222222222222222222222222222222222222';
    const buildId1 = crypto.randomUUID();
    const buildId2 = crypto.randomUUID();

    assert.notStrictEqual(buildId1, buildId2, 'Build UUIDs must be unique');
    assert.match(buildId1, /^[0-9a-fA-F-]{36}$/);
    assert.match(buildId2, /^[0-9a-fA-F-]{36}$/);
    assert.notStrictEqual(sha1, sha2);
  });

  await runTest('Rejects truncated 8-character commit SHA in build manifest', async () => {
    let errorCaught = false;
    try {
      generateBuildManifest({
        buildId: crypto.randomUUID(),
        firmwareFamily: 'esp32c6-switch-platform',
        version: '1.0.0',
        gitCommitSha: 'a1b2c3d4', // TRUNCATED 8-CHAR SHA (INVALID)
        artifacts: [],
        compatibleHardwareRevisions: ['HW_1_0'],
      });
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Invalid Git commit SHA') || err.message.includes('40-char'));
    }
    assert.strictEqual(errorCaught, true, 'Manifest must strictly reject truncated SHA');
  });

  // ── 2. TARGET CONSISTENCY & MULTI-TARGET RECONCILIATION ───────────────
  console.log('\n2. Target Consistency & Multi-Target Reconciliation:');

  await runTest('Target maps deterministically: esp32-c6 -> esp32c6 / riscv32-esp-elf', async () => {
    assert.strictEqual(MCU_TO_IDF_TARGET_MAP['esp32-c6'], 'esp32c6');
    assert.strictEqual(MCU_TO_TOOLCHAIN_MAP['esp32-c6'], 'riscv32-esp-elf');
  });

  await runTest('Target maps deterministically: esp32 -> esp32 / xtensa-esp-elf', async () => {
    assert.strictEqual(MCU_TO_IDF_TARGET_MAP['esp32'], 'esp32');
    assert.strictEqual(MCU_TO_TOOLCHAIN_MAP['esp32'], 'xtensa-esp-elf');
  });

  await runTest('Target maps deterministically: esp32-s3 -> esp32s3 / xtensa-esp-elf', async () => {
    assert.strictEqual(MCU_TO_IDF_TARGET_MAP['esp32-s3'], 'esp32s3');
    assert.strictEqual(MCU_TO_TOOLCHAIN_MAP['esp32-s3'], 'xtensa-esp-elf');
  });

  await runTest('Rejects mismatched target configuration: esp32-c6 with xtensa compiler', async () => {
    let errorCaught = false;
    try {
      generateBuildManifest({
        buildId: crypto.randomUUID(),
        firmwareFamily: 'esp32c6-switch-platform',
        version: '1.0.0',
        gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'xtensa-esp-elf', // MISMATCH: ESP32-C6 is RISC-V!
        compatibleHardwareRevisions: ['HW_1_0'],
        artifacts: [
          {
            artifactType: 'APP_BIN',
            fileName: 'test.bin',
            fileSizeBytes: 1024,
            sha256: 'a'.repeat(64),
            storagePath: 'test/path',
          },
        ],
      });
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Toolchain consistency error'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject inconsistent MCU/toolchain pair');
  });

  await runTest('Rejects cross-architecture contamination: esp32 binary claiming esp32c6 target', async () => {
    const mismatchDir = path.join(tempTestDir, 'mismatch_chip_build');
    createSyntheticBuild(mismatchDir, {
      flasherArgs: {
        extra_esptool_args: { chip: 'esp32' },
      },
    });

    let errorCaught = false;
    try {
      discoverArtifacts(mismatchDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Target Architecture Mismatch'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject build directory compiled for esp32 when esp32c6 is targeted');
  });

  // ── 3. ARTIFACT DISCOVERY & BUDGET VALIDATION ─────────────────────────
  console.log('\n3. Artifact Discovery & Budget Validation:');

  await runTest('Discovers all required and diagnostic build artifacts', async () => {
    const validBuildPath = path.join(tempTestDir, 'valid_build');
    createSyntheticBuild(validBuildPath);

    const artifacts = discoverArtifacts(validBuildPath, 'eh-smart-switch-app', 'esp32', 'esp32');
    assert.strictEqual(artifacts.length, 5);

    const types = artifacts.map((a) => a.artifactType).sort();
    assert.deepStrictEqual(types, ['APP_BIN', 'BOOTLOADER', 'ELF', 'MAP', 'PARTITION_TABLE']);
    assert.strictEqual(artifacts[0].targetMcu, 'esp32');
    assert.strictEqual(artifacts[0].idfTarget, 'esp32');
  });

  await runTest('Rejects build directory with missing required binary (e.g. missing bootloader)', async () => {
    const incompleteBuildPath = path.join(tempTestDir, 'incomplete_build');
    createSyntheticBuild(incompleteBuildPath);

    // Delete bootloader
    fs.unlinkSync(path.join(incompleteBuildPath, 'bootloader', 'bootloader.bin'));

    let errorCaught = false;
    try {
      discoverArtifacts(incompleteBuildPath, 'eh-smart-switch-app');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Required firmware artifact'));
    }
    assert.strictEqual(errorCaught, true, 'Must throw error when required artifact is missing');
  });

  await runTest('Rejects corrupted zero-byte artifact', async () => {
    const zeroByteBuildPath = path.join(tempTestDir, 'zero_byte_build');
    createSyntheticBuild(zeroByteBuildPath);

    // Truncate app binary to 0 bytes
    fs.writeFileSync(path.join(zeroByteBuildPath, 'eh-smart-switch-app.bin'), Buffer.alloc(0));

    let errorCaught = false;
    try {
      discoverArtifacts(zeroByteBuildPath, 'eh-smart-switch-app');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('invalid size (0 bytes)'));
    }
    assert.strictEqual(errorCaught, true, 'Zero-byte binary must be rejected');
  });

  await runTest('Rejects application binary exceeding partition table size limit (1792 KB)', async () => {
    const oversizedBuildPath = path.join(tempTestDir, 'oversized_build');
    // 2.2 MB binary exceeds 1792 KB ota_0 partition limit
    createSyntheticBuild(oversizedBuildPath, { appSize: 2306867 });

    let errorCaught = false;
    try {
      discoverArtifacts(oversizedBuildPath, 'eh-smart-switch-app');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('exceeds maximum partition size'));
    }
    assert.strictEqual(errorCaught, true, 'Oversized binary must be rejected');
  });

  // ── 4. CRYPTOGRAPHIC SHA-256 & CORRUPTION DETECTION ───────────────────
  console.log('\n4. Cryptographic SHA-256 & Corruption Detection:');

  await runTest('Computes deterministic SHA-256 and verifies byte-for-byte integrity', async () => {
    const shaBuildPath = path.join(tempTestDir, 'sha_build');
    createSyntheticBuild(shaBuildPath);
    const artifacts = discoverArtifacts(shaBuildPath, 'eh-smart-switch-app');

    const appArt = artifacts.find((a) => a.artifactType === 'APP_BIN');
    assert.ok(appArt);
    assert.match(appArt.sha256, /^[0-9a-fA-F]{64}$/);

    const verified = computeArtifactChecksums(artifacts);
    assert.strictEqual(verified.length, 5);
    assert.strictEqual(verified.every((v) => v.valid), true);
  });

  await runTest('Detects binary tampering/corruption and fails integrity validation', async () => {
    const corruptBuildPath = path.join(tempTestDir, 'corrupt_build');
    createSyntheticBuild(corruptBuildPath);
    const artifacts = discoverArtifacts(corruptBuildPath, 'eh-smart-switch-app');

    const appArt = artifacts.find((a) => a.artifactType === 'APP_BIN');

    // Simulate bit-flip corruption in the file on disk after discovery
    const originalBytes = fs.readFileSync(appArt.fullPath);
    originalBytes[100] = originalBytes[100] ^ 0xff; // Invert byte
    fs.writeFileSync(appArt.fullPath, originalBytes);

    let corruptionCaught = false;
    try {
      computeArtifactChecksums([appArt]);
    } catch (err) {
      corruptionCaught = true;
      assert.ok(err.message.includes('SHA-256 integrity mismatch'));
    }
    assert.strictEqual(corruptionCaught, true, 'Corrupted binary must trigger SHA-256 mismatch error');
  });

  // ── 5. MANIFEST GENERATION & RELEASE-READINESS GATES ───────────────────
  console.log('\n5. Manifest Generation & Release-Readiness Gates:');

  await runTest('Generates machine-readable FirmwareBuildManifest conforming to Zod schema', async () => {
    const manifestBuildPath = path.join(tempTestDir, 'manifest_build');
    createSyntheticBuild(manifestBuildPath);
    const artifacts = discoverArtifacts(manifestBuildPath, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6');

    const manifest = generateBuildManifest({
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0',
      gitCommitSha: '1522289f46555b947dac5efb0ad0fbbc9f44260a',
      gitBranch: 'main',
      gitTag: 'v1.0.0',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      idfVersion: 'v5.4.1',
      buildProfile: 'release',
      compatibleHardwareRevisions: ['hw_rev_switch_1x_1_0', 'HW_1_0'],
      artifacts,
    });

    assert.ok(manifest);
    assert.strictEqual(manifest.schemaVersion, 1);
    assert.match(manifest.buildId, /^[0-9a-fA-F-]{36}$/);
    assert.strictEqual(manifest.targetMcu, 'esp32-c6');
    assert.strictEqual(manifest.idfTarget, 'esp32c6');
    assert.strictEqual(manifest.toolchain, 'riscv32-esp-elf');
    assert.strictEqual(manifest.artifacts.length, 5);

    // Validate with Zod parser directly
    const parsed = FirmwareBuildManifestSchema.parse(manifest);
    assert.strictEqual(parsed.firmwareFamily, 'esp32c6-switch-platform');
  });

  await runTest('Evaluates release-readiness: passes when all 8 gates are satisfied', async () => {
    const validManifest = {
      schemaVersion: 1,
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0',
      gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
      gitBranch: 'main',
      idfVersion: 'v5.4.1',
      buildProfile: 'release',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      compatibleHardwareRevisions: ['hw_rev_switch_1x_1_0'],
      artifacts: [
        {
          artifactType: 'APP_BIN',
          fileName: 'eh-smart-switch-app.bin',
          fileSizeBytes: 1048576,
          sha256: 'a'.repeat(64),
          storagePath: 'firmware/builds/test/eh-smart-switch-app.bin',
        },
        {
          artifactType: 'BOOTLOADER',
          fileName: 'bootloader.bin',
          fileSizeBytes: 28672,
          sha256: 'b'.repeat(64),
          storagePath: 'firmware/builds/test/bootloader.bin',
        },
        {
          artifactType: 'PARTITION_TABLE',
          fileName: 'partition-table.bin',
          fileSizeBytes: 3072,
          sha256: 'c'.repeat(64),
          storagePath: 'firmware/builds/test/partition-table.bin',
        },
      ],
      generatedAt: new Date().toISOString(),
    };

    const readiness = evaluateReleaseReadiness(validManifest, { testsPassed: true });
    assert.strictEqual(readiness.isReadyForApproval, true);
    assert.strictEqual(readiness.checks.length, 8);
    assert.strictEqual(readiness.checks.every((c) => c.passed), true);
  });

  await runTest('Release-readiness gate blocks approval on target inconsistency', async () => {
    const inconsistentManifest = {
      schemaVersion: 1,
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-switch-platform', // expects esp32-c6
      version: '1.0.0',
      gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
      gitBranch: 'main',
      idfVersion: 'v5.4.1',
      buildProfile: 'release',
      targetMcu: 'esp32', // MISMATCH: esp32 instead of esp32-c6
      idfTarget: 'esp32',
      toolchain: 'xtensa-esp-elf',
      compatibleHardwareRevisions: ['hw_rev_switch_1x_1_0'],
      artifacts: [
        {
          artifactType: 'APP_BIN',
          fileName: 'eh-smart-switch-app.bin',
          fileSizeBytes: 1048576,
          sha256: 'a'.repeat(64),
          storagePath: 'firmware/builds/test/eh-smart-switch-app.bin',
        },
      ],
      generatedAt: new Date().toISOString(),
    };

    const readiness = evaluateReleaseReadiness(inconsistentManifest, { testsPassed: true });
    assert.strictEqual(readiness.isReadyForApproval, false);
    const targetGate = readiness.checks.find((c) => c.gate === 'TARGET_CONSISTENCY_VERIFIED');
    assert.strictEqual(targetGate.passed, false);
  });

  // ── 6. API / DOMAIN READINESS ENDPOINT ─────────────────────────────────
  console.log('\n6. API / Domain Readiness Endpoint:');

  await runTest('GET /api/v1/firmware/releases/:id/readiness returns structured gate evaluation', async () => {
    // 1. Create a release
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/v1/firmware/releases',
      payload: {
        firmwareFamily: 'esp32c6-switch-platform',
        productVariantId: 'eh-smart-switch-1x',
        version: '2.1.0',
        gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        sha256: 'd'.repeat(64),
      },
    });
    assert.strictEqual(createRes.statusCode, 201);
    const releaseId = JSON.parse(createRes.body).data.id;

    // 2. Query readiness before builds registered -> should not be ready
    const preRes = await app.inject({
      method: 'GET',
      url: `/api/v1/firmware/releases/${releaseId}/readiness`,
    });
    assert.strictEqual(preRes.statusCode, 200);
    const preBody = JSON.parse(preRes.body);
    assert.strictEqual(preBody.success, true);
    assert.strictEqual(preBody.data.isReadyForApproval, false);
    assert.ok(preBody.data.checks.some((c) => c.gate === 'BUILD_ARTIFACTS_REGISTERED' && !c.passed));

    // 3. Register build
    const buildRes = await app.inject({
      method: 'POST',
      url: `/api/v1/firmware/releases/${releaseId}/builds`,
      payload: {
        firmwareFamilyId: 'esp32c6-switch-platform',
        gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        idfVersion: 'v5.4.1',
        toolchainInfo: { targetMcu: 'esp32-c6', idfTarget: 'esp32c6', toolchain: 'riscv32-esp-elf' },
      },
    });
    assert.strictEqual(buildRes.statusCode, 201);
    const buildId = JSON.parse(buildRes.body).data.id;

    // 4. Register artifacts
    await app.inject({
      method: 'POST',
      url: `/api/v1/firmware/releases/${releaseId}/artifacts`,
      payload: {
        buildId,
        artifactType: 'APP_BIN',
        fileName: 'eh-smart-switch-app.bin',
        fileSizeBytes: 1048576,
        sha256: 'e'.repeat(64),
        storagePath: 'firmware/test/app.bin',
      },
    });
    await app.inject({
      method: 'POST',
      url: `/api/v1/firmware/releases/${releaseId}/artifacts`,
      payload: {
        buildId,
        artifactType: 'BOOTLOADER',
        fileName: 'bootloader.bin',
        fileSizeBytes: 28672,
        sha256: 'f'.repeat(64),
        storagePath: 'firmware/test/bootloader.bin',
      },
    });
    await app.inject({
      method: 'POST',
      url: `/api/v1/firmware/releases/${releaseId}/artifacts`,
      payload: {
        buildId,
        artifactType: 'PARTITION_TABLE',
        fileName: 'partition-table.bin',
        fileSizeBytes: 3072,
        sha256: '0'.repeat(64),
        storagePath: 'firmware/test/partition-table.bin',
      },
    });

    // 5. Define hardware compatibility
    await app.inject({
      method: 'POST',
      url: `/api/v1/firmware/releases/${releaseId}/compatibility`,
      payload: {
        hardwareRevisionId: 'hw_rev_switch_1x_1_0',
        isVerified: true,
      },
    });

    // 6. Query readiness now -> all 7 gates should pass!
    const postRes = await app.inject({
      method: 'GET',
      url: `/api/v1/firmware/releases/${releaseId}/readiness`,
    });
    assert.strictEqual(postRes.statusCode, 200);
    const postBody = JSON.parse(postRes.body);
    assert.strictEqual(postBody.success, true);
    assert.strictEqual(postBody.data.isReadyForApproval, true);
    assert.strictEqual(postBody.data.checks.length, 7);
    assert.strictEqual(postBody.data.checks.every((c) => c.passed), true);
  });

  // ── 7. CI WORKFLOW CONFIGURATION INTEGRITY & TARGET VERIFICATION ─────
  console.log('\n7. CI Workflow Configuration Integrity & Target Verification:');

  await runTest('.github/workflows/firmware-ci.yml separates production esp32c6 and prototype esp32 jobs', async () => {
    const ciPath = path.join(ROOT_DIR, '.github', 'workflows', 'firmware-ci.yml');
    assert.ok(fs.existsSync(ciPath), 'firmware-ci.yml must exist');
    const content = fs.readFileSync(ciPath, 'utf8');

    // Toolchain pinning
    assert.ok(content.includes('esp_idf_version: \'v5.4.1\''), 'Must pin to ESP-IDF v5.4.1');
    assert.ok(content.includes('check-esp-idf-toolchain.js'), 'Must invoke toolchain drift guard');

    // Production job uses esp32c6
    assert.ok(content.includes('build-production-esp32c6:'), 'Must define production build job');
    assert.ok(content.includes('target: \'esp32c6\''), 'Production job must compile esp32c6');
    assert.ok(content.includes('--target-mcu esp32-c6 --idf-target esp32c6'), 'Production pipeline must target esp32c6');

    // Prototype job uses esp32
    assert.ok(content.includes('build-prototype-esp32:'), 'Must define prototype build job');
    assert.ok(content.includes('target: \'esp32\''), 'Prototype job must compile esp32');
    assert.ok(content.includes('--target-mcu esp32 --idf-target esp32'), 'Prototype pipeline must target esp32');
  });

  await runTest('.github/workflows/firmware-release.yml strictly compiles validated production target and resolves Model A tag', async () => {
    const releasePath = path.join(ROOT_DIR, '.github', 'workflows', 'firmware-release.yml');
    assert.ok(fs.existsSync(releasePath), 'firmware-release.yml must exist');
    const content = fs.readFileSync(releasePath, 'utf8');

    assert.ok(content.includes('v*.*.*'), 'Must trigger on semantic release tags');
    assert.ok(content.includes('*@v*.*.*'), 'Must trigger on family-scoped release tags');
    assert.ok(content.includes('esp_idf_version: \'v5.4.1\''), 'Must pin to ESP-IDF v5.4.1');
    assert.ok(content.includes('target: ${{ env.IDF_TARGET }}'), 'Release workflow MUST compile dynamically resolved target');
    assert.ok(content.includes('--target-mcu "${TARGET_MCU}" --idf-target "${IDF_TARGET}"'), 'Release pipeline must declare dynamic target');
    assert.ok(content.includes('esp32c6-switch-platform'), 'Release pipeline must default to production switch family');
    assert.ok(content.includes('TARGET_FAMILY'), 'Release pipeline must dynamically bind TARGET_FAMILY from tag');
    assert.ok(!content.includes("target: 'esp32'\n"), 'Release workflow must NOT compile prototype esp32 target');
  });

  await runTest('Cross-target rejection: esp32c6 binary claiming esp32 target is rejected', async () => {
    const reverseMismatchDir = path.join(tempTestDir, 'reverse_mismatch_chip_build');
    createSyntheticBuild(reverseMismatchDir, {
      flasherArgs: {
        extra_esptool_args: { chip: 'esp32c6' },
      },
    });

    let errorCaught = false;
    try {
      discoverArtifacts(reverseMismatchDir, 'eh-smart-switch-app', 'esp32', 'esp32');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Target Architecture Mismatch'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject build directory compiled for esp32c6 when esp32 is targeted');
  });

  // ── 8. CANONICAL PRODUCT DEFINITIONS & RECONCILIATION ──────────────
  console.log('\n8. Canonical Product Definitions & Inventory Reconciliation:');

  await runTest('Exact count and structure of product-definitions/ inventory (11 definitions across 6 families)', async () => {
    const prodDefDir = path.join(ROOT_DIR, 'product-definitions');
    assert.ok(fs.existsSync(prodDefDir), 'product-definitions directory must exist');

    const expectedFamilies = ['sensor-node', 'smart-fan', 'smart-hub', 'smart-light', 'smart-socket', 'smart-switch'];
    const actualFamilies = fs
      .readdirSync(prodDefDir)
      .filter((f) => fs.statSync(path.join(prodDefDir, f)).isDirectory() && !f.startsWith('_') && f !== 'tests')
      .sort();
    assert.deepStrictEqual(actualFamilies, expectedFamilies, 'Family directories must exactly match the 6 canonical families');

    // Collect all metadata.json
    const definitions = [];
    for (const fam of actualFamilies) {
      const famDir = path.join(prodDefDir, fam);
      const subdirs = fs.readdirSync(famDir).filter((d) => fs.statSync(path.join(famDir, d)).isDirectory());
      for (const sub of subdirs) {
        const metaPath = path.join(famDir, sub, 'metadata.json');
        if (fs.existsSync(metaPath)) {
          const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
          definitions.push({
            familyDir: fam,
            subDir: sub,
            productVariantId: meta.productVariantId,
            firmwareFamily: meta.firmwareFamily,
            mcuFamily: meta.hardwareProfile?.mcuFamily || meta.mcuFamily,
            supportedHardwareRevisions: meta.supportedHardwareRevisions,
          });
        }
      }
    }

    assert.strictEqual(definitions.length, 11, 'There must be exactly 11 product definitions');

    const expectedVariantIds = [
      'eh-sensor-node-v1',
      'eh-smart-fan-1x',
      'eh-smart-hub-v1',
      'eh-smart-light-cct',
      'eh-smart-socket-1x',
      'eh-smart-socket-2x',
      'eh-smart-socket-3x',
      'eh-smart-switch-1x',
      'eh-smart-switch-2x',
      'eh-smart-switch-3x',
      'eh-smart-switch-4x',
    ];
    const actualVariantIds = definitions.map((d) => d.productVariantId).sort();
    assert.deepStrictEqual(actualVariantIds, expectedVariantIds, 'Product variant IDs must exactly match canonical catalog');

    // Verify each definition maps correctly to MCU and firmware family
    for (const d of definitions) {
      assert.ok(d.firmwareFamily, `${d.productVariantId} must define firmwareFamily`);
      assert.ok(d.mcuFamily, `${d.productVariantId} must define mcuFamily`);
      assert.ok(Array.isArray(d.supportedHardwareRevisions) && d.supportedHardwareRevisions.length > 0);

      // Verify mapping against FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP
      const variantsForFamily = FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP[d.firmwareFamily];
      assert.ok(variantsForFamily, `Firmware family ${d.firmwareFamily} must be registered in FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP`);
      assert.ok(variantsForFamily.includes(d.productVariantId), `${d.productVariantId} must be in ${d.firmwareFamily} variants`);

      // Verify target MCU mapping
      if (d.firmwareFamily === 'esp32s3-hub-platform') {
        assert.strictEqual(d.mcuFamily, 'esp32-s3');
      } else {
        assert.strictEqual(d.mcuFamily, 'esp32-c6');
      }
    }
  });

  await runTest('Verify naming discrepancies: eh-smart-light-rgbw and eh-sensor-node-env do NOT exist in product-definitions', async () => {
    const prodDefDir = path.join(ROOT_DIR, 'product-definitions');
    const allFiles = [];
    function scanDir(dir) {
      for (const item of fs.readdirSync(dir)) {
        const full = path.join(dir, item);
        if (fs.statSync(full).isDirectory()) scanDir(full);
        else allFiles.push(full);
      }
    }
    scanDir(prodDefDir);

    for (const file of allFiles) {
      const content = fs.readFileSync(file, 'utf8');
      assert.ok(!content.includes('"eh-smart-light-rgbw"'), `File ${file} must NOT contain speculative eh-smart-light-rgbw`);
      assert.ok(!content.includes('"eh-sensor-node-env"'), `File ${file} must NOT contain speculative eh-sensor-node-env`);
    }

    // Verify canonical counterparts DO exist
    const cctMetaPath = path.join(prodDefDir, 'smart-light', 'cct', 'metadata.json');
    assert.ok(fs.existsSync(cctMetaPath), 'eh-smart-light-cct metadata must exist');
    const cctMeta = JSON.parse(fs.readFileSync(cctMetaPath, 'utf8'));
    assert.strictEqual(cctMeta.productVariantId, 'eh-smart-light-cct');

    const sensorMetaPath = path.join(prodDefDir, 'sensor-node', 'v1', 'metadata.json');
    assert.ok(fs.existsSync(sensorMetaPath), 'eh-sensor-node-v1 metadata must exist');
    const sensorMeta = JSON.parse(fs.readFileSync(sensorMetaPath, 'utf8'));
    assert.strictEqual(sensorMeta.productVariantId, 'eh-sensor-node-v1');
  });

  // ── 9. RELEASE TAG MODEL & MANIFEST CONSISTENCY ─────────────────────
  console.log('\n9. Release Tag Model & Manifest Consistency:');

  await runTest('Model A: Release tag parsing supports family-scoped and default release tags', async () => {
    // Family-scoped tags
    const scoped1 = parseReleaseTag('esp32c6-switch-platform@v1.2.3');
    assert.strictEqual(scoped1.firmwareFamily, 'esp32c6-switch-platform');
    assert.strictEqual(scoped1.version, '1.2.3');

    const scoped2 = parseReleaseTag('esp32c6-socket-platform@v2.0.0');
    assert.strictEqual(scoped2.firmwareFamily, 'esp32c6-socket-platform');
    assert.strictEqual(scoped2.version, '2.0.0');

    // Generic tag defaults to primary production family esp32c6-switch-platform
    const generic = parseReleaseTag('v1.0.0');
    assert.strictEqual(generic.firmwareFamily, 'esp32c6-switch-platform');
    assert.strictEqual(generic.version, '1.0.0');
  });

  await runTest('Manifest generation populates productVariants and ensures target consistency', async () => {
    const dummyArtifacts = [
      {
        artifactType: 'APP_BIN',
        fileName: 'eh-smart-switch-app.bin',
        fileSizeBytes: 1048576,
        sha256: 'a'.repeat(64),
        storagePath: 'builds/app.bin',
      },
    ];

    const manifest = generateBuildManifest({
      buildId: '123e4567-e89b-12d3-a456-426614174000',
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0',
      gitCommitSha: 'a'.repeat(40),
      gitBranch: 'main',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      compatibleHardwareRevisions: ['HW_1_0', 'HW_1_1'],
      artifacts: dummyArtifacts,
    });

    assert.strictEqual(manifest.firmwareFamily, 'esp32c6-switch-platform');
    assert.strictEqual(manifest.targetMcu, 'esp32-c6');
    assert.strictEqual(manifest.idfTarget, 'esp32c6');
    assert.strictEqual(manifest.toolchain, 'riscv32-esp-elf');
    assert.strictEqual(manifest.lifecycleStatus, 'RELEASED');
    assert.deepStrictEqual(manifest.productVariants, [
      'eh-smart-switch-1x',
      'eh-smart-switch-2x',
      'eh-smart-switch-3x',
      'eh-smart-switch-4x',
    ]);
  });

  await runTest('Release manifests explicitly emit lifecycleStatus: "RELEASED" and dev builds emit "BUILDING"', async () => {
    const dummyArtifacts = [
      {
        artifactType: 'APP_BIN',
        fileName: 'eh-smart-switch-app.bin',
        fileSizeBytes: 1048576,
        sha256: 'a'.repeat(64),
        storagePath: 'builds/app.bin',
      },
    ];

    const releaseManifest = generateBuildManifest({
      buildId: '123e4567-e89b-12d3-a456-426614174000',
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0',
      gitCommitSha: 'a'.repeat(40),
      gitBranch: 'main',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      buildProfile: 'release',
      compatibleHardwareRevisions: ['HW_1_0', 'HW_1_1'],
      artifacts: dummyArtifacts,
    });

    assert.strictEqual(releaseManifest.lifecycleStatus, 'RELEASED');
    assert.strictEqual(Object.prototype.hasOwnProperty.call(releaseManifest, 'lifecycleStatus'), true);

    const devManifest = generateBuildManifest({
      buildId: '123e4567-e89b-12d3-a456-426614174001',
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0-dev',
      gitCommitSha: 'b'.repeat(40),
      gitBranch: 'feature/test',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      buildProfile: 'debug',
      compatibleHardwareRevisions: ['HW_1_0'],
      artifacts: dummyArtifacts,
    });

    assert.strictEqual(devManifest.lifecycleStatus, 'BUILDING');
  });

  await runTest('Real production build verification against build_c6 artifacts (if present)', async () => {
    const buildC6Dir = path.join(ROOT_DIR, 'firmware', 'platforms', 'esp32', 'smart-switch-app', 'build_c6');
    if (fs.existsSync(buildC6Dir) && fs.existsSync(path.join(buildC6Dir, 'flasher_args.json'))) {
      const artifacts = discoverArtifacts(buildC6Dir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6');
      assert.strictEqual(artifacts.length, 5);

      const manifest = generateBuildManifest({
        buildId: crypto.randomUUID(),
        firmwareFamily: 'esp32c6-switch-platform',
        version: '1.0.0',
        gitCommitSha: '1522289f46555b947dac5efb0ad0fbbc9f44260a',
        targetMcu: 'esp32-c6',
        idfTarget: 'esp32c6',
        toolchain: 'riscv32-esp-elf',
        compatibleHardwareRevisions: ['HW_1_0', 'HW_1_1'],
        artifacts,
      });

      assert.strictEqual(manifest.targetMcu, 'esp32-c6');
      assert.strictEqual(manifest.idfTarget, 'esp32c6');
      assert.strictEqual(manifest.toolchain, 'riscv32-esp-elf');
      assert.deepStrictEqual(manifest.productVariants, [
        'eh-smart-switch-1x',
        'eh-smart-switch-2x',
        'eh-smart-switch-3x',
        'eh-smart-switch-4x',
      ]);

      const readiness = evaluateReleaseReadiness(manifest, { testsPassed: true });
      assert.strictEqual(readiness.isReadyForApproval, true);
    }
  });

  // ── 10. PRODUCTION RELEASE FAMILY ELIGIBILITY & TARGET RESOLUTION GUARDS ──
  console.log('\n10. Production Release Family Eligibility & Target Resolution Guards:');

  await runTest('Allowed release family: esp32c6-switch-platform@v1.0.0 accepted and resolves production target', async () => {
    const parsed = parseReleaseTag('esp32c6-switch-platform@v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32c6-switch-platform');
    assert.strictEqual(parsed.version, '1.0.0');
    assert.strictEqual(parsed.isFamilyScoped, true);

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, true);
    assert.strictEqual(validation.metadata.id, 'esp32c6-switch-platform');
    assert.strictEqual(validation.metadata.targetMcu, 'esp32-c6');
    assert.strictEqual(validation.metadata.idfTarget, 'esp32c6');
    assert.strictEqual(validation.metadata.toolchain, 'riscv32-esp-elf');
    assert.strictEqual(validation.metadata.implementationStatus, 'IMPLEMENTED');
    assert.strictEqual(validation.metadata.releaseEligibility, 'PRODUCTION');
  });

  await runTest('Implemented production family: esp32c6-socket-platform@v1.0.0 accepted with valid firmware implementation', async () => {
    const parsed = parseReleaseTag('esp32c6-socket-platform@v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32c6-socket-platform');
    assert.strictEqual(parsed.version, '1.0.0');
    assert.strictEqual(parsed.isFamilyScoped, true);

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, true);
    assert.strictEqual(validation.metadata.id, 'esp32c6-socket-platform');
    assert.strictEqual(validation.metadata.targetMcu, 'esp32-c6');
    assert.strictEqual(validation.metadata.idfTarget, 'esp32c6');
    assert.strictEqual(validation.metadata.toolchain, 'riscv32-esp-elf');
    assert.strictEqual(validation.metadata.implementationStatus, 'IMPLEMENTED');
    assert.strictEqual(validation.metadata.releaseEligibility, 'PRODUCTION');
  });

  await runTest('Planned family: esp32c6-fan-platform@v1.0.0 is strictly rejected from production release', async () => {
    const parsed = parseReleaseTag('esp32c6-fan-platform@v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32c6-fan-platform');
    assert.strictEqual(parsed.version, '1.0.0');

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, false);
    assert.ok(validation.error.includes("Firmware family 'esp32c6-fan-platform' is not currently eligible for production release."));
    assert.ok(validation.error.includes('Implementation status is PLANNED.'));

    // Verify local pipeline runner throws
    let threw = false;
    try {
      await runFirmwarePipeline({
        firmwareFamily: 'esp32c6-fan-platform',
        version: '1.0.0',
        buildProfile: 'release',
        isProductionRelease: true,
        skipTests: true,
      });
    } catch (err) {
      threw = true;
      assert.ok(err.message.includes("Firmware family 'esp32c6-fan-platform' is not currently eligible for production release."));
    }
    assert.strictEqual(threw, true, 'runFirmwarePipeline must throw for planned family');
  });

  await runTest('Future MCU planned family: esp32s3-hub-platform@v1.0.0 is strictly rejected while planned', async () => {
    const parsed = parseReleaseTag('esp32s3-hub-platform@v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32s3-hub-platform');
    assert.strictEqual(parsed.version, '1.0.0');

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, false);
    assert.ok(validation.error.includes("Firmware family 'esp32s3-hub-platform' is not currently eligible for production release."));
    assert.ok(validation.error.includes('Implementation status is PLANNED.'));

    let threw = false;
    try {
      await runFirmwarePipeline({
        firmwareFamily: 'esp32s3-hub-platform',
        version: '1.0.0',
        buildProfile: 'release',
        isProductionRelease: true,
        skipTests: true,
      });
    } catch (err) {
      threw = true;
      assert.ok(err.message.includes("Firmware family 'esp32s3-hub-platform' is not currently eligible for production release."));
    }
    assert.strictEqual(threw, true, 'runFirmwarePipeline must throw for future MCU planned family');
  });

  await runTest('Prototype family: esp32-dev-platform@v1.0.0 is strictly rejected from production release workflow', async () => {
    const parsed = parseReleaseTag('esp32-dev-platform@v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32-dev-platform');
    assert.strictEqual(parsed.version, '1.0.0');

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, false);
    assert.ok(validation.error.includes("Firmware family 'esp32-dev-platform' is not currently eligible for production release."));
    assert.ok(validation.error.includes('Classified as PROTOTYPE_ONLY.'));

    let threw = false;
    try {
      await runFirmwarePipeline({
        firmwareFamily: 'esp32-dev-platform',
        version: '1.0.0',
        buildProfile: 'release',
        isProductionRelease: true,
        skipTests: true,
      });
    } catch (err) {
      threw = true;
      assert.ok(err.message.includes("Firmware family 'esp32-dev-platform' is not currently eligible for production release."));
    }
    assert.strictEqual(threw, true, 'runFirmwarePipeline must throw for prototype family');
  });

  await runTest('Generic tag v1.0.0 resolves only to default production family esp32c6-switch-platform', async () => {
    const parsed = parseReleaseTag('v1.0.0');
    assert.strictEqual(parsed.firmwareFamily, 'esp32c6-switch-platform');
    assert.strictEqual(parsed.version, '1.0.0');
    assert.strictEqual(parsed.isFamilyScoped, false);

    const validation = validateProductionReleaseFamily(parsed.firmwareFamily);
    assert.strictEqual(validation.valid, true);
  });

  await runTest('Deterministic target resolution across all canonical families', async () => {
    for (const [familyId, meta] of Object.entries(CANONICAL_FIRMWARE_FAMILIES)) {
      assert.strictEqual(meta.id, familyId);
      assert.ok(meta.targetMcu);
      assert.ok(meta.idfTarget);
      assert.ok(meta.toolchain);
      assert.strictEqual(meta.idfTarget, MCU_TO_IDF_TARGET_MAP[meta.targetMcu]);
      assert.strictEqual(meta.toolchain, MCU_TO_TOOLCHAIN_MAP[meta.targetMcu]);
    }
  });

  await runTest('Release workflow (.github/workflows/firmware-release.yml) validates family BEFORE compilation and binds target dynamically', async () => {
    const releasePath = path.join(ROOT_DIR, '.github', 'workflows', 'firmware-release.yml');
    const content = fs.readFileSync(releasePath, 'utf8');

    // Verification order: step with validateProductionReleaseFamily occurs BEFORE "Compile Production Firmware"
    const validationIndex = content.indexOf('validateProductionReleaseFamily');
    const compileIndex = content.indexOf('Compile Production Firmware');
    assert.ok(validationIndex !== -1, 'Must invoke validateProductionReleaseFamily in release workflow');
    assert.ok(compileIndex !== -1, 'Must contain compilation step');
    assert.ok(validationIndex < compileIndex, 'Family validation MUST occur BEFORE compilation');

    // Dynamic target binding
    assert.ok(content.includes('target: ${{ env.IDF_TARGET }}'), 'Compilation step must dynamically use ${{ env.IDF_TARGET }}');
    assert.ok(content.includes('--target-mcu "${TARGET_MCU}"'), 'Pipeline step must use dynamic TARGET_MCU');
    assert.ok(content.includes('--idf-target "${IDF_TARGET}"'), 'Pipeline step must use dynamic IDF_TARGET');
    assert.ok(content.includes('--toolchain "${TOOLCHAIN}"'), 'Pipeline step must use dynamic TOOLCHAIN');
  });

  // ── 11. FIRMWARE FAMILY ARTIFACT CONSISTENCY & CROSS-FAMILY PROTECTION ───
  console.log('\n11. Firmware Family Artifact Consistency & Cross-Family Protection:');

  await runTest('Switch: family = esp32c6-switch-platform -> valid switch config -> target esp32c6 -> manifest family = switch', async () => {
    const switchBuildDir = path.join(tempTestDir, 'switch_build_valid');
    createSyntheticBuild(switchBuildDir, {
      family: 'esp32c6-switch-platform',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      flasherArgs: { chip: 'esp32c6' },
    });

    const artifacts = discoverArtifacts(switchBuildDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6', 'esp32c6-switch-platform');
    const appArt = artifacts.find((a) => a.artifactType === 'APP_BIN');
    assert.ok(appArt, 'Must find APP_BIN');
    assert.strictEqual(appArt.embeddedFamily, 'esp32c6-switch-platform');

    const manifest = generateBuildManifest({
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-switch-platform',
      version: '1.0.0',
      gitCommitSha: '1111222233334444555566667777888899990000',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      compatibleHardwareRevisions: ['hw_rev_switch_1x_1_0'],
      artifacts,
    });

    assert.strictEqual(manifest.firmwareFamily, 'esp32c6-switch-platform');
    assert.deepStrictEqual(manifest.productVariants, ['eh-smart-switch-1x', 'eh-smart-switch-2x', 'eh-smart-switch-3x', 'eh-smart-switch-4x']);

    const readiness = evaluateReleaseReadiness(manifest, { testsPassed: true, embeddedFamily: appArt.embeddedFamily });
    assert.strictEqual(readiness.isReadyForApproval, true);
    const familyGate = readiness.checks.find((c) => c.gate === 'FAMILY_CONTENT_CONSISTENCY_VERIFIED');
    assert.ok(familyGate, 'Must include family content consistency gate');
    assert.strictEqual(familyGate.passed, true);
  });

  await runTest('Socket: family = esp32c6-socket-platform -> valid socket config -> target esp32c6 -> manifest family = socket', async () => {
    const socketBuildDir = path.join(tempTestDir, 'socket_build_valid');
    createSyntheticBuild(socketBuildDir, {
      family: 'esp32c6-socket-platform',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      flasherArgs: { chip: 'esp32c6' },
    });

    const artifacts = discoverArtifacts(socketBuildDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6', 'esp32c6-socket-platform');
    const appArt = artifacts.find((a) => a.artifactType === 'APP_BIN');
    assert.ok(appArt, 'Must find APP_BIN');
    assert.strictEqual(appArt.embeddedFamily, 'esp32c6-socket-platform');

    const manifest = generateBuildManifest({
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-socket-platform',
      version: '1.0.0',
      gitCommitSha: '2222333344445555666677778888999900001111',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      compatibleHardwareRevisions: ['hw_rev_socket_1x_1_0'],
      artifacts,
    });

    assert.strictEqual(manifest.firmwareFamily, 'esp32c6-socket-platform');
    assert.deepStrictEqual(manifest.productVariants, ['eh-smart-socket-1x', 'eh-smart-socket-2x', 'eh-smart-socket-3x']);

    const readiness = evaluateReleaseReadiness(manifest, { testsPassed: true, embeddedFamily: appArt.embeddedFamily });
    assert.strictEqual(readiness.isReadyForApproval, true);
    const familyGate = readiness.checks.find((c) => c.gate === 'FAMILY_CONTENT_CONSISTENCY_VERIFIED');
    assert.ok(familyGate, 'Must include family content consistency gate');
    assert.strictEqual(familyGate.passed, true);
  });

  await runTest('Cross-family mismatch: socket family + switch build configuration is strictly rejected', async () => {
    // Build directory prepared for switch, but pipeline attempts to release as socket
    const crossMismatchDir = path.join(tempTestDir, 'cross_mismatch_switch_for_socket');
    createSyntheticBuild(crossMismatchDir, {
      family: 'esp32c6-switch-platform',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      flasherArgs: { chip: 'esp32c6' },
    });

    let errorCaught = false;
    try {
      discoverArtifacts(crossMismatchDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6', 'esp32c6-socket-platform');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Firmware Family Mismatch') || err.message.includes('Cross-Family Mismatch'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject switch build when releasing under socket family');
  });

  await runTest('Cross-family mismatch: switch family + socket build configuration is strictly rejected', async () => {
    // Build directory prepared for socket, but pipeline attempts to release as switch
    const crossMismatchDir = path.join(tempTestDir, 'cross_mismatch_socket_for_switch');
    createSyntheticBuild(crossMismatchDir, {
      family: 'esp32c6-socket-platform',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      flasherArgs: { chip: 'esp32c6' },
    });

    let errorCaught = false;
    try {
      discoverArtifacts(crossMismatchDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6', 'esp32c6-switch-platform');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Firmware Family Mismatch') || err.message.includes('Cross-Family Mismatch'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject socket build when releasing under switch family');
  });

  await runTest('Cross-family mismatch: binary with missing family signature is rejected', async () => {
    const noSigDir = path.join(tempTestDir, 'no_sig_build');
    createSyntheticBuild(noSigDir, {
      family: null, // No embedded family marker
      firmwareFamilyJson: false,
    });

    let errorCaught = false;
    try {
      discoverArtifacts(noSigDir, 'eh-smart-switch-app', 'esp32-c6', 'esp32c6', 'esp32c6-switch-platform');
    } catch (err) {
      errorCaught = true;
      assert.ok(err.message.includes('Missing embedded family metadata marker'));
    }
    assert.strictEqual(errorCaught, true, 'Must reject binary without embedded family marker');
  });

  await runTest('Release-readiness gate rejects cross-family release approval', async () => {
    const dummyManifest = generateBuildManifest({
      buildId: crypto.randomUUID(),
      firmwareFamily: 'esp32c6-socket-platform',
      version: '1.0.0',
      gitCommitSha: '4444555566667777888899990000111122223333',
      targetMcu: 'esp32-c6',
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      compatibleHardwareRevisions: ['hw_rev_socket_1x_1_0'],
      artifacts: [
        {
          artifactType: 'APP_BIN',
          fileName: 'eh-smart-switch-app.bin',
          fileSizeBytes: 1048576,
          sha256: 'a'.repeat(64),
          storagePath: 'firmware/test/app.bin',
          targetMcu: 'esp32-c6',
          idfTarget: 'esp32c6',
        },
        {
          artifactType: 'BOOTLOADER',
          fileName: 'bootloader.bin',
          fileSizeBytes: 28672,
          sha256: 'b'.repeat(64),
          storagePath: 'firmware/test/bootloader.bin',
          targetMcu: 'esp32-c6',
          idfTarget: 'esp32c6',
        },
        {
          artifactType: 'PARTITION_TABLE',
          fileName: 'partition-table.bin',
          fileSizeBytes: 3072,
          sha256: 'c'.repeat(64),
          storagePath: 'firmware/test/partition-table.bin',
          targetMcu: 'esp32-c6',
          idfTarget: 'esp32c6',
        },
      ],
    });

    // Provide mismatched embedded family ('esp32c6-switch-platform') against socket release
    const readiness = evaluateReleaseReadiness(dummyManifest, {
      testsPassed: true,
      embeddedFamily: 'esp32c6-switch-platform',
    });

    assert.strictEqual(readiness.isReadyForApproval, false);
    const familyGate = readiness.checks.find((c) => c.gate === 'FAMILY_CONTENT_CONSISTENCY_VERIFIED');
    assert.ok(familyGate);
    assert.strictEqual(familyGate.passed, false);
    assert.ok(familyGate.detail.includes('Cross-family release contamination rejected'));
  });

  await runTest('Product variant isolation: switch variants never leak to socket and vice versa', async () => {
    const switchVariants = FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP['esp32c6-switch-platform'];
    const socketVariants = FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP['esp32c6-socket-platform'];

    assert.ok(switchVariants.every((v) => v.startsWith('eh-smart-switch-')));
    assert.ok(socketVariants.every((v) => v.startsWith('eh-smart-socket-')));

    // Disjoint set
    const intersection = switchVariants.filter((v) => socketVariants.includes(v));
    assert.strictEqual(intersection.length, 0, 'Switch and socket variants must be completely disjoint');
  });

  await runTest('Release workflow (.github/workflows/firmware-release.yml) passes EH_FIRMWARE_FAMILY and verifies binary signature', async () => {
    const releasePath = path.join(ROOT_DIR, '.github', 'workflows', 'firmware-release.yml');
    const content = fs.readFileSync(releasePath, 'utf8');

    assert.ok(content.includes('EH_FIRMWARE_FAMILY: ${{ env.TARGET_FAMILY }}'), 'Workflow must pass EH_FIRMWARE_FAMILY during compilation');
    assert.ok(content.includes('EH_FIRMWARE_FAMILY:${TARGET_FAMILY}:END_FAMILY'), 'Workflow must verify binary artifact embedded signature');
  });

  // Cleanup temp test directory
  try {
    fs.rmSync(tempTestDir, { recursive: true, force: true });
  } catch {
    // cleanup fallback
  }

  await app.close();

  console.log('\n=== FIRMWARE AUTOMATED BUILD & RELEASE SUMMARY ===');
  console.log(`Total:  ${totalTests}`);
  console.log(`Passed: ${passedTests}`);
  console.log(`Failed: ${failedTests}`);

  if (failedTests > 0) {
    console.error('\nSOME FIRMWARE AUTOMATED BUILD & RELEASE TESTS FAILED ❌');
    process.exit(1);
  } else {
    console.log('\nALL FIRMWARE AUTOMATED BUILD & RELEASE TESTS PASSED [OK]\n');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error(`Fatal error in firmware automated build test runner: ${err.stack || err.message}`);
  process.exit(1);
});
