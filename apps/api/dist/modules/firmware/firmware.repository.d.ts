/**
 * EH Home Firmware Repository
 *
 * Implements persistence layer via Drizzle ORM and fallback memory store.
 */
import { EhDatabase } from '@eh-home/db-schema';
import { CreateFirmwareReleaseBody, DefineCompatibilityBody, FirmwareArtifactDetail, FirmwareBuildDetail, FirmwareCompatibilityItem, FirmwareFamilyDetail, FirmwareReleaseDetail, ListFirmwareFamiliesQuery, ListFirmwareReleasesQuery, RegisterArtifactBody, RegisterBuildBody } from './firmware.schema';
export declare class FirmwareRepository {
    private db?;
    private memoryFamilies;
    private memoryReleases;
    private memoryBuilds;
    private memoryArtifacts;
    private memoryCompatibilities;
    private initializedMemory;
    constructor(db?: EhDatabase);
    private ensureMemoryCache;
    listFamilies(query: ListFirmwareFamiliesQuery): Promise<{
        items: FirmwareFamilyDetail[];
        total: number;
    }>;
    getFamilyById(id: string): Promise<FirmwareFamilyDetail | null>;
    listReleases(query: ListFirmwareReleasesQuery): Promise<{
        items: FirmwareReleaseDetail[];
        total: number;
    }>;
    getReleaseById(id: string): Promise<FirmwareReleaseDetail | null>;
    getReleaseByFamilyAndVersion(firmwareFamily: string, version: string): Promise<FirmwareReleaseDetail | null>;
    createRelease(data: CreateFirmwareReleaseBody): Promise<FirmwareReleaseDetail>;
    updateReleaseStatus(id: string, newStatus: string, releasedAt?: string | null): Promise<FirmwareReleaseDetail | null>;
    registerBuild(data: RegisterBuildBody): Promise<FirmwareBuildDetail>;
    getBuildById(id: string): Promise<FirmwareBuildDetail | null>;
    registerArtifact(data: RegisterArtifactBody): Promise<FirmwareArtifactDetail>;
    getArtifactsByBuildId(buildId: string): Promise<FirmwareArtifactDetail[]>;
    defineCompatibility(firmwareReleaseId: string, data: DefineCompatibilityBody): Promise<FirmwareCompatibilityItem>;
    getCompatibilitiesByReleaseId(releaseId: string): Promise<FirmwareCompatibilityItem[]>;
    checkHardwareRevisionExists(hardwareRevisionId: string): Promise<boolean>;
}
//# sourceMappingURL=firmware.repository.d.ts.map