import { OtaManifest, OtaExecutionState } from '@eh-home/contracts';
import { IOtaRepository } from './ota.repository';
export declare function semverCompare(a: string, b: string): number;
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
export declare class OtaService {
    private repo;
    constructor(repo: IOtaRepository);
    registerRelease(manifest: OtaManifest, additional?: any): Promise<any>;
    checkUpdate(params: {
        productVariantId: string;
        hardwareRevision: string;
        currentVersion: string;
        targetChannel?: string;
    }): Promise<OtaCheckResult>;
    verifyArtifactIntegrity(params: VerifySignatureParams): {
        valid: boolean;
        reason?: string;
    };
    createOtaJob(params: {
        deviceId: string;
        releaseId: string;
        rolloutId?: string;
        fromVersion: string;
    }): Promise<any>;
    /**
     * Evaluates the multi-point security gate before an OTA job can transition to AUTHORIZED.
     * REQUESTED does NOT imply AUTHORIZED.
     */
    authorizeOtaJob(jobId: string, context?: OtaAuthorizationContext): Promise<OtaAuthorizationResult>;
    updateJobProgress(jobId: string, status: OtaExecutionState, progressPercent?: number, errorCode?: string, errorMessage?: string): Promise<any>;
    cancelOtaJob(jobId: string, reason?: string): Promise<any>;
    getLatestJob(deviceId: string): Promise<any | null>;
    getJobById(jobId: string): Promise<any | null>;
}
//# sourceMappingURL=ota.service.d.ts.map