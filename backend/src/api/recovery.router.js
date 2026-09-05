'use strict';

/**
 * Recovery API Router (Phase 33)
 *
 * Exposes administrative disaster recovery, backup, integrity, and restore endpoints:
 * - POST /api/v1/admin/recovery/backups
 * - GET  /api/v1/admin/recovery/backups
 * - GET  /api/v1/admin/recovery/backups/:backupId
 * - POST /api/v1/admin/recovery/backups/:backupId/verify
 * - POST /api/v1/admin/recovery/restore/plan
 * - POST /api/v1/admin/recovery/restore
 * - GET  /api/v1/admin/recovery/restore/:operationId
 * - GET  /api/v1/admin/recovery/checkpoints
 * - GET  /api/v1/admin/recovery/integrity
 *
 * SECURITY & SCOPING:
 * - Strictly restricted to authenticated ADMIN / SUPERADMIN roles (401 / 403).
 * - Read endpoints redact any sensitive internals.
 * - No client SQL, no raw object downloads for unprivileged users.
 */

class RecoveryApiRouter {
  constructor({ recoveryService, recoveryRepo = null }) {
    if (!recoveryService) throw new Error('recoveryService is required for RecoveryApiRouter');
    this.recoveryService = recoveryService;
    this.repo = recoveryRepo || recoveryService.repo;
  }

  async handle(method, rawPath, body = {}, headers = {}, params = {}) {
    const userId = params.userId || headers['x-user-id'] || null;
    const userRole = headers['x-user-role'] || params.userRole || null;
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPERADMIN' || headers['x-admin-role'] === 'true';

    // Normalize path
    const path = (rawPath.length > 1 && rawPath.endsWith('/')) ? rawPath.slice(0, -1) : rawPath;

    // Authentication check
    if (!userId) {
      return {
        status: 401,
        body: { error: 'UNAUTHORIZED', message: 'Authentication required for disaster recovery operations' }
      };
    }

    // Role check: all recovery endpoints require administrative authorization
    if (!isAdmin) {
      return {
        status: 403,
        body: { error: 'FORBIDDEN', message: 'Administrative role required for disaster recovery operations' }
      };
    }

    try {
      // 1. POST /api/v1/admin/recovery/backups
      if (method === 'POST' && path === '/api/v1/admin/recovery/backups') {
        const result = await this.recoveryService.createBackup({
          scope: body.scope || 'FULL',
          homeId: body.homeId || null,
          initiatedBy: userId,
          customBackupId: body.backupId || null,
          expirationDays: body.expirationDays || 30
        });
        return { status: 201, body: result };
      }

      // 2. GET /api/v1/admin/recovery/backups
      if (method === 'GET' && path === '/api/v1/admin/recovery/backups') {
        const backups = await this.repo.listBackupRecords({
          limit: parseInt(params.limit || '50', 10),
          offset: parseInt(params.offset || '0', 10),
          status: params.status || undefined,
          scope: params.scope || undefined,
          homeId: params.homeId || undefined
        });
        return { status: 200, body: backups };
      }

      // 3. POST /api/v1/admin/recovery/backups/:backupId/verify
      if (method === 'POST' && path.startsWith('/api/v1/admin/recovery/backups/') && path.endsWith('/verify')) {
        const parts = path.split('/');
        const backupId = parts[parts.length - 2];
        const report = await this.recoveryService.verifyBackupIntegrity(backupId, userId);
        return { status: 200, body: report };
      }

      // 4. GET /api/v1/admin/recovery/backups/:backupId
      if (method === 'GET' && path.startsWith('/api/v1/admin/recovery/backups/')) {
        const backupId = path.split('/').pop();
        const record = await this.repo.getBackupRecord(backupId);
        if (!record) {
          return { status: 404, body: { error: 'NOT_FOUND', message: `Backup ${backupId} not found` } };
        }
        const objects = await this.repo.getBackupObjects(backupId);
        return { status: 200, body: { ...record, objects } };
      }

      // 5. POST /api/v1/admin/recovery/restore/plan
      if (method === 'POST' && path === '/api/v1/admin/recovery/restore/plan') {
        if (!body.backupId) {
          return { status: 400, body: { error: 'BAD_REQUEST', message: 'backupId is required to plan restore' } };
        }
        const plan = await this.recoveryService.planRestore({
          backupId: body.backupId,
          targetScope: body.targetScope || 'FULL',
          homeId: body.homeId || null,
          initiatedBy: userId
        });
        return { status: 200, body: plan };
      }

      // 6. POST /api/v1/admin/recovery/restore
      if (method === 'POST' && path === '/api/v1/admin/recovery/restore') {
        if (!body.backupId) {
          return { status: 400, body: { error: 'BAD_REQUEST', message: 'backupId is required to execute restore' } };
        }
        const result = await this.recoveryService.executeRestore({
          backupId: body.backupId,
          targetScope: body.targetScope || 'FULL',
          homeId: body.homeId || null,
          initiatedBy: userId,
          dryRun: Boolean(body.dryRun),
          customOperationId: body.operationId || null
        });
        return { status: 200, body: result };
      }

      // 7. GET /api/v1/admin/recovery/restore/:operationId
      if (method === 'GET' && path.startsWith('/api/v1/admin/recovery/restore/')) {
        const operationId = path.split('/').pop();
        const op = await this.repo.getRestoreOperation(operationId);
        if (!op) {
          return { status: 404, body: { error: 'NOT_FOUND', message: `Restore operation ${operationId} not found` } };
        }
        return { status: 200, body: op };
      }

      // 8. GET /api/v1/admin/recovery/checkpoints
      if (method === 'GET' && path === '/api/v1/admin/recovery/checkpoints') {
        const checkpoints = await this.recoveryService.getCheckpoints({
          limit: parseInt(params.limit || '50', 10),
          offset: parseInt(params.offset || '0', 10),
          checkpointType: params.checkpointType || undefined
        });
        return { status: 200, body: checkpoints };
      }

      // 9. GET /api/v1/admin/recovery/integrity
      if (method === 'GET' && path === '/api/v1/admin/recovery/integrity') {
        const results = await this.repo.listIntegrityResults({
          limit: parseInt(params.limit || '50', 10),
          offset: parseInt(params.offset || '0', 10),
          backupId: params.backupId || undefined
        });
        return { status: 200, body: results };
      }

      return {
        status: 404,
        body: { error: 'NOT_FOUND', message: `Route ${method} ${rawPath} not found in Recovery API` }
      };
    } catch (err) {
      return {
        status: err.message && err.message.includes('not found') ? 404 : 500,
        body: {
          error: 'RECOVERY_OPERATION_ERROR',
          message: err.message
        }
      };
    }
  }
}

module.exports = { RecoveryApiRouter };
