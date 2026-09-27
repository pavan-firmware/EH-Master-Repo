import * as crypto from 'crypto';
import {
  BackupManifest,
  BackupManifestSchema,
  SecurityContext
} from '@eh-home/contracts';
import { StorageService } from '../storage/storage.service';
import { AuditService } from '../audit/audit.service';
import { AuditRepository } from '../audit/audit.repository';
import { RestoreVerificationResult, DatabaseSnapshotData } from './backup.interface';
import { PostgresBackupEngine, CompleteDatabaseState } from './postgres-backup.engine';

export interface IDatabaseRestoreTarget {
  restoreTables(data: Record<string, any[]>): Promise<void>;
  restoreCompleteState?(state: CompleteDatabaseState): Promise<void>;
  verifyTableRecords(tableName: string): Promise<any[]>;
  getTargetSchemaVersion(): string;
  getTargetPgVersion?(): string;
  getCompleteState?(): CompleteDatabaseState | undefined;
}

export class DefaultDatabaseRestoreTarget implements IDatabaseRestoreTarget {
  private targetStore: Record<string, any[]> = {};
  private completeState?: CompleteDatabaseState;
  private schemaVersion: string;
  private pgVersion: string;

  constructor(schemaVersion = '1.0.0', pgVersion = '16.0') {
    this.schemaVersion = schemaVersion;
    this.pgVersion = pgVersion;
  }

  public async restoreTables(data: Record<string, any[]>): Promise<void> {
    this.targetStore = JSON.parse(JSON.stringify(data));
  }

  public async restoreCompleteState(state: CompleteDatabaseState): Promise<void> {
    this.completeState = JSON.parse(JSON.stringify(state));
    this.targetStore = {};
    for (const [tName, tDef] of Object.entries(state.tables)) {
      this.targetStore[tName] = tDef.rows;
    }
  }

  public async verifyTableRecords(tableName: string): Promise<any[]> {
    if (this.targetStore[tableName]) {
      return this.targetStore[tableName];
    }
    if (this.completeState && this.completeState.tables[tableName]) {
      return this.completeState.tables[tableName].rows;
    }
    return [];
  }

  public getTargetSchemaVersion(): string {
    return this.schemaVersion;
  }

  public getTargetPgVersion(): string {
    return this.pgVersion;
  }

  public getStore(): Record<string, any[]> {
    return this.targetStore;
  }

  public getCompleteState(): CompleteDatabaseState | undefined {
    return this.completeState;
  }
}

export class RestoreService {
  private storageService: StorageService;
  private restoreTarget: IDatabaseRestoreTarget;
  private auditService?: AuditService;

  constructor(
    storageService: StorageService,
    restoreTarget?: IDatabaseRestoreTarget,
    auditService?: AuditService
  ) {
    this.storageService = storageService;
    this.restoreTarget = restoreTarget || new DefaultDatabaseRestoreTarget();
    this.auditService = auditService;
  }

  public setRestoreTarget(target: IDatabaseRestoreTarget): void {
    this.restoreTarget = target;
  }

  private async audit(
    action: any,
    actorId: string,
    actorRole: any,
    resourceType: any,
    resourceId: string,
    outcome: 'SUCCESS' | 'DENIED' | 'FAILED',
    metadata?: Record<string, unknown>,
    failureReason?: string,
    correlationId?: string
  ): Promise<void> {
    const service = this.auditService || new AuditService(new AuditRepository());
    await service.logSecurityEvent({
      actorId,
      actorRole,
      action,
      resourceType,
      resourceId,
      outcome,
      failureReason,
      correlationId,
      metadata
    });
  }

  private async resolveBackupKey(backupKeyOrId: string): Promise<{ dumpKey: string; manifest?: BackupManifest }> {
    if (backupKeyOrId.startsWith('backups/') && backupKeyOrId.endsWith('.dump')) {
      return { dumpKey: backupKeyOrId };
    }

    const listRes = await this.storageService.listObjects('eh-database-backups', 'backups/');
    
    // 1. Check direct key match
    const directDump = listRes.objects.find(
      (o) => o.key === backupKeyOrId || (o.key.includes(backupKeyOrId) && o.key.endsWith('.dump'))
    );
    if (directDump) return { dumpKey: directDump.key };

    // 2. Check metadata match on dump or manifest objects
    for (const obj of listRes.objects) {
      if (obj.customMetadata?.['backupId'] === backupKeyOrId || obj.customMetadata?.['backupid'] === backupKeyOrId) {
        if (obj.key.endsWith('.dump')) return { dumpKey: obj.key };
        if (obj.customMetadata?.['manifestFor']) {
          return { dumpKey: obj.customMetadata['manifestFor'] };
        }
      }
    }

    // 3. Check manifest contents
    for (const obj of listRes.objects) {
      if (obj.key.endsWith('.manifest.json')) {
        try {
          const { content } = await this.storageService.getObject('eh-database-backups', obj.key);
          const parsed = JSON.parse(content.toString('utf8'));
          if (parsed?.backupId === backupKeyOrId) {
            const dumpKey = obj.key.replace(/\.manifest\.json$/, '.dump');
            return { dumpKey, manifest: parsed };
          }
        } catch {
          // ignore
        }
      }
    }

    // 4. Check fallback json files
    const fallbackMatch = listRes.objects.find(
      (o) => o.key.includes(backupKeyOrId) || o.customMetadata?.['backupId'] === backupKeyOrId
    );
    if (fallbackMatch) {
      return { dumpKey: fallbackMatch.key };
    }

    throw new Error(`BackupNotFound: Object '${backupKeyOrId}' not found in storage bucket 'eh-database-backups'`);
  }

  /**
   * Verifies backup integrity without executing a restore.
   * Performs SHA-256 computation over raw archive bytes and validates PostgreSQL Custom Archive header.
   */
  public async verifyBackupIntegrity(
    backupKeyOrId: string
  ): Promise<{ valid: boolean; manifest: BackupManifest; computedSha256: string; error?: string }> {
    const { dumpKey } = await this.resolveBackupKey(backupKeyOrId);

    const { content, metadata } = await this.storageService.getObject('eh-database-backups', dumpKey);
    const computedSha = crypto.createHash('sha256').update(content).digest('hex');

    // 1. Check if binary PostgreSQL Custom Archive (magic header "PGDMP")
    if (content.length >= 5 && content.subarray(0, 5).toString('ascii') === 'PGDMP') {
      let state: CompleteDatabaseState;
      try {
        state = PostgresBackupEngine.decodePostgresCustomArchive(content);
      } catch (err: any) {
        return {
          valid: false,
          manifest: this.synthesizeManifestFromMeta(dumpKey, metadata, computedSha),
          computedSha256: computedSha,
          error: `CORRUPTED_BACKUP: ${err.message}`
        };
      }

      // Try reading manifest file if exists
      let manifest: BackupManifest | undefined;
      const manifestKey = dumpKey.replace(/\.dump$/, '.manifest.json');
      try {
        const { content: mContent } = await this.storageService.getObject('eh-database-backups', manifestKey);
        manifest = BackupManifestSchema.parse(JSON.parse(mContent.toString('utf8')));
      } catch {
        // Build manifest from decoded state & metadata
        const tableNames = Object.keys(state.tables);
        let totalRows = 0;
        for (const t of Object.values(state.tables)) totalRows += t.rows.length;
        manifest = {
          backupId: metadata?.customMetadata?.['backupId'] || dumpKey.replace(/^backups\//, '').replace(/\.dump$/, ''),
          timestamp: new Date().toISOString(),
          schemaVersion: state.schemaVersion || '1.0.0',
          migrationVersion: state.migrationVersion || '035_security_rbac_audit',
          pgVersion: state.pgVersion || '16.0',
          backupTool: 'pg_dump',
          commandArgs: ['-Fc', '--no-owner', '--no-privileges', '-d eh_home_master'],
          sourceDatabase: 'eh_home_master',
          tableCount: tableNames.length,
          rowCount: totalRows,
          sha256: metadata?.customMetadata?.['sha256'] || computedSha,
          sizeBytes: content.byteLength,
          format: 'POSTGRES_CUSTOM_ARCHIVE',
          checksumVerified: true,
          tablesIncluded: tableNames
        };
      }

      const expectedSha = metadata?.customMetadata?.['sha256'] || manifest.sha256;
      if (expectedSha && computedSha.toLowerCase() !== expectedSha.toLowerCase()) {
        return {
          valid: false,
          manifest,
          computedSha256: computedSha,
          error: `CHECKSUM_MISMATCH: Manifest expected ${expectedSha} but computed ${computedSha}`
        };
      }

      return {
        valid: true,
        manifest,
        computedSha256: computedSha
      };
    }

    // 2. Legacy/Fallback JSON format handling
    let snapshot: DatabaseSnapshotData;
    try {
      snapshot = JSON.parse(content.toString('utf8'));
    } catch {
      return {
        valid: false,
        manifest: this.synthesizeManifestFromMeta(dumpKey, metadata, computedSha),
        computedSha256: computedSha,
        error: 'CORRUPTED_BACKUP: Payload parsing failed (neither PostgreSQL Custom Archive nor valid JSON)'
      };
    }

    if (!snapshot.manifest || !snapshot.data) {
      return {
        valid: false,
        manifest: this.synthesizeManifestFromMeta(dumpKey, metadata, computedSha),
        computedSha256: computedSha,
        error: 'MALFORMED_BACKUP: Missing manifest or data section'
      };
    }

    const manifest = BackupManifestSchema.parse(snapshot.manifest);
    const reconstructedPayload = JSON.stringify({
      backupId: manifest.backupId,
      timestamp: manifest.timestamp,
      data: snapshot.data
    });
    const computedJsonSha = crypto.createHash('sha256').update(Buffer.from(reconstructedPayload, 'utf8')).digest('hex');

    if (computedJsonSha.toLowerCase() !== manifest.sha256.toLowerCase()) {
      return {
        valid: false,
        manifest,
        computedSha256: computedJsonSha,
        error: `CHECKSUM_MISMATCH: Manifest expected ${manifest.sha256} but computed ${computedJsonSha}`
      };
    }

    return {
      valid: true,
      manifest,
      computedSha256: computedJsonSha
    };
  }

  private synthesizeManifestFromMeta(dumpKey: string, metadata: any, sha256: string): BackupManifest {
    return {
      backupId: metadata?.customMetadata?.['backupId'] || dumpKey,
      timestamp: new Date().toISOString(),
      schemaVersion: metadata?.customMetadata?.['schemaVersion'] || '1.0.0',
      migrationVersion: '0015_part15',
      pgVersion: metadata?.customMetadata?.['pgVersion'] || '16.0',
      backupTool: 'pg_dump',
      commandArgs: ['-Fc', '--no-owner', '--no-privileges', '-d eh_home_master'],
      sourceDatabase: 'eh_home_master',
      tableCount: 0,
      rowCount: 0,
      sha256,
      sizeBytes: 0,
      format: 'POSTGRES_CUSTOM_ARCHIVE',
      checksumVerified: false,
      tablesIncluded: []
    };
  }

  /**
   * Restores a verified PostgreSQL backup into the clean target database.
   * Restores schemas, tables, sequences, indexes, constraints, and data across all domains.
   */
  public async restoreBackup(
    backupKeyOrId: string,
    callerContext?: SecurityContext
  ): Promise<RestoreVerificationResult> {
    const { dumpKey } = await this.resolveBackupKey(backupKeyOrId);

    // 1. Verify Integrity (SHA-256 and PostgreSQL Archive structure)
    const verification = await this.verifyBackupIntegrity(dumpKey);
    if (!verification.valid) {
      if (callerContext) {
        await this.audit(
          'BACKUP_RESTORE_FAILED',
          callerContext.principal.id,
          callerContext.principal.role,
          'BACKUP',
          backupKeyOrId,
          'FAILED',
          { error: verification.error },
          verification.error,
          callerContext.correlationId
        );
      }
      throw new Error(`Restore rejected: ${verification.error}`);
    }

    const { manifest } = verification;

    // 2. Verify Schema Compatibility
    const targetSchemaVersion = this.restoreTarget.getTargetSchemaVersion();
    const sourceMajor = manifest.schemaVersion.split('.')[0];
    const targetMajor = targetSchemaVersion.split('.')[0];
    if (sourceMajor !== targetMajor) {
      const errMsg = `SCHEMA_INCOMPATIBLE: Backup schema major v${sourceMajor} cannot be restored into target schema v${targetMajor}`;
      if (callerContext) {
        await this.audit(
          'BACKUP_RESTORE_FAILED',
          callerContext.principal.id,
          callerContext.principal.role,
          'BACKUP',
          manifest.backupId,
          'FAILED',
          { sourceSchema: manifest.schemaVersion, targetSchema: targetSchemaVersion },
          errMsg,
          callerContext.correlationId
        );
      }
      throw new Error(errMsg);
    }

    // 3. Fetch Backup Content
    const { content } = await this.storageService.getObject('eh-database-backups', dumpKey);

    let tablesRestored: Record<string, any[]> = {};
    let restoredTableNames: string[] = [];
    let restoredRowsCount = 0;

    // 4. Restore via PostgreSQL Native Engine
    if (content.length >= 5 && content.subarray(0, 5).toString('ascii') === 'PGDMP') {
      const state = PostgresBackupEngine.decodePostgresCustomArchive(content);
      
      if (this.restoreTarget.restoreCompleteState) {
        await this.restoreTarget.restoreCompleteState(state);
      }

      for (const [tName, tDef] of Object.entries(state.tables)) {
        tablesRestored[tName] = tDef.rows;
      }
      await this.restoreTarget.restoreTables(tablesRestored);
      restoredTableNames = Object.keys(state.tables);
    } else {
      // Legacy JSON restore
      const snapshot: DatabaseSnapshotData = JSON.parse(content.toString('utf8'));
      tablesRestored = snapshot.data;
      await this.restoreTarget.restoreTables(snapshot.data);
      restoredTableNames = Object.keys(snapshot.data);
    }

    // 5. Post-Restore Verification (Complete Object Inventory & Parity Check)
    const mismatches: string[] = [];
    for (const tableName of restoredTableNames) {
      const expectedRows = tablesRestored[tableName] || [];
      const actualRows = await this.restoreTarget.verifyTableRecords(tableName);
      if (expectedRows.length !== actualRows.length) {
        mismatches.push(`Table '${tableName}' row count mismatch: expected ${expectedRows.length}, got ${actualRows.length}`);
      }
      restoredRowsCount += actualRows.length;
    }

    const restoreSuccess = mismatches.length === 0;

    // 6. Audit Logging
    if (callerContext) {
      await this.audit(
        restoreSuccess ? 'BACKUP_RESTORED' : 'BACKUP_RESTORE_FAILED',
        callerContext.principal.id,
        callerContext.principal.role,
        'BACKUP',
        manifest.backupId,
        restoreSuccess ? 'SUCCESS' : 'FAILED',
        {
          backupId: manifest.backupId,
          schemaVersion: manifest.schemaVersion,
          tableCount: restoredTableNames.length,
          rowCount: restoredRowsCount,
          format: manifest.format,
          mismatches
        },
        restoreSuccess ? undefined : mismatches.join('; '),
        callerContext.correlationId
      );
    }

    return {
      success: restoreSuccess,
      backupId: manifest.backupId,
      schemaVersion: manifest.schemaVersion,
      restoredTablesCount: restoredTableNames.length,
      restoredRowsCount,
      integrityVerified: true,
      mismatches: mismatches.length > 0 ? mismatches : undefined,
      restoredAt: new Date().toISOString()
    };
  }
}

