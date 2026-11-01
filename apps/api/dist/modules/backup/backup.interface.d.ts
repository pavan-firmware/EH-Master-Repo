import { BackupManifest } from '@eh-home/contracts';
export interface DatabaseSnapshotData {
    manifest: BackupManifest;
    data: Record<string, any[]>;
}
export interface BackupCreationResult {
    manifest: BackupManifest;
    objectKey: string;
    storageBucket: string;
}
export interface RestoreVerificationResult {
    success: boolean;
    backupId: string;
    schemaVersion: string;
    restoredTablesCount: number;
    restoredRowsCount: number;
    integrityVerified: boolean;
    mismatches?: string[];
    restoredAt: string;
}
export interface BackupListResult {
    backups: BackupManifest[];
    totalCount: number;
}
//# sourceMappingURL=backup.interface.d.ts.map