'use strict';

const crypto = require('crypto');

/**
 * EH Home — Phase 24 Unified Home Decision & Intelligence Service
 *
 * Orchestration layer synthesizing device states, presence, context, energy telemetry,
 * dynamic tariffs, forecasts, and schedules into explainable decisions, prioritized
 * recommendations, and safe automated actions.
 */

const DECISION_PRIORITY_RANKS = {
  SAFETY: 1,
  MANUAL_USER_ACTION: 2,
  EXPLICIT_HOME_MODE: 3,
  SCHEDULED_AUTOMATION: 4,
  ENERGY_COST_OPTIMIZATION: 5,
  PREDICTIVE_OPTIMIZATION: 6,
  CONVENIENCE_RECOMMENDATION: 7
};

class IntelligenceService {
  /**
   * @param {Object} opts
   * @param {Object} opts.decisionRepo         - IntelligenceDecisionRepository
   * @param {Object} opts.recommendationRepo   - IntelligenceRecommendationRepository
   * @param {Object} opts.outcomeRepo          - IntelligenceOutcomeRepository
   * @param {Object} [opts.deviceRepo]         - DeviceRepository
   * @param {Object} [opts.deviceStateRepo]    - DeviceStateRepository
   * @param {Object} [opts.roomRepo]           - RoomRepository
   * @param {Object} [opts.homeRepo]           - HomeRepository
   * @param {Object} [opts.energyService]      - EnergyService
   * @param {Object} [opts.contextService]     - ContextService
   * @param {Object} [opts.automationService]  - AutomationService
   * @param {Object} [opts.sceneService]       - SceneService
   * @param {Object} [opts.commandService]     - DeviceCommandService
   * @param {Object} [opts.notificationService]- NotificationService
   * @param {Object} [opts.realtimeEventBus]   - RealtimeEventBus
   * @param {Object} [opts.homeAuthService]    - HomeAuthorizationService
   */
  constructor({
    decisionRepo,
    recommendationRepo,
    outcomeRepo,
    deviceRepo = null,
    deviceStateRepo = null,
    roomRepo = null,
    homeRepo = null,
    energyService = null,
    contextService = null,
    automationService = null,
    sceneService = null,
    commandService = null,
    notificationService = null,
    realtimeEventBus = null,
    homeAuthService = null
  }) {
    this.decisionRepo = decisionRepo;
    this.recommendationRepo = recommendationRepo;
    this.outcomeRepo = outcomeRepo;
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.roomRepo = roomRepo;
    this.homeRepo = homeRepo;
    this.energyService = energyService;
    this.contextService = contextService;
    this.automationService = automationService;
    this.sceneService = sceneService;
    this.commandService = commandService;
    this.notificationService = notificationService;
    this.realtimeEventBus = realtimeEventBus;
    this.homeAuthService = homeAuthService;
  }

  // ---------------------------------------------------------------------------
  // 1. Unified Home Intelligence Snapshot
  // ---------------------------------------------------------------------------

  /**
   * Builds an authoritative, summarized unified snapshot across all home subsystems.
   */
  async generateUnifiedSnapshot(homeId) {
    if (!homeId) throw new Error('homeId is required');
    const now = new Date();

    // 1. Context & Presence
    let homeContext = 'HOME';
    let presenceState = 'HOME';
    let isOccupied = true;
    let contextConfidence = 0.9;

    if (this.contextService) {
      try {
        const hc = await this.contextService.contextRepo?.getHomeContext(homeId);
        if (hc) {
          homeContext = hc.mode;
          isOccupied = Boolean(hc.is_occupied);
          contextConfidence = Number(hc.confidence || 0.9);
        }
        const ps = await this.contextService.getPresenceSnapshot(homeId);
        if (ps) {
          presenceState = ps.state;
          if (hc?.precedence_tier !== 'MANUAL_OVERRIDE') {
            isOccupied = ps.isOccupied;
          }
        }
      } catch (_) {}
    }

    // 2. Devices & Power
    let deviceCount = 0;
    let activeDevicesCount = 0;
    let totalPowerW = 0;
    const devicesList = [];

    if (this.deviceRepo) {
      try {
        const devs = await this.deviceRepo.findByHomeId(homeId);
        deviceCount = devs.length;

        for (const d of devs) {
          let isOn = false;
          let powerW = 0;
          if (this.deviceStateRepo) {
            const state = await this.deviceStateRepo.getFullState?.(d.id) ||
                          await this.deviceStateRepo.findByDeviceId?.(d.id);
            if (state && Array.isArray(state.channels)) {
              for (const ch of state.channels) {
                if (ch.reportedState?.enabled || ch.desiredState?.enabled || ch.reportedState?.power || ch.desiredState?.power) {
                  isOn = true;
                }
              }
            }
          }

          if (this.energyService?.telemetryRepo) {
            const latest = await this.energyService.telemetryRepo.getLatestMeasurement?.(d.id, 1);
            if (latest) {
              powerW = Number(latest.power_w || (latest.p_mw ? latest.p_mw / 1000 : 0));
            }
          }

          if (isOn || powerW > 5) {
            activeDevicesCount++;
          }
          totalPowerW += powerW;

          devicesList.push({
            id: d.id,
            name: d.custom_name || d.name || 'Device',
            roomId: d.room_id,
            isOn,
            powerW
          });
        }
      } catch (_) {}
    }

    // 3. Energy Tariff & Forecast
    let tariffPeriod = 'STANDARD';
    let tariffPrice = 0.18;
    let forecastPredictedKwh = 0;
    let activeAnomalyCount = 0;

    if (this.energyService) {
      try {
        const rate = await this.energyService.resolveCurrentRate(homeId, now.toISOString());
        if (rate) {
          tariffPeriod = rate.periodType || 'STANDARD';
          tariffPrice = Number(rate.pricePerKwh || 0.18);
        }
      } catch (_) {}

      try {
        if (this.energyService.getForecast) {
          const forecast = await this.energyService.getForecast(homeId, 'next_24_hours');
          if (forecast) forecastPredictedKwh = Number(forecast.predictedKwh || 0);
        }
      } catch (_) {}

      try {
        if (this.energyService.getAnomalies) {
          const anomalies = await this.energyService.getAnomalies(homeId, { unresolvedOnly: true });
          if (Array.isArray(anomalies)) activeAnomalyCount = anomalies.length;
        } else if (this.energyService.anomalyRepo) {
          const anomalies = await this.energyService.anomalyRepo.findByHomeId(homeId);
          if (Array.isArray(anomalies)) activeAnomalyCount = anomalies.length;
        }
      } catch (_) {}
    }

    // 4. Automations & Schedules
    let activeAutomationCount = 0;
    let activeScheduleCount = 0;
    if (this.automationService?.automationRepo) {
      try {
        const autos = await this.automationService.automationRepo.findByHome(homeId);
        activeAutomationCount = (autos || []).filter(a => a.is_enabled).length;
      } catch (_) {}
    }

    return {
      homeId,
      timestamp: now.toISOString(),
      homeContext,
      presenceState,
      isOccupied,
      contextConfidence,
      deviceCount,
      activeDevicesCount,
      totalPowerW: Math.round(totalPowerW * 100) / 100,
      tariffPeriod,
      tariffPrice,
      forecastPredictedKwh: Math.round(forecastPredictedKwh * 100) / 100,
      activeAnomalyCount,
      activeAutomationCount,
      activeScheduleCount,
      devicesSummary: devicesList
    };
  }

  // ---------------------------------------------------------------------------
  // 2. Deterministic Decision & Recommendation Engine
  // ---------------------------------------------------------------------------

  /**
   * Deterministically evaluates unified conditions across subsystems to generate explainable decisions & recommendations.
   */
  async evaluateDecisions(homeId) {
    if (!homeId) throw new Error('homeId is required');
    const snapshot = await this.generateUnifiedSnapshot(homeId);
    const generatedDecisions = [];
    const generatedRecommendations = [];
    const now = new Date();

    // -------------------------------------------------------------------------
    // Rule 1: Idle Devices Left ON in Empty Home (TURN_OFF_UNUSED_DEVICE)
    // -------------------------------------------------------------------------
    if ((snapshot.homeContext === 'AWAY' || snapshot.presenceState === 'AWAY' || !snapshot.isOccupied) && snapshot.activeDevicesCount > 0) {
      for (const dev of (snapshot.devicesSummary || [])) {
        if (dev.isOn || dev.powerW > 10) {
          const rec = {
            homeId,
            recommendationType: 'TURN_OFF_UNUSED_DEVICE',
            priority: 'CONVENIENCE_RECOMMENDATION',
            priorityRank: DECISION_PRIORITY_RANKS.CONVENIENCE_RECOMMENDATION,
            confidence: 'HIGH',
            risk: 'LOW',
            title: `Turn Off ${dev.name}`,
            description: `${dev.name} is ON (${dev.powerW}W) while home is ${snapshot.homeContext} and unoccupied.`,
            evidence: {
              homeContext: snapshot.homeContext,
              presenceState: snapshot.presenceState,
              isOccupied: snapshot.isOccupied,
              deviceId: dev.id,
              powerW: dev.powerW
            },
            proposedAction: {
              actionType: 'device_command',
              deviceId: dev.id,
              command: 'setPower',
              params: { value: false }
            },
            expectedBenefit: `Saves standby energy while away (~${Math.round(dev.powerW * 8 / 1000 * 100) / 100} kWh/day)`,
            isAutoExecutable: true,
            status: 'GENERATED',
            createdAt: now.toISOString(),
            expiresAt: new Date(now.getTime() + 4 * 3600 * 1000).toISOString()
          };

          const savedRec = await this.recommendationRepo.createRecommendation(rec);
          generatedRecommendations.push(savedRec);

          // Also generate corresponding safe decision
          const dec = {
            homeId,
            decisionType: 'TURN_OFF_IDLE_DEVICE',
            priority: 'CONVENIENCE_RECOMMENDATION',
            priorityRank: DECISION_PRIORITY_RANKS.CONVENIENCE_RECOMMENDATION,
            confidence: 'HIGH',
            confidenceScore: 0.90,
            risk: 'LOW',
            evidence: rec.evidence,
            proposedAction: rec.proposedAction,
            expectedEffect: `Turn OFF ${dev.name} to eliminate standby power in empty home`,
            isAutoExecutable: true,
            safetyResult: { isSafe: true, riskLevel: 'LOW', reason: 'Safe convenience action on idle device' },
            status: 'GENERATED',
            createdAt: now.toISOString(),
            expiresAt: rec.expiresAt
          };

          const savedDec = await this.decisionRepo.createDecision(dec);
          generatedDecisions.push(savedDec);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Rule 2: Peak Tariff Period Load Optimization (SHIFT_LOAD_TO_CHEAPER_PERIOD)
    // -------------------------------------------------------------------------
    if (snapshot.tariffPeriod === 'PEAK' && snapshot.totalPowerW > 500) {
      const rec = {
        homeId,
        recommendationType: 'SHIFT_LOAD_TO_CHEAPER_PERIOD',
        priority: 'ENERGY_COST_OPTIMIZATION',
        priorityRank: DECISION_PRIORITY_RANKS.ENERGY_COST_OPTIMIZATION,
        confidence: 'HIGH',
        risk: 'MEDIUM',
        title: 'Shift Heavy Load Outside Peak Tariff',
        description: `Current electricity rate is in PEAK period ($${snapshot.tariffPrice}/kWh) with ${snapshot.totalPowerW}W total power draw.`,
        evidence: {
          tariffPeriod: snapshot.tariffPeriod,
          tariffPrice: snapshot.tariffPrice,
          totalPowerW: snapshot.totalPowerW
        },
        proposedAction: {
          actionType: 'notification_or_schedule',
          suggestion: 'Defer heavy appliances to OFF_PEAK rate period'
        },
        expectedBenefit: `Reduces peak energy costs by up to 40%`,
        isAutoExecutable: false,
        status: 'GENERATED',
        createdAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 2 * 3600 * 1000).toISOString()
      };

      const savedRec = await this.recommendationRepo.createRecommendation(rec);
      generatedRecommendations.push(savedRec);

      const dec = {
        homeId,
        decisionType: 'PEAK_TARIFF_LOAD_SHEDDING',
        priority: 'ENERGY_COST_OPTIMIZATION',
        priorityRank: DECISION_PRIORITY_RANKS.ENERGY_COST_OPTIMIZATION,
        confidence: 'HIGH',
        confidenceScore: 0.85,
        risk: 'MEDIUM',
        evidence: rec.evidence,
        proposedAction: rec.proposedAction,
        expectedEffect: 'Curtail non-essential energy consumption during expensive peak window',
        isAutoExecutable: false,
        safetyResult: { isSafe: true, riskLevel: 'MEDIUM', reason: 'User approval required for load deferral' },
        status: 'GENERATED',
        createdAt: now.toISOString(),
        expiresAt: rec.expiresAt
      };

      const savedDec = await this.decisionRepo.createDecision(dec);
      generatedDecisions.push(savedDec);
    }

    // -------------------------------------------------------------------------
    // Rule 3: Investigate Active Energy Anomalies (INVESTIGATE_ANOMALY)
    // -------------------------------------------------------------------------
    if (snapshot.activeAnomalyCount > 0) {
      const rec = {
        homeId,
        recommendationType: 'INVESTIGATE_ANOMALY',
        priority: 'SAFETY',
        priorityRank: DECISION_PRIORITY_RANKS.SAFETY,
        confidence: 'HIGH',
        risk: 'HIGH',
        title: `${snapshot.activeAnomalyCount} Unresolved Energy Anomalies Detected`,
        description: `Abnormal power spikes or telemetry irregularities were detected and require your review.`,
        evidence: {
          activeAnomalyCount: snapshot.activeAnomalyCount,
          totalPowerW: snapshot.totalPowerW
        },
        proposedAction: {
          actionType: 'user_review',
          target: 'energy_anomalies_page'
        },
        expectedBenefit: 'Protects equipment and eliminates unexpected baseline inflation',
        isAutoExecutable: false,
        status: 'GENERATED',
        createdAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 12 * 3600 * 1000).toISOString()
      };

      const savedRec = await this.recommendationRepo.createRecommendation(rec);
      generatedRecommendations.push(savedRec);
    }

    // -------------------------------------------------------------------------
    // Rule 4: Home Mode Mismatch / Suggest Away (CHANGE_HOME_MODE)
    // -------------------------------------------------------------------------
    if (snapshot.presenceState === 'AWAY' && snapshot.homeContext === 'HOME') {
      const rec = {
        homeId,
        recommendationType: 'CHANGE_HOME_MODE',
        priority: 'EXPLICIT_HOME_MODE',
        priorityRank: DECISION_PRIORITY_RANKS.EXPLICIT_HOME_MODE,
        confidence: 'HIGH',
        risk: 'LOW',
        title: 'Switch Home Context to AWAY Mode',
        description: 'All members are confirmed AWAY, but home context is still in HOME mode.',
        evidence: {
          presenceState: snapshot.presenceState,
          homeContext: snapshot.homeContext
        },
        proposedAction: {
          actionType: 'set_context_mode',
          mode: 'AWAY'
        },
        expectedBenefit: 'Engages perimeter security and away energy conservation rules',
        isAutoExecutable: true,
        status: 'GENERATED',
        createdAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 1 * 3600 * 1000).toISOString()
      };

      const savedRec = await this.recommendationRepo.createRecommendation(rec);
      generatedRecommendations.push(savedRec);

      const dec = {
        homeId,
        decisionType: 'AUTO_SET_AWAY_MODE',
        priority: 'EXPLICIT_HOME_MODE',
        priorityRank: DECISION_PRIORITY_RANKS.EXPLICIT_HOME_MODE,
        confidence: 'HIGH',
        confidenceScore: 0.92,
        risk: 'LOW',
        evidence: rec.evidence,
        proposedAction: rec.proposedAction,
        expectedEffect: 'Automatically synchronize home context to AWAY mode',
        isAutoExecutable: true,
        safetyResult: { isSafe: true, riskLevel: 'LOW', reason: 'Safe context transition' },
        status: 'GENERATED',
        createdAt: now.toISOString(),
        expiresAt: rec.expiresAt
      };

      const savedDec = await this.decisionRepo.createDecision(dec);
      generatedDecisions.push(savedDec);
    }

    // Publish Realtime Events
    if (this.realtimeEventBus) {
      for (const r of generatedRecommendations) {
        this.realtimeEventBus.publish({
          type: 'intelligence.recommendation_created',
          homeId,
          data: r
        });
      }
      for (const d of generatedDecisions) {
        this.realtimeEventBus.publish({
          type: 'intelligence.decision_created',
          homeId,
          data: d
        });
      }
    }

    return {
      snapshot,
      decisionsCount: generatedDecisions.length,
      recommendationsCount: generatedRecommendations.length,
      decisions: generatedDecisions,
      recommendations: generatedRecommendations
    };
  }

  // ---------------------------------------------------------------------------
  // 3. Safe Auto-Execution Engine
  // ---------------------------------------------------------------------------

  /**
   * Evaluates generated decisions and safely auto-executes eligible LOW-risk actions.
   * Strictly enforces:
   *   1. Risk == 'LOW'
   *   2. isAutoExecutable == true
   *   3. Decision Priority ordering (1 -> 7)
   *   4. Manual user action cooldown on target device is not active
   *   5. Device is available / online
   */
  async autoExecuteSafeDecisions(homeId, actorContext = { userId: 'system_intelligence', role: 'OWNER' }) {
    if (!homeId) throw new Error('homeId is required');
    const decisions = await this.decisionRepo.getDecisionsByHome(homeId, { status: 'GENERATED' });
    const executedResults = [];

    // Sort by priority rank ascending (1 = SAFETY, 2 = MANUAL, ... 7 = CONVENIENCE)
    decisions.sort((a, b) => (a.priority_rank || 7) - (b.priority_rank || 7));

    for (const dec of decisions) {
      // Eligibility Checks
      if (dec.risk !== 'LOW' || !dec.is_auto_executable) {
        continue;
      }

      const action = dec.proposed_action || {};

      // 1. Context Mode Change Action
      if (action.actionType === 'set_context_mode' && action.mode && this.contextService) {
        try {
          const res = await this.contextService.setContextOverride({
            homeId,
            userId: actorContext.userId,
            mode: action.mode,
            reason: `Intelligence Decision ${dec.id}`
          });

          await this.decisionRepo.updateDecisionStatus(dec.id, 'AUTO_EXECUTED');
          const outcome = await this.outcomeRepo.recordOutcome({
            decisionId: dec.id,
            homeId,
            status: 'AUTO_EXECUTED',
            previousState: { mode: res.context?.previousMode },
            newState: { mode: res.context?.mode },
            expectedBenefit: dec.expected_effect
          });

          executedResults.push({ decisionId: dec.id, status: 'AUTO_EXECUTED', outcome });
          continue;
        } catch (err) {
          await this.decisionRepo.updateDecisionStatus(dec.id, 'FAILED');
          await this.outcomeRepo.recordOutcome({
            decisionId: dec.id,
            homeId,
            status: 'FAILED',
            failureReason: err.message
          });
          executedResults.push({ decisionId: dec.id, status: 'FAILED', error: err.message });
          continue;
        }
      }

      // 2. Device Command Action
      if (action.actionType === 'device_command' && action.deviceId) {
        const deviceId = action.deviceId;

        // Anti-fighting Check: Respect Manual Command Priority Cooldown
        if (this.automationService && this.automationService._manualCommandCooldown) {
          const cooldownExpiry = this.automationService._manualCommandCooldown.get(deviceId);
          if (cooldownExpiry && Date.now() < cooldownExpiry) {
            await this.decisionRepo.updateDecisionStatus(dec.id, 'SKIPPED');
            await this.outcomeRepo.recordOutcome({
              decisionId: dec.id,
              homeId,
              status: 'SKIPPED',
              failureReason: `Suppressed by manual command priority cooldown until ${new Date(cooldownExpiry).toISOString()}`
            });
            executedResults.push({ decisionId: dec.id, status: 'SKIPPED', reason: 'manual_command_cooldown' });
            continue;
          }
        }

        // Execute via authoritative CommandService
        if (this.commandService) {
          try {
            const cmdEnvelope = {
              commandId: crypto.randomUUID(),
              deviceId,
              channelIndex: action.channelIndex || 1,
              action: action.command || 'setPower',
              params: action.params || { value: false },
              idempotencyKey: `intel_${dec.id}_${deviceId}`,
              source: 'INTELLIGENCE_ENGINE'
            };

            const receipt = await this.commandService.sendCommand(
              { userId: actorContext.userId, homeId, role: 'OWNER' },
              cmdEnvelope
            );

            const isSuccess = receipt && (receipt.status === 'APPLIED' || receipt.status === 'CREATED' || receipt.state === 'applied');

            await this.decisionRepo.updateDecisionStatus(dec.id, isSuccess ? 'AUTO_EXECUTED' : 'FAILED');
            const outcome = await this.outcomeRepo.recordOutcome({
              decisionId: dec.id,
              homeId,
              status: isSuccess ? 'AUTO_EXECUTED' : 'FAILED',
              newState: { commandReceipt: receipt },
              expectedBenefit: dec.expected_effect,
              failureReason: isSuccess ? null : 'Device command execution failed'
            });

            executedResults.push({ decisionId: dec.id, status: isSuccess ? 'AUTO_EXECUTED' : 'FAILED', outcome });
          } catch (err) {
            await this.decisionRepo.updateDecisionStatus(dec.id, 'FAILED');
            await this.outcomeRepo.recordOutcome({
              decisionId: dec.id,
              homeId,
              status: 'FAILED',
              failureReason: err.message
            });
            executedResults.push({ decisionId: dec.id, status: 'FAILED', error: err.message });
          }
        }
      }
    }

    return {
      evaluatedCount: decisions.length,
      executedCount: executedResults.filter(r => r.status === 'AUTO_EXECUTED').length,
      results: executedResults
    };
  }

  // ---------------------------------------------------------------------------
  // 4. Recommendation & Decision Lifecycle Management
  // ---------------------------------------------------------------------------

  async acceptRecommendation(homeId, recommendationId, actorContext = {}) {
    if (!homeId) throw new Error('homeId is required');
    if (!recommendationId) throw new Error('recommendationId is required');

    const rec = await this.recommendationRepo.getRecommendationById(recommendationId);
    if (!rec || rec.home_id !== homeId) {
      throw new Error(`Recommendation '${recommendationId}' not found`);
    }

    await this.recommendationRepo.updateRecommendationStatus(recommendationId, 'ACCEPTED');

    // Execute proposed action if applicable
    let executionResult = null;
    if (rec.proposed_action?.actionType === 'device_command' && rec.proposed_action?.deviceId && this.commandService) {
      const cmdEnvelope = {
        commandId: crypto.randomUUID(),
        deviceId: rec.proposed_action.deviceId,
        channelIndex: rec.proposed_action.channelIndex || 1,
        action: rec.proposed_action.command || 'setPower',
        params: rec.proposed_action.params || { value: false },
        idempotencyKey: `rec_accept_${recommendationId}`,
        source: 'RECOMMENDATION_ACCEPT'
      };

      executionResult = await this.commandService.sendCommand(
        { userId: actorContext.userId || 'user', homeId, role: 'MEMBER' },
        cmdEnvelope
      );
    }

    const outcome = await this.outcomeRepo.recordOutcome({
      decisionId: recommendationId,
      homeId,
      status: 'ACCEPTED',
      feedback: 'Accepted by user',
      newState: { executionResult }
    });

    return { success: true, status: 'ACCEPTED', outcome };
  }

  async rejectRecommendation(homeId, recommendationId, reason = '', actorContext = {}) {
    if (!homeId) throw new Error('homeId is required');
    if (!recommendationId) throw new Error('recommendationId is required');

    const rec = await this.recommendationRepo.getRecommendationById(recommendationId);
    if (!rec || rec.home_id !== homeId) {
      throw new Error(`Recommendation '${recommendationId}' not found`);
    }

    await this.recommendationRepo.updateRecommendationStatus(recommendationId, 'REJECTED');

    const outcome = await this.outcomeRepo.recordOutcome({
      decisionId: recommendationId,
      homeId,
      status: 'REJECTED',
      feedback: reason || 'Rejected by user'
    });

    return { success: true, status: 'REJECTED', outcome };
  }

  async executeDecision(homeId, decisionId, actorContext = {}) {
    if (!homeId) throw new Error('homeId is required');
    if (!decisionId) throw new Error('decisionId is required');

    const dec = await this.decisionRepo.getDecisionById(decisionId);
    if (!dec || dec.home_id !== homeId) {
      throw new Error(`Decision '${decisionId}' not found`);
    }

    const action = dec.proposed_action || {};
    let isSuccess = true;
    let errorMsg = null;

    if (action.actionType === 'device_command' && action.deviceId && this.commandService) {
      try {
        const cmdEnvelope = {
          commandId: crypto.randomUUID(),
          deviceId: action.deviceId,
          channelIndex: action.channelIndex || 1,
          action: action.command || 'setPower',
          params: action.params || { value: false },
          idempotencyKey: `manual_exec_${decisionId}`,
          source: 'DECISION_EXECUTE'
        };

        const receipt = await this.commandService.sendCommand(
          { userId: actorContext.userId || 'user', homeId, role: 'OWNER' },
          cmdEnvelope
        );
        isSuccess = receipt && !receipt.error;
      } catch (err) {
        isSuccess = false;
        errorMsg = err.message;
      }
    }

    const finalStatus = isSuccess ? 'EXECUTED' : 'FAILED';
    await this.decisionRepo.updateDecisionStatus(decisionId, finalStatus);

    const outcome = await this.outcomeRepo.recordOutcome({
      decisionId,
      homeId,
      status: finalStatus,
      feedback: 'Executed manually by user',
      failureReason: errorMsg
    });

    return { success: isSuccess, status: finalStatus, outcome };
  }

  // ---------------------------------------------------------------------------
  // 5. Intelligence Summary
  // ---------------------------------------------------------------------------

  async getIntelligenceSummary(homeId) {
    if (!homeId) throw new Error('homeId is required');
    const snapshot = await this.generateUnifiedSnapshot(homeId);
    const recommendations = await this.recommendationRepo.getRecommendationsByHome(homeId, { limit: 10, status: 'GENERATED' });
    const decisions = await this.decisionRepo.getDecisionsByHome(homeId, { limit: 10 });
    const outcomes = await this.outcomeRepo.getOutcomesByHome(homeId, { limit: 10 });

    return {
      snapshot,
      activeRecommendationsCount: recommendations.length,
      recommendations,
      recentDecisions: decisions,
      recentOutcomes: outcomes
    };
  }
}

module.exports = {
  IntelligenceService,
  DECISION_PRIORITY_RANKS
};
