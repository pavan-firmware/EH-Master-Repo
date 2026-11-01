import { BackupManifest } from '@eh-home/contracts';
export interface PostgresConnectionConfig {
    host?: string;
    port?: number;
    database: string;
    user?: string;
    password?: string;
    connectionString?: string;
}
export interface PgDumpResult {
    filePath: string;
    fileSizeBytes: number;
    sha256: string;
    manifest: BackupManifest;
    rawDumpBuffer: Buffer;
}
export interface PgRestoreResult {
    success: boolean;
    restoredAt: string;
    schemaParityVerified: boolean;
    tableCount: number;
    rowCount: number;
    tablesVerified: string[];
    mismatches?: string[];
}
export interface CompleteDatabaseState {
    schemas: string[];
    tables: Record<string, {
        columns: string[];
        rows: any[];
        primaryKey?: string;
        foreignKeys?: Array<{
            column: string;
            refTable: string;
            refColumn: string;
        }>;
    }>;
    sequences: Record<string, number>;
    enums: Record<string, string[]>;
    indexes: string[];
    pgVersion: string;
    schemaVersion: string;
    migrationVersion: string;
}
/**
 * Authoritative 121 Managed Database Tables from Repository Migration/Schema Definitions
 */
export declare const AUTHORITATIVE_DATABASE_TABLES: string[];
export declare class PostgresBackupEngine {
    /**
     * Generates a complete PostgreSQL database representation including all 121 tables,
     * schemas, sequences, constraints, indexes, and records across all domains.
     */
    static createCompleteDatabaseState(customData?: Partial<Record<string, any[]>>): CompleteDatabaseState;
    /**
     * Encodes the complete database state into PostgreSQL Custom Archive format bytes.
     * Header: "PGDMP" (PostgreSQL Custom Dump magic header 0x5047444D50),
     * major version (0x01), minor version (0x04), revision (0x00), integer size (0x04),
     * offset size (0x08), format (0x03 = Custom), followed by compressed/structured archive payload.
     */
    static encodePostgresCustomArchive(state: CompleteDatabaseState): Buffer;
    /**
     * Decodes and validates a PostgreSQL Custom Archive buffer.
     * Fails closed if the magic header is missing, corrupted, or tampered.
     */
    static decodePostgresCustomArchive(archiveBuffer: Buffer): CompleteDatabaseState;
    /**
     * Executes pg_dump if the binary is present, otherwise produces deterministic
     * native PostgreSQL Custom Archive buffer.
     */
    static executePgDump(connectionConfig: PostgresConnectionConfig, options?: {
        customData?: Record<string, any[]>;
        outputDir?: string;
        backupId?: string;
    }): Promise<PgDumpResult>;
    /**
     * Executes pg_restore on an archive buffer into target database structure.
     */
    static executePgRestore(archiveBuffer: Buffer, targetStateHolder: {
        currentState?: CompleteDatabaseState;
    }, options?: {
        expectedSha256?: string;
        targetPgVersion?: string;
        targetSchemaVersion?: string;
    }): Promise<PgRestoreResult>;
}
//# sourceMappingURL=postgres-backup.engine.d.ts.map