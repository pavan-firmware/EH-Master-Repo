/**
 * EH Home API Domain Modules Registry
 *
 * Establishes the modular-monolith domain boundaries.
 * In PART 03, the foundational system module is active.
 * Subsequent parts register their domain routes into this structure.
 */
export * from './system/system.routes';
export * from './system/system.service';
export * from './system/system.schema';
export * from './products';
export * from './hardware';
export * from './firmware';
export * from './inventory';
export * from './mqtt';
export * from './telemetry';
export * from './commands';
export * from './ota';
export * from './security/security.service';
export * from './security/security.repository';
export * from './security/security.routes';
export * from './audit/audit.service';
export * from './audit/audit.repository';
export * from './audit/audit.routes';
export * from './storage/storage.interface';
export * from './storage/storage.service';
export * from './storage/storage.routes';
export * from './storage/providers/memory-storage.provider';
export * from './storage/providers/s3-storage.provider';
export * from './backup/backup.interface';
export * from './backup/backup.service';
export * from './backup/restore.service';
export * from './backup/backup.routes';
export * from './backup/postgres-backup.engine';
//# sourceMappingURL=index.d.ts.map