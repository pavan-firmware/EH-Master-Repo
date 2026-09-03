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

  async prunePresenceSignals(days = 14) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('presence_signals', s => (s.observed_at || s.created_at) < cutoff);
    for (const s of stale) {
      await this.db.delete('presence_signals', s.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneContextTransitions(days = 30) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('context_transitions', t => t.created_at < cutoff);
    for (const t of stale) {
      await this.db.delete('context_transitions', t.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneIntelligenceDecisions(days = 60) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('intelligence_decisions', d => d.created_at < cutoff);
    for (const d of stale) {
      await this.db.delete('intelligence_decisions', d.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneIntelligenceRecommendations(days = 30) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('intelligence_recommendations', r => r.created_at < cutoff);
    for (const r of stale) {
      await this.db.delete('intelligence_recommendations', r.id);
    }
    return { pruned: stale.length, cutoff };
  }

  async pruneIntelligenceOutcomes(days = 90) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('intelligence_decision_outcomes', o => (o.executed_at || o.created_at) < cutoff);
    for (const o of stale) {
      await this.db.delete('intelligence_decision_outcomes', o.id);
    }
    return { pruned: stale.length, cutoff };
  }

  // Phase 25 — Reliability & Self-Healing Retention

  async pruneReliabilityIncidents(days = 90) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('reliability_incidents', i =>
      i.created_at < cutoff && ['RESOLVED', 'AUTO_RESOLVED'].includes(i.status)
    );
    for (const i of stale) await this.db.delete('reliability_incidents', i.id);
    return { pruned: stale.length, cutoff };
  }

  async pruneReliabilityDiagnostics(days = 90) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('reliability_diagnostics', d => d.created_at < cutoff);
    for (const d of stale) await this.db.delete('reliability_diagnostics', d.id);
    return { pruned: stale.length, cutoff };
  }

  async pruneReliabilityRecoveryAttempts(days = 60) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('reliability_recovery_attempts', r =>
      r.created_at < cutoff && ['RECOVERED', 'PARTIALLY_RECOVERED', 'FAILED'].includes(r.status)
    );
    for (const r of stale) await this.db.delete('reliability_recovery_attempts', r.id);
    return { pruned: stale.length, cutoff };
  }

  async pruneReliabilitySnapshots(days = 30) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('reliability_health_snapshots', s => s.created_at < cutoff);
    for (const s of stale) await this.db.delete('reliability_health_snapshots', s.id);
    return { pruned: stale.length, cutoff };
  }

  async pruneMaintenanceRecommendations(days = 180) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('maintenance_recommendations', r =>
      r.created_at < cutoff && ['COMPLETED', 'REJECTED'].includes(r.status)
    );
    for (const r of stale) await this.db.delete('maintenance_recommendations', r.id);
    return { pruned: stale.length, cutoff };
  }

  // Phase 26 — Multi-Protocol Connectivity Retention

  async pruneTransportHealthSnapshots(days = 30) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('transport_health_snapshots', s => s.snapshotted_at < cutoff || s.created_at < cutoff);
    for (const s of stale) await this.db.delete('transport_health_snapshots', s.id);
    return { pruned: stale.length, cutoff };
  }

  async pruneCommissioningSessions(days = 60) {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    const stale = await this.db.find('commissioning_sessions', s =>
      s.created_at < cutoff && ['COMPLETED', 'FAILED', 'CANCELLED'].includes(s.stage)
    );
    for (const s of stale) await this.db.delete('commissioning_sessions', s.id);
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
    const presenceSignals = await this.prunePresenceSignals(policies.presenceSignalDays || 14);
    const contextTransitions = await this.pruneContextTransitions(policies.contextTransitionDays || 30);
    const intelDecisions = await this.pruneIntelligenceDecisions(policies.intelDecisionDays || 60);
    const intelRecs = await this.pruneIntelligenceRecommendations(policies.intelRecDays || 30);
    const intelOutcomes = await this.pruneIntelligenceOutcomes(policies.intelOutcomeDays || 90);
    const reliabilityInc = await this.pruneReliabilityIncidents(policies.reliabilityIncidentDays || 90);
    const reliabilityDiag = await this.pruneReliabilityDiagnostics(policies.reliabilityDiagDays || 90);
    const reliabilityRec = await this.pruneReliabilityRecoveryAttempts(policies.reliabilityRecoveryDays || 60);
    const reliabilitySnap = await this.pruneReliabilitySnapshots(policies.reliabilitySnapshotDays || 30);
    const maintRecs = await this.pruneMaintenanceRecommendations(policies.maintenanceRecDays || 180);
    const transportHealth = await this.pruneTransportHealthSnapshots(policies.transportHealthDays || 30);
    const commissioning = await this.pruneCommissioningSessions(policies.commissioningDays || 60);

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
      accuracyRecordsPruned: accuracy.pruned,
      presenceSignalsPruned: presenceSignals.pruned,
      contextTransitionsPruned: contextTransitions.pruned,
      intelDecisionsPruned: intelDecisions.pruned,
      intelRecsPruned: intelRecs.pruned,
      intelOutcomesPruned: intelOutcomes.pruned,
      reliabilityIncidentsPruned: reliabilityInc.pruned,
      reliabilityDiagnosticsPruned: reliabilityDiag.pruned,
      reliabilityRecoveryAttemptsPruned: reliabilityRec.pruned,
      reliabilitySnapshotsPruned: reliabilitySnap.pruned,
      maintenanceRecommendationsPruned: maintRecs.pruned,
      transportHealthSnapshotsPruned: transportHealth.pruned,
      commissioningSessionsPruned: commissioning.pruned
    };
  }
}

module.exports = { DataRetentionService };
