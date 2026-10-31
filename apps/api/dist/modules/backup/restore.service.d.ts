import { BackupManifest, SecurityContext } from '@eh-home/contracts';
import { StorageService } from '../storage/storage.service';
import { AuditService } from '../audit/audit.service';
import { RestoreVerificationResult } from './backup.interface';
import { CompleteDatabaseState } from './postgres-backup.engine';
export interface IDatabaseRestoreTarget {
    restoreTables(data: Record<string, any[]>): Promise<void>;
    restoreCompleteState?(state: CompleteDatabaseState): Promise<void>;
    verifyTableRecords(tableName: string): Promise<any[]>;
    getTargetSchemaVersion(): string;
    getTargetPgVersion?(): string;
    getCompleteState?(): CompleteDatabaseState | undefined;
}
export declare class DefaultDatabaseRestoreTarget implements IDatabaseRestoreTarget {
    private targetStore;
    private completeState?;
    private schemaVersion;
    private pgVersion;
    constructor(schemaVersion?: string, pgVersion?: string);
    restoreTables(data: Record<string, any[]>): Promise<void>;
    restoreCompleteState(state: CompleteDatabaseState): Promise<void>;
    verifyTableRecords(tableName: string): Promise<any[]>;
    getTargetSchemaVersion(): string;
    getTargetPgVersion(): string;
    getStore(): Record<string, any[]>;
    getCompleteState(): CompleteDatabaseState | undefined;
}
export declare class RestoreService {
    private storageService;
    private restoreTarget;
    private auditService?;
    constructor(storageService: StorageService, restoreTarget?: IDatabaseRestoreTarget, auditService?: AuditService);
    setRestoreTarget(target: IDatabaseRestoreTarget): void;
    private audit;
    private resolveBackupKey;
    /**
     * Verifies backup integrity without executing a restore.
     * Performs SHA-256 computation over raw archive bytes and validates PostgreSQL Custom Archive header.
     */
    verifyBackupIntegrity(backupKeyOrId: string): Promise<{
        valid: boolean;
        manifest: BackupManifest;
        computedSha256: string;
        error?: string;
    }>;
    private synthesizeManifestFromMeta;
    /**
     * Restores a verified PostgreSQL backup into the clean target database.
     * Restores schemas, tables, sequences, indexes, constraints, and data across all domains.
     */
    restoreBackup(backupKeyOrId: string, callerContext?: SecurityContext): Promise<RestoreVerificationResult>;
}
//# sourceMappingURL=restore.service.d.ts.map