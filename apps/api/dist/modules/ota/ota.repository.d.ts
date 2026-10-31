import { OtaManifest } from '@eh-home/contracts';
export interface IOtaRepository {
    registerRelease(manifest: OtaManifest, additional?: any): Promise<void>;
    getReleaseById(releaseId: string): Promise<any | null>;
    findReleasesForVariant(productVariantId: string, hardwareRevision?: string): Promise<any[]>;
    createOtaJob(job: any): Promise<any>;
    updateOtaJob(jobId: string, updates: any): Promise<any | null>;
    getOtaJob(jobId: string): Promise<any | null>;
    getLatestDeviceJob(deviceId: string): Promise<any | null>;
}
export declare class OtaRepository implements IOtaRepository {
    private db;
    private releasesStore;
    private jobsStore;
    constructor(db?: any);
    registerRelease(manifest: OtaManifest, additional?: any): Promise<void>;
    getReleaseById(releaseId: string): Promise<any | null>;
    findReleasesForVariant(productVariantId: string, hardwareRevision?: string): Promise<any[]>;
    createOtaJob(job: any): Promise<any>;
    updateOtaJob(jobId: string, updates: any): Promise<any | null>;
    getOtaJob(jobId: string): Promise<any | null>;
    getLatestDeviceJob(deviceId: string): Promise<any | null>;
}
//# sourceMappingURL=ota.repository.d.ts.map