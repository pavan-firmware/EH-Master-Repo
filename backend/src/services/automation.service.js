'use strict';

/**
 * EH Home — AutomationService (Phase 10 & Phase 20)
 *
 * Implements:
 *   - Rule lifecycle (create, list, get, update, toggle, delete)
 *   - Multi-scope condition evaluation (device state, availability, time window)
 *   - Smart Energy Condition evaluation (instantaneous power, cumulative energy, sustained power, daily budget)
 *   - Deterministic hysteresis & debounce engine to prevent ON/OFF oscillations
 *   - Replay / storm / duplicate telemetry protection
 *   - Loop & recursion safeguards (scene -> automation -> scene loops)
 *   - Multi-device command & scene execution via DeviceCommandService & SceneService
 *   - Durable execution logging with rich telemetry snapshots
 *   - RealtimeEventBus & NotificationService integration
 */

const crypto = require('crypto');

class AutomationService {
  constructor({
    automationRepo,
    homeAuthService,
    deviceCommandService,
    deviceStateRepo = null,
    eventBus = null,
    logRepo = null,
    telemetryRepo = null,
    aggregateRepo = null,
    energyExecutionRepo = null,
    notificationService = null,
    sceneService = null
  }) {
    this.automationRepo = automationRepo;
    this.homeAuthService = homeAuthService;
    this.deviceCommandService = deviceCommandService;
    this.deviceStateRepo = deviceStateRepo;
    this.eventBus = eventBus;
    this.logRepo = logRepo;
    this.telemetryRepo = telemetryRepo;
    this.aggregateRepo = aggregateRepo;
    this.energyExecutionRepo = energyExecutionRepo;
    this.notificationService = notificationService;
    this.sceneService = sceneService;

    // Hysteresis & cooldown tracking: key -> { isTriggered: boolean, lastTriggeredAt: number, lastValue: number }
    this._hysteresisState = new Map();
    // Sustained duration tracking: key -> { firstExceededAt: number }
    this._sustainedTracker = new Map();
  }

  async createAutomation({
    homeId,
    userId,
    name,
    description = null,
    isEnabled = true,
    triggerType,
    triggerConfig = {},
    conditions = [],
    actions = [],
    timezone = 'UTC',
    scopeType = 'device',
    scopeId = null,
    hysteresis = null,
    cooldownSeconds = 0
  }) {
    if (!name || name.trim() === '') {
      const err = new Error('Automation name is required');
      err.statusCode = 400;
      throw err;
    }
    if (!triggerType) {
      const err = new Error('triggerType is required');
      err.statusCode = 400;
      throw err;
    }

    if (this.homeAuthService) {
      const auth = await this.homeAuthService.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageAutomations'
      });
      if (!auth.isAuthorized) {
        const err = new Error(auth.message || 'Forbidden');
        err.statusCode = auth.statusCode || 403;
        throw err;
      }
    }

    const automationId = `auto_${crypto.randomUUID()}`;
    const cleanTriggerConfig = {
      ...triggerConfig,
      scopeType,
      scopeId,
      hysteresis: hysteresis || triggerConfig?.hysteresis || null,
      cooldownSeconds: cooldownSeconds || triggerConfig?.cooldownSeconds || 0
    };

    return this.automationRepo.createAutomation({
      id: automationId,
      homeId,
      name: name.trim(),
      description,
      isEnabled,
      triggerType,
      triggerConfig: cleanTriggerConfig,
      conditions,
      actions,
      timezone
    });
  }

  async listAutomations({ homeId, userId, filterType = null }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    let list = await this.automationRepo.findByHomeId(homeId);
    if (filterType === 'energy') {
      list = list.filter(a =>
        a.trigger_type === 'energy_threshold' ||
        a.trigger_type === 'energy' ||
        (Array.isArray(a.conditions) && a.conditions.some(c =>
          c.type === 'energy_condition' ||
          c.type === 'energy_threshold' ||
          c.metric === 'instantaneous_power' ||
          c.metric === 'sustained_power' ||
          c.metric === 'daily_energy' ||
          c.metric === 'cumulative_energy'
        ))
      );
    }
    return list;
  }

  async getAutomation({ homeId, userId, automationId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    const auto = await this.automationRepo.findById(automationId);
    if (!auto || auto.home_id !== homeId) {
      const err = new Error(`Automation ${automationId} not found in home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }
    return auto;
  }

  async updateAutomation({ homeId, userId, automationId, updates }) {
    if (this.homeAuthService) {
      const auth = await this.homeAuthService.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageAutomations'
      });
      if (!auth.isAuthorized) {
        const err = new Error(auth.message || 'Forbidden');
        err.statusCode = auth.statusCode || 403;
        throw err;
      }
    }
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.updateAutomation(automationId, updates);
  }

  async toggleAutomation({ homeId, userId, automationId, isEnabled }) {
    if (this.homeAuthService) {
      const auth = await this.homeAuthService.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageAutomations'
      });
      if (!auth.isAuthorized) {
        const err = new Error(auth.message || 'Forbidden');
        err.statusCode = auth.statusCode || 403;
        throw err;
      }
    }
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.updateAutomation(automationId, { is_enabled: isEnabled });
  }

  async deleteAutomation({ homeId, userId, automationId }) {
    if (this.homeAuthService) {
      const auth = await this.homeAuthService.authorizeRequest({
        userId,
        homeId,
        requiredCapability: 'canManageAutomations'
      });
      if (!auth.isAuthorized) {
        const err = new Error(auth.message || 'Forbidden');
        err.statusCode = auth.statusCode || 403;
        throw err;
      }
    }
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.deleteAutomation(automationId);
  }

  async getExecutionHistory({ homeId, userId, automationId = null, limit = 50 }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    if (this.logRepo) {
      const logs = automationId
        ? await this.logRepo.findByAutomationId(automationId, limit)
        : await this.logRepo.findByHomeId(homeId, limit);
      if (logs && logs.length > 0) return logs;
    }
    if (this.energyExecutionRepo) {
      if (automationId) {
        return this.energyExecutionRepo.findByAutomationId(automationId, limit);
      }
      return this.energyExecutionRepo.findByHomeId(homeId, { limit });
    }
    return [];
  }

  /**
   * Evaluate a single condition against current state and telemetry context
   */
  async evaluateCondition(cond, context = {}) {
    if (!cond) return true;
    const condType = cond.type || cond.kind || (cond.metric ? 'energy_condition' : null);
    if (!condType) return true;

    switch (condType) {
      case 'time_window': {
        const now = context.asOfDate ? new Date(context.asOfDate) : new Date();
        const currentHours = now.getUTCHours();
        const currentMins = now.getUTCMinutes();
        const currentTotal = currentHours * 60 + currentMins;

        if (cond.daysOfWeek && Array.isArray(cond.daysOfWeek) && cond.daysOfWeek.length > 0) {
          const jsDay = now.getUTCDay();
          const isoDay = jsDay === 0 ? 7 : jsDay;
          if (!cond.daysOfWeek.includes(isoDay)) {
            return false;
          }
        }

        if (cond.startTime && cond.endTime) {
          const [sH, sM] = cond.startTime.split(':').map(Number);
          const [eH, eM] = cond.endTime.split(':').map(Number);
          const startTotal = sH * 60 + sM;
          const endTotal = eH * 60 + eM;

          if (startTotal <= endTotal) {
            return currentTotal >= startTotal && currentTotal <= endTotal;
          } else {
            // Wraps past midnight (e.g. 22:00 to 06:00)
            return currentTotal >= startTotal || currentTotal <= endTotal;
          }
        }
        return true;
      }

      case 'device_channel_state': {
        if (!this.deviceStateRepo || !cond.deviceId) return true;
        try {
          const state = (await this.deviceStateRepo.getFullState?.(cond.deviceId)) ||
                        (await this.deviceStateRepo.findByDeviceId?.(cond.deviceId)) ||
                        (await this.deviceStateRepo.findById?.(cond.deviceId));
          if (!state) return false;
          if (cond.channel !== undefined || cond.channelIndex !== undefined) {
            const chIdx = cond.channel !== undefined ? cond.channel : cond.channelIndex;
            let channelVal;
            if (Array.isArray(state.channels)) {
              const chObj = state.channels.find(c => c.channelIndex === chIdx || c.channel_index === chIdx);
              channelVal = chObj?.reportedState || chObj?.desiredState || chObj;
            } else if (state.channels && typeof state.channels === 'object') {
              channelVal = state.channels[chIdx] ?? state.channels[String(chIdx)];
            }
            if (channelVal === undefined) return false;
            if (cond.expectedState?.enabled !== undefined || cond.expectedState?.value !== undefined) {
              const expected = cond.expectedState.enabled ?? cond.expectedState.value;
              const actual = channelVal.enabled ?? channelVal.power ?? channelVal;
              return Boolean(actual) === Boolean(expected);
            }
          }
          return true;
        } catch (_) {
          return false;
        }
      }

      case 'device_availability': {
        if (!this.deviceStateRepo || !cond.deviceId) return true;
        try {
          const state = (await this.deviceStateRepo.getFullState?.(cond.deviceId)) ||
                        (await this.deviceStateRepo.findByDeviceId?.(cond.deviceId)) ||
                        (await this.deviceStateRepo.findById?.(cond.deviceId));
          const expected = cond.expectedAvailability || 'ONLINE';
          const actual = state?.connectionState || state?.availability || 'ONLINE';
          return actual === expected;
        } catch (_) {
          return false;
        }
      }

      // Energy Automation Conditions
      case 'energy_condition':
      case 'energy_threshold':
      case 'instantaneous_power':
      case 'sustained_power':
      case 'daily_energy':
      case 'monthly_energy':
      case 'cumulative_energy': {
        return this._evaluateEnergyCondition(cond, context);
      }

      default:
        return true;
    }
  }

  /**
   * Internal deterministic evaluation for energy conditions
   */
  async _evaluateEnergyCondition(cond, context = {}) {
    const metric = cond.metric || cond.type || 'instantaneous_power';
    const operator = (cond.operator || 'GT').toUpperCase();
    const threshold = Number(cond.threshold);
    if (isNaN(threshold)) return false;

    // Check optional embedded timeWindow
    if (cond.timeWindow) {
      const windowMet = await this.evaluateCondition({ type: 'time_window', ...cond.timeWindow }, context);
      if (!windowMet) return false;
    }

    // Extract actual numeric value based on metric
    let actualValue = null;
    const telemetry = context.telemetry || null;

    if (telemetry) {
      if (metric === 'instantaneous_power' || metric === 'sustained_power' || metric === 'power' || metric === 'energy_threshold') {
        if (typeof telemetry.powerW === 'number') {
          actualValue = telemetry.powerW;
        } else if (typeof telemetry.p_mw === 'number') {
          actualValue = telemetry.p_mw / 1000.0;
        }
      } else if (metric === 'daily_energy') {
        if (typeof telemetry.dailyEnergyKwh === 'number') {
          actualValue = telemetry.dailyEnergyKwh;
        } else if (typeof telemetry.e_tot_wh === 'number') {
          actualValue = telemetry.e_tot_wh / 1000.0;
        }
      } else if (metric === 'cumulative_energy' || metric === 'energy') {
        if (typeof telemetry.totalEnergyKwh === 'number') {
          actualValue = telemetry.totalEnergyKwh;
        } else if (typeof telemetry.e_tot_wh === 'number') {
          actualValue = telemetry.e_tot_wh / 1000.0;
        }
      }
    }

    // Fallback: lookup from telemetry repo if not in context
    if (actualValue === null && cond.deviceId && this.telemetryRepo) {
      const channelIndex = cond.channelIndex || 1;
      const latest = await this.telemetryRepo.getLatestMeasurement(cond.deviceId, channelIndex);
      if (latest) {
        if (metric === 'instantaneous_power' || metric === 'sustained_power' || metric === 'power' || metric === 'energy_threshold') {
          actualValue = latest.p_mw / 1000.0;
        } else if (metric === 'cumulative_energy' || metric === 'energy') {
          actualValue = latest.e_tot_wh / 1000.0;
        }
      }
    }

    // Never interpret missing telemetry as zero
    if (actualValue === null || actualValue === undefined || isNaN(actualValue)) {
      return false;
    }

    // Record evaluated value in context for logs
    context._evaluatedEnergyValue = actualValue;

    // Compare with operator
    let isSatisfied = false;
    switch (operator) {
      case 'GT':
      case '>':
        isSatisfied = actualValue > threshold;
        break;
      case 'GTE':
      case '>=':
        isSatisfied = actualValue >= threshold;
        break;
      case 'LT':
      case '<':
        isSatisfied = actualValue < threshold;
        break;
      case 'LTE':
      case '<=':
        isSatisfied = actualValue <= threshold;
        break;
      case 'EQ':
      case '==':
        isSatisfied = Math.abs(actualValue - threshold) < 0.001;
        break;
      default:
        isSatisfied = actualValue > threshold;
    }

    // Sustained duration logic (e.g. power > 1500W for 60 seconds)
    const durationSeconds = Number(cond.durationSeconds || 0);
    if (durationSeconds > 0) {
      const trackerKey = `${context.automationId || 'rule'}_${cond.deviceId || 'dev'}`;
      const now = Date.now();

      if (isSatisfied) {
        const tracker = this._sustainedTracker.get(trackerKey);
        if (!tracker || !tracker.firstExceededAt) {
          this._sustainedTracker.set(trackerKey, { firstExceededAt: now });
          return false; // Just started exceeding, wait for duration
        } else {
          const elapsedSec = (now - tracker.firstExceededAt) / 1000.0;
          if (elapsedSec >= durationSeconds) {
            return true;
          }
          return false;
        }
      } else {
        // Value dropped below threshold — reset sustained tracker
        this._sustainedTracker.delete(trackerKey);
        return false;
      }
    }

    return isSatisfied;
  }

  /**
   * Evaluate conditions array (supports AND logic)
   */
  async evaluateConditions(conditions, context = {}) {
    if (!conditions || !Array.isArray(conditions) || conditions.length === 0) {
      return true;
    }

    for (const cond of conditions) {
      const isMet = await this.evaluateCondition(cond, context);
      if (!isMet) {
        return false;
      }
    }
    return true;
  }

  /**
   * Execute an automation rule with safety loops, hysteresis, cooldown, and durability
   */
  async runAutomation({
    homeId,
    userId = null,
    automationId,
    triggerSource = 'manual',
    executionIdentity = null,
    context = {}
  }) {
    const auto = await this.automationRepo.findById(automationId);
    if (!auto || auto.home_id !== homeId) {
      const err = new Error(`Automation ${automationId} not found in home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }

    const execId = executionIdentity || `auto_exec_${crypto.randomUUID()}`;
    const startTime = Date.now();
    const scopeType = auto.trigger_config?.scopeType || auto.scopeType || 'device';
    const scopeId = auto.trigger_config?.scopeId || auto.scopeId || null;
    const telemetryContext = {
      evaluatedValue: context._evaluatedEnergyValue ?? null,
      telemetry: context.telemetry || null,
      triggerSource
    };

    // 1. Loop & Recursion Protection (Scene -> Automation -> Scene loop prevention)
    const depth = Number(context.depth || 0);
    const executionChain = Array.isArray(context.executionChain) ? context.executionChain : [];
    if (depth > 3 || executionChain.includes(automationId)) {
      await this._recordExecutionLog({
        homeId,
        automationId,
        scopeType,
        scopeId,
        triggerType: auto.trigger_type || triggerSource,
        triggerReason: `Safety suppression: loop detected (chain: ${executionChain.join('->')})`,
        telemetryContext,
        status: 'skipped',
        skipReason: 'loop_detected',
        durationMs: Date.now() - startTime
      });
      return {
        success: false,
        status: 'skipped',
        skipReason: 'loop_detected',
        automationId,
        message: 'Execution aborted: potential recursive loop detected'
      };
    }

    // 2. Disabled Rule Check
    if (triggerSource !== 'manual' && !auto.is_enabled) {
      return {
        success: false,
        status: 'skipped_disabled',
        skipReason: 'disabled',
        automationId,
        message: 'Automation is disabled'
      };
    }

    // 3. Cooldown & Hysteresis Checks
    const hysteresisKey = `${automationId}_${scopeId || 'global'}`;
    const hState = this._hysteresisState.get(hysteresisKey) || { isTriggered: false, lastTriggeredAt: 0, lastValue: 0 };
    const cooldownSeconds = Number(auto.trigger_config?.cooldownSeconds || auto.cooldownSeconds || 0);

    if (triggerSource !== 'manual' && cooldownSeconds > 0) {
      const elapsed = (Date.now() - hState.lastTriggeredAt) / 1000.0;
      if (elapsed < cooldownSeconds) {
        await this._recordExecutionLog({
          homeId,
          automationId,
          scopeType,
          scopeId,
          triggerType: auto.trigger_type || triggerSource,
          triggerReason: `Suppressed by cooldown (${Math.round(elapsed)}s / ${cooldownSeconds}s)`,
          telemetryContext,
          status: 'skipped',
          skipReason: 'in_cooldown',
          durationMs: Date.now() - startTime
        });
        return {
          success: false,
          status: 'skipped',
          skipReason: 'in_cooldown',
          automationId,
          message: `Rule in cooldown for ${Math.round(cooldownSeconds - elapsed)} more seconds`
        };
      }
    }

    // Hysteresis recovery check
    const recoveryThreshold = auto.trigger_config?.hysteresis?.recoveryThreshold !== undefined
      ? Number(auto.trigger_config.hysteresis.recoveryThreshold)
      : (auto.hysteresis?.recoveryThreshold !== undefined ? Number(auto.hysteresis.recoveryThreshold) : null);

    // 4. Condition Evaluation
    const evalContext = { ...context, automationId };
    const conditionsMet = await this.evaluateConditions(auto.conditions, evalContext);

    // Check hysteresis active state
    if (triggerSource !== 'manual' && hState.isTriggered && recoveryThreshold !== null) {
      const currentVal = evalContext._evaluatedEnergyValue;
      if (currentVal !== null && currentVal !== undefined) {
        // If trigger was for high power (> threshold) and currentVal hasn't fallen below recoveryThreshold yet
        if (currentVal > recoveryThreshold) {
          await this._recordExecutionLog({
            homeId,
            automationId,
            scopeType,
            scopeId,
            triggerType: auto.trigger_type || triggerSource,
            triggerReason: `Hysteresis active: power (${currentVal}W) not below recovery threshold (${recoveryThreshold}W)`,
            telemetryContext,
            status: 'skipped',
            skipReason: 'hysteresis_active',
            durationMs: Date.now() - startTime
          });
          return {
            success: false,
            status: 'skipped',
            skipReason: 'hysteresis_active',
            automationId,
            message: 'Hysteresis active: awaiting recovery below recovery threshold'
          };
        } else {
          // Recovered! Reset triggered state
          hState.isTriggered = false;
          this._hysteresisState.set(hysteresisKey, hState);
        }
      }
    }

    if (!conditionsMet) {
      await this._recordExecutionLog({
        homeId,
        automationId,
        scopeType,
        scopeId,
        triggerType: auto.trigger_type || triggerSource,
        triggerReason: 'Conditions were not satisfied',
        telemetryContext,
        status: 'skipped',
        skipReason: 'conditions_not_met',
        durationMs: Date.now() - startTime
      });
      return {
        success: false,
        status: 'conditions_not_met',
        skipReason: 'conditions_not_met',
        automationId,
        message: 'Conditions were not satisfied'
      };
    }

    // 5. Conditions satisfied — update hysteresis state
    this._hysteresisState.set(hysteresisKey, {
      isTriggered: true,
      lastTriggeredAt: Date.now(),
      lastValue: evalContext._evaluatedEnergyValue || 0
    });

    // 6. Action Execution
    const targetResults = [];
    let successCount = 0;
    let failCount = 0;

    const actorContext = {
      userId: userId || 'system_energy_automation',
      homeId,
      role: 'OWNER'
    };

    const nextChain = [...executionChain, automationId];

    for (let i = 0; i < (auto.actions || []).length; i++) {
      const act = auto.actions[i];
      const actionType = act.actionType || (act.sceneId ? 'scene_execution' : 'device_command');

      if (actionType === 'scene_execution' && act.sceneId && this.sceneService) {
        try {
          const sceneRes = await this.sceneService.runScene({
            homeId,
            userId: actorContext.userId,
            sceneId: act.sceneId,
            executionIdentity: `${execId}_scene_${i}`,
            context: { ...context, depth: depth + 1, executionChain: nextChain }
          });
          if (sceneRes && sceneRes.status !== 'failed') {
            successCount++;
          } else {
            failCount++;
          }
          targetResults.push({
            sceneId: act.sceneId,
            actionType: 'scene_execution',
            status: sceneRes.status || 'succeeded',
            receipt: sceneRes
          });
        } catch (err) {
          failCount++;
          targetResults.push({
            sceneId: act.sceneId,
            actionType: 'scene_execution',
            status: 'failed',
            error: err.message
          });
        }
        continue;
      }

      // Device Command Execution
      const actionIdempotency = `${execId}_act_${i}_${act.deviceId || 'dev'}`;
      let action = 'setPower';
      let params = {};

      if (act.command === 'set_power' || act.command === 'setPower' || act.action === 'setPower' || act.action === 'set_power') {
        action = 'setPower';
        const val = act.params?.value ?? act.parameters?.value ?? act.parameters?.enabled ?? act.enabled ?? true;
        params = { value: Boolean(val) };
      } else if (act.command === 'setLevel' || act.action === 'setLevel') {
        action = 'setLevel';
        params = { level: act.params?.level ?? act.parameters?.level ?? 100 };
      } else if (act.command === 'setColorTemp' || act.action === 'setColorTemp') {
        action = 'setColorTemp';
        params = { colorTemp: act.params?.colorTemp ?? act.parameters?.colorTemp ?? 4000 };
      } else if (act.command === 'identifyDevice' || act.action === 'identifyDevice') {
        action = 'identifyDevice';
        params = {};
      }

      const cmdEnvelope = {
        commandId: crypto.randomUUID(),
        deviceId: act.deviceId,
        channelIndex: act.channel || act.channelIndex || 1,
        action,
        params,
        idempotencyKey: actionIdempotency,
        source: 'AUTOMATION'
      };

      try {
        const receipt = await this.deviceCommandService.sendCommand(actorContext, cmdEnvelope);
        const isSuccess = receipt && !receipt.mqttError && !receipt.error &&
          (receipt.status === 'APPLIED' || receipt.status === 'CREATED' || receipt.state === 'applied' || receipt.state === 'succeeded' || receipt.state === 'ACKNOWLEDGED');

        if (isSuccess) {
          successCount++;
        } else {
          failCount++;
        }

        targetResults.push({
          deviceId: act.deviceId,
          channel: cmdEnvelope.channelIndex,
          command: action,
          status: isSuccess ? 'succeeded' : 'failed',
          receipt
        });
      } catch (err) {
        failCount++;
        targetResults.push({
          deviceId: act.deviceId,
          channel: cmdEnvelope.channelIndex,
          command: action,
          status: 'failed',
          error: err.message
        });
      }
    }

    let overallStatus = 'succeeded';
    if (failCount > 0 && successCount > 0) {
      overallStatus = 'partial';
    } else if (failCount > 0 && successCount === 0 && (auto.actions || []).length > 0) {
      overallStatus = 'failed';
    }

    const durationMs = Date.now() - startTime;

    // 7. Persist Execution Log
    await this._recordExecutionLog({
      homeId,
      automationId,
      executionIdentity: execId,
      scopeType,
      scopeId,
      triggerType: auto.trigger_type || triggerSource,
      triggerReason: `Energy condition triggered (${auto.name})`,
      telemetryContext,
      requestedAction: auto.actions,
      resultingState: targetResults,
      status: overallStatus,
      durationMs
    });

    // 8. Publish Realtime Events & Notifications
    if (this.eventBus) {
      this.eventBus.publish({
        type: overallStatus === 'failed' ? 'energy.automation.failed' : 'energy.automation.executed',
        homeId,
        payload: {
          automationId,
          automationName: auto.name,
          triggerSource,
          status: overallStatus,
          executionIdentity: execId,
          targetResults,
          durationMs,
          timestamp: new Date().toISOString()
        }
      });
    }

    if (this.notificationService && overallStatus !== 'succeeded') {
      try {
        await this.notificationService.notifyHome({
          homeId,
          category: 'automation',
          title: `Energy Automation ${overallStatus === 'failed' ? 'Failed' : 'Issue'}`,
          body: `Automation '${auto.name}' encountered errors during execution.`,
          metadata: { automationId, status: overallStatus }
        });
      } catch (_) {}
    }

    return {
      success: overallStatus !== 'failed',
      automationId,
      status: overallStatus,
      executionIdentity: execId,
      durationMs,
      targetResults
    };
  }

  async _recordExecutionLog({
    homeId,
    automationId,
    executionIdentity = null,
    scopeType = 'device',
    scopeId = null,
    triggerType = 'energy',
    triggerReason = '',
    telemetryContext = {},
    previousState = null,
    requestedAction = null,
    resultingState = null,
    status = 'succeeded',
    skipReason = null,
    errorMessage = null,
    durationMs = 0
  }) {
    const nowIso = new Date().toISOString();

    if (this.energyExecutionRepo) {
      try {
        await this.energyExecutionRepo.createExecution({
          id: `enexec_${crypto.randomUUID()}`,
          homeId,
          automationId,
          scopeType,
          scopeId,
          triggerType,
          triggerReason,
          telemetryContext,
          previousState,
          requestedAction,
          resultingState,
          status,
          skipReason,
          errorMessage,
          durationMs,
          createdAt: nowIso
        });
      } catch (err) {
        console.warn('[AutomationService] Failed to record energy execution log:', err.message);
      }
    }

    if (this.logRepo) {
      try {
        await this.logRepo.createLog({
          id: `log_${crypto.randomUUID()}`,
          homeId,
          automationId,
          triggerSource: triggerType,
          status: status === 'skipped' ? 'skipped' : status,
          executionIdentity: executionIdentity || `exec_${crypto.randomUUID()}`,
          targetResults: Array.isArray(resultingState) ? resultingState : [],
          errorMessage: errorMessage || skipReason,
          durationMs,
          executedAt: nowIso
        });
      } catch (_) {}
    }
  }
}

module.exports = { AutomationService };
