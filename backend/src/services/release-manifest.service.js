'use strict';

/**
 * EH Home — Release Manifest Service (Phase 45)
 *
 * Provides deterministic generation, canonical validation, and checksum
 * verification for platform release manifests spanning Backend, Database,
 * Flutter, ESP32 Firmware, and SBOM dependencies.
 */

const crypto = require('crypto');

const VALID_CHANNELS = ['DEVELOPMENT', 'BETA', 'PRODUCTION'];
const SEMVER_REGEX = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/;
const GIT_SHA_REGEX = /^[0-9a-f]{40}$/i;

class ReleaseManifestService {
  /**
   * Validates semantic version string against SemVer 2.0.0.
   */
  static isValidSemver(version) {
    if (typeof version !== 'string') return false;
    return SEMVER_REGEX.test(version);
  }

  /**
   * Validates 40-character Git SHA string.
   */
  static isValidGitSha(sha) {
    if (typeof sha !== 'string') return false;
    return GIT_SHA_REGEX.test(sha);
  }

  /**
   * Computes SHA-256 digest of buffer or string.
   */
  static computeSha256(content) {
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  /**
   * Builds and validates a canonical release manifest object.
   */
  static buildManifest({
    releaseId,
    version,
    channel = 'DEVELOPMENT',
    sourceCommit,
    schemaVersion = '029',
    backend = {},
    flutter = {},
    firmware = {},
    artifacts = [],
    sbom = {},
    compatibility = {},
    releaseNotes = {},
    builtBy = 'EH CI/CD Builder'
  }) {
    if (!releaseId || typeof releaseId !== 'string') {
      throw new Error('releaseId is required and must be a non-empty string');
    }
    if (!ReleaseManifestService.isValidSemver(version)) {
      throw new Error(`Invalid semantic version: ${version}`);
    }
    const normalizedChannel = (channel || 'DEVELOPMENT').toUpperCase();
    if (!VALID_CHANNELS.includes(normalizedChannel)) {
      throw new Error(`Invalid release channel: ${channel}. Allowed: ${VALID_CHANNELS.join(', ')}`);
    }
    if (!ReleaseManifestService.isValidGitSha(sourceCommit)) {
      throw new Error(`Invalid sourceCommit Git SHA: ${sourceCommit}`);
    }

    // Validate artifacts
    if (!Array.isArray(artifacts) || artifacts.length === 0) {
      throw new Error('Release manifest must contain at least one artifact');
    }

    const validatedArtifacts = artifacts.map((art, idx) => {
      if (!art.name || !art.type || !art.sha256) {
        throw new Error(`Artifact at index ${idx} missing required fields (name, type, sha256)`);
      }
      return {
        name: art.name,
        type: art.type,
        sha256: art.sha256,
        sizeBytes: art.sizeBytes || 0,
        signature: art.signature || null,
        url: art.url || null
      };
    });

    const manifest = {
      releaseId,
      version,
      channel: normalizedChannel,
      sourceCommit: sourceCommit.toLowerCase(),
      schemaVersion,
      buildTimestamp: new Date().toISOString(),
      builtBy,
      backend: {
        version: backend.version || version,
        dockerTag: backend.dockerTag || `eh-backend:${version}`,
        nodeVersion: backend.nodeVersion || process.version,
        sha256: backend.sha256 || null
      },
      flutter: {
        version: flutter.version || version,
        buildNumber: flutter.buildNumber || 1,
        targetPlatforms: flutter.targetPlatforms || ['android', 'ios', 'web'],
        minBackendVersion: flutter.minBackendVersion || '1.0.0'
      },
      firmware: firmware || {},
      artifacts: validatedArtifacts,
      sbom: {
        format: sbom.format || 'SPDX-JSON',
        sha256: sbom.sha256 || null,
        componentCount: sbom.componentCount || 0
      },
      compatibility: {
        minClientVersion: compatibility.minClientVersion || '1.0.0',
        minFirmwareVersion: compatibility.minFirmwareVersion || '1.0.0',
        supportedProducts: compatibility.supportedProducts || ['eh-switch-1x', 'eh-switch-2x', 'eh-socket-1x', 'eh-socket-2x']
      },
      releaseNotes: {
        summary: releaseNotes.summary || `Release ${version}`,
        features: releaseNotes.features || [],
        fixes: releaseNotes.fixes || [],
        securityNotes: releaseNotes.securityNotes || [],
        migrationNotes: releaseNotes.migrationNotes || [],
        breakingChanges: releaseNotes.breakingChanges || []
      }
    };

    // Calculate overall manifest digest
    const canonicalString = JSON.stringify(manifest);
    manifest.manifestDigest = ReleaseManifestService.computeSha256(canonicalString);

    return manifest;
  }

  /**
   * Verifies that all artifacts in manifest match expected hashes.
   */
  static verifyArtifactIntegrity(manifest, artifactBuffers = {}) {
    const results = [];
    for (const art of manifest.artifacts) {
      const buffer = artifactBuffers[art.name];
      if (!buffer) {
        results.push({ name: art.name, valid: false, error: 'Artifact buffer missing' });
        continue;
      }
      const actualHash = ReleaseManifestService.computeSha256(buffer);
      const valid = actualHash === art.sha256;
      results.push({
        name: art.name,
        expectedHash: art.sha256,
        actualHash,
        valid,
        error: valid ? null : 'Hash mismatch'
      });
    }
    const allValid = results.length > 0 && results.every(r => r.valid);
    return { allValid, results };
  }
}

module.exports = {
  ReleaseManifestService,
  VALID_CHANNELS
};
