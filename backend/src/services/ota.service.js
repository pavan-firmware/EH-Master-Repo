'use strict';

/**
 * EH Home — OTA Firmware Release Service (Phase 8)
 *
 * Manages signed OTA firmware releases and compatibility matching.
 */

const path = require('path');
const { SchemaValidator } = require('../../../packages/contracts/validator');

class OtaService {
  constructor(options = {}) {
    this.releases = new Map();
    this.validator = options.validator || new SchemaValidator();
    if (!this.validator.schemas.has('OTAManifest')) {
      try {
        const schemaPath = path.join(__dirname, '../../../packages/contracts/ota/ota-manifest.schema.json');
        this.validator.loadSchema(schemaPath);
      } catch (err) {
        // Ignored if schema path not found in custom environments
      }
    }
  }

  semverCompare(v1, v2) {
    if (!v1 || !v2) return 0;
    const p1 = v1.split('.').map(Number);
    const p2 = v2.split('.').map(Number);
    for (let i = 0; i < 3; i++) {
      if (p1[i] > p2[i]) return 1;
      if (p1[i] < p2[i]) return -1;
    }
    return 0;
  }

  registerRelease(manifest) {
    const result = this.validator.validate('OTAManifest', manifest);
    if (!result.valid) {
      throw new Error(`Invalid OTA manifest: ${result.errors ? result.errors.join(', ') : 'unknown error'}`);
    }

    this.releases.set(manifest.releaseId, manifest);
    return manifest;
  }

  getRelease(releaseId) {
    return this.releases.get(releaseId) || null;
  }

  listReleases(productVariantId = null) {
    const list = Array.from(this.releases.values());
    if (productVariantId) {
      return list.filter(r => r.productVariantId === productVariantId);
    }
    return list;
  }

  checkUpdate({ productVariantId, hardwareRevision, currentVersion }) {
    if (!productVariantId || !currentVersion) {
      throw new Error('productVariantId and currentVersion are required');
    }

    const compatibleReleases = Array.from(this.releases.values()).filter(r => {
      if (r.productVariantId !== productVariantId) return false;
      if (hardwareRevision && r.hardwareRevision !== hardwareRevision) return false;
      // Must be newer than current version
      if (this.semverCompare(r.version, currentVersion) <= 0) return false;
      // Must satisfy minimum firmware requirement
      if (r.minFirmwareVersion && this.semverCompare(currentVersion, r.minFirmwareVersion) < 0) return false;
      return true;
    });

    if (compatibleReleases.length === 0) {
      return { updateAvailable: false, release: null };
    }

    // Sort to get highest version
    compatibleReleases.sort((a, b) => this.semverCompare(b.version, a.version));
    return {
      updateAvailable: true,
      release: compatibleReleases[0]
    };
  }
}

module.exports = { OtaService };
