"use strict";
/**
 * EH Home Firmware Repository
 *
 * Implements persistence layer via Drizzle ORM and fallback memory store.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirmwareRepository = void 0;
const drizzle_orm_1 = require("drizzle-orm");
const contracts_1 = require("@eh-home/contracts");
const db_schema_1 = require("@eh-home/db-schema");
class FirmwareRepository {
    db;
    memoryFamilies = new Map();
    memoryReleases = new Map();
    memoryBuilds = new Map();
    memoryArtifacts = new Map();
    memoryCompatibilities = new Map();
    initializedMemory = false;
    constructor(db) {
        this.db = db;
        this.ensureMemoryCache();
    }
    ensureMemoryCache() {
        if (this.initializedMemory)
            return;
        // Seed 6 canonical firmware families from product definitions
        const canonicalFamilies = [
            {
                id: 'esp32c6-switch-platform',
                displayName: 'ESP32-C6 Smart Switch Platform',
                targetMcu: 'esp32-c6',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'Firmware platform for 1X, 2X, 3X, 4X Smart Relay Switches',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
            {
                id: 'esp32c6-socket-platform',
                displayName: 'ESP32-C6 Smart Socket Platform',
                targetMcu: 'esp32-c6',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'Firmware platform for 1X, 2X, 3X 16A Smart Power Sockets',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
            {
                id: 'esp32c6-fan-platform',
                displayName: 'ESP32-C6 Smart Fan Controller Platform',
                targetMcu: 'esp32-c6',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'Firmware platform for Triac-based Smart Fan Regulators',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
            {
                id: 'esp32c6-light-platform',
                displayName: 'ESP32-C6 Smart Lighting Platform',
                targetMcu: 'esp32-c6',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'Firmware platform for CCT Dual-PWM Smart Lights',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
            {
                id: 'esp32s3-hub-platform',
                displayName: 'ESP32-S3 Smart Controller / Hub Platform',
                targetMcu: 'esp32-s3',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'High-performance gateway and Matter border controller',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
            {
                id: 'esp32c6-sensor-platform',
                displayName: 'ESP32-C6 Sensor Node Platform',
                targetMcu: 'esp32-c6',
                defaultIdfVersion: 'v5.4.1',
                repositoryUrl: 'https://github.com/eh-home/firmware-esp32.git',
                description: 'Low-power environmental sensor and presence node',
                createdAt: '2026-01-01T00:00:00Z',
                updatedAt: '2026-01-01T00:00:00Z',
            },
        ];
        canonicalFamilies.forEach((f) => this.memoryFamilies.set(f.id, f));
        // Seed a baseline production release for smart switch
        const baselineRelease = {
            id: 'rel_switch_v1_0_0',
            productVariantId: 'eh-smart-switch-1x',
            hardwareRevision: 'HW_1_0',
            firmwareFamily: 'esp32c6-switch-platform',
            version: '1.0.0',
            minFirmwareVersion: '1.0.0',
            releaseChannel: 'production',
            binarySizeBytes: 1048576,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            ed25519Signature: 'a'.repeat(128),
            downloadUrl: 'https://artifacts.eh-home.internal/firmware/v1.0.0/app.bin',
            releaseNotes: 'Initial production release for EH Smart Switch',
            status: 'RELEASED',
            gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            gitBranch: 'main',
            idfVersion: 'v5.4.1',
            createdAt: '2026-01-01T00:00:00Z',
            releasedAt: '2026-01-02T00:00:00Z',
        };
        this.memoryReleases.set(baselineRelease.id, baselineRelease);
        // Seed associated build
        const baselineBuild = {
            id: 'bld_switch_v1_0_0',
            firmwareReleaseId: baselineRelease.id,
            firmwareFamilyId: 'esp32c6-switch-platform',
            gitCommitSha: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            gitBranch: 'main',
            gitTag: 'v1.0.0',
            idfVersion: 'v5.4.1',
            buildProfile: 'release',
            toolchainInfo: { espIdf: '5.4.1', compiler: 'xtensa-esp-elf-14.2.0' },
            builtBy: 'ci-runner-01',
            builtAt: '2026-01-01T00:00:00Z',
            createdAt: '2026-01-01T00:00:00Z',
        };
        this.memoryBuilds.set(baselineBuild.id, baselineBuild);
        // Seed artifact
        const baselineArtifact = {
            id: 'art_switch_v1_0_0_app',
            buildId: baselineBuild.id,
            artifactType: 'APP_BIN',
            fileName: 'smart-switch-app.bin',
            fileSizeBytes: 1048576,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            storagePath: 'firmware/builds/bld_switch_v1_0_0/smart-switch-app.bin',
            downloadUrl: 'https://artifacts.eh-home.internal/firmware/v1.0.0/app.bin',
            signature: 'a'.repeat(128),
            createdAt: '2026-01-01T00:00:00Z',
        };
        this.memoryArtifacts.set(baselineArtifact.id, baselineArtifact);
        // Seed compatibility
        const baselineCompat = {
            id: 'comp_switch_v1_0_0_hw_1_0',
            firmwareReleaseId: baselineRelease.id,
            hardwareRevisionId: 'hw_rev_switch_1x_1_0',
            minHardwareRevision: 'HW_1_0',
            maxHardwareRevision: 'HW_1_1',
            isVerified: true,
            verificationNotes: 'Verified on factory test harness',
            verifiedAt: '2026-01-01T00:00:00Z',
            createdAt: '2026-01-01T00:00:00Z',
        };
        this.memoryCompatibilities.set(baselineCompat.id, baselineCompat);
        this.initializedMemory = true;
    }
    async listFamilies(query) {
        if (this.db) {
            try {
                const conditions = [];
                if (query.targetMcu) {
                    conditions.push((0, drizzle_orm_1.eq)(db_schema_1.firmwareFamilies.targetMcu, query.targetMcu));
                }
                const whereClause = conditions.length > 0 ? (0, drizzle_orm_1.and)(...conditions) : undefined;
                const rows = await this.db
                    .select()
                    .from(db_schema_1.firmwareFamilies)
                    .where(whereClause)
                    .limit(query.limit)
                    .offset(query.offset);
                if (rows.length > 0) {
                    const items = rows.map((r) => ({
                        id: r.id,
                        displayName: r.displayName,
                        targetMcu: r.targetMcu,
                        defaultIdfVersion: r.defaultIdfVersion,
                        repositoryUrl: r.repositoryUrl,
                        description: r.description,
                        createdAt: r.createdAt.toISOString(),
                        updatedAt: r.updatedAt.toISOString(),
                    }));
                    return { items, total: items.length };
                }
            }
            catch {
                // Fall back to memory
            }
        }
        let items = Array.from(this.memoryFamilies.values());
        if (query.targetMcu) {
            items = items.filter((f) => f.targetMcu === query.targetMcu);
        }
        const total = items.length;
        const paginated = items.slice(query.offset, query.offset + query.limit);
        return { items: paginated, total };
    }
    async getFamilyById(id) {
        if (this.db) {
            try {
                const rows = await this.db.select().from(db_schema_1.firmwareFamilies).where((0, drizzle_orm_1.eq)(db_schema_1.firmwareFamilies.id, id)).limit(1);
                const r = rows[0];
                if (r) {
                    return {
                        id: r.id,
                        displayName: r.displayName,
                        targetMcu: r.targetMcu,
                        defaultIdfVersion: r.defaultIdfVersion,
                        repositoryUrl: r.repositoryUrl,
                        description: r.description,
                        createdAt: r.createdAt.toISOString(),
                        updatedAt: r.updatedAt.toISOString(),
                    };
                }
            }
            catch {
                // Fall back to memory
            }
        }
        return this.memoryFamilies.get(id) || null;
    }
    async listReleases(query) {
        if (this.db) {
            try {
                const conditions = [];
                if (query.firmwareFamily) {
                    conditions.push((0, drizzle_orm_1.eq)(db_schema_1.firmwareReleases.firmwareFamily, query.firmwareFamily));
                }
                if (query.productVariantId) {
                    conditions.push((0, drizzle_orm_1.eq)(db_schema_1.firmwareReleases.productVariantId, query.productVariantId));
                }
                if (query.status) {
                    const domainStatus = (0, contracts_1.toDomainReleaseStatus)(query.status);
                    const legacyStatus = (0, contracts_1.toLegacyReleaseStatus)(query.status);
                    if (domainStatus !== legacyStatus) {
                        conditions.push((0, drizzle_orm_1.inArray)(db_schema_1.firmwareReleases.status, [domainStatus, legacyStatus]));
                    }
                    else {
                        conditions.push((0, drizzle_orm_1.eq)(db_schema_1.firmwareReleases.status, domainStatus));
                    }
                }
                if (query.version) {
                    conditions.push((0, drizzle_orm_1.eq)(db_schema_1.firmwareReleases.version, query.version));
                }
                const whereClause = conditions.length > 0 ? (0, drizzle_orm_1.and)(...conditions) : undefined;
                const rows = await this.db
                    .select()
                    .from(db_schema_1.firmwareReleases)
                    .where(whereClause)
                    .limit(query.limit)
                    .offset(query.offset);
                if (rows.length > 0) {
                    const items = rows.map((r) => ({
                        id: r.id,
                        productVariantId: r.productVariantId,
                        hardwareRevision: r.hardwareRevision,
                        firmwareFamily: r.firmwareFamily,
                        version: r.version,
                        minFirmwareVersion: r.minFirmwareVersion,
                        releaseChannel: r.releaseChannel,
                        binarySizeBytes: r.binarySizeBytes,
                        sha256: r.sha256,
                        ed25519Signature: r.ed25519Signature,
                        downloadUrl: r.downloadUrl,
                        releaseNotes: r.releaseNotes,
                        status: (0, contracts_1.toDomainReleaseStatus)(r.status),
                        createdAt: r.createdAt,
                        releasedAt: r.releasedAt,
                    }));
                    return { items, total: items.length };
                }
            }
            catch {
                // Fall back to memory
            }
        }
        let items = Array.from(this.memoryReleases.values());
        if (query.firmwareFamily) {
            items = items.filter((r) => r.firmwareFamily === query.firmwareFamily);
        }
        if (query.productVariantId) {
            items = items.filter((r) => r.productVariantId === query.productVariantId);
        }
        if (query.status) {
            const targetDomainStatus = (0, contracts_1.toDomainReleaseStatus)(query.status);
            items = items.filter((r) => (0, contracts_1.toDomainReleaseStatus)(r.status) === targetDomainStatus);
        }
        if (query.version) {
            items = items.filter((r) => r.version === query.version);
        }
        if (query.hardwareRevisionId) {
            const compatibleReleaseIds = new Set();
            for (const c of this.memoryCompatibilities.values()) {
                if (c.hardwareRevisionId === query.hardwareRevisionId) {
                    compatibleReleaseIds.add(c.firmwareReleaseId);
                }
            }
            items = items.filter((r) => compatibleReleaseIds.has(r.id) || r.hardwareRevision === query.hardwareRevisionId);
        }
        const total = items.length;
        const paginated = items.slice(query.offset, query.offset + query.limit);
        return { items: paginated, total };
    }
    async getReleaseById(id) {
        const release = this.memoryReleases.get(id);
        if (!release)
            return null;
        const builds = Array.from(this.memoryBuilds.values())
            .filter((b) => b.firmwareReleaseId === id)
            .map((b) => ({
            ...b,
            artifacts: Array.from(this.memoryArtifacts.values()).filter((a) => a.buildId === b.id),
        }));
        const compatibilities = Array.from(this.memoryCompatibilities.values()).filter((c) => c.firmwareReleaseId === id);
        return {
            ...release,
            builds,
            compatibilities,
        };
    }
    async getReleaseByFamilyAndVersion(firmwareFamily, version) {
        for (const r of this.memoryReleases.values()) {
            if (r.firmwareFamily === firmwareFamily && r.version === version) {
                return r;
            }
        }
        return null;
    }
    async createRelease(data) {
        const id = data.id || `rel_${data.firmwareFamily.replace(/[^a-z0-9]/g, '_')}_v${data.version.replace(/[^a-z0-9]/g, '_')}`;
        const now = new Date().toISOString();
        const newRelease = {
            id,
            productVariantId: data.productVariantId,
            hardwareRevision: data.hardwareRevision || null,
            firmwareFamily: data.firmwareFamily,
            version: data.version,
            minFirmwareVersion: data.minFirmwareVersion || null,
            releaseChannel: data.releaseChannel || 'production',
            binarySizeBytes: data.binarySizeBytes,
            sha256: data.sha256,
            ed25519Signature: data.ed25519Signature || '',
            downloadUrl: data.downloadUrl || '',
            releaseNotes: data.releaseNotes || null,
            status: data.status || 'DRAFT',
            gitCommitSha: data.gitCommitSha,
            gitBranch: data.gitBranch || 'main',
            idfVersion: data.idfVersion || 'v5.4.1',
            createdAt: now,
            releasedAt: null,
            builds: [],
            compatibilities: [],
        };
        if (this.db) {
            try {
                await this.db.insert(db_schema_1.firmwareReleases).values({
                    id: newRelease.id,
                    productVariantId: newRelease.productVariantId,
                    hardwareRevision: newRelease.hardwareRevision,
                    firmwareFamily: newRelease.firmwareFamily,
                    version: newRelease.version,
                    minFirmwareVersion: newRelease.minFirmwareVersion,
                    releaseChannel: newRelease.releaseChannel,
                    binarySizeBytes: newRelease.binarySizeBytes,
                    sha256: newRelease.sha256,
                    ed25519Signature: newRelease.ed25519Signature,
                    downloadUrl: newRelease.downloadUrl,
                    releaseNotes: newRelease.releaseNotes,
                    status: (0, contracts_1.toLegacyReleaseStatus)(newRelease.status),
                    createdAt: newRelease.createdAt,
                    releasedAt: newRelease.releasedAt,
                });
            }
            catch {
                // Fall back to memory
            }
        }
        this.memoryReleases.set(id, newRelease);
        return newRelease;
    }
    async updateReleaseStatus(id, newStatus, releasedAt) {
        const release = this.memoryReleases.get(id);
        if (!release)
            return null;
        release.status = newStatus;
        if (releasedAt !== undefined) {
            release.releasedAt = releasedAt;
        }
        if (this.db) {
            try {
                const dbStatus = (0, contracts_1.toLegacyReleaseStatus)(newStatus);
                await this.db
                    .update(db_schema_1.firmwareReleases)
                    .set({ status: dbStatus, releasedAt: releasedAt || null })
                    .where((0, drizzle_orm_1.eq)(db_schema_1.firmwareReleases.id, id));
            }
            catch {
                // Fall back to memory
            }
        }
        this.memoryReleases.set(id, release);
        return release;
    }
    async registerBuild(data) {
        const id = data.id || `bld_${Date.now()}_${data.gitCommitSha.substring(0, 7)}`;
        const now = new Date().toISOString();
        const newBuild = {
            id,
            firmwareReleaseId: data.firmwareReleaseId || null,
            firmwareFamilyId: data.firmwareFamilyId,
            gitCommitSha: data.gitCommitSha,
            gitBranch: data.gitBranch || 'main',
            gitTag: data.gitTag || null,
            idfVersion: data.idfVersion || 'v5.4.1',
            buildProfile: data.buildProfile || 'release',
            toolchainInfo: data.toolchainInfo || {},
            builtBy: data.builtBy || null,
            builtAt: now,
            createdAt: now,
            artifacts: [],
        };
        if (this.db) {
            try {
                await this.db.insert(db_schema_1.firmwareBuilds).values({
                    id: newBuild.id,
                    firmwareReleaseId: newBuild.firmwareReleaseId,
                    firmwareFamilyId: newBuild.firmwareFamilyId,
                    gitCommitSha: newBuild.gitCommitSha,
                    gitBranch: newBuild.gitBranch,
                    gitTag: newBuild.gitTag,
                    idfVersion: newBuild.idfVersion,
                    buildProfile: newBuild.buildProfile,
                    toolchainInfo: newBuild.toolchainInfo,
                    builtBy: newBuild.builtBy,
                });
            }
            catch {
                // Fall back to memory
            }
        }
        this.memoryBuilds.set(id, newBuild);
        return newBuild;
    }
    async getBuildById(id) {
        const build = this.memoryBuilds.get(id);
        if (!build)
            return null;
        const artifacts = Array.from(this.memoryArtifacts.values()).filter((a) => a.buildId === id);
        return { ...build, artifacts };
    }
    async registerArtifact(data) {
        const id = data.id || `art_${data.buildId}_${data.artifactType.toLowerCase()}`;
        const now = new Date().toISOString();
        const newArtifact = {
            id,
            buildId: data.buildId,
            artifactType: data.artifactType,
            fileName: data.fileName,
            fileSizeBytes: data.fileSizeBytes,
            sha256: data.sha256,
            storagePath: data.storagePath,
            downloadUrl: data.downloadUrl || null,
            signature: data.signature || null,
            createdAt: now,
        };
        if (this.db) {
            try {
                await this.db.insert(db_schema_1.firmwareArtifacts).values({
                    id: newArtifact.id,
                    buildId: newArtifact.buildId,
                    artifactType: newArtifact.artifactType,
                    fileName: newArtifact.fileName,
                    fileSizeBytes: newArtifact.fileSizeBytes,
                    sha256: newArtifact.sha256,
                    storagePath: newArtifact.storagePath,
                    downloadUrl: newArtifact.downloadUrl,
                    signature: newArtifact.signature,
                });
            }
            catch {
                // Fall back to memory
            }
        }
        this.memoryArtifacts.set(id, newArtifact);
        return newArtifact;
    }
    async getArtifactsByBuildId(buildId) {
        return Array.from(this.memoryArtifacts.values()).filter((a) => a.buildId === buildId);
    }
    async defineCompatibility(firmwareReleaseId, data) {
        const id = `comp_${firmwareReleaseId}_${data.hardwareRevisionId}`;
        const now = new Date().toISOString();
        const newCompat = {
            id,
            firmwareReleaseId,
            hardwareRevisionId: data.hardwareRevisionId,
            minHardwareRevision: data.minHardwareRevision || null,
            maxHardwareRevision: data.maxHardwareRevision || null,
            isVerified: true,
            verificationNotes: data.verificationNotes || null,
            verifiedAt: now,
            createdAt: now,
        };
        if (this.db) {
            try {
                await this.db.insert(db_schema_1.firmwareHardwareCompatibility).values({
                    id: newCompat.id,
                    firmwareReleaseId: newCompat.firmwareReleaseId,
                    hardwareRevisionId: newCompat.hardwareRevisionId,
                    minHardwareRevision: newCompat.minHardwareRevision,
                    maxHardwareRevision: newCompat.maxHardwareRevision,
                    isVerified: newCompat.isVerified,
                    verificationNotes: newCompat.verificationNotes,
                });
            }
            catch {
                // Fall back to memory
            }
        }
        this.memoryCompatibilities.set(id, newCompat);
        return newCompat;
    }
    async getCompatibilitiesByReleaseId(releaseId) {
        if (this.db) {
            try {
                const rows = await this.db
                    .select()
                    .from(db_schema_1.firmwareHardwareCompatibility)
                    .where((0, drizzle_orm_1.eq)(db_schema_1.firmwareHardwareCompatibility.firmwareReleaseId, releaseId));
                if (rows.length > 0) {
                    return rows.map((r) => ({
                        id: r.id,
                        firmwareReleaseId: r.firmwareReleaseId,
                        hardwareRevisionId: r.hardwareRevisionId,
                        minHardwareRevision: r.minHardwareRevision,
                        maxHardwareRevision: r.maxHardwareRevision,
                        isVerified: r.isVerified,
                        verificationNotes: r.verificationNotes,
                        verifiedAt: r.verifiedAt.toISOString(),
                        createdAt: r.createdAt.toISOString(),
                    }));
                }
            }
            catch {
                // Fall back to memory
            }
        }
        return Array.from(this.memoryCompatibilities.values()).filter((c) => c.firmwareReleaseId === releaseId);
    }
    async checkHardwareRevisionExists(hardwareRevisionId) {
        if (this.db) {
            try {
                const rows = await this.db
                    .select({ id: db_schema_1.hardwareRevisions.id })
                    .from(db_schema_1.hardwareRevisions)
                    .where((0, drizzle_orm_1.eq)(db_schema_1.hardwareRevisions.id, hardwareRevisionId))
                    .limit(1);
                return rows.length > 0;
            }
            catch {
                return true;
            }
        }
        return true;
    }
}
exports.FirmwareRepository = FirmwareRepository;
//# sourceMappingURL=firmware.repository.js.map