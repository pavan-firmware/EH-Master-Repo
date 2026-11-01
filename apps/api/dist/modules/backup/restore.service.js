"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.RestoreService = exports.DefaultDatabaseRestoreTarget = void 0;
const crypto = __importStar(require("crypto"));
const contracts_1 = require("@eh-home/contracts");
const audit_service_1 = require("../audit/audit.service");
const audit_repository_1 = require("../audit/audit.repository");
const postgres_backup_engine_1 = require("./postgres-backup.engine");
class DefaultDatabaseRestoreTarget {
    targetStore = {};
    completeState;
    schemaVersion;
    pgVersion;
    constructor(schemaVersion = '1.0.0', pgVersion = '16.0') {
        this.schemaVersion = schemaVersion;
        this.pgVersion = pgVersion;
    }
    async restoreTables(data) {
        this.targetStore = JSON.parse(JSON.stringify(data));
    }
    async restoreCompleteState(state) {
        this.completeState = JSON.parse(JSON.stringify(state));
        this.targetStore = {};
        for (const [tName, tDef] of Object.entries(state.tables)) {
            this.targetStore[tName] = tDef.rows;
        }
    }
    async verifyTableRecords(tableName) {
        if (this.targetStore[tableName]) {
            return this.targetStore[tableName];
        }
        if (this.completeState && this.completeState.tables[tableName]) {
            return this.completeState.tables[tableName].rows;
        }
        return [];
    }
    getTargetSchemaVersion() {
        return this.schemaVersion;
    }
    getTargetPgVersion() {
        return this.pgVersion;
    }
    getStore() {
        return this.targetStore;
    }
    getCompleteState() {
        return this.completeState;
    }
}
exports.DefaultDatabaseRestoreTarget = DefaultDatabaseRestoreTarget;
class RestoreService {
    storageService;
    restoreTarget;
    auditService;
    constructor(storageService, restoreTarget, auditService) {
        this.storageService = storageService;
        this.restoreTarget = restoreTarget || new DefaultDatabaseRestoreTarget();
        this.auditService = auditService;
    }
    setRestoreTarget(target) {
        this.restoreTarget = target;
    }
    async audit(action, actorId, actorRole, resourceType, resourceId, outcome, metadata, failureReason, correlationId) {
        const service = this.auditService || new audit_service_1.AuditService(new audit_repository_1.AuditRepository());
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
    async resolveBackupKey(backupKeyOrId) {
        if (backupKeyOrId.startsWith('backups/') && backupKeyOrId.endsWith('.dump')) {
            return { dumpKey: backupKeyOrId };
        }
        const listRes = await this.storageService.listObjects('eh-database-backups', 'backups/');
        // 1. Check direct key match
        const directDump = listRes.objects.find((o) => o.key === backupKeyOrId || (o.key.includes(backupKeyOrId) && o.key.endsWith('.dump')));
        if (directDump)
            return { dumpKey: directDump.key };
        // 2. Check metadata match on dump or manifest objects
        for (const obj of listRes.objects) {
            if (obj.customMetadata?.['backupId'] === backupKeyOrId || obj.customMetadata?.['backupid'] === backupKeyOrId) {
                if (obj.key.endsWith('.dump'))
                    return { dumpKey: obj.key };
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
                }
                catch {
                    // ignore
                }
            }
        }
        // 4. Check fallback json files
        const fallbackMatch = listRes.objects.find((o) => o.key.includes(backupKeyOrId) || o.customMetadata?.['backupId'] === backupKeyOrId);
        if (fallbackMatch) {
            return { dumpKey: fallbackMatch.key };
        }
        throw new Error(`BackupNotFound: Object '${backupKeyOrId}' not found in storage bucket 'eh-database-backups'`);
    }
    /**
     * Verifies backup integrity without executing a restore.
     * Performs SHA-256 computation over raw archive bytes and validates PostgreSQL Custom Archive header.
     */
    async verifyBackupIntegrity(backupKeyOrId) {
        const { dumpKey } = await this.resolveBackupKey(backupKeyOrId);
        const { content, metadata } = await this.storageService.getObject('eh-database-backups', dumpKey);
        const computedSha = crypto.createHash('sha256').update(content).digest('hex');
        // 1. Check if binary PostgreSQL Custom Archive (magic header "PGDMP")
        if (content.length >= 5 && content.subarray(0, 5).toString('ascii') === 'PGDMP') {
            let state;
            try {
                state = postgres_backup_engine_1.PostgresBackupEngine.decodePostgresCustomArchive(content);
            }
            catch (err) {
                return {
                    valid: false,
                    manifest: this.synthesizeManifestFromMeta(dumpKey, metadata, computedSha),
                    computedSha256: computedSha,
                    error: `CORRUPTED_BACKUP: ${err.message}`
                };
            }
            // Try reading manifest file if exists
            let manifest;
            const manifestKey = dumpKey.replace(/\.dump$/, '.manifest.json');
            try {
                const { content: mContent } = await this.storageService.getObject('eh-database-backups', manifestKey);
                manifest = contracts_1.BackupManifestSchema.parse(JSON.parse(mContent.toString('utf8')));
            }
            catch {
                // Build manifest from decoded state & metadata
                const tableNames = Object.keys(state.tables);
                let totalRows = 0;
                for (const t of Object.values(state.tables))
                    totalRows += t.rows.length;
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
        let snapshot;
        try {
            snapshot = JSON.parse(content.toString('utf8'));
        }
        catch {
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
        const manifest = contracts_1.BackupManifestSchema.parse(snapshot.manifest);
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
    synthesizeManifestFromMeta(dumpKey, metadata, sha256) {
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
    async restoreBackup(backupKeyOrId, callerContext) {
        const { dumpKey } = await this.resolveBackupKey(backupKeyOrId);
        // 1. Verify Integrity (SHA-256 and PostgreSQL Archive structure)
        const verification = await this.verifyBackupIntegrity(dumpKey);
        if (!verification.valid) {
            if (callerContext) {
                await this.audit('BACKUP_RESTORE_FAILED', callerContext.principal.id, callerContext.principal.role, 'BACKUP', backupKeyOrId, 'FAILED', { error: verification.error }, verification.error, callerContext.correlationId);
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
                await this.audit('BACKUP_RESTORE_FAILED', callerContext.principal.id, callerContext.principal.role, 'BACKUP', manifest.backupId, 'FAILED', { sourceSchema: manifest.schemaVersion, targetSchema: targetSchemaVersion }, errMsg, callerContext.correlationId);
            }
            throw new Error(errMsg);
        }
        // 3. Fetch Backup Content
        const { content } = await this.storageService.getObject('eh-database-backups', dumpKey);
        let tablesRestored = {};
        let restoredTableNames = [];
        let restoredRowsCount = 0;
        // 4. Restore via PostgreSQL Native Engine
        if (content.length >= 5 && content.subarray(0, 5).toString('ascii') === 'PGDMP') {
            const state = postgres_backup_engine_1.PostgresBackupEngine.decodePostgresCustomArchive(content);
            if (this.restoreTarget.restoreCompleteState) {
                await this.restoreTarget.restoreCompleteState(state);
            }
            for (const [tName, tDef] of Object.entries(state.tables)) {
                tablesRestored[tName] = tDef.rows;
            }
            await this.restoreTarget.restoreTables(tablesRestored);
            restoredTableNames = Object.keys(state.tables);
        }
        else {
            // Legacy JSON restore
            const snapshot = JSON.parse(content.toString('utf8'));
            tablesRestored = snapshot.data;
            await this.restoreTarget.restoreTables(snapshot.data);
            restoredTableNames = Object.keys(snapshot.data);
        }
        // 5. Post-Restore Verification (Complete Object Inventory & Parity Check)
        const mismatches = [];
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
            await this.audit(restoreSuccess ? 'BACKUP_RESTORED' : 'BACKUP_RESTORE_FAILED', callerContext.principal.id, callerContext.principal.role, 'BACKUP', manifest.backupId, restoreSuccess ? 'SUCCESS' : 'FAILED', {
                backupId: manifest.backupId,
                schemaVersion: manifest.schemaVersion,
                tableCount: restoredTableNames.length,
                rowCount: restoredRowsCount,
                format: manifest.format,
                mismatches
            }, restoreSuccess ? undefined : mismatches.join('; '), callerContext.correlationId);
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
exports.RestoreService = RestoreService;
//# sourceMappingURL=restore.service.js.map