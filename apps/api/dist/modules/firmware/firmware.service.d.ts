/**
 * EH Home Firmware Domain Service
 *
 * Implements business logic, release lifecycle state machine,
 * Git commit traceability, SHA-256 integrity verification, and hardware compatibility.
 */
import { ReleaseReadinessGate } from '@eh-home/contracts';
import { FirmwareRepository } from './firmware.repository';
import { CreateFirmwareReleaseBody, DefineCompatibilityBody, FirmwareArtifactDetail, FirmwareBuildDetail, FirmwareCompatibilityItem, FirmwareFamilyDetail, FirmwareReleaseDetail, ListFirmwareFamiliesQuery, ListFirmwareReleasesQuery, RegisterArtifactBody, RegisterBuildBody, UpdateReleaseStatusBody } from './firmware.schema';
/**
 * Storage abstraction for firmware binary artifacts (Step 22)
 * Allows plugging in future S3CompatibleArtifactStore without modifying business logic.
 */
export interface IFirmwareArtifactStore {
    storeArtifact(key: string, data: Buffer, contentType?: string): Promise<{
        storagePath: string;
        sha256: string;
        size: number;
    }>;
    getArtifactUrl(key: string): Promise<string>;
    verifyIntegrity(data: Buffer, expectedSha256: string): boolean;
}
export declare class InMemoryArtifactStore implements IFirmwareArtifactStore {
    private storage;
    storeArtifact(key: string, data: Buffer): Promise<{
        storagePath: string;
        sha256: string;
        size: number;
    }>;
    getArtifactUrl(key: string): Promise<string>;
    verifyIntegrity(data: Buffer, expectedSha256: string): boolean;
}
export declare class FirmwareService {
    private repository;
    private artifactStore;
    constructor(repository: FirmwareRepository, artifactStore?: IFirmwareArtifactStore);
    getArtifactStore(): IFirmwareArtifactStore;
    /**
     * Lists firmware families matching query.
     */
    listFamilies(query: ListFirmwareFamiliesQuery): Promise<{
        items: FirmwareFamilyDetail[];
        total: number;
        limit: number;
        offset: number;
    }>;
    /**
     * Retrieves a single firmware family by ID.
     */
    getFamily(id: string): Promise<FirmwareFamilyDetail | null>;
    /**
     * Lists firmware releases matching filters.
     */
    listReleases(query: ListFirmwareReleasesQuery): Promise<{
        items: FirmwareReleaseDetail[];
        total: number;
        limit: number;
        offset: number;
    }>;
    /**
     * Retrieves single firmware release by ID.
     */
    getRelease(id: string): Promise<FirmwareReleaseDetail | null>;
    /**
     * Creates a new firmware release in DRAFT or INITIAL status.
     */
    createRelease(data: CreateFirmwareReleaseBody): Promise<FirmwareReleaseDetail>;
    /**
     * Governs firmware release lifecycle transitions.
     * State Machine:
     * DRAFT -> BUILDING -> VALIDATION -> APPROVED -> RELEASED -> DEPRECATED -> RETIRED
     * With emergency security revocation into REVOKED (Terminal).
     */
    updateReleaseStatus(id: string, body: UpdateReleaseStatusBody): Promise<FirmwareReleaseDetail>;
    /**
     * Registers a compilation build against a firmware release.
     */
    registerBuild(data: RegisterBuildBody): Promise<FirmwareBuildDetail>;
    /**
     * Registers a binary artifact associated with a build.
     */
    registerArtifact(data: RegisterArtifactBody): Promise<FirmwareArtifactDetail>;
    /**
     * Defines and verifies hardware revision compatibility for a firmware release.
     */
    defineCompatibility(releaseId: string, data: DefineCompatibilityBody): Promise<FirmwareCompatibilityItem>;
    /**
     * Retrieves compatibility definitions for a release.
     */
    getCompatibility(releaseId: string): Promise<FirmwareCompatibilityItem[]>;
    /**
     * Evaluates automated release-readiness gates (Part 08).
     * Verifies source identity, build registration, required binary artifacts,
     * SHA-256 integrity, hardware compatibility, and non-terminal lifecycle status.
     */
    evaluateReleaseReadiness(releaseId: string): Promise<ReleaseReadinessGate>;
}
//# sourceMappingURL=firmware.service.d.ts.map