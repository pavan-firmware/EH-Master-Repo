import { BackupManifest, BackupRetentionPolicy, SecurityContext } from '@eh-home/contracts';
import { StorageService } from '../storage/storage.service';
import { AuditService } from '../audit/audit.service';
import { BackupCreationResult, BackupListResult } from './backup.interface';
import { CompleteDatabaseState } from './postgres-backup.engine';
export interface IDatabaseDataProvider {
    fetchAllData(): Promise<Record<string, any[]>>;
    fetchCompleteState?(): Promise<CompleteDatabaseState>;
    getSourceName(): string;
    getSchemaVersion(): string;
    getMigrationVersion(): string;
    getPgVersion?(): string;
}
export declare class DefaultDatabaseDataProvider implements IDatabaseDataProvider {
    private customTables?;
    constructor(customTables?: Record<string, any[]>);
    fetchAllData(): Promise<Record<string, any[]>>;
    fetchCompleteState(): Promise<CompleteDatabaseState>;
    getSourceName(): string;
    getSchemaVersion(): string;
    getMigrationVersion(): string;
    getPgVersion(): string;
}
export declare class BackupService {
    private storageService;
    private dataProvider;
    private auditService?;
    private retentionPolicy;
    constructor(storageService: StorageService, dataProvider?: IDatabaseDataProvider, auditService?: AuditService);
    setDataProvider(provider: IDatabaseDataProvider): void;
    setRetentionPolicy(policy: Partial<BackupRetentionPolicy>): void;
    getRetentionPolicy(): BackupRetentionPolicy;
    private audit;
    /**
     * Creates a verified, timestamped PostgreSQL-native database backup archive.
     * Command: pg_dump -Fc --no-owner --no-privileges
     */
    createBackup(callerContext?: SecurityContext): Promise<BackupCreationResult>;
    /**
     * Lists available backup manifests stored in object storage
     */
    listBackups(): Promise<BackupListResult>;
    /**
     * Retrieves a specific backup archive by ID or object key
     */
    getBackup(backupIdOrKey: string): Promise<{
        archiveBuffer: Buffer;
        state: CompleteDatabaseState;
        manifest?: BackupManifest;
    }>;
    /**
     * Prunes backups exceeding retention policy limits.
     * Safety Guard: Strictly isolated to 'eh-database-backups' and keys starting with 'backups/'.
     */
    pruneExpiredBackups(policy?: Partial<BackupRetentionPolicy>, callerContext?: SecurityContext): Promise<{
        prunedCount: number;
        remainingCount: number;
        deletedKeys: string[];
    }>;
}
//# sourceMappingURL=backup.service.d.ts.map