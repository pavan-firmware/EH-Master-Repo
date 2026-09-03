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

  async pruneEnergyExecutions(olderThanDays = 30) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('energy_automation_executions', e => e.created_at < cutoff);
    for (const e of stale) {
      await this.db.delete('energy_automation_executions', e.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneEnergyOptimizations(olderThanDays = 60) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('energy_optimizations', e => e.updated_at < cutoff && (e.is_dismissed === 1 || e.is_dismissed === true));
    for (const e of stale) {
      await this.db.delete('energy_optimizations', e.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneCostOptimizations(olderThanDays = 60) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('cost_optimizations', e => e.updated_at < cutoff && (e.is_dismissed === 1 || e.is_dismissed === true));
    for (const e of stale) {
      await this.db.delete('cost_optimizations', e.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneEnergyForecasts(olderThanDays = 30) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('energy_forecasts', f => f.created_at < cutoff);
    for (const f of stale) {
      await this.db.delete('energy_forecasts', f.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneEnergyAnomalies(olderThanDays = 60) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('energy_anomalies', a => a.created_at < cutoff);
    for (const a of stale) {
      await this.db.delete('energy_anomalies', a.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneForecastAccuracy(olderThanDays = 90) {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('forecast_accuracy_records', r => r.created_at < cutoff);
    for (const r of stale) {
      await this.db.delete('forecast_accuracy_records', r.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async runRetentionCycle(policies = {}) {
    const notif = await this.pruneNotifications(policies.notificationDays || 30);
    const audit = await this.pruneAuditLogs(policies.auditLogDays || 90);
    const syncAudit = await this.prunePendingAudits(policies.syncAuditDays || 14);
    const exportRec = await this.pruneExportRecords(policies.exportDays || 7);
    const energyExec = await this.pruneEnergyExecutions(policies.energyExecutionDays || 30);
    const energyOpt = await this.pruneEnergyOptimizations(policies.energyOptimizationDays || 60);
    const costOpt = await this.pruneCostOptimizations(policies.costOptimizationDays || 60);
    const forecasts = await this.pruneEnergyForecasts(policies.forecastDays || 30);
    const anomalies = await this.pruneEnergyAnomalies(policies.anomalyDays || 60);
    const accuracy = await this.pruneForecastAccuracy(policies.accuracyDays || 90);

    return {
      executedAt: new Date().toISOString(),
      notificationsPruned: notif.pruned,
      auditLogsPruned: audit.pruned,
      syncAuditsPruned: syncAudit.pruned,
      exportsPruned: exportRec.pruned,
      energyExecutionsPruned: energyExec.pruned,
      energyOptimizationsPruned: energyOpt.pruned,
      costOptimizationsPruned: costOpt.pruned,
      forecastsPruned: forecasts.pruned,
      anomaliesPruned: anomalies.pruned,
      accuracyRecordsPruned: accuracy.pruned
    };
  }
}

module.exports = { DataRetentionService };
