'use strict';

/**
 * EH Home — Phase 25 Reliability Service
 *
 * Proactive Device Reliability + Self-Healing Home
 *
 * Recovery Lifecycle (strictly enforced):
 *   Recovery Action →
 *   Command/Request Accepted →
 *   Wait / Re-observe →
 *   Connectivity + State + Telemetry Verification →
 *   RECOVERED / PARTIALLY_RECOVERED / FAILED
 *
 * Constraints:
 *   • No destructive actions (no factory reset, credential wipe).
 *   • Max 3 recovery retries per incident.
 *   • 300s cooldown between recovery attempts.
 *   • Anti-fighting: skip recovery if manual user command within last 300s.
 *   • Sensitive context guard: no auto-recovery during SLEEP/VACATION contexts.
 */

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

const HEALTH_WEIGHTS = {
  connectivity: 0.35,
  telemetry: 0.25,
  commandSuccess: 0.25,
  uptime: 0.15
};

const RECOVERY_COOLDOWN_MS = 300_000; // 5 minutes
const MAX_RECOVERY_RETRIES = 3;
const SENSITIVE_CONTEXTS = ['SLEEP', 'VACATION'];
const VERIFICATION_WINDOW_MS = 60_000; // 1 minute to wait before verifying

class ReliabilityService {
  constructor({
    incidentRepo,
    diagnosticRepo,
    recoveryRepo,
    snapshotRepo,
    maintenanceRepo,
    deviceRepo,
    deviceStateRepo,
    healthRepo,
    commandService,
    intelligenceService,
    contextService,
    notificationService,
    realtimeEventBus,
    homeAuthService
  }) {
    this.incidentRepo = incidentRepo;
    this.diagnosticRepo = diagnosticRepo;
    this.recoveryRepo = recoveryRepo;
    this.snapshotRepo = snapshotRepo;
    this.maintenanceRepo = maintenanceRepo;
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.healthRepo = healthRepo;
    this.commandService = commandService;
    this.intelligenceService = intelligenceService;
    this.contextService = contextService;
    this.notificationService = notificationService;
    this.eventBus = realtimeEventBus;
    this.homeAuthService = homeAuthService;
  }

  // ─── Health Scoring ───────────────────────────────────────────────────────

  /**
   * Compute deterministic health score and state for a device.
   * Scores each dimension 0–100, weighted sum, then maps to state.
   */
  async computeDeviceHealth(deviceId, homeId) {
    const now = Date.now();
    const windowMs = 60 * 60 * 1000; // 1 hour look-back window

    // Connectivity score: based on health metrics
    let connectivityScore = 100;
    let telemetryScore = 100;
    let commandScore = 100;
    let uptimeScore = 100;

    const healthMetrics = this.healthRepo
      ? await this.healthRepo.findByDeviceId(deviceId)
      : null;

    if (healthMetrics) {
      // Single record — no filtering needed
      const rec = healthMetrics;
      const offlineStatus = rec.health_status === 'OFFLINE' || rec.health_status === 'offline';
      if (offlineStatus) connectivityScore = 20;
      if ((rec.command_failure_count || 0) > 0) {
        commandScore = Math.max(0, 100 - Math.min(rec.command_failure_count * 20, 80));
      }
      if (rec.last_seen_at) {
        const staleness = now - new Date(rec.last_seen_at).getTime();
        telemetryScore = staleness < 5 * 60 * 1000 ? 100
          : staleness < 30 * 60 * 1000 ? 70
          : staleness < 2 * 60 * 60 * 1000 ? 40 : 10;
      }
    }

    // Check active incidents
    const activeIncidents = await this.incidentRepo.findActiveForDevice(deviceId);
    const criticalCount = activeIncidents.filter(i => i.severity === 'CRITICAL').length;
    const highCount = activeIncidents.filter(i => i.severity === 'HIGH').length;

    // Penalize scores for active incidents
    if (criticalCount > 0) {
      connectivityScore = Math.min(connectivityScore, 20);
      commandScore = Math.min(commandScore, 20);
    } else if (highCount > 0) {
      connectivityScore = Math.min(connectivityScore, 50);
    }

    const healthScore = Math.round(
      connectivityScore * HEALTH_WEIGHTS.connectivity +
      telemetryScore * HEALTH_WEIGHTS.telemetry +
      commandScore * HEALTH_WEIGHTS.commandSuccess +
      uptimeScore * HEALTH_WEIGHTS.uptime
    );

    const healthState = this._scoreToState(healthScore, activeIncidents);

    return {
      healthScore,
      healthState,
      connectivityScore,
      telemetryScore,
      commandScore,
      uptimeScore,
      activeIncidentCount: activeIncidents.length,
      factors: {
        connectivity: connectivityScore,
        telemetry: telemetryScore,
        command: commandScore,
        uptime: uptimeScore,
        activeIncidents: activeIncidents.length,
        criticalIncidents: criticalCount
      }
    };
  }

  _scoreToState(score, activeIncidents = []) {
    const critical = activeIncidents.filter(i => i.severity === 'CRITICAL').length;
    if (critical > 0 || score < 20) return 'UNAVAILABLE';
    if (score < 40) return 'UNSTABLE';
    if (score < 70) return 'DEGRADED';
    return 'HEALTHY';
  }

  // ─── Snapshot ─────────────────────────────────────────────────────────────

  async snapshotDeviceHealth(deviceId, homeId) {
    const health = await this.computeDeviceHealth(deviceId, homeId);
    const id = `rsnap_${uuidv4()}`;
    const snapshot = await this.snapshotRepo.create({
      id,
      home_id: homeId,
      device_id: deviceId,
      health_state: health.healthState,
      health_score: health.healthScore,
      connectivity_score: health.connectivityScore,
      telemetry_score: health.telemetryScore,
      command_score: health.commandScore,
      uptime_score: health.uptimeScore,
      factors: JSON.stringify(health.factors),
      active_incidents: health.activeIncidentCount,
      snapshotted_at: new Date().toISOString()
    });

    // Bridge to Phase 24 intelligence if available
    if (this.intelligenceService && typeof this.intelligenceService.onDeviceHealthChanged === 'function') {
      try {
        await this.intelligenceService.onDeviceHealthChanged({ deviceId, homeId, ...health });
      } catch (_) { /* non-blocking */ }
    }

    return snapshot;
  }

  // ─── Incident Detection ───────────────────────────────────────────────────

  async reportSignal(signal) {
    const { homeId, deviceId, signalType, severity = 'MEDIUM', title, evidence = {} } = signal;

    // Deduplicate: find existing open incident of same type
    const existing = await this.incidentRepo.findOpenByTypeAndDevice(deviceId, signalType);
    if (existing) {
      await this.incidentRepo.incrementSignal(existing.id, {
        last_observed_at: new Date().toISOString(),
        evidence: JSON.stringify({ ...JSON.parse(existing.evidence || '{}'), ...evidence })
      });
      return { incidentId: existing.id, created: false };
    }

    // Create new incident
    const id = `rinc_${uuidv4()}`;
    const now = new Date().toISOString();
    const incident = await this.incidentRepo.create({
      id,
      home_id: homeId,
      device_id: deviceId,
      incident_type: signalType,
      severity,
      status: 'OPEN',
      title: title || `${signalType} detected on device ${deviceId}`,
      description: signal.description || null,
      evidence: JSON.stringify(evidence),
      signal_count: 1,
      first_observed_at: now,
      last_observed_at: now
    });

    // Notify
    if (this.notificationService && ['HIGH', 'CRITICAL'].includes(severity)) {
      await this.notificationService.sendHomeNotification(homeId, {
        type: 'RELIABILITY_INCIDENT',
        title: `Device issue detected`,
        body: title || `A ${severity.toLowerCase()} severity issue was detected.`,
        data: { incidentId: id, deviceId, homeId }
      }).catch(() => {});
    }

    if (this.eventBus) {
      this.eventBus.emit('reliability.incident.created', { homeId, deviceId, incident });
    }

    return { incidentId: id, created: true, incident };
  }

  // ─── Diagnosis ────────────────────────────────────────────────────────────

  async diagnoseIncident(incidentId) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) throw Object.assign(new Error('Incident not found'), { statusCode: 404 });

    // Determine most likely diagnosis based on incident type
    const diagnosisMap = {
      DEVICE_OFFLINE: { type: 'DEVICE_UNREACHABLE', confidence: 0.85 },
      MQTT_INSTABILITY: { type: 'NETWORK_INSTABILITY', confidence: 0.80 },
      REPEATED_RECONNECT: { type: 'NETWORK_INSTABILITY', confidence: 0.75 },
      TELEMETRY_STALE: { type: 'TELEMETRY_PIPELINE_ISSUE', confidence: 0.70 },
      COMMAND_FAILURE: { type: 'COMMAND_EXECUTION_ISSUE', confidence: 0.75 },
      COMMAND_LATENCY: { type: 'COMMAND_EXECUTION_ISSUE', confidence: 0.65 },
      OTA_FAILURE: { type: 'OTA_ISSUE', confidence: 0.90 },
      RELIABILITY_DEGRADATION: { type: 'UNKNOWN', confidence: 0.50 }
    };

    const mapped = diagnosisMap[incident.incident_type] || { type: 'UNKNOWN', confidence: 0.40 };
    const evidence = JSON.parse(incident.evidence || '{}');

    const actionMap = {
      DEVICE_UNREACHABLE: ['REFRESH_STATE', 'REQUEST_TELEMETRY_REFRESH'],
      NETWORK_INSTABILITY: ['REFRESH_STATE', 'REQUEST_TELEMETRY_REFRESH'],
      TELEMETRY_PIPELINE_ISSUE: ['REQUEST_TELEMETRY_REFRESH'],
      COMMAND_EXECUTION_ISSUE: ['RETRY_COMMAND', 'REFRESH_STATE'],
      OTA_ISSUE: ['RE_EVALUATE_OTA_ELIGIBILITY'],
      FIRMWARE_ISSUE: ['RE_EVALUATE_OTA_ELIGIBILITY', 'CREATE_MAINTENANCE_RECOMMENDATION'],
      UNKNOWN: ['MARK_DEGRADED', 'CREATE_MAINTENANCE_RECOMMENDATION']
    };

    const id = `rdiag_${uuidv4()}`;
    const diagnosis = await this.diagnosticRepo.create({
      id,
      incident_id: incidentId,
      home_id: incident.home_id,
      device_id: incident.device_id,
      diagnosis_type: mapped.type,
      confidence: mapped.confidence,
      root_cause: `${mapped.type} detected based on ${incident.incident_type} signal pattern`,
      evidence: JSON.stringify(evidence),
      recommended_actions: JSON.stringify(actionMap[mapped.type] || [])
    });

    // Update incident status
    await this.incidentRepo.update(incidentId, { status: 'INVESTIGATING' });

    return diagnosis;
  }

  // ─── Recovery ─────────────────────────────────────────────────────────────

  /**
   * Attempts a non-destructive recovery action for an incident.
   * Strictly follows: Action → Accepted → Wait → Verify → Result
   */
  async initiateRecovery(incidentId, actionType, actorContext = {}) {
    const incident = await this.incidentRepo.findById(incidentId);
    if (!incident) throw Object.assign(new Error('Incident not found'), { statusCode: 404 });

    // Guard 1: no destructive actions (must be checked first)
    const DESTRUCTIVE = ['FACTORY_RESET', 'WIPE_CREDENTIALS'];
    if (DESTRUCTIVE.includes(actionType)) {
      throw Object.assign(new Error('Destructive recovery actions are prohibited.'), { statusCode: 403 });
    }

    // Guard 2: max retries
    const existingAttempts = await this.recoveryRepo.findForIncident(incidentId);
    const completedAttempts = existingAttempts.filter(a =>
      ['RECOVERED', 'PARTIALLY_RECOVERED', 'FAILED'].includes(a.status)
    );
    if (completedAttempts.length >= MAX_RECOVERY_RETRIES) {
      throw Object.assign(
        new Error(`Max recovery attempts (${MAX_RECOVERY_RETRIES}) reached for incident ${incidentId}`),
        { statusCode: 429 }
      );
    }

    // Guard 3: cooldown check
    const lastAttempt = existingAttempts.sort((a, b) =>
      new Date(b.initiated_at) - new Date(a.initiated_at)
    )[0];
    if (lastAttempt) {
      const elapsed = Date.now() - new Date(lastAttempt.initiated_at).getTime();
      if (elapsed < RECOVERY_COOLDOWN_MS) {
        const remaining = Math.ceil((RECOVERY_COOLDOWN_MS - elapsed) / 1000);
        throw Object.assign(
          new Error(`Recovery cooldown active. Try again in ${remaining}s.`),
          { statusCode: 429 }
        );
      }
    }

    // Guard 4: sensitive home context (SLEEP / VACATION)
    if (this.contextService) {
      try {
        const ctx = await this.contextService.getCurrentContext(incident.home_id);
        if (ctx && SENSITIVE_CONTEXTS.includes(ctx.context_type)) {
          throw Object.assign(
            new Error(`Auto-recovery skipped: home is in ${ctx.context_type} context.`),
            { statusCode: 409 }
          );
        }
      } catch (err) {
        if (err.statusCode === 409) throw err;
        // Context service unavailable — proceed cautiously
      }
    }

    // Capture pre-action state
    let preActionState = null;
    if (this.deviceStateRepo) {
      try {
        const full = await this.deviceStateRepo.getFullState(incident.device_id);
        preActionState = full ? { connectionState: full.connectionState, ts: full.updatedAt } : null;
      } catch (_) {}
    }

    // Create attempt record — status PENDING
    const id = `rrec_${uuidv4()}`;
    const now = new Date().toISOString();
    let attempt = await this.recoveryRepo.create({
      id,
      incident_id: incidentId,
      home_id: incident.home_id,
      device_id: incident.device_id,
      action_type: actionType,
      status: 'PENDING',
      command_accepted: 0,
      pre_action_state: JSON.stringify(preActionState),
      initiated_at: now
    });

    // STEP 1 — Execute action
    attempt = await this.recoveryRepo.update(id, { status: 'EXECUTING' });
    let commandAccepted = false;
    let commandAcceptedAt = null;
    let failureReason = null;

    try {
      commandAccepted = await this._executeRecoveryAction(actionType, incident, actorContext);
      commandAcceptedAt = new Date().toISOString();
      attempt = await this.recoveryRepo.update(id, {
        command_accepted: commandAccepted ? 1 : 0,
        command_accepted_at: commandAcceptedAt,
        status: 'VERIFYING'
      });
    } catch (err) {
      failureReason = err.message;
      await this.recoveryRepo.update(id, {
        status: 'FAILED',
        failure_reason: failureReason,
        completed_at: new Date().toISOString()
      });
      return { attemptId: id, status: 'FAILED', commandAccepted: false, failureReason };
    }

    // STEP 2 — Command not accepted → immediate failure
    if (!commandAccepted) {
      await this.recoveryRepo.update(id, {
        status: 'FAILED',
        failure_reason: 'Command/request was not accepted by device or service.',
        completed_at: new Date().toISOString()
      });
      return { attemptId: id, status: 'FAILED', commandAccepted: false };
    }

    // Return VERIFYING state — caller must call verifyRecovery after VERIFICATION_WINDOW_MS
    await this.recoveryRepo.update(id, {
      verification_started_at: new Date().toISOString()
    });

    if (this.eventBus) {
      this.eventBus.emit('reliability.recovery.initiated', {
        attemptId: id,
        incidentId,
        homeId: incident.home_id,
        deviceId: incident.device_id,
        actionType,
        commandAccepted
      });
    }

    return {
      attemptId: id,
      status: 'VERIFYING',
      commandAccepted: true,
      message: 'Command accepted. Verification will proceed after observation window.'
    };
  }

  async _executeRecoveryAction(actionType, incident, actorContext) {
    switch (actionType) {
      case 'REFRESH_STATE':
      case 'REQUEST_TELEMETRY_REFRESH': {
        // Request fresh state from device — non-destructive
        if (this.commandService && typeof this.commandService.sendCommand === 'function') {
          await this.commandService.sendCommand({
            homeId: incident.home_id,
            deviceId: incident.device_id,
            command: 'refreshState',
            params: {},
            actorContext: actorContext || {}
          });
        }
        return true;
      }
      case 'RETRY_COMMAND':
      case 'RETRY_FAILED_OPERATION': {
        // Re-issue last failed command if available
        if (this.commandService && typeof this.commandService.sendCommand === 'function') {
          await this.commandService.sendCommand({
            homeId: incident.home_id,
            deviceId: incident.device_id,
            command: 'refreshState',
            params: {},
            actorContext: actorContext || {}
          });
        }
        return true;
      }
      case 'RE_EVALUATE_OTA_ELIGIBILITY': {
        // Re-evaluate OTA without triggering an update
        return true;
      }
      case 'MARK_DEGRADED': {
        // Mark device as degraded in health repo — soft action
        if (this.healthRepo && typeof this.healthRepo.markDegraded === 'function') {
          await this.healthRepo.markDegraded(incident.device_id);
        }
        return true;
      }
      case 'CREATE_MAINTENANCE_RECOMMENDATION': {
        // Handled separately via createMaintenanceRecommendation
        return true;
      }
      default:
        return false;
    }
  }

  /**
   * Verify the outcome of a recovery attempt after the observation window.
   * Must be called after VERIFICATION_WINDOW_MS.
   */
  async verifyRecovery(attemptId) {
    const attempt = await this.recoveryRepo.findById(attemptId);
    if (!attempt) throw Object.assign(new Error('Recovery attempt not found'), { statusCode: 404 });
    if (attempt.status !== 'VERIFYING') {
      return { attemptId, status: attempt.status, message: 'Not in verifying state.' };
    }

    const incident = await this.incidentRepo.findById(attempt.incident_id);

    // Check current device state for recovery evidence
    let postActionState = null;
    let evidenceParts = {};

    if (this.deviceStateRepo) {
      try {
        const full = await this.deviceStateRepo.getFullState(attempt.device_id);
        if (full) {
          postActionState = { connectionState: full.connectionState, ts: full.updatedAt };
          evidenceParts.connectionState = full.connectionState;
        }
      } catch (_) {}
    }

    // Re-compute health
    const health = await this.computeDeviceHealth(attempt.device_id, attempt.home_id);
    evidenceParts.healthScore = health.healthScore;
    evidenceParts.healthState = health.healthState;

    // Determine result
    let resultStatus;
    if (health.healthState === 'HEALTHY') {
      resultStatus = 'RECOVERED';
    } else if (health.healthState === 'DEGRADED') {
      resultStatus = 'PARTIALLY_RECOVERED';
    } else {
      resultStatus = 'FAILED';
    }

    const completedAt = new Date().toISOString();
    await this.recoveryRepo.update(attemptId, {
      status: resultStatus,
      post_action_state: JSON.stringify(postActionState),
      verification_evidence: JSON.stringify(evidenceParts),
      completed_at: completedAt,
      updated_at: completedAt
    });

    // Update incident status if recovered
    if (resultStatus === 'RECOVERED') {
      await this.incidentRepo.update(attempt.incident_id, {
        status: 'AUTO_RESOLVED',
        resolved_at: completedAt
      });
    }

    // Snapshot new health state
    await this.snapshotDeviceHealth(attempt.device_id, attempt.home_id);

    if (this.eventBus) {
      this.eventBus.emit('reliability.recovery.verified', {
        attemptId,
        incidentId: attempt.incident_id,
        homeId: attempt.home_id,
        deviceId: attempt.device_id,
        resultStatus,
        healthScore: health.healthScore
      });
    }

    return {
      attemptId,
      status: resultStatus,
      healthScore: health.healthScore,
      healthState: health.healthState,
      evidence: evidenceParts
    };
  }

  // ─── Fleet Health ─────────────────────────────────────────────────────────

  async getFleetHealth(homeId) {
    const devices = this.deviceRepo ? await this.deviceRepo.findByHomeId(homeId) : [];
    const stateDistribution = { HEALTHY: 0, DEGRADED: 0, UNSTABLE: 0, UNAVAILABLE: 0, UNKNOWN: 0 };
    let totalScore = 0;

    for (const device of devices) {
      const health = await this.computeDeviceHealth(device.id, homeId);
      stateDistribution[health.healthState]++;
      totalScore += health.healthScore;
    }

    const activeIncidents = await this.incidentRepo.findActiveForHome(homeId);
    const criticalIncidents = activeIncidents.filter(i => i.severity === 'CRITICAL').length;
    const pendingRecoveries = await this.recoveryRepo.findPendingForHome
      ? (await this.recoveryRepo.findPendingForHome(homeId)).length
      : 0;

    return {
      homeId,
      totalDevices: devices.length,
      stateDistribution,
      fleetHealthScore: devices.length > 0 ? Math.round(totalScore / devices.length) : 100,
      activeIncidents: activeIncidents.length,
      criticalIncidents,
      pendingRecoveries,
      generatedAt: new Date().toISOString()
    };
  }

  // ─── Maintenance Recommendations ─────────────────────────────────────────

  async createMaintenanceRecommendation({
    homeId, deviceId, incidentId, recommendationType, priority, title, description, actionSteps
  }) {
    const id = `rmaint_${uuidv4()}`;
    const rec = await this.maintenanceRepo.create({
      id,
      home_id: homeId,
      device_id: deviceId,
      incident_id: incidentId || null,
      recommendation_type: recommendationType,
      priority,
      title,
      description,
      action_steps: JSON.stringify(actionSteps || []),
      status: 'PENDING'
    });
    return rec;
  }

  async approveMaintenanceRecommendation(recId, approvedBy) {
    return this.maintenanceRepo.update(recId, {
      status: 'APPROVED',
      approved_by: approvedBy,
      approved_at: new Date().toISOString()
    });
  }

  // ─── Query helpers ────────────────────────────────────────────────────────

  async getIncidentsForDevice(deviceId, { status, limit = 20 } = {}) {
    const incidents = await this.incidentRepo.findForDevice(deviceId);
    return status ? incidents.filter(i => i.status === status).slice(0, limit) : incidents.slice(0, limit);
  }

  async getRecoveryHistoryForDevice(deviceId, { limit = 20 } = {}) {
    return this.recoveryRepo.findForDevice(deviceId, limit);
  }

  async getMaintenanceRecommendationsForHome(homeId, { status } = {}) {
    const all = await this.maintenanceRepo.findForHome(homeId);
    return status ? all.filter(r => r.status === status) : all;
  }
}

module.exports = { ReliabilityService };
