'use strict';

/**
 * EH Home — AutomationService (Phase 10)
 *
 * Implements rule lifecycle, trigger evaluation, condition logic,
 * multi-device command execution, execution history logging, and realtime event publication.
 */

const crypto = require('crypto');

class AutomationService {
  constructor({
    automationRepo,
    homeAuthService,
    deviceCommandService,
    deviceStateRepo = null,
    eventBus = null,
    logRepo = null
  }) {
    this.automationRepo = automationRepo;
    this.homeAuthService = homeAuthService;
    this.deviceCommandService = deviceCommandService;
    this.deviceStateRepo = deviceStateRepo;
    this.eventBus = eventBus;
    this.logRepo = logRepo;
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
    timezone = 'UTC'
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
      await this.homeAuthService.requireMembership(userId, homeId);
    }

    const automationId = `auto_${crypto.randomUUID()}`;
    return this.automationRepo.createAutomation({
      id: automationId,
      homeId,
      name: name.trim(),
      description,
      isEnabled,
      triggerType,
      triggerConfig,
      conditions,
      actions,
      timezone
    });
  }

  async listAutomations({ homeId, userId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    return this.automationRepo.findByHomeId(homeId);
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
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.updateAutomation(automationId, updates);
  }

  async toggleAutomation({ homeId, userId, automationId, isEnabled }) {
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.updateAutomation(automationId, { is_enabled: isEnabled });
  }

  async deleteAutomation({ homeId, userId, automationId }) {
    await this.getAutomation({ homeId, userId, automationId });
    return this.automationRepo.deleteAutomation(automationId);
  }

  async getExecutionHistory({ homeId, userId, automationId, limit = 50 }) {
    if (automationId) {
      await this.getAutomation({ homeId, userId, automationId });
      if (this.logRepo) {
        return this.logRepo.findByAutomationId(automationId, limit);
      }
    } else {
      if (this.homeAuthService) {
        await this.homeAuthService.requireMembership(userId, homeId);
      }
      if (this.logRepo) {
        return this.logRepo.findByHomeId(homeId, limit);
      }
    }
    return [];
  }

  /**
   * Evaluate a single condition against current state and context
   */
  async evaluateCondition(cond, context = {}) {
    if (!cond || !cond.type) return true;

    switch (cond.type) {
      case 'time_window': {
        // e.g. startTime: '08:00', endTime: '22:00'
        const now = context.asOfDate ? new Date(context.asOfDate) : new Date();
        const currentHours = now.getUTCHours();
        const currentMins = now.getUTCMinutes();
        const currentTotal = currentHours * 60 + currentMins;

        if (cond.startTime && cond.endTime) {
          const [sH, sM] = cond.startTime.split(':').map(Number);
          const [eH, eM] = cond.endTime.split(':').map(Number);
          const startTotal = sH * 60 + sM;
          const endTotal = eH * 60 + eM;

          if (startTotal <= endTotal) {
            return currentTotal >= startTotal && currentTotal <= endTotal;
          } else {
            // Wraps past midnight
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
          if (cond.channel !== undefined) {
            let channelVal;
            if (Array.isArray(state.channels)) {
              const chObj = state.channels.find(c => c.channelIndex === cond.channel || c.channel_index === cond.channel);
              channelVal = chObj?.reportedState || chObj?.desiredState || chObj;
            } else if (state.channels && typeof state.channels === 'object') {
              channelVal = state.channels[cond.channel] ?? state.channels[String(cond.channel)];
            }
            if (channelVal === undefined) return false;
            if (cond.expectedState?.enabled !== undefined) {
              const actual = channelVal.enabled ?? channelVal.power ?? channelVal;
              return Boolean(actual) === Boolean(cond.expectedState.enabled);
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

      default:
        return true;
    }
  }

  /**
   * Evaluate conditions array (supports AND / OR logic)
   */
  async evaluateConditions(conditions, context = {}) {
    if (!conditions || !Array.isArray(conditions) || conditions.length === 0) {
      return true;
    }

    for (const cond of conditions) {
      const isMet = await this.evaluateCondition(cond, context);
      if (!isMet) {
        return false; // Strict AND evaluation for top-level condition list
      }
    }
    return true;
  }

  /**
   * Execute an automation rule
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

    // If triggered by scheduler / state change and rule is disabled, skip
    if (triggerSource !== 'manual' && !auto.is_enabled) {
      return {
        success: false,
        status: 'skipped_disabled',
        automationId,
        message: 'Automation is disabled'
      };
    }

    // Evaluate conditions
    const conditionsMet = await this.evaluateConditions(auto.conditions, context);
    if (!conditionsMet) {
      if (this.logRepo) {
        await this.logRepo.createLog({
          id: `log_${crypto.randomUUID()}`,
          homeId,
          automationId,
          triggerSource,
          status: 'conditions_not_met',
          executionIdentity: executionIdentity || `exec_${crypto.randomUUID()}`,
          targetResults: [],
          durationMs: 0
        });
      }
      return {
        success: false,
        status: 'conditions_not_met',
        automationId,
        message: 'Conditions were not satisfied'
      };
    }

    const execId = executionIdentity || `auto_exec_${crypto.randomUUID()}`;
    const startTime = Date.now();
    const targetResults = [];
    let successCount = 0;
    let failCount = 0;

    const actorContext = {
      userId: userId || 'system_automation',
      homeId,
      role: 'OWNER'
    };

    for (let i = 0; i < (auto.actions || []).length; i++) {
      const act = auto.actions[i];
      const actionIdempotency = `${execId}_act_${i}_${act.deviceId || 'dev'}`;

      let action = 'setPower';
      let params = {};
      if (act.command === 'set_power' || act.command === 'setPower' || act.action === 'setPower' || act.action === 'set_power') {
        action = 'setPower';
        const val = act.parameters?.value ?? act.parameters?.enabled ?? act.enabled ?? true;
        params = { value: Boolean(val) };
      } else if (act.command === 'setLevel' || act.action === 'setLevel') {
        action = 'setLevel';
        params = { level: act.parameters?.level ?? 100 };
      } else if (act.command === 'setColorTemp' || act.action === 'setColorTemp') {
        action = 'setColorTemp';
        params = { colorTemp: act.parameters?.colorTemp ?? 4000 };
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

        const isSuccess = receipt && !receipt.mqttError && !receipt.error && (receipt.status === 'APPLIED' || receipt.status === 'CREATED' || receipt.state === 'applied' || receipt.state === 'succeeded' || receipt.state === 'ACKNOWLEDGED');
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

    if (this.logRepo) {
      await this.logRepo.createLog({
        id: `log_${crypto.randomUUID()}`,
        homeId,
        automationId,
        triggerSource,
        status: overallStatus,
        executionIdentity: execId,
        targetResults,
        durationMs
      });
    }

    if (this.eventBus) {
      this.eventBus.publish({
        type: 'automation.executed',
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

    return {
      success: overallStatus !== 'failed',
      automationId,
      status: overallStatus,
      executionIdentity: execId,
      durationMs,
      targetResults
    };
  }
}

module.exports = { AutomationService };
