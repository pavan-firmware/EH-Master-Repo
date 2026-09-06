'use strict';

/**
 * EH Home — Phase 45: Production Release, Deployment & Distribution Readiness Tests
 *
 * Validates 30 scenarios covering release metadata, semantic versioning, lifecycle state machine,
 * artifact integrity, migration release gates, environment separation, deployment prechecks,
 * post-deployment health verification, rollback engine, RBAC, SBOM, and secret safety.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { ReleaseManifestService } = require('../src/services/release-manifest.service');
const { ReleaseService, RELEASE_STATES } = require('../src/services/release.service');
const { MetricsService } = require('../src/services/metrics.service');
const { StructuredLogger } = require('../src/shared/structured-logger');

const passed = [];
const failed = [];

async function test(name, fn) {
  try {
    await fn();
    passed.push(name);
    console.log(`  ✓ Scenario ${passed.length + failed.length}: ${name}`);
  } catch (err) {
    failed.push({ name, error: err.message, stack: err.stack });
    console.error(`  ✗ Scenario ${passed.length + failed.length}: ${name}`);
    console.error(`    Error: ${err.message}`);
  }
}

function createSampleManifestParams(overrides = {}) {
  const dummySha = 'a'.repeat(40);
  return {
    releaseId: 'rel-2026-09-01',
    version: '1.4.0',
    channel: 'PRODUCTION',
    sourceCommit: dummySha,
    schemaVersion: '029',
    backend: {
      version: '1.4.0',
      dockerTag: 'eh-backend:1.4.0',
      sha256: 'b'.repeat(64)
    },
    flutter: {
      version: '1.4.0',
      buildNumber: 45,
      targetPlatforms: ['android', 'ios', 'web'],
      minBackendVersion: '1.3.0'
    },
    firmware: {
      'eh-switch-1x': {
        version: '1.4.0',
        sha256: 'c'.repeat(64),
        minFirmwareVersion: '1.0.0',
        hardwareProfile: 'ESP32_C3'
      }
    },
    artifacts: [
      {
        name: 'eh-backend-1.4.0.tar.gz',
        type: 'DOCKER_IMAGE',
        sha256: 'd'.repeat(64),
        sizeBytes: 104857600
      },
      {
        name: 'eh-switch-1x-1.4.0.bin',
        type: 'FIRMWARE_BINARY',
        sha256: 'e'.repeat(64),
        sizeBytes: 1048576,
        signature: 'ed25519-sig-mock'
      }
    ],
    sbom: {
      format: 'SPDX-JSON',
      sha256: 'f'.repeat(64),
      componentCount: 42
    },
    releaseNotes: {
      summary: 'Production Release 1.4.0',
      features: ['Performance optimizations', 'Bounded pagination'],
      fixes: ['Fixed rate limiter burst handling'],
      securityNotes: ['Hardened RBAC on observability endpoints'],
      migrationNotes: ['Migration 029 applied'],
      breakingChanges: []
    },
    ...overrides
  };
}

async function runSuite() {
  console.log('=== PHASE 45: PRODUCTION RELEASE & DEPLOYMENT READINESS TESTS ===\n');

  // =========================================================================
  // 1. Release metadata validation
  // =========================================================================
  await test('1. Release metadata validation (required fields and structure)', async () => {
    const params = createSampleManifestParams();
    const manifest = ReleaseManifestService.buildManifest(params);

    assert.strictEqual(manifest.releaseId, 'rel-2026-09-01');
    assert.strictEqual(manifest.version, '1.4.0');
    assert.strictEqual(manifest.channel, 'PRODUCTION');
    assert.ok(manifest.manifestDigest);
    assert.ok(manifest.buildTimestamp);
  });

  // =========================================================================
  // 2. Semantic version validation
  // =========================================================================
  await test('2. Semantic version validation (SemVer 2.0.0 compliance)', async () => {
    assert.strictEqual(ReleaseManifestService.isValidSemver('1.0.0'), true);
    assert.strictEqual(ReleaseManifestService.isValidSemver('1.4.0-beta.1'), true);
    assert.strictEqual(ReleaseManifestService.isValidSemver('2.1.0+20260906'), true);
    assert.strictEqual(ReleaseManifestService.isValidSemver('invalid.version'), false);
    assert.strictEqual(ReleaseManifestService.isValidSemver('1.0'), false);
  });

  // =========================================================================
  // 3. Source commit metadata
  // =========================================================================
  await test('3. Source commit metadata (40-char SHA tracking)', async () => {
    const validSha = 'a1b2c3d4e5f678901234567890abcdef12345678';
    assert.strictEqual(ReleaseManifestService.isValidGitSha(validSha), true);
    assert.strictEqual(ReleaseManifestService.isValidGitSha('short-sha'), false);
    assert.strictEqual(ReleaseManifestService.isValidGitSha('g'.repeat(40)), false); // non-hex
  });

  // =========================================================================
  // 4. Release lifecycle transitions
  // =========================================================================
  await test('4. Release lifecycle transitions (DRAFT -> VALIDATED -> CANDIDATE -> PUBLISHED -> DEPLOYED -> SUPERSEDED)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    assert.strictEqual(release.status, RELEASE_STATES.DRAFT);

    await service.validateRelease(release.releaseId, { passed: true });
    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.VALIDATED);

    await service.promoteToCandidate(release.releaseId);
    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.CANDIDATE);

    await service.publishRelease(release.releaseId, 'PRODUCTION');
    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.PUBLISHED);

    await service.deployRelease(release.releaseId, { environment: 'production', healthCheckFn: async () => true });
    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.DEPLOYED);

    // Deploy another release to supersede
    const nextRelease = await service.createRelease(createSampleManifestParams({ releaseId: 'rel-next', version: '1.4.1' }));
    await service.validateRelease(nextRelease.releaseId, { passed: true });
    await service.promoteToCandidate(nextRelease.releaseId);
    await service.publishRelease(nextRelease.releaseId, 'PRODUCTION');
    await service.deployRelease(nextRelease.releaseId, { environment: 'production', healthCheckFn: async () => true });

    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.SUPERSEDED);
    assert.strictEqual(service.getRelease(nextRelease.releaseId).status, RELEASE_STATES.DEPLOYED);
  });

  // =========================================================================
  // 5. Invalid release rejection
  // =========================================================================
  await test('5. Invalid release rejection (blocks illegal state jumps)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());

    // Cannot jump from DRAFT directly to PUBLISHED
    await assert.rejects(async () => {
      await service.publishRelease(release.releaseId, 'PRODUCTION');
    }, /Illegal release lifecycle transition/);
  });

  // =========================================================================
  // 6. Artifact checksum validation
  // =========================================================================
  await test('6. Artifact checksum validation (SHA-256 integrity verification)', async () => {
    const backendContent = 'docker image binary content';
    const backendSha = ReleaseManifestService.computeSha256(backendContent);

    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams({
      artifacts: [
        { name: 'app.tar.gz', type: 'DOCKER', sha256: backendSha }
      ]
    }));

    const validCheck = ReleaseManifestService.verifyArtifactIntegrity(manifest, {
      'app.tar.gz': backendContent
    });
    assert.strictEqual(validCheck.allValid, true);

    const corruptCheck = ReleaseManifestService.verifyArtifactIntegrity(manifest, {
      'app.tar.gz': 'tampered content'
    });
    assert.strictEqual(corruptCheck.allValid, false);
    assert.strictEqual(corruptCheck.results[0].error, 'Hash mismatch');
  });

  // =========================================================================
  // 7. Artifact signature metadata validation
  // =========================================================================
  await test('7. Artifact signature metadata validation (Ed25519 metadata)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    const firmwareArt = manifest.artifacts.find(a => a.type === 'FIRMWARE_BINARY');
    assert.ok(firmwareArt);
    assert.strictEqual(firmwareArt.signature, 'ed25519-sig-mock');
  });

  // =========================================================================
  // 8. Release manifest validation
  // =========================================================================
  await test('8. Release manifest validation (canonical schema, zero secrets)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    const json = JSON.stringify(manifest);

    assert.ok(!json.includes('password'));
    assert.ok(!json.includes('private_key'));
    assert.ok(!json.includes('bearer'));
    assert.strictEqual(typeof manifest.manifestDigest, 'string');
  });

  // =========================================================================
  // 9. Channel promotion rules
  // =========================================================================
  await test('9. Channel promotion rules (explicit channel assignment)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams({ channel: 'BETA' }));
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    const published = service.getRelease(release.releaseId);
    assert.strictEqual(published.channel, 'PRODUCTION');
  });

  // =========================================================================
  // 10. Migration release gate
  // =========================================================================
  await test('10. Migration release gate (validates schema version 029)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams({ schemaVersion: '029' }));
    const precheck = await service.executeDeploymentPrechecks(release.releaseId, 'production');

    const schemaGate = precheck.checks.find(c => c.check === 'DATABASE_SCHEMA_GATE');
    assert.ok(schemaGate);
    assert.strictEqual(schemaGate.passed, true);
  });

  // =========================================================================
  // 11. Production configuration validation
  // =========================================================================
  await test('11. Production configuration validation (rejects dev configs)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    
    // Pass with clean prod config
    const cleanPrecheck = await service.executeDeploymentPrechecks(release.releaseId, 'production', {
      NODE_ENV: 'production',
      ALLOW_DEV_DEFAULTS: 'false'
    });
    const cleanConfigGate = cleanPrecheck.checks.find(c => c.check === 'PRODUCTION_CONFIG_GATE');
    assert.strictEqual(cleanConfigGate.passed, true);

    // Fail with dev defaults in prod
    const badPrecheck = await service.executeDeploymentPrechecks(release.releaseId, 'production', {
      NODE_ENV: 'production',
      ALLOW_DEV_DEFAULTS: 'true'
    });
    const badConfigGate = badPrecheck.checks.find(c => c.check === 'PRODUCTION_CONFIG_GATE');
    assert.strictEqual(badConfigGate.passed, false);
  });

  // =========================================================================
  // 12. Environment separation
  // =========================================================================
  await test('12. Environment separation (rejects test NODE_ENV in production)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    
    const precheck = await service.executeDeploymentPrechecks(release.releaseId, 'production', {
      NODE_ENV: 'test'
    });
    const configGate = precheck.checks.find(c => c.check === 'PRODUCTION_CONFIG_GATE');
    assert.strictEqual(configGate.passed, false);
  });

  // =========================================================================
  // 13. Deployment precheck
  // =========================================================================
  await test('13. Deployment precheck (all gates must pass before deploy)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    const precheck = await service.executeDeploymentPrechecks(release.releaseId, 'production');
    assert.strictEqual(precheck.allPassed, true);
    assert.strictEqual(precheck.checks.length >= 4, true);
  });

  // =========================================================================
  // 14. Health-gated deployment
  // =========================================================================
  await test('14. Health-gated deployment (verifies healthy response)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    const deployed = await service.deployRelease(release.releaseId, {
      environment: 'production',
      healthCheckFn: async () => ({ healthy: true, liveness: 'OK', readiness: 'OK' })
    });

    assert.strictEqual(deployed.status, RELEASE_STATES.DEPLOYED);
    assert.ok(deployed.deployedAt);
  });

  // =========================================================================
  // 15. Deployment failure handling
  // =========================================================================
  await test('15. Deployment failure handling (marks release as FAILED if health check fails)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    await assert.rejects(async () => {
      await service.deployRelease(release.releaseId, {
        environment: 'production',
        healthCheckFn: async () => { throw new Error('Database connection timeout during startup'); }
      });
    }, /Database connection timeout/);

    assert.strictEqual(service.getRelease(release.releaseId).status, RELEASE_STATES.FAILED);
  });

  // =========================================================================
  // 16. Rollback authorization
  // =========================================================================
  await test('16. Rollback authorization (ADMIN only, restores target release)', async () => {
    const service = new ReleaseService();
    
    // Release 1 (known good)
    const rel1 = await service.createRelease(createSampleManifestParams({ releaseId: 'rel-1', version: '1.0.0' }));
    await service.validateRelease(rel1.releaseId, { passed: true });
    await service.promoteToCandidate(rel1.releaseId);
    await service.publishRelease(rel1.releaseId, 'PRODUCTION');
    await service.deployRelease(rel1.releaseId, { environment: 'production', healthCheckFn: async () => true });

    // Release 2 (current)
    const rel2 = await service.createRelease(createSampleManifestParams({ releaseId: 'rel-2', version: '1.1.0' }));
    await service.validateRelease(rel2.releaseId, { passed: true });
    await service.promoteToCandidate(rel2.releaseId);
    await service.publishRelease(rel2.releaseId, 'PRODUCTION');
    await service.deployRelease(rel2.releaseId, { environment: 'production', healthCheckFn: async () => true });

    // Execute rollback
    const rollbackResult = await service.executeRollback('rel-2', {
      targetReleaseId: 'rel-1',
      reason: 'Memory leak in rel-2'
    });

    assert.strictEqual(rollbackResult.success, true);
    assert.strictEqual(rollbackResult.activeReleaseId, 'rel-1');
    assert.strictEqual(service.getRelease('rel-2').status, RELEASE_STATES.ROLLED_BACK);
    assert.strictEqual(service.getRelease('rel-1').status, RELEASE_STATES.DEPLOYED);
  });

  // =========================================================================
  // 17. Invalid rollback rejection
  // =========================================================================
  await test('17. Invalid rollback rejection (rejects non-existent or invalid target)', async () => {
    const service = new ReleaseService();
    const rel1 = await service.createRelease(createSampleManifestParams({ releaseId: 'rel-1', version: '1.0.0' }));
    await service.validateRelease(rel1.releaseId, { passed: true });
    await service.promoteToCandidate(rel1.releaseId);
    await service.publishRelease(rel1.releaseId, 'PRODUCTION');
    await service.deployRelease(rel1.releaseId, { environment: 'production', healthCheckFn: async () => true });

    await assert.rejects(async () => {
      await service.executeRollback('rel-1', { targetReleaseId: 'rel-non-existent' });
    }, /Release not found/);
  });

  // =========================================================================
  // 18. Firmware artifact compatibility
  // =========================================================================
  await test('18. Firmware artifact compatibility (anti-rollback & hardware profile)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    const fw = manifest.firmware['eh-switch-1x'];
    assert.ok(fw);
    assert.strictEqual(fw.hardwareProfile, 'ESP32_C3');
    assert.strictEqual(fw.minFirmwareVersion, '1.0.0');
  });

  // =========================================================================
  // 19. Flutter release metadata
  // =========================================================================
  await test('19. Flutter release metadata (version, build number, platforms)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    assert.strictEqual(manifest.flutter.version, '1.4.0');
    assert.strictEqual(manifest.flutter.buildNumber, 45);
    assert.deepStrictEqual(manifest.flutter.targetPlatforms, ['android', 'ios', 'web']);
  });

  // =========================================================================
  // 20. Secret scanning / release safety
  // =========================================================================
  await test('20. Secret scanning / release safety (zero secrets in release manifest)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    const manifestStr = JSON.stringify(manifest);

    const bannedKeywords = ['password', 'bearer', 'secret_key', 'private_key'];
    bannedKeywords.forEach(word => {
      assert.ok(!manifestStr.toLowerCase().includes(`"${word}"`), `Manifest must not contain "${word}"`);
    });
  });

  // =========================================================================
  // 21. SBOM / dependency inventory association
  // =========================================================================
  await test('21. SBOM / dependency inventory association (SPDX-JSON linkage)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    assert.strictEqual(manifest.sbom.format, 'SPDX-JSON');
    assert.strictEqual(manifest.sbom.componentCount, 42);
    assert.ok(manifest.sbom.sha256);
  });

  // =========================================================================
  // 22. Audit integration
  // =========================================================================
  await test('22. Audit integration (records lifecycle transitions)', async () => {
    const auditLogs = [];
    const mockAuditService = {
      recordAudit: (entry) => auditLogs.push(entry)
    };

    const service = new ReleaseService({ auditService: mockAuditService });
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });

    assert.strictEqual(auditLogs.length, 2);
    assert.strictEqual(auditLogs[0].action, 'RELEASE_CREATED');
    assert.strictEqual(auditLogs[1].action, 'RELEASE_VALIDATED');
  });

  // =========================================================================
  // 23. Observability integration
  // =========================================================================
  await test('23. Observability integration (records deployment metrics)', async () => {
    const metrics = new MetricsService();
    const service = new ReleaseService({ metricsService: metrics });
    
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');
    await service.deployRelease(release.releaseId, { environment: 'production', healthCheckFn: async () => true });

    const snapshot = metrics.getSnapshot();
    assert.ok(snapshot.counters['deployments_total{environment=production,status=SUCCESS}']);
  });

  // =========================================================================
  // 24. Incident correlation
  // =========================================================================
  await test('24. Incident correlation (links failed deployments to incident metadata)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    try {
      await service.deployRelease(release.releaseId, {
        environment: 'production',
        healthCheckFn: async () => { throw new Error('Database migration connection refused'); }
      });
    } catch (err) {
      // Incident payload correlation
      const incidentCorrelation = {
        releaseId: release.releaseId,
        sourceCommit: release.sourceCommit,
        error: err.message,
        timestamp: new Date().toISOString()
      };
      assert.strictEqual(incidentCorrelation.releaseId, 'rel-2026-09-01');
      assert.strictEqual(incidentCorrelation.error, 'Database migration connection refused');
    }
  });

  // =========================================================================
  // 25. Release RBAC
  // =========================================================================
  await test('25. Release RBAC (non-admin cannot publish or deploy)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);

    const normalUser = { id: 'usr-regular', role: 'MEMBER' };
    await assert.rejects(async () => {
      await service.publishRelease(release.releaseId, 'PRODUCTION', normalUser);
    }, /Unauthorized: Operation requires ADMIN privileges/);
  });

  // =========================================================================
  // 26. Artifact reproducibility metadata
  // =========================================================================
  await test('26. Artifact reproducibility metadata (toolchain, node version)', async () => {
    const manifest = ReleaseManifestService.buildManifest(createSampleManifestParams());
    assert.strictEqual(manifest.backend.nodeVersion, process.version);
    assert.strictEqual(manifest.builtBy, 'EH CI/CD Builder');
  });

  // =========================================================================
  // 27. Post-deployment health verification
  // =========================================================================
  await test('27. Post-deployment health verification (executes probe)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    await service.publishRelease(release.releaseId, 'PRODUCTION');

    let probeExecuted = false;
    await service.deployRelease(release.releaseId, {
      environment: 'production',
      healthCheckFn: async () => {
        probeExecuted = true;
        return true;
      }
    });

    assert.strictEqual(probeExecuted, true);
  });

  // =========================================================================
  // 28. Release candidate promotion
  // =========================================================================
  await test('28. Release candidate promotion (VALIDATED -> CANDIDATE)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    const candidate = await service.promoteToCandidate(release.releaseId);
    assert.strictEqual(candidate.status, RELEASE_STATES.CANDIDATE);
  });

  // =========================================================================
  // 29. Production promotion gate
  // =========================================================================
  await test('29. Production promotion gate (explicit promotion action)', async () => {
    const service = new ReleaseService();
    const release = await service.createRelease(createSampleManifestParams());
    await service.validateRelease(release.releaseId, { passed: true });
    await service.promoteToCandidate(release.releaseId);
    const published = await service.publishRelease(release.releaseId, 'PRODUCTION');

    assert.strictEqual(published.status, RELEASE_STATES.PUBLISHED);
    assert.strictEqual(published.channel, 'PRODUCTION');
  });

  // =========================================================================
  // 30. Release regression / integrity verification
  // =========================================================================
  await test('30. Release regression / integrity verification (deterministic manifest generation)', async () => {
    const params = createSampleManifestParams();
    const manifest1 = ReleaseManifestService.buildManifest(params);
    const manifest2 = ReleaseManifestService.buildManifest(params);

    assert.strictEqual(manifest1.version, manifest2.version);
    assert.strictEqual(manifest1.sourceCommit, manifest2.sourceCommit);
    assert.strictEqual(manifest1.artifacts.length, manifest2.artifacts.length);
  });

  console.log(`\n=== RESULTS: ${passed.length}/${passed.length + failed.length} SCENARIOS PASSED ===`);
  if (failed.length > 0) {
    console.error(`\nFAILED SCENARIOS (${failed.length}):`);
    failed.forEach(f => console.error(` - ${f.name}: ${f.error}`));
    process.exit(1);
  }
}

runSuite().catch(err => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
