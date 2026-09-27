import {
  OtaManifest,
  OtaManifestSchema,
  OtaExecutionState,
  validateOtaStateTransition,
  CANONICAL_FIRMWARE_FAMILIES
} from '@eh-home/contracts';
import { IOtaRepository } from './ota.repository';
import * as crypto from 'crypto';

export function semverCompare(a: string, b: string): number {
  const pa = a.split('.').map((n) => parseInt(n, 10) || 0);
  const pb = b.split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) {
    const diff = (pa[i] || 0) - (pb[i] || 0);
    if (diff !== 0) return diff > 0 ? 1 : -1;
  }
  return 0;
}

export interface OtaCheckResult {
  updateAvailable: boolean;
  release: any | null;
  reason?: string;
}

export interface VerifySignatureParams {
  artifactBuffer: Buffer;
  expectedSha256: string;
  ed25519SignatureHex: string;
  publicKeyPemOrDer?: string;
}

export interface OtaAuthorizationContext {
  deviceTrustState?: string;
  deviceHardwareRevision?: string;
  deviceMcu?: string;
  deviceProductVariantId?: string;
}

export interface OtaAuthorizationResult {
  authorized: boolean;
  jobId: string;
  releaseId: string;
  status: OtaExecutionState;
  errorCode?: string;
  errorMessage?: string;
}

export class OtaService {
  private repo: IOtaRepository;

  constructor(repo: IOtaRepository) {
    this.repo = repo;
  }

  public async registerRelease(manifest: OtaManifest, additional?: any): Promise<any> {
    const parsed = OtaManifestSchema.parse(manifest);

    // Validate downloadUrl is HTTPS
    if (!parsed.downloadUrl.startsWith('https://')) {
      throw new Error('Security Violation: downloadUrl must use secure HTTPS protocol');
    }

    // Validate binary size
    if (parsed.binarySizeBytes > 1792 * 1024) {
      throw new Error(`Binary size ${parsed.binarySizeBytes} bytes exceeds maximum partition capacity (1792 KB)`);
    }

    // Fail closed on invalid / missing cryptographic signature
    if (!parsed.ed25519Signature || parsed.ed25519Signature.length !== 128) {
      throw new Error('Security Violation: Release manifest missing valid 128-char hex Ed25519 signature');
    }

    // Fail closed on invalid / missing SHA-256 digest
    if (!parsed.sha256 || parsed.sha256.length !== 64) {
      throw new Error('Security Violation: Release manifest missing valid 64-char hex SHA-256 digest');
    }

    await this.repo.registerRelease(parsed, additional);
    return this.repo.getReleaseById(parsed.releaseId);
  }

  public async checkUpdate(params: {
    productVariantId: string;
    hardwareRevision: string;
    currentVersion: string;
    targetChannel?: string;
  }): Promise<OtaCheckResult> {
    const releases = await this.repo.findReleasesForVariant(params.productVariantId, params.hardwareRevision);

    // Filter strictly by canonical RELEASED or legacy PUBLISHED status only
    const published = (releases || []).filter(
      (r: any) => r.status === 'RELEASED' || r.status === 'PUBLISHED'
    );
    if (published.length === 0) {
      return { updateAvailable: false, release: null, reason: 'NO_RELEASES_FOR_HARDWARE' };
    }

    // Sort releases ascending by semver
    published.sort((a, b) => semverCompare(a.version, b.version));

    // Find the next eligible upgrade
    for (const rel of published) {
      const cmp = semverCompare(rel.version, params.currentVersion);
      if (cmp <= 0) {
        // Version is older or already current (anti-rollback guard)
        continue;
      }

      // Check bridge / minimum firmware version
      if (rel.minFirmwareVersion && semverCompare(params.currentVersion, rel.minFirmwareVersion) < 0) {
        // Device current version is lower than minimum bridge version required
        continue;
      }

      return {
        updateAvailable: true,
        release: rel
      };
    }

    return {
      updateAvailable: false,
      release: null,
      reason: 'ALREADY_UP_TO_DATE'
    };
  }

  public verifyArtifactIntegrity(params: VerifySignatureParams): { valid: boolean; reason?: string } {
    const computedSha = crypto.createHash('sha256').update(params.artifactBuffer).digest('hex');
    if (computedSha.toLowerCase() !== params.expectedSha256.toLowerCase()) {
      return {
        valid: false,
        reason: `SHA-256 hash mismatch: computed ${computedSha} != expected ${params.expectedSha256}`
      };
    }

    if (!params.ed25519SignatureHex || params.ed25519SignatureHex.length !== 128) {
      return {
        valid: false,
        reason: 'Invalid Ed25519 signature: must be 128 hex characters'
      };
    }

    return { valid: true };
  }

  public async createOtaJob(params: {
    deviceId: string;
    releaseId: string;
    rolloutId?: string;
    fromVersion: string;
  }): Promise<any> {
    const release = await this.repo.getReleaseById(params.releaseId);
    if (!release) {
      throw new Error(`Firmware release ${params.releaseId} not found`);
    }

    return this.repo.createOtaJob({
      deviceId: params.deviceId,
      releaseId: params.releaseId,
      rolloutId: params.rolloutId,
      firmwareFamily: release.firmwareFamily,
      targetVersion: release.version,
      fromVersion: params.fromVersion,
      status: 'REQUESTED',
      progressPercent: 0,
      sha256: release.sha256,
      ed25519Signature: release.ed25519Signature
    });
  }

  /**
   * Evaluates the multi-point security gate before an OTA job can transition to AUTHORIZED.
   * REQUESTED does NOT imply AUTHORIZED.
   */
  public async authorizeOtaJob(
    jobId: string,
    context: OtaAuthorizationContext = {}
  ): Promise<OtaAuthorizationResult> {
    const job = await this.repo.getOtaJob(jobId);
    if (!job) {
      throw new Error(`OTA job '${jobId}' not found`);
    }

    if (job.status !== 'REQUESTED') {
      throw new Error(`Cannot authorize OTA job in state '${job.status}'. Expected 'REQUESTED'.`);
    }

    const release = await this.repo.getReleaseById(job.releaseId);
    if (!release) {
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_RELEASE_NOT_FOUND', `Release ${job.releaseId} not found`);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_RELEASE_NOT_FOUND',
        errorMessage: `Release ${job.releaseId} not found`
      };
    }

    // Gate 1: Device Trust State
    const trust = context.deviceTrustState || 'TRUSTED';
    if (['REVOKED', 'DECOMMISSIONED', 'QUARANTINED'].includes(trust)) {
      const err = `Device '${job.deviceId}' is ${trust} and not authorized for OTA updates`;
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_REVOKED_DEVICE', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_REVOKED_DEVICE',
        errorMessage: err
      };
    }

    // Gate 2: Release Lifecycle Status (Must be strictly RELEASED or legacy PUBLISHED only)
    const relStatus = release.status;
    if (!relStatus || (relStatus !== 'RELEASED' && relStatus !== 'PUBLISHED')) {
      const err = `Firmware release '${release.id}' has unapproved lifecycle status '${relStatus || 'MISSING'}'. Production OTA authorization strictly requires RELEASED or legacy PUBLISHED.`;
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_LIFECYCLE_NOT_RELEASED', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_LIFECYCLE_NOT_RELEASED',
        errorMessage: err
      };
    }

    // Gate 3: Firmware Family Compatibility
    if (context.deviceProductVariantId) {
      const canonicalFamily = CANONICAL_FIRMWARE_FAMILIES[release.firmwareFamily];
      if (canonicalFamily && !canonicalFamily.productVariants.includes(context.deviceProductVariantId)) {
        const err = `Firmware family '${release.firmwareFamily}' is incompatible with variant '${context.deviceProductVariantId}'`;
        await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_FAMILY_MISMATCH', err);
        return {
          authorized: false,
          jobId,
          releaseId: job.releaseId,
          status: 'FAILED',
          errorCode: 'OTA_AUTH_FAMILY_MISMATCH',
          errorMessage: err
        };
      }
    }

    // Gate 4: Hardware Revision Compatibility
    if (context.deviceHardwareRevision && release.hardwareRevision) {
      if (context.deviceHardwareRevision !== release.hardwareRevision) {
        const err = `Hardware revision mismatch: device is '${context.deviceHardwareRevision}', release requires '${release.hardwareRevision}'`;
        await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_HARDWARE_INCOMPATIBLE', err);
        return {
          authorized: false,
          jobId,
          releaseId: job.releaseId,
          status: 'FAILED',
          errorCode: 'OTA_AUTH_HARDWARE_INCOMPATIBLE',
          errorMessage: err
        };
      }
    }

    // Gate 5: Target MCU Compatibility & Exact Match (Canonical Production: esp32-c6, esp32-s3)
    if (!context.deviceMcu || typeof context.deviceMcu !== 'string' || context.deviceMcu.trim() === '') {
      const err = 'Target MCU missing: device MCU must be explicitly specified for OTA authorization';
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_TARGET_MISMATCH', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_TARGET_MISMATCH',
        errorMessage: err
      };
    }

    const familyMeta = CANONICAL_FIRMWARE_FAMILIES[release.firmwareFamily];
    if (familyMeta) {
      if (familyMeta.targetMcu !== context.deviceMcu) {
        const err = `Target MCU mismatch: device is '${context.deviceMcu}', release requires '${familyMeta.targetMcu}'`;
        await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_TARGET_MISMATCH', err);
        return {
          authorized: false,
          jobId,
          releaseId: job.releaseId,
          status: 'FAILED',
          errorCode: 'OTA_AUTH_TARGET_MISMATCH',
          errorMessage: err
        };
      }
    } else {
      const err = `Unknown firmware family '${release.firmwareFamily}' for MCU compatibility validation`;
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_TARGET_MISMATCH', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_TARGET_MISMATCH',
        errorMessage: err
      };
    }

    // Gate 6: Digital Signature & Integrity Presence
    if (!release.ed25519Signature || release.ed25519Signature.length !== 128) {
      const err = 'Cryptographic signature is missing or invalid (must be 128 hex chars)';
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_SIGNATURE_INVALID', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_SIGNATURE_INVALID',
        errorMessage: err
      };
    }

    if (!release.sha256 || release.sha256.length !== 64) {
      const err = 'Cryptographic SHA-256 digest is missing or invalid (must be 64 hex chars)';
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_HASH_INVALID', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_HASH_INVALID',
        errorMessage: err
      };
    }

    // Gate 7: Anti-Rollback Rule (Target version must be strictly greater than fromVersion)
    if (semverCompare(job.targetVersion, job.fromVersion) <= 0) {
      const err = `Anti-rollback violation: target version '${job.targetVersion}' <= current version '${job.fromVersion}'`;
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_ANTI_ROLLBACK', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_ANTI_ROLLBACK',
        errorMessage: err
      };
    }

    // Gate 8: Bridge / Minimum Firmware Version Gating
    if (release.minFirmwareVersion && semverCompare(job.fromVersion, release.minFirmwareVersion) < 0) {
      const err = `Bridge version requirement not met: current version '${job.fromVersion}' < required minimum '${release.minFirmwareVersion}'`;
      await this.updateJobProgress(jobId, 'FAILED', 0, 'OTA_AUTH_BRIDGE_VERSION_UNMET', err);
      return {
        authorized: false,
        jobId,
        releaseId: job.releaseId,
        status: 'FAILED',
        errorCode: 'OTA_AUTH_BRIDGE_VERSION_UNMET',
        errorMessage: err
      };
    }

    // All gates passed! Transition to AUTHORIZED
    const updated = await this.updateJobProgress(jobId, 'AUTHORIZED', 0);
    return {
      authorized: true,
      jobId,
      releaseId: job.releaseId,
      status: updated.status
    };
  }

  public async updateJobProgress(
    jobId: string,
    status: OtaExecutionState,
    progressPercent = 0,
    errorCode?: string,
    errorMessage?: string
  ): Promise<any> {
    const existing = await this.repo.getOtaJob(jobId);
    if (!existing) {
      throw new Error(`OTA job '${jobId}' not found`);
    }

    // Enforce canonical state machine transition validation
    validateOtaStateTransition(existing.status as OtaExecutionState, status);

    return this.repo.updateOtaJob(jobId, {
      status,
      progressPercent,
      errorCode: errorCode || null,
      errorMessage: errorMessage || null
    });
  }

  public async cancelOtaJob(jobId: string, reason = 'Cancelled by operator'): Promise<any> {
    return this.updateJobProgress(jobId, 'CANCELLED', 0, 'CANCELLED_BY_OPERATOR', reason);
  }

  public async getLatestJob(deviceId: string): Promise<any | null> {
    return this.repo.getLatestDeviceJob(deviceId);
  }

  public async getJobById(jobId: string): Promise<any | null> {
    return this.repo.getOtaJob(jobId);
  }
}
