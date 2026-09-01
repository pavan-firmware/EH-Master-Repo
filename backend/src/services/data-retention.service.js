'use strict';

/**
 * EH Home — Data Retention & Policy Pruning Service (Phase 17)
 *
 * Implements bounded retention for non-critical telemetry and historical audit logs.
 * Invariant: NEVER deletes active devices, claims, factory identities, or user accounts.
 */

class DataRetentionService {
  constructor({ db }) {
    this.db = db;
  }

  async pruneNotifications(olderThanDays = 30) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('notifications', n => n.created_at < cutoff);
    for (const n of stale) {
      await this.db.delete('notifications', n.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneAuditLogs(olderThanDays = 90) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('audit_logs', a => a.created_at < cutoff);
    for (const a of stale) {
      await this.db.delete('audit_logs', a.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async prunePendingAudits(olderThanDays = 14) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('pending_change_audits', a => a.applied_at < cutoff);
    for (const a of stale) {
      await this.db.delete('pending_change_audits', a.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneExportRecords(olderThanDays = 7) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('data_export_records', e => e.created_at < cutoff);
    for (const e of stale) {
      await this.db.delete('data_export_records', e.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async runRetentionCycle(policies = {}) {
    const notif = await this.pruneNotifications(policies.notificationDays || 30);
    const audit = await this.pruneAuditLogs(policies.auditLogDays || 90);
    const syncAudit = await this.prunePendingAudits(policies.syncAuditDays || 14);
    const exportRec = await this.pruneExportRecords(policies.exportDays || 7);

    return {
      executedAt: new Date().toISOString(),
      notificationsPruned: notif.pruned,
      auditLogsPruned: audit.pruned,
      syncAuditsPruned: syncAudit.pruned,
      exportsPruned: exportRec.pruned
    };
  }
}

module.exports = { DataRetentionService };
