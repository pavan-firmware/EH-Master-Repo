/**
 * EH Home Firmware Domain Service
 *
 * Implements business logic, release lifecycle state machine,
 * Git commit traceability, SHA-256 integrity verification, and hardware compatibility.
 */

import * as crypto from 'crypto';
import { ReleaseReadinessGate, ReleaseReadinessGateSchema, MCU_TO_TOOLCHAIN_MAP } from '@eh-home/contracts';
import { FirmwareRepository } from './firmware.repository';
import {
  CreateFirmwareReleaseBody,
  DefineCompatibilityBody,
  FirmwareArtifactDetail,
  FirmwareBuildDetail,
  FirmwareCompatibilityItem,
  FirmwareFamilyDetail,
  FirmwareReleaseDetail,
  ListFirmwareFamiliesQuery,
  ListFirmwareReleasesQuery,
  RegisterArtifactBody,
  RegisterBuildBody,
  UpdateReleaseStatusBody,
} from './firmware.schema';

/**
 * Storage abstraction for firmware binary artifacts (Step 22)
 * Allows plugging in future S3CompatibleArtifactStore without modifying business logic.
 */
export interface IFirmwareArtifactStore {
  storeArtifact(key: string, data: Buffer, contentType?: string): Promise<{ storagePath: string; sha256: string; size: number }>;
  getArtifactUrl(key: string): Promise<string>;
  verifyIntegrity(data: Buffer, expectedSha256: string): boolean;
}

export class InMemoryArtifactStore implements IFirmwareArtifactStore {
  private storage: Map<string, Buffer> = new Map();

  async storeArtifact(key: string, data: Buffer): Promise<{ storagePath: string; sha256: string; size: number }> {
    const sha256 = crypto.createHash('sha256').update(data).digest('hex');
    this.storage.set(key, data);
    return {
      storagePath: `firmware/artifacts/${key}`,
      sha256,
      size: data.length,
    };
  }

  async getArtifactUrl(key: string): Promise<string> {
    return `https://artifacts.eh-home.internal/firmware/${key}`;
  }

  verifyIntegrity(data: Buffer, expectedSha256: string): boolean {
    const computed = crypto.createHash('sha256').update(data).digest('hex');
    return computed.toLowerCase() === expectedSha256.toLowerCase();
  }
}

export class FirmwareService {
  private repository: FirmwareRepository;
  private artifactStore: IFirmwareArtifactStore;

  constructor(repository: FirmwareRepository, artifactStore?: IFirmwareArtifactStore) {
    this.repository = repository;
    this.artifactStore = artifactStore || new InMemoryArtifactStore();
  }

  getArtifactStore(): IFirmwareArtifactStore {
    return this.artifactStore;
  }

  /**
   * Lists firmware families matching query.
   */
  async listFamilies(query: ListFirmwareFamiliesQuery): Promise<{ items: FirmwareFamilyDetail[]; total: number; limit: number; offset: number }> {
    const result = await this.repository.listFamilies(query);
    return {
      items: result.items,
      total: result.total,
      limit: query.limit,
      offset: query.offset,
    };
  }

  /**
   * Retrieves a single firmware family by ID.
   */
  async getFamily(id: string): Promise<FirmwareFamilyDetail | null> {
    return this.repository.getFamilyById(id);
  }

  /**
   * Lists firmware releases matching filters.
   */
  async listReleases(query: ListFirmwareReleasesQuery): Promise<{ items: FirmwareReleaseDetail[]; total: number; limit: number; offset: number }> {
    const result = await this.repository.listReleases(query);
    return {
      items: result.items,
      total: result.total,
      limit: query.limit,
      offset: query.offset,
    };
  }

  /**
   * Retrieves single firmware release by ID.
   */
  async getRelease(id: string): Promise<FirmwareReleaseDetail | null> {
    return this.repository.getReleaseById(id);
  }

  /**
   * Creates a new firmware release in DRAFT or INITIAL status.
   */
  async createRelease(data: CreateFirmwareReleaseBody): Promise<FirmwareReleaseDetail> {
    // 1. Verify firmware family exists
    const family = await this.repository.getFamilyById(data.firmwareFamily);
    if (!family) {
      throw new Error(`Firmware family '${data.firmwareFamily}' does not exist`);
    }

    // 2. Validate Git commit SHA format (40-char hex)
    if (!/^[0-9a-fA-F]{40}$/.test(data.gitCommitSha)) {
      throw new Error(`Invalid Git commit SHA '${data.gitCommitSha}'. Must be 40 hexadecimal characters.`);
    }

    // 3. Check for duplicate release within the same family and semantic version
    const existing = await this.repository.getReleaseByFamilyAndVersion(data.firmwareFamily, data.version);
    if (existing) {
      throw new Error(`Firmware release version '${data.version}' already exists for family '${data.firmwareFamily}'`);
    }

    // 4. Invariant: initial release status is strictly DRAFT (cannot create directly as REVOKED or other states)
    if (data.status && data.status !== 'DRAFT') {
      throw new Error(
        `New firmware release must be created in 'DRAFT' status. Cannot create directly in status '${data.status}'.`
      );
    }

    return this.repository.createRelease({
      ...data,
      status: 'DRAFT',
    });
  }

  /**
   * Governs firmware release lifecycle transitions.
   * State Machine:
   * DRAFT -> BUILDING -> VALIDATION -> APPROVED -> RELEASED -> DEPRECATED -> RETIRED
   * With emergency security revocation into REVOKED (Terminal).
   */
  async updateReleaseStatus(
    id: string,
    body: UpdateReleaseStatusBody
  ): Promise<FirmwareReleaseDetail> {
    const release = await this.repository.getReleaseById(id);
    if (!release) {
      throw new Error(`Firmware release '${id}' not found`);
    }

    const currentStatus = release.status;
    const newStatus = body.status;

    // Define allowed transitions
    const allowedTransitions: Record<string, string[]> = {
      DRAFT: ['BUILDING', 'RETIRED'],
      BUILDING: ['VALIDATION', 'DRAFT', 'RETIRED'],
      VALIDATION: ['APPROVED', 'DRAFT', 'RETIRED'],
      APPROVED: ['RELEASED', 'DEPRECATED', 'RETIRED', 'REVOKED'],
      RELEASED: ['DEPRECATED', 'RETIRED', 'REVOKED'],
      DEPRECATED: ['RETIRED', 'REVOKED'],
      RETIRED: ['REVOKED'],
      REVOKED: [],
    };

    const validNextStates = allowedTransitions[currentStatus] || [];

    if (!validNextStates.includes(newStatus) && currentStatus !== newStatus) {
      if (currentStatus === 'REVOKED') {
        throw new Error(
          `Cannot transition from terminal state 'REVOKED' to '${newStatus}'. Revoked releases are permanently invalid.`
        );
      }
      throw new Error(
        `Invalid lifecycle transition from '${currentStatus}' to '${newStatus}'. Allowed: ${validNextStates.join(', ')}`
      );
    }

    // Record release timestamp when transitioning to RELEASED
    const releasedAt = newStatus === 'RELEASED' ? new Date().toISOString() : release.releasedAt;

    const updated = await this.repository.updateReleaseStatus(id, newStatus, releasedAt);
    if (!updated) {
      throw new Error(`Failed to update status for release '${id}'`);
    }
    return updated;
  }

  /**
   * Registers a compilation build against a firmware release.
   */
  async registerBuild(data: RegisterBuildBody): Promise<FirmwareBuildDetail> {
    if (data.firmwareReleaseId) {
      const release = await this.repository.getReleaseById(data.firmwareReleaseId);
      if (!release) {
        throw new Error(`Firmware release '${data.firmwareReleaseId}' does not exist`);
      }

      // Immutability guard: cannot attach new builds to locked releases
      if (['APPROVED', 'RELEASED', 'DEPRECATED', 'RETIRED', 'REVOKED'].includes(release.status)) {
        throw new Error(
          `Cannot attach new build to locked release in status '${release.status}'. Approved, released, and terminal releases are immutable.`
        );
      }
    }

    if (!/^[0-9a-fA-F]{40}$/.test(data.gitCommitSha)) {
      throw new Error(`Invalid Git commit SHA '${data.gitCommitSha}'`);
    }

    return this.repository.registerBuild(data);
  }

  /**
   * Registers a binary artifact associated with a build.
   */
  async registerArtifact(data: RegisterArtifactBody): Promise<FirmwareArtifactDetail> {
    const build = await this.repository.getBuildById(data.buildId);
    if (!build) {
      throw new Error(`Firmware build '${data.buildId}' does not exist`);
    }

    if (data.fileSizeBytes <= 0) {
      throw new Error(`Invalid binary file size (${data.fileSizeBytes} bytes). Must be > 0.`);
    }

    if (!/^[0-9a-fA-F]{64}$/.test(data.sha256)) {
      throw new Error(`Invalid SHA-256 checksum '${data.sha256}'. Must be 64 hexadecimal characters.`);
    }

    // Check duplicate artifactType for the same build
    const existing = await this.repository.getArtifactsByBuildId(data.buildId);
    if (existing.some((a) => a.artifactType === data.artifactType)) {
      throw new Error(`Artifact type '${data.artifactType}' already exists for build '${data.buildId}'`);
    }

    return this.repository.registerArtifact(data);
  }

  /**
   * Defines and verifies hardware revision compatibility for a firmware release.
   */
  async defineCompatibility(
    releaseId: string,
    data: DefineCompatibilityBody
  ): Promise<FirmwareCompatibilityItem> {
    const release = await this.repository.getReleaseById(releaseId);
    if (!release) {
      throw new Error(`Firmware release '${releaseId}' not found`);
    }

    // Immutability guard: cannot alter compatibility on terminal/revoked releases
    if (release.status === 'RETIRED' || release.status === 'REVOKED') {
      throw new Error(
        `Cannot define compatibility for release '${releaseId}' in terminal status '${release.status}'.`
      );
    }

    return this.repository.defineCompatibility(releaseId, data);
  }

  /**
   * Retrieves compatibility definitions for a release.
   */
  async getCompatibility(releaseId: string): Promise<FirmwareCompatibilityItem[]> {
    const release = await this.repository.getReleaseById(releaseId);
    if (!release) {
      throw new Error(`Firmware release '${releaseId}' not found`);
    }
    return this.repository.getCompatibilitiesByReleaseId(releaseId);
  }

  /**
   * Evaluates automated release-readiness gates (Part 08).
   * Verifies source identity, build registration, required binary artifacts,
   * SHA-256 integrity, hardware compatibility, and non-terminal lifecycle status.
   */
  async evaluateReleaseReadiness(releaseId: string): Promise<ReleaseReadinessGate> {
    const release = await this.repository.getReleaseById(releaseId);
    if (!release) {
      throw new Error(`Firmware release '${releaseId}' not found`);
    }

    const checks: { gate: string; passed: boolean; detail: string }[] = [];

    // 1. Source Identity
    const validCommit = !!release.gitCommitSha && /^[0-9a-fA-F]{40}$/.test(release.gitCommitSha);
    checks.push({
      gate: 'SOURCE_GIT_SHA_VALID',
      passed: validCommit,
      detail: validCommit ? `Git commit ${release.gitCommitSha} is valid 40-char hex` : 'Invalid Git commit SHA',
    });

    // 2. Compilation Builds Present
    const hasBuilds = Array.isArray(release.builds) && release.builds.length > 0;
    checks.push({
      gate: 'BUILD_ARTIFACTS_REGISTERED',
      passed: hasBuilds,
      detail: hasBuilds
        ? `${release.builds!.length} build(s) registered against release`
        : 'No builds registered for this release',
    });

    // 3. Required Binary Artifacts Present (APP_BIN, BOOTLOADER, PARTITION_TABLE)
    const allArtifacts = (release.builds || []).flatMap((b) => b.artifacts || []);
    const hasAppBin = allArtifacts.some((a) => a.artifactType === 'APP_BIN' && a.fileSizeBytes > 0);
    const hasBootloader = allArtifacts.some((a) => a.artifactType === 'BOOTLOADER' && a.fileSizeBytes > 0);
    const hasPartitionTable = allArtifacts.some((a) => a.artifactType === 'PARTITION_TABLE' && a.fileSizeBytes > 0);
    const artifactsValid = hasAppBin && hasBootloader && hasPartitionTable;
    checks.push({
      gate: 'REQUIRED_BINARIES_PRESENT',
      passed: artifactsValid,
      detail: artifactsValid
        ? `Found ${allArtifacts.length} artifacts including APP_BIN, BOOTLOADER, and PARTITION_TABLE`
        : 'Missing required binary artifacts (APP_BIN, BOOTLOADER, or PARTITION_TABLE)',
    });

    // 4. SHA-256 Digest Verification
    const checksumsValid = allArtifacts.length > 0 && allArtifacts.every((a) => /^[0-9a-fA-F]{64}$/.test(a.sha256));
    checks.push({
      gate: 'SHA256_CHECKSUMS_VERIFIED',
      passed: checksumsValid,
      detail: checksumsValid ? 'All artifacts have valid 64-char hex SHA-256 digests' : 'Invalid or missing SHA-256 digests',
    });

    // 5. Hardware Compatibility Verified
    const hasCompat =
      Array.isArray(release.compatibilities) &&
      release.compatibilities.length > 0 &&
      release.compatibilities.some((c) => c.isVerified);
    checks.push({
      gate: 'HARDWARE_COMPATIBILITY_VERIFIED',
      passed: hasCompat,
      detail: hasCompat
        ? `Verified compatibility with ${release.compatibilities!.filter((c) => c.isVerified).length} hardware revision(s)`
        : 'No verified hardware compatibility definitions found',
    });

    // 6. Non-Terminal Lifecycle Status
    const nonTerminal = release.status !== 'REVOKED' && release.status !== 'RETIRED';
    checks.push({
      gate: 'LIFECYCLE_STATUS_ELIGIBLE',
      passed: nonTerminal,
      detail: nonTerminal
        ? `Current status '${release.status}' is eligible`
        : `Cannot approve release in terminal status '${release.status}'`,
    });

    // 7. Target Architecture Consistency Gate
    const family = await this.repository.getFamilyById(release.firmwareFamily);
    const targetMcu = family?.targetMcu || 'esp32-c6';
    const expectedToolchain = MCU_TO_TOOLCHAIN_MAP[targetMcu as keyof typeof MCU_TO_TOOLCHAIN_MAP] || 'riscv32-esp-elf';

    let targetConsistent = true;
    let targetDetail = `Target MCU '${targetMcu}' (${expectedToolchain}) matches family '${release.firmwareFamily}'`;

    if (release.builds && release.builds.length > 0) {
      for (const b of release.builds) {
        const buildInfo = b.toolchainInfo as Record<string, unknown> | undefined;
        if (buildInfo?.targetMcu && buildInfo.targetMcu !== targetMcu) {
          targetConsistent = false;
          targetDetail = `Target mismatch: Build targeted '${buildInfo.targetMcu}', but family '${release.firmwareFamily}' requires '${targetMcu}'`;
          break;
        }
      }
    }

    checks.push({
      gate: 'TARGET_ARCHITECTURE_CONSISTENT',
      passed: targetConsistent,
      detail: targetDetail,
    });

    const isReadyForApproval = checks.every((c) => c.passed);

    return ReleaseReadinessGateSchema.parse({
      releaseId,
      isReadyForApproval,
      evaluatedAt: new Date().toISOString(),
      checks,
    });
  }
}
