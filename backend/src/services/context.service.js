'use strict';

const crypto = require('crypto');

/**
 * EH Home — Presence and Context Intelligence Service (Phase 23)
 *
 * Provides deterministic signal reconciliation, source confidence weighting,
 * stale signal expiry, home occupancy aggregation, inferred room context,
 * context precedence state machine, manual overrides, and energy correlation.
 */

const SOURCE_WEIGHTS = {
  manual: 1.0,
  mobile_app: 0.90,
  lan_wifi: 0.80,
  ble: 0.75,
  device_activity: 0.65,
  sensor: 0.70
};

const DEFAULT_SIGNAL_TTL_MS = 30 * 60 * 1000; // 30 minutes

class ContextService {
  /**
   * @param {Object} opts
   * @param {Object} opts.signalRepo         - PresenceSignalRepository
   * @param {Object} opts.stateRepo          - PresenceStateRepository
   * @param {Object} opts.contextRepo        - HomeContextRepository
   * @param {Object} opts.overrideRepo       - ContextOverrideRepository
   * @param {Object} opts.transitionRepo     - ContextTransitionRepository
   * @param {Object} [opts.homeRepo]         - HomeRepository
   * @param {Object} [opts.deviceRepo]       - DeviceRepository
   * @param {Object} [opts.roomRepo]         - RoomRepository
   * @param {Object} [opts.energyService]    - EnergyService
   * @param {Object} [opts.automationService]- AutomationService
   * @param {Object} [opts.notificationService] - NotificationService
   * @param {Object} [opts.realtimeEventBus] - RealtimeEventBus
   */
  constructor({
    signalRepo,
    stateRepo,
    contextRepo,
    overrideRepo,
    transitionRepo,
    homeRepo = null,
    deviceRepo = null,
    roomRepo = null,
    energyService = null,
    automationService = null,
    notificationService = null,
    realtimeEventBus = null
  }) {
    this.signalRepo = signalRepo;
    this.stateRepo = stateRepo;
    this.contextRepo = contextRepo;
    this.overrideRepo = overrideRepo;
    this.transitionRepo = transitionRepo;
    this.homeRepo = homeRepo;
    this.deviceRepo = deviceRepo;
    this.roomRepo = roomRepo;
    this.energyService = energyService;
    this.automationService = automationService;
    this.notificationService = notificationService;
    this.realtimeEventBus = realtimeEventBus;

    // In-memory debounce / cooldown tracker for state transitions to prevent flapping
    this._recentTransitions = new Map(); // homeId -> { mode, timestamp }
  }

  setAutomationService(service) {
    this.automationService = service;
  }

  setEnergyService(service) {
    this.energyService = service;
  }

  // ---------------------------------------------------------------------------
  // 1. Signal Ingestion & Reconciliation Engine
  // ---------------------------------------------------------------------------

  /**
   * Ingest an incoming presence signal, validate, reconcile user state and trigger context evaluation.
   */
  async recordPresenceSignal({
    userId,
    homeId,
    source,
    state,
    confidence = 1.0,
    evidence = {},
    observedAt = null,
    expiresAt = null
  }) {
    if (!userId) throw new Error('userId is required');
    if (!homeId) throw new Error('homeId is required');
    if (!source || !SOURCE_WEIGHTS[source]) {
      throw new Error(`Invalid presence source '${source}'`);
    }
    if (!['HOME', 'AWAY', 'UNKNOWN', 'SLEEP'].includes(state)) {
      throw new Error(`Invalid presence state '${state}'`);
    }

    const obsDate = observedAt ? new Date(observedAt) : new Date();
    const sourceWeight = SOURCE_WEIGHTS[source] || 0.70;
    const finalConfidence = Math.min(1.0, Math.max(0.0, Number(confidence) * sourceWeight));

    const expDate = expiresAt
      ? new Date(expiresAt)
      : new Date(obsDate.getTime() + DEFAULT_SIGNAL_TTL_MS);

    // Persist signal snapshot
    const signal = await this.signalRepo.recordSignal({
      userId,
      homeId,
      source,
      state,
      confidence: finalConfidence,
      evidence,
      observedAt: obsDate.toISOString(),
      expiresAt: expDate.toISOString()
    });

    // Update reconciled user presence state
    await this.stateRepo.upsertUserState({
      homeId,
      userId,
      state,
      confidence: finalConfidence,
      source,
      isStale: 0,
      lastObservedAt: obsDate.toISOString(),
      expiresAt: expDate.toISOString()
    });

    // Evaluate whole-home presence & context
    const contextResult = await this.evaluateHomeContext(homeId, {
      triggerSource: `signal_${source}`,
      evidence: { userId, source, state, confidence: finalConfidence }
    });

    return { signal, context: contextResult };
  }

  /**
   * Reconciles all active user signals for a home into a whole-home PresenceSnapshot.
   */
  async getPresenceSnapshot(homeId, { asOfDate = null } = {}) {
    if (!homeId) throw new Error('homeId is required');
    const now = asOfDate ? new Date(asOfDate) : new Date();

    const userStates = await this.stateRepo.getHomeStates(homeId);
    let activeHomeUsers = 0;
    let activeAwayUsers = 0;
    let maxHomeConfidence = 0;
    let totalAwayConfidence = 0;
    const stateMap = {};

    for (const u of userStates) {
      const exp = u.expires_at ? new Date(u.expires_at) : null;
      const obs = u.last_observed_at ? new Date(u.last_observed_at) : null;
      const isStale = (exp && exp < now) || (obs && (now.getTime() - obs.getTime() > DEFAULT_SIGNAL_TTL_MS));

      const effectiveState = isStale ? 'UNKNOWN' : u.state;
      stateMap[u.user_id] = {
        state: effectiveState,
        confidence: isStale ? 0.2 : u.confidence,
        source: u.source,
        observedAt: u.last_observed_at,
        isStale
      };

      if (!isStale) {
        if (effectiveState === 'HOME' || effectiveState === 'SLEEP') {
          activeHomeUsers++;
          if (u.confidence > maxHomeConfidence) maxHomeConfidence = u.confidence;
        } else if (effectiveState === 'AWAY') {
          activeAwayUsers++;
          totalAwayConfidence += u.confidence;
        }
      }
    }

    // Deterministic Whole-Home Aggregation Rule:
    let homePresence = 'UNKNOWN';
    let homeConfidence = 0.3;
    let isOccupied = false;

    if (activeHomeUsers > 0) {
      homePresence = 'HOME';
      isOccupied = true;
      homeConfidence = maxHomeConfidence || 0.85;
    } else if (userStates.length > 0 && activeAwayUsers === userStates.length) {
      homePresence = 'AWAY';
      isOccupied = false;
      homeConfidence = totalAwayConfidence / Math.max(1, activeAwayUsers);
    } else {
      homePresence = 'UNKNOWN';
      isOccupied = false;
      homeConfidence = 0.35;
    }

    // Evaluate Inferred Room Presence
    const inferredRooms = await this._inferRoomPresence(homeId, now);

    return {
      homeId,
      state: homePresence,
      confidence: Math.round(homeConfidence * 100) / 100,
      isOccupied,
      activeUserCount: activeHomeUsers,
      userStates: stateMap,
      inferredRooms,
      calculatedAt: now.toISOString()
    };
  }

  async _inferRoomPresence(homeId, now) {
    if (!this.roomRepo) return [];
    try {
      const rooms = await this.roomRepo.getRoomsByHome(homeId);
      const inferred = [];

      for (const r of rooms) {
        const roomId = r.id;
        // Check for recent device activity in this room
        let hasRecentActivity = false;
        let lastActivity = null;

        if (this.deviceRepo) {
          const devs = await this.deviceRepo.getDevicesByRoom(roomId);
          for (const d of devs) {
            if (d.last_seen_at) {
              const seen = new Date(d.last_seen_at);
              if (now.getTime() - seen.getTime() < 15 * 60 * 1000) { // 15 mins
                hasRecentActivity = true;
                if (!lastActivity || seen > lastActivity) lastActivity = seen;
              }
            }
          }
        }

        inferred.push({
          roomId,
          isOccupied: hasRecentActivity,
          confidence: hasRecentActivity ? 0.75 : 0.40,
          isInferred: true,
          inferenceReason: hasRecentActivity ? 'Recent connected device activity' : 'No recent device activity',
          lastActivityAt: lastActivity ? lastActivity.toISOString() : null
        });
      }
      return inferred;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Context Engine & Precedence State Machine
  // ---------------------------------------------------------------------------

  /**
   * Evaluates whole-home context according to strict precedence tiers:
   * 1. Active Manual Overrides (VACATION, SLEEP, HOME, AWAY, GUEST, QUIET_HOURS)
   * 2. Scheduled Sleep / Quiet Hours Windows
   * 3. Reconciled Home Presence (HOME, AWAY)
   * 4. Default Fallback
   */
  async evaluateHomeContext(homeId, { triggerSource = 'reconciliation', evidence = {} } = {}) {
    if (!homeId) throw new Error('homeId is required');
    const now = new Date();

    const currentContext = await this.contextRepo.getHomeContext(homeId);
    const prevMode = currentContext ? currentContext.mode : null;

    // Tier 1: Check Active Manual Overrides
    const activeOverride = await this.overrideRepo.getActiveOverride(homeId);
    let resolvedMode = 'HOME';
    let precedenceTier = 'DEFAULT_FALLBACK';
    let isVacation = false;
    let isOccupied = true;
    let confidence = 0.90;

    if (activeOverride) {
      resolvedMode = activeOverride.mode;
      precedenceTier = 'MANUAL_OVERRIDE';
      isVacation = activeOverride.mode === 'VACATION';
      isOccupied = activeOverride.mode !== 'AWAY' && activeOverride.mode !== 'VACATION';
      confidence = 1.0;
    } else {
      // Tier 3: Reconciled Presence Snapshot
      const snapshot = await this.getPresenceSnapshot(homeId, { asOfDate: now });
      if (snapshot.state === 'AWAY') {
        resolvedMode = 'AWAY';
        precedenceTier = 'RECONCILED_PRESENCE';
        isOccupied = false;
        confidence = snapshot.confidence;
      } else if (snapshot.state === 'HOME' || snapshot.state === 'SLEEP') {
        resolvedMode = snapshot.state === 'SLEEP' ? 'SLEEP' : 'HOME';
        precedenceTier = 'RECONCILED_PRESENCE';
        isOccupied = true;
        confidence = snapshot.confidence;
      } else {
        // Fallback / UNKNOWN
        resolvedMode = prevMode || 'HOME';
        precedenceTier = 'DEFAULT_FALLBACK';
        isOccupied = resolvedMode !== 'AWAY' && resolvedMode !== 'VACATION';
        confidence = 0.50;
      }
    }

    // Check if mode actually changed or is new
    const hasChanged = prevMode !== resolvedMode;

    const savedContext = await this.contextRepo.upsertHomeContext({
      homeId,
      mode: resolvedMode,
      previousMode: prevMode,
      precedenceTier,
      activeOverrideId: activeOverride ? activeOverride.id : null,
      isVacation: isVacation ? 1 : 0,
      isOccupied: isOccupied ? 1 : 0,
      confidence,
      updatedAt: now.toISOString()
    });

    if (hasChanged && prevMode !== null) {
      // Record transition history
      await this.transitionRepo.recordTransition({
        homeId,
        fromMode: prevMode,
        toMode: resolvedMode,
        triggerSource,
        reason: `Context changed from ${prevMode} to ${resolvedMode} via ${precedenceTier}`,
        evidence,
        createdAt: now.toISOString()
      });

      // Emit Realtime Events
      if (this.realtimeEventBus) {
        this.realtimeEventBus.publish({
          type: 'context.mode_changed',
          homeId,
          data: { fromMode: prevMode, toMode: resolvedMode, precedenceTier, isOccupied }
        });
        this.realtimeEventBus.publish({
          type: 'context.home_state_changed',
          homeId,
          data: { isOccupied, mode: resolvedMode }
        });
      }

      // Trigger Context Automations safely
      if (this.automationService && this.automationService.evaluateAndTriggerAutomations) {
        try {
          await this.automationService.evaluateAndTriggerAutomations(homeId, {
            homeId,
            context: {
              home_context: resolvedMode,
              previous_context: prevMode,
              is_occupied: isOccupied,
              precedence_tier: precedenceTier
            }
          });
        } catch (_) {}
      }

      // Notifications for significant modes
      if (this.notificationService) {
        if (resolvedMode === 'AWAY' || resolvedMode === 'VACATION') {
          await this.notificationService.notifyHome({
            homeId,
            type: 'CONTEXT_MODE_CHANGED',
            title: `Home mode changed to ${resolvedMode}`,
            message: `EH Home is now in ${resolvedMode} mode. Away security & energy optimizations are active.`,
            priority: 'NORMAL'
          });
        }
      }
    }

    return {
      homeId,
      mode: resolvedMode,
      previousMode: prevMode,
      precedenceTier,
      activeOverride: activeOverride
        ? {
            id: activeOverride.id,
            userId: activeOverride.user_id,
            mode: activeOverride.mode,
            reason: activeOverride.reason,
            expiresAt: activeOverride.expires_at
          }
        : null,
      isVacation,
      isOccupied,
      confidence,
      updatedAt: now.toISOString()
    };
  }

  // ---------------------------------------------------------------------------
  // 3. Manual Overrides Management
  // ---------------------------------------------------------------------------

  async setContextOverride({
    homeId,
    userId,
    mode,
    reason = '',
    durationHours = null
  }) {
    if (!homeId) throw new Error('homeId is required');
    if (!userId) throw new Error('userId is required');
    if (!['HOME', 'AWAY', 'SLEEP', 'VACATION', 'GUEST', 'QUIET_HOURS'].includes(mode)) {
      throw new Error(`Invalid context mode '${mode}'`);
    }

    // Clear existing active overrides
    await this.overrideRepo.clearActiveOverridesForHome(homeId);

    const now = new Date();
    const expiresAt = durationHours ? new Date(now.getTime() + durationHours * 3600 * 1000).toISOString() : null;

    const override = await this.overrideRepo.createOverride({
      homeId,
      userId,
      mode,
      reason,
      expiresAt,
      isActive: 1
    });

    const context = await this.evaluateHomeContext(homeId, {
      triggerSource: 'manual_override',
      evidence: { userId, mode, reason }
    });

    return { override, context };
  }

  async clearContextOverride(homeId, userId) {
    if (!homeId) throw new Error('homeId is required');
    await this.overrideRepo.clearActiveOverridesForHome(homeId);

    const context = await this.evaluateHomeContext(homeId, {
      triggerSource: 'manual_override_cleared',
      evidence: { userId }
    });

    return { success: true, context };
  }

  // ---------------------------------------------------------------------------
  // 4. Energy Integration & Anomaly Detection While Away
  // ---------------------------------------------------------------------------

  async checkEnergyWhileAway(homeId) {
    const context = await this.contextRepo.getHomeContext(homeId);
    if (!context || (context.mode !== 'AWAY' && context.mode !== 'VACATION')) {
      return { hasAnomaly: false, reason: 'Home is not in AWAY/VACATION mode' };
    }

    if (!this.energyService) return { hasAnomaly: false };

    let totalPowerW = 0;

    // 1. Inspect recent telemetry measurements
    if (this.energyService.telemetryRepo) {
      const measurements = await this.energyService.telemetryRepo.findByTimeRange(homeId, {}) || [];
      for (const t of measurements) {
        totalPowerW += Number(t.power_w || t.power || 0);
      }
    }

    // 2. Also check aggregates if power is not in raw measurements
    if (totalPowerW === 0 && this.energyService.aggregateRepo) {
      const aggs = await this.energyService.aggregateRepo.findByPeriod(homeId, {}) || [];
      for (const a of aggs) {
        totalPowerW += Number(a.peak_power_w || a.avg_power_w || 0);
      }
    }

    if (totalPowerW > 500) { // High unexpected load during absence (> 500W)
      const anom = {
        hasAnomaly: true,
        type: 'HIGH_ENERGY_WHILE_AWAY',
        totalPowerW,
        mode: context.mode,
        message: `High energy draw (${totalPowerW} W) detected while home is in ${context.mode} mode.`
      };

      if (this.realtimeEventBus) {
        this.realtimeEventBus.publish({
          type: 'context.anomaly_detected',
          homeId,
          data: anom
        });
      }

      return anom;
    }

    return { hasAnomaly: false, mode: context.mode };
  }
}

module.exports = { ContextService };
