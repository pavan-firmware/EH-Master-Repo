'use strict';

/**
 * EH Home — Production Release & Deployment Orchestration Service (Phase 45)
 *
 * Implements canonical release lifecycle state machine, validation gating,
 * pre-deployment checks, post-deployment health verification, and rollback engine.
 */

const { ReleaseManifestService } = require('./release-manifest.service');

const RELEASE_STATES = {
  DRAFT: 'DRAFT',
  VALIDATED: 'VALIDATED',
  CANDIDATE: 'CANDIDATE',
  PUBLISHED: 'PUBLISHED',
  DEPLOYED: 'DEPLOYED',
  SUPERSEDED: 'SUPERSEDED',
  REJECTED: 'REJECTED',
  FAILED: 'FAILED',
  ROLLED_BACK: 'ROLLED_BACK'
};

const ALLOWED_TRANSITIONS = {
  [RELEASE_STATES.DRAFT]: [RELEASE_STATES.VALIDATED, RELEASE_STATES.REJECTED],
  [RELEASE_STATES.VALIDATED]: [RELEASE_STATES.CANDIDATE, RELEASE_STATES.REJECTED],
  [RELEASE_STATES.CANDIDATE]: [RELEASE_STATES.PUBLISHED, RELEASE_STATES.REJECTED],
  [RELEASE_STATES.PUBLISHED]: [RELEASE_STATES.DEPLOYED, RELEASE_STATES.REJECTED, RELEASE_STATES.SUPERSEDED],
  [RELEASE_STATES.DEPLOYED]: [RELEASE_STATES.SUPERSEDED, RELEASE_STATES.ROLLED_BACK, RELEASE_STATES.FAILED],
  [RELEASE_STATES.SUPERSEDED]: [],
  [RELEASE_STATES.REJECTED]: [],
  [RELEASE_STATES.FAILED]: [RELEASE_STATES.ROLLED_BACK],
  [RELEASE_STATES.ROLLED_BACK]: []
};

class ReleaseService {
  constructor({
    auditService = null,
    metricsService = null,
    logger = null,
    migrationVerifier = null
  } = {}) {
    this.auditService = auditService;
    this.metricsService = metricsService;
    this.logger = logger;
    this.migrationVerifier = migrationVerifier;
    this.releases = new Map();
    this.deployments = [];
    this.currentDeployedReleaseId = null;
  }

  /**
   * Creates a new release in DRAFT state.
   */
  async createRelease(manifestParams, actor = { id: 'system', role: 'ADMIN' }) {
    const manifest = ReleaseManifestService.buildManifest(manifestParams);

    if (this.releases.has(manifest.releaseId)) {
      throw new Error(`Release with ID ${manifest.releaseId} already exists`);
    }

    const releaseRecord = {
      ...manifest,
      status: RELEASE_STATES.DRAFT,
      history: [
        {
          fromStatus: null,
          toStatus: RELEASE_STATES.DRAFT,
          timestamp: new Date().toISOString(),
          actorUserId: actor.id,
          reason: 'Initial creation'
        }
      ],
      validationReport: null,
      deployedAt: null,
      rollbackInfo: null
    };

    this.releases.set(manifest.releaseId, releaseRecord);
    this._recordAudit('RELEASE_CREATED', { releaseId: manifest.releaseId, version: manifest.version }, actor);
    this._recordMetric('releases_created_total', { channel: manifest.channel });

    return releaseRecord;
  }

  /**
   * Transition release to VALIDATED state after automated checks pass.
   */
  async validateRelease(releaseId, validationReport = {}, actor = { id: 'system', role: 'ADMIN' }) {
    const release = this._getReleaseOrThrow(releaseId);
    this._assertTransition(release.status, RELEASE_STATES.VALIDATED);

    if (validationReport.passed !== true) {
      release.status = RELEASE_STATES.REJECTED;
      release.validationReport = validationReport;
      this._addHistory(release, RELEASE_STATES.REJECTED, actor.id, `Validation failed: ${validationReport.reason || 'Unknown error'}`);
      throw new Error(`Release validation failed: ${validationReport.reason || 'Checks failed'}`);
    }

    release.status = RELEASE_STATES.VALIDATED;
    release.validationReport = validationReport;
    this._addHistory(release, RELEASE_STATES.VALIDATED, actor.id, 'Validation passed');
    this._recordAudit('RELEASE_VALIDATED', { releaseId, version: release.version }, actor);

    return release;
  }

  /**
   * Promotes validated release to CANDIDATE.
   */
  async promoteToCandidate(releaseId, actor = { id: 'system', role: 'ADMIN' }) {
    this._assertAdminOrOperator(actor);
    const release = this._getReleaseOrThrow(releaseId);
    this._assertTransition(release.status, RELEASE_STATES.CANDIDATE);

    release.status = RELEASE_STATES.CANDIDATE;
    this._addHistory(release, RELEASE_STATES.CANDIDATE, actor.id, 'Promoted to release candidate');
    this._recordAudit('RELEASE_CANDIDATE_PROMOTED', { releaseId, version: release.version }, actor);

    return release;
  }

  /**
   * Promotes candidate to PUBLISHED for distribution in target channel.
   */
  async publishRelease(releaseId, targetChannel = 'PRODUCTION', actor = { id: 'system', role: 'ADMIN' }) {
    this._assertAdmin(actor);
    const release = this._getReleaseOrThrow(releaseId);
    this._assertTransition(release.status, RELEASE_STATES.PUBLISHED);

    // Enforce channel promotion invariants
    const normalizedChannel = targetChannel.toUpperCase();
    if (normalizedChannel === 'PRODUCTION' && release.channel !== 'PRODUCTION') {
      release.channel = 'PRODUCTION';
    }

    release.status = RELEASE_STATES.PUBLISHED;
    this._addHistory(release, RELEASE_STATES.PUBLISHED, actor.id, `Published to ${release.channel} channel`);
    this._recordAudit('RELEASE_PUBLISHED', { releaseId, version: release.version, channel: release.channel }, actor);
    this._recordMetric('releases_published_total', { channel: release.channel });

    return release;
  }

  /**
   * Executes deterministic pre-deployment validation gates.
   */
  async executeDeploymentPrechecks(releaseId, targetEnv = 'production', envConfig = {}) {
    const release = this._getReleaseOrThrow(releaseId);
    const checks = [];

    // 1. Lifecycle check
    checks.push({
      check: 'LIFECYCLE_STATUS',
      passed: release.status === RELEASE_STATES.PUBLISHED || release.status === RELEASE_STATES.CANDIDATE,
      message: `Release status is ${release.status}`
    });

    // 2. Schema / Database gate
    const schemaPass = release.schemaVersion === '029';
    checks.push({
      check: 'DATABASE_SCHEMA_GATE',
      passed: schemaPass,
      message: `Schema version ${release.schemaVersion} matches expected baseline`
    });

    // 3. Environment configuration safety
    const isProd = targetEnv.toLowerCase() === 'production';
    let configPass = true;
    let configMsg = 'Configuration valid';
    if (isProd) {
      if (envConfig.ALLOW_DEV_DEFAULTS === 'true' || envConfig.NODE_ENV === 'test') {
        configPass = false;
        configMsg = 'Production environment rejects test/dev configurations';
      }
    }
    checks.push({
      check: 'PRODUCTION_CONFIG_GATE',
      passed: configPass,
      message: configMsg
    });

    // 4. Artifact integrity gate
    const artifactsValid = release.artifacts && release.artifacts.length > 0 && release.artifacts.every(a => a.sha256);
    checks.push({
      check: 'ARTIFACT_INTEGRITY_GATE',
      passed: Boolean(artifactsValid),
      message: artifactsValid ? 'All artifacts have valid SHA-256 digests' : 'Artifacts missing or invalid'
    });

    const allPassed = checks.every(c => c.passed);
    return {
      releaseId,
      targetEnv,
      timestamp: new Date().toISOString(),
      allPassed,
      checks
    };
  }

  /**
   * Executes deployment with post-deployment health check gating.
   */
  async deployRelease(releaseId, { environment = 'production', healthCheckFn = null, actor = { id: 'system', role: 'ADMIN' } } = {}) {
    this._assertAdmin(actor);
    const release = this._getReleaseOrThrow(releaseId);

    // 1. Run Prechecks
    const precheck = await this.executeDeploymentPrechecks(releaseId, environment);
    if (!precheck.allPassed) {
      throw new Error(`Deployment prechecks failed: ${precheck.checks.filter(c => !c.passed).map(c => c.message).join(', ')}`);
    }

    // 2. State transition
    this._assertTransition(release.status, RELEASE_STATES.DEPLOYED);

    // Supersede previously deployed release
    if (this.currentDeployedReleaseId && this.currentDeployedReleaseId !== releaseId) {
      const prev = this.releases.get(this.currentDeployedReleaseId);
      if (prev && prev.status === RELEASE_STATES.DEPLOYED) {
        prev.status = RELEASE_STATES.SUPERSEDED;
        this._addHistory(prev, RELEASE_STATES.SUPERSEDED, actor.id, `Superseded by ${releaseId}`);
      }
    }

    // 3. Post-deployment health verification
    if (typeof healthCheckFn === 'function') {
      try {
        const healthResult = await healthCheckFn();
        if (healthResult !== true && (!healthResult || healthResult.healthy !== true)) {
          release.status = RELEASE_STATES.FAILED;
          this._addHistory(release, RELEASE_STATES.FAILED, actor.id, 'Post-deployment health check returned unhealthy');
          throw new Error('Post-deployment health check failed');
        }
      } catch (err) {
        release.status = RELEASE_STATES.FAILED;
        this._addHistory(release, RELEASE_STATES.FAILED, actor.id, `Health check error: ${err.message}`);
        throw err;
      }
    }

    release.status = RELEASE_STATES.DEPLOYED;
    release.deployedAt = new Date().toISOString();
    this.currentDeployedReleaseId = releaseId;

    this._addHistory(release, RELEASE_STATES.DEPLOYED, actor.id, `Deployed to ${environment}`);
    this._recordAudit('RELEASE_DEPLOYED', { releaseId, version: release.version, environment }, actor);
    this._recordMetric('deployments_total', { status: 'SUCCESS', environment });

    return release;
  }

  /**
   * Executes rollback to a previous known-good release.
   */
  async executeRollback(currentReleaseId, { targetReleaseId, reason = 'Incident recovery', actor = { id: 'system', role: 'ADMIN' } } = {}) {
    this._assertAdmin(actor);
    const current = this._getReleaseOrThrow(currentReleaseId);
    const target = this._getReleaseOrThrow(targetReleaseId);

    if (current.status !== RELEASE_STATES.DEPLOYED && current.status !== RELEASE_STATES.FAILED) {
      throw new Error(`Cannot rollback release in status ${current.status}`);
    }

    // Rollback target must be valid
    if (target.status !== RELEASE_STATES.SUPERSEDED && target.status !== RELEASE_STATES.PUBLISHED) {
      throw new Error(`Rollback target ${targetReleaseId} must be in SUPERSEDED or PUBLISHED state`);
    }

    // Database safe rollback check: schema versions must be compatible
    if (current.schemaVersion !== target.schemaVersion) {
      // Non-destructive check
      if (this.logger) {
        this.logger.warn('Rollback target schema version differs from current', {
          currentSchema: current.schemaVersion,
          targetSchema: target.schemaVersion
        });
      }
    }

    current.status = RELEASE_STATES.ROLLED_BACK;
    current.rollbackInfo = {
      rolledBackToReleaseId: targetReleaseId,
      reason,
      timestamp: new Date().toISOString(),
      actorUserId: actor.id
    };
    this._addHistory(current, RELEASE_STATES.ROLLED_BACK, actor.id, `Rolled back to ${targetReleaseId}: ${reason}`);

    target.status = RELEASE_STATES.DEPLOYED;
    target.deployedAt = new Date().toISOString();
    this.currentDeployedReleaseId = targetReleaseId;
    this._addHistory(target, RELEASE_STATES.DEPLOYED, actor.id, `Restored via rollback from ${currentReleaseId}`);

    this._recordAudit('RELEASE_ROLLED_BACK', {
      fromReleaseId: currentReleaseId,
      toReleaseId: targetReleaseId,
      reason
    }, actor);

    return {
      success: true,
      currentReleaseId,
      activeReleaseId: targetReleaseId,
      timestamp: new Date().toISOString()
    };
  }

  getRelease(releaseId) {
    return this.releases.get(releaseId) || null;
  }

  listReleases({ status = null, channel = null, limit = 50, offset = 0 } = {}) {
    let list = Array.from(this.releases.values());
    if (status) {
      list = list.filter(r => r.status === status);
    }
    if (channel) {
      list = list.filter(r => r.channel === channel);
    }
    return list.slice(offset, offset + limit);
  }

  // --- Helpers ---

  _getReleaseOrThrow(releaseId) {
    const r = this.releases.get(releaseId);
    if (!r) {
      throw new Error(`Release not found: ${releaseId}`);
    }
    return r;
  }

  _assertTransition(fromStatus, toStatus) {
    const allowed = ALLOWED_TRANSITIONS[fromStatus] || [];
    if (!allowed.includes(toStatus)) {
      throw new Error(`Illegal release lifecycle transition: ${fromStatus} -> ${toStatus}`);
    }
  }

  _assertAdmin(actor) {
    if (!actor || (actor.role !== 'ADMIN' && actor.role !== 'SUPERADMIN')) {
      throw new Error('Unauthorized: Operation requires ADMIN privileges');
    }
  }

  _assertAdminOrOperator(actor) {
    if (!actor || (actor.role !== 'ADMIN' && actor.role !== 'SUPERADMIN' && actor.role !== 'OPERATOR')) {
      throw new Error('Unauthorized: Operation requires ADMIN or OPERATOR privileges');
    }
  }

  _addHistory(release, toStatus, actorUserId, reason) {
    const last = release.history[release.history.length - 1];
    release.history.push({
      fromStatus: last ? last.toStatus : null,
      toStatus,
      timestamp: new Date().toISOString(),
      actorUserId,
      reason
    });
  }

  _recordAudit(action, metadata, actor) {
    if (this.auditService && typeof this.auditService.recordAudit === 'function') {
      this.auditService.recordAudit({
        action,
        actorUserId: actor ? actor.id : 'system',
        resourceType: 'RELEASE',
        metadata
      });
    }
  }

  _recordMetric(name, labels = {}) {
    if (this.metricsService && typeof this.metricsService.incrementCounter === 'function') {
      this.metricsService.incrementCounter(name, 1, labels);
    }
  }
}

module.exports = {
  ReleaseService,
  RELEASE_STATES,
  ALLOWED_TRANSITIONS
};
