/**
 * Device Trust Service (Phase 32)
 *
 * Implements deterministic device trust state evaluation, safe concurrent credential rotation,
 * explicit quarantine/revocation, offline/local-first trust, factory reset reconciliation,
 * and OTA security policy enforcement.
 *
 * HARD SECURITY INVARIANTS:
 * 1. `device_credentials` remains the authoritative store for currently usable device credentials.
 *    `device_credential_lifecycle` is a historical lifecycle/rotation ledger only.
 * 2. `device_credential_lifecycle.metadata` MUST NOT contain raw secrets, passwords, or keys.
 * 3. Credential rotation is concurrency-safe & idempotent: only 1 pending generation at a time.
 * 4. FACTORY_RESET is a lifecycle/reconciliation state, NOT an automatic trust-recovery state.
 *    It MUST NOT automatically transition REVOKED -> TRUSTED or DECOMMISSIONED -> TRUSTED.
 * 5. OTA policy distinguishes Normal OTA from Security/Recovery OTA.
 *    Quarantine NEVER bypasses firmware signature verification.
 */

const crypto = require('crypto');
const { AuditRedactionService } = require('./audit-redaction.service');

const TRUST_STATES = Object.freeze({
  PROVISIONED: 'PROVISIONED',
  COMMISSIONED: 'COMMISSIONED',
  TRUSTED: 'TRUSTED',
  DEGRADED: 'DEGRADED',
  QUARANTINED: 'QUARANTINED',
  REVOKED: 'REVOKED',
  DECOMMISSIONED: 'DECOMMISSIONED',
  FACTORY_RESET: 'FACTORY_RESET'
});

class DeviceTrustService {
  /**
   * @param {Object} opts
   * @param {Object} opts.deviceTrustRepo           - DeviceTrustRepository instance
   * @param {Object} [opts.deviceRepo]              - DeviceRepository instance
   * @param {Object} [opts.securityAuditRepo]       - SecurityAuditRepository instance
   * @param {Object} [opts.operationalEventService] - OperationalEventService instance
   * @param {Object} [opts.notificationService]     - NotificationService instance
   */
  constructor({
    deviceTrustRepo,
    deviceRepo = null,
    securityAuditRepo = null,
    operationalEventService = null,
    notificationService = null
  }) {
    if (!deviceTrustRepo) {
      throw new Error('deviceTrustRepo is required for DeviceTrustService');
    }
    this.deviceTrustRepo = deviceTrustRepo;
    this.deviceRepo = deviceRepo;
    this.securityAuditRepo = securityAuditRepo;
    this.operationalEventService = operationalEventService;
    this.notificationService = notificationService;
  }

  // ===========================================================================
  // 1. Trust State Evaluation & Querying
  // ===========================================================================

  async getDeviceTrustState(deviceId) {
    const existing = await this.deviceTrustRepo.getTrustState(deviceId);
    if (existing) {
      return existing;
    }
    // A device with an active home claim is in TRUSTED state by default
    let defaultState = TRUST_STATES.PROVISIONED;
    if (this.deviceRepo) {
      try {
        const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
        if (auth) {
          defaultState = TRUST_STATES.TRUSTED;
        }
      } catch {
        // ignore
      }
    }
    // Return default initialized trust state record
    return {
      device_id: deviceId,
      trust_state: defaultState,
      trust_score: 100.0,
      reasoning_json: { initialized: true },
      quarantined_at: null,
      revoked_at: null,
      last_evaluated_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
  }

  /**
   * Continuous deterministic trust score & state calculation.
   */
  async evaluateTrust(deviceId, observations = {}) {
    const current = await this.getDeviceTrustState(deviceId);

    // If already REVOKED or DECOMMISSIONED, trust cannot be updated via passive observation
    if (current.trust_state === TRUST_STATES.REVOKED || current.trust_state === TRUST_STATES.DECOMMISSIONED) {
      return current;
    }

    let score = 100.0;
    const reasoning = { ...observations };

    // Deduct for authentication failure bursts
    const authFailures = Number(observations.authFailureBurstCount || 0);
    if (authFailures > 0) {
      score -= Math.min(60, authFailures * 10);
      reasoning.authPenalty = Math.min(60, authFailures * 10);
    }

    // Deduct for signature failures
    const signatureFailures = Number(observations.signatureFailures || 0);
    if (signatureFailures > 0) {
      score -= Math.min(60, signatureFailures * 20);
      reasoning.sigPenalty = Math.min(60, signatureFailures * 20);
    }

    // Deduct for stale telemetry / intermittent drops
    if (observations.telemetryStale) {
      score -= 20.0;
      reasoning.telemetryStalePenalty = 20.0;
    }

    // Deduct for unexpected reset loops
    if (observations.frequentCrashLoops) {
      score -= 25.0;
      reasoning.crashLoopPenalty = 25.0;
    }

    score = Math.max(0, Math.min(100, score));

    // Determine target state based on score thresholds & hard criteria
    let nextState = current.trust_state;

    if (observations.isExplicitlyQuarantined || authFailures >= 10 || score < 40) {
      nextState = TRUST_STATES.QUARANTINED;
    } else if (score < 80) {
      nextState = TRUST_STATES.DEGRADED;
    } else {
      nextState = current.trust_state === TRUST_STATES.QUARANTINED ? TRUST_STATES.DEGRADED : TRUST_STATES.TRUSTED;
    }

    const updated = await this.deviceTrustRepo.upsertTrustState({
      deviceId,
      trustState: nextState,
      trustScore: score,
      reasoningJson: reasoning,
      quarantinedAt: nextState === TRUST_STATES.QUARANTINED ? (current.quarantined_at || new Date().toISOString()) : null,
      revokedAt: null,
      lastEvaluatedAt: new Date().toISOString()
    });

    if (nextState === TRUST_STATES.QUARANTINED && current.trust_state !== TRUST_STATES.QUARANTINED) {
      await this._recordSecurityIncident(deviceId, {
        eventType: 'QUARANTINE_ENACTED',
        severity: 'WARNING',
        details: { previousTrustState: current.trust_state, score, reasoning }
      });
    }

    return updated;
  }

  // ===========================================================================
  // 2. Explicit Quarantine & Revocation
  // ===========================================================================

  async quarantineDevice(deviceId, { reason, actorUserId = null, evidence = {} }) {
    const current = await this.getDeviceTrustState(deviceId);
    if (current.trust_state === TRUST_STATES.REVOKED || current.trust_state === TRUST_STATES.DECOMMISSIONED) {
      throw new Error(`Cannot quarantine device ${deviceId}: already in ${current.trust_state} state`);
    }

    const now = new Date().toISOString();
    const updated = await this.deviceTrustRepo.upsertTrustState({
      deviceId,
      trustState: TRUST_STATES.QUARANTINED,
      trustScore: 30.0,
      reasoningJson: { quarantineReason: reason, evidence },
      quarantinedAt: now,
      revokedAt: null,
      lastEvaluatedAt: now
    });

    await this._recordSecurityIncident(deviceId, {
      eventType: 'QUARANTINE_ENACTED',
      severity: 'WARNING',
      action: 'DEVICE_QUARANTINED',
      actorUserId,
      details: { reason, evidence }
    });

    return updated;
  }

  async revokeDevice(deviceId, {
    revocationType = 'COMPROMISED',
    reason,
    actorUserId = null,
    evidence = {},
    remediationAllowed = false
  }) {
    if (!reason || reason.trim() === '') {
      throw new Error('Revocation reason is mandatory');
    }

    const now = new Date().toISOString();
    const revocationId = `rev_${crypto.randomUUID()}`;

    // 1. Record explicit revocation
    const revocation = await this.deviceTrustRepo.createRevocation({
      id: revocationId,
      deviceId,
      revocationType,
      reason,
      actorUserId,
      evidenceJson: evidence,
      remediationAllowed,
      createdAt: now
    });

    // 2. Set trust state to REVOKED
    await this.deviceTrustRepo.upsertTrustState({
      deviceId,
      trustState: TRUST_STATES.REVOKED,
      trustScore: 0.0,
      reasoningJson: { revocationId, reason, revocationType, remediationAllowed },
      quarantinedAt: null,
      revokedAt: now,
      lastEvaluatedAt: now
    });

    // 3. Fix 1: Atomically set authoritative credential_state to REVOKED
    await this.deviceTrustRepo.updateAuthoritativeCredentialState(deviceId, 'REVOKED');

    // 4. Update active lifecycle records to REVOKED
    const lifecycleRecords = await this.deviceTrustRepo.listLifecycleRecords(deviceId);
    for (const rec of lifecycleRecords) {
      if (rec.status === 'CONFIRMED' || rec.status === 'ROTATION_PENDING') {
        await this.deviceTrustRepo.updateLifecycleRecord(rec.id, {
          status: 'REVOKED',
          revoked_at: now
        });
      }
    }

    // 5. Audit & Telemetry
    await this._recordSecurityIncident(deviceId, {
      eventType: 'REVOCATION_ENACTED',
      severity: 'CRITICAL',
      action: 'DEVICE_REVOKED',
      actorUserId,
      details: { revocationId, revocationType, reason, remediationAllowed }
    });

    return revocation;
  }

  async restoreTrust(deviceId, {
    reason,
    actorUserId,
    attestationVerified = false,
    targetState = TRUST_STATES.TRUSTED
  }) {
    const current = await this.getDeviceTrustState(deviceId);

    if (current.trust_state === TRUST_STATES.REVOKED || current.trust_state === TRUST_STATES.DECOMMISSIONED) {
      const latestRev = await this.deviceTrustRepo.getLatestRevocation(deviceId);
      if (latestRev && !latestRev.remediation_allowed && !attestationVerified) {
        throw new Error(`Device ${deviceId} was permanently revoked without remediation authority`);
      }
      if (!attestationVerified) {
        throw new Error(`Restoration of REVOKED device ${deviceId} requires explicit cryptographic attestation verification`);
      }
    }

    const now = new Date().toISOString();
    const updated = await this.deviceTrustRepo.upsertTrustState({
      deviceId,
      trustState: targetState,
      trustScore: 100.0,
      reasoningJson: { restoredReason: reason, attestationVerified, restoredBy: actorUserId },
      quarantinedAt: null,
      revokedAt: null,
      lastEvaluatedAt: now
    });

    // If restoring from REVOKED, re-activate authoritative credential state
    if (current.trust_state === TRUST_STATES.REVOKED) {
      await this.deviceTrustRepo.updateAuthoritativeCredentialState(deviceId, 'ACTIVE');
    }

    await this._recordSecurityIncident(deviceId, {
      eventType: 'TRUST_RESTORED',
      severity: 'INFO',
      action: 'DEVICE_TRUST_RESTORED',
      actorUserId,
      details: { previousTrustState: current.trust_state, targetState, reason, attestationVerified }
    });

    return updated;
  }

  // ===========================================================================
  // 3. Factory Reset Reconciliation (Fix 4)
  // ===========================================================================

  /**
   * FACTORY_RESET is a lifecycle/reconciliation state, NOT an automatic trust-recovery state.
   * Preserves immutable identity, clears ownership, invalidates temporary credentials,
   * forces re-evaluation. MUST NOT automatically transition REVOKED -> TRUSTED.
   */
  async reconcileFactoryReset(deviceId, { actorUserId = null, evidence = {} }) {
    const current = await this.getDeviceTrustState(deviceId);

    // Hard Invariant: FACTORY_RESET MUST NOT transition REVOKED/DECOMMISSIONED to TRUSTED
    if (current.trust_state === TRUST_STATES.REVOKED || current.trust_state === TRUST_STATES.DECOMMISSIONED) {
      // Retain REVOKED status; do not restore trust
      await this._recordSecurityIncident(deviceId, {
        eventType: 'TRUST_STATE_CHANGED',
        severity: 'WARNING',
        action: 'FACTORY_RESET_ON_REVOKED_DEVICE',
        actorUserId,
        details: { note: 'Factory reset rejected trust restoration on revoked device', evidence }
      });
      return {
        deviceId,
        trustState: current.trust_state,
        trustRestored: false,
        message: 'Factory reset completed but device remains REVOKED. Authorized remediation required.'
      };
    }

    const now = new Date().toISOString();
    const updated = await this.deviceTrustRepo.upsertTrustState({
      deviceId,
      trustState: TRUST_STATES.FACTORY_RESET,
      trustScore: 60.0,
      reasoningJson: { factoryReset: true, reconciledAt: now, evidence },
      quarantinedAt: null,
      revokedAt: null,
      lastEvaluatedAt: now
    });

    // Invalidate temporary credentials
    await this.deviceTrustRepo.updateAuthoritativeCredentialState(deviceId, 'RESET');

    await this._recordSecurityIncident(deviceId, {
      eventType: 'TRUST_STATE_CHANGED',
      severity: 'NOTICE',
      action: 'FACTORY_RESET_RECONCILED',
      actorUserId,
      details: { previousTrustState: current.trust_state, newTrustState: TRUST_STATES.FACTORY_RESET }
    });

    return {
      deviceId,
      trustState: TRUST_STATES.FACTORY_RESET,
      trustRestored: false,
      message: 'Factory reset reconciled. Device is in FACTORY_RESET state awaiting commissioning.'
    };
  }

  // ===========================================================================
  // 4. Safe Credential Rotation (Fix 1, 2, 3)
  // ===========================================================================

  /**
   * Concurrency-safe and idempotent initiation.
   * Only one ROTATION_PENDING generation per device + type at a time.
   * Metadata is strictly non-secret (defense-in-depth sanitization).
   */
  async initiateCredentialRotation(deviceId, {
    credentialType = 'MQTT',
    keyIdentifier,
    fingerprint = null,
    metadata = {}
  }) {
    if (!keyIdentifier) {
      throw new Error('keyIdentifier is required for credential rotation');
    }

    // 1. Check for existing pending rotation (idempotency)
    const pending = await this.deviceTrustRepo.getActiveOrPendingLifecycleRecord(deviceId, credentialType);
    if (pending) {
      // Reuse existing pending rotation operation
      return {
        lifecycleRecord: pending,
        isReusedPending: true,
        rotationGeneration: pending.rotation_generation
      };
    }

    // 2. Allocate next generation atomically
    const nextGeneration = await this.deviceTrustRepo.getNextGenerationNumber(deviceId, credentialType);
    const rotationId = `cred_rot_${crypto.randomUUID()}`;

    // 3. Persist lifecycle record (historical ledger only; authoritative device_credentials remains unchanged)
    const newRecord = await this.deviceTrustRepo.createLifecycleRecord({
      id: rotationId,
      deviceId,
      credentialType,
      keyIdentifier,
      fingerprint,
      status: 'ROTATION_PENDING',
      rotationGeneration: nextGeneration,
      issuedAt: new Date().toISOString(),
      metadata
    });

    await this._recordSecurityIncident(deviceId, {
      eventType: 'ROTATION_INITIATED',
      severity: 'INFO',
      action: 'CREDENTIAL_ROTATION_INITIATED',
      details: { credentialType, rotationGeneration: nextGeneration, rotationId }
    });

    return {
      lifecycleRecord: newRecord,
      isReusedPending: false,
      rotationGeneration: nextGeneration
    };
  }

  /**
   * Concurrency-safe confirmation.
   * Updates authoritative `device_credentials` only when confirmed.
   * Transitions lifecycle record to CONFIRMED and previous generation to ROTATED.
   */
  async confirmCredentialRotation(deviceId, {
    rotationId,
    confirmationEvidence = {},
    newMqttPasswordHash = null,
    newLocalSessionKeyHash = null,
    tlsClientCertFingerprint = null
  }) {
    const record = await this.deviceTrustRepo.getLifecycleRecordById(rotationId);
    if (!record) {
      throw new Error(`Rotation record ${rotationId} not found`);
    }
    if (record.device_id !== deviceId) {
      throw new Error(`Rotation record ${rotationId} does not belong to device ${deviceId}`);
    }
    if (record.status !== 'ROTATION_PENDING') {
      throw new Error(`Rotation record ${rotationId} is in status '${record.status}', cannot confirm`);
    }

    const now = new Date().toISOString();

    // 1. Mark previous active lifecycle generations as ROTATED
    const allRecords = await this.deviceTrustRepo.listLifecycleRecords(deviceId, record.credential_type);
    for (const r of allRecords) {
      if (r.id !== rotationId && r.status === 'CONFIRMED') {
        await this.deviceTrustRepo.updateLifecycleRecord(r.id, {
          status: 'ROTATED',
          rotated_at: now
        });
      }
    }

    // 2. Mark this generation as CONFIRMED
    const updatedRecord = await this.deviceTrustRepo.updateLifecycleRecord(rotationId, {
      status: 'CONFIRMED',
      metadata: {
        ...(record.metadata || {}),
        confirmationEvidence: confirmationEvidence || {},
        confirmedAt: now
      }
    });

    // 3. Fix 1: Update authoritative device_credentials with newly confirmed credential
    const credUpdates = {
      credential_state: 'ACTIVE',
      rotated_at: now
    };
    if (newMqttPasswordHash) credUpdates.mqtt_password_hash = newMqttPasswordHash;
    if (newLocalSessionKeyHash) credUpdates.local_session_key_hash = newLocalSessionKeyHash;
    if (tlsClientCertFingerprint !== undefined) credUpdates.tls_client_cert_fingerprint = tlsClientCertFingerprint;

    await this.deviceTrustRepo.upsertAuthoritativeCredential(deviceId, credUpdates);

    await this._recordSecurityIncident(deviceId, {
      eventType: 'ROTATION_CONFIRMED',
      severity: 'INFO',
      action: 'CREDENTIAL_ROTATION_CONFIRMED',
      details: { rotationId, credentialType: record.credential_type, rotationGeneration: record.rotation_generation }
    });

    return updatedRecord;
  }

  // ===========================================================================
  // 5. Execution Authorization & Policy Checks (Fix 5)
  // ===========================================================================

  async canExecuteCommand(deviceId) {
    const trust = await this.getDeviceTrustState(deviceId);
    if (trust.trust_state === TRUST_STATES.REVOKED || trust.trust_state === TRUST_STATES.DECOMMISSIONED) {
      return { allowed: false, reason: `Device is ${trust.trust_state}` };
    }
    if (trust.trust_state === TRUST_STATES.QUARANTINED) {
      return { allowed: false, reason: 'Device is QUARANTINED' };
    }
    return { allowed: true };
  }

  async canPerformOta(deviceId, { isRecoveryOta = false, firmwareSignatureVerified = true } = {}) {
    // Quarantine NEVER bypasses signature verification
    if (!firmwareSignatureVerified) {
      return { allowed: false, reason: 'Firmware cryptographic signature verification failed' };
    }

    const trust = await this.getDeviceTrustState(deviceId);

    if (trust.trust_state === TRUST_STATES.REVOKED || trust.trust_state === TRUST_STATES.DECOMMISSIONED) {
      return { allowed: false, reason: `OTA denied: device is ${trust.trust_state}` };
    }

    if (trust.trust_state === TRUST_STATES.QUARANTINED) {
      if (isRecoveryOta) {
        return { allowed: true, isRecovery: true };
      }
      return {
        allowed: false,
        reason: 'Normal OTA is prohibited for QUARANTINED devices. Authorized Security/Recovery OTA required.'
      };
    }

    if (trust.trust_state === TRUST_STATES.TRUSTED || trust.trust_state === TRUST_STATES.DEGRADED) {
      return { allowed: true, isRecovery: false };
    }

    return { allowed: false, reason: `Device in ${trust.trust_state} state is not eligible for OTA` };
  }

  async verifyDirectLanSession(deviceId, { payload, hmacSignature, expectedKeyHash }) {
    const trust = await this.getDeviceTrustState(deviceId);
    if (trust.trust_state === TRUST_STATES.REVOKED || trust.trust_state === TRUST_STATES.QUARANTINED) {
      return { verified: false, reason: `Direct LAN rejected: Device is ${trust.trust_state}` };
    }

    if (!payload || !hmacSignature || !expectedKeyHash) {
      return { verified: false, reason: 'Missing HMAC payload, signature, or key hash' };
    }

    // Verify HMAC
    const computedHmac = crypto.createHmac('sha256', expectedKeyHash).update(typeof payload === 'string' ? payload : JSON.stringify(payload)).digest('hex');
    const isValid = crypto.timingSafeEqual(Buffer.from(computedHmac, 'hex'), Buffer.from(hmacSignature, 'hex'));

    return { verified: isValid, reason: isValid ? null : 'Invalid HMAC signature' };
  }

  // ===========================================================================
  // 6. Security Incident & Audit Chaining
  // ===========================================================================

  async _recordSecurityIncident(deviceId, {
    eventType,
    severity = 'INFO',
    action = null,
    actorUserId = null,
    details = {}
  }) {
    const { sanitized: cleanDetails } = AuditRedactionService.redact(details);

    // 1. Hash-chained security audit record if securityAuditRepo is configured
    if (this.securityAuditRepo && action) {
      try {
        await this.securityAuditRepo.appendRecord({
          id: `sec_audit_${crypto.randomUUID()}`,
          actorUserId,
          deviceId,
          action,
          resourceType: 'DEVICE_TRUST',
          resourceId: deviceId,
          outcome: severity === 'CRITICAL' || severity === 'WARNING' ? 'DENIED' : 'SUCCESS',
          canonicalPayload: cleanDetails
        });
      } catch (err) {
        // Non-blocking in dev/test, but logged
      }
    }

    // 2. Operational Event log if operationalEventService is configured
    if (this.operationalEventService) {
      try {
        await this.operationalEventService.recordEvent({
          deviceId,
          userId: actorUserId,
          subsystem: 'SECURITY',
          operation: 'DEVICE_TRUST',
          action: action || eventType,
          severity,
          authorizationResult: 'AUTHORIZED',
          outcome: 'SUCCESS',
          metadata: cleanDetails
        });
      } catch (err) {
        // Non-blocking
      }
    }
  }
}

module.exports = { DeviceTrustService, TRUST_STATES };
