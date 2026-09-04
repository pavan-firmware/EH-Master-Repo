'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * EdgeAutomationService (Phase 28)
 *
 * Provides local runtime execution for Automations, Scenes, and Schedules at the edge.
 * Operates offline without cloud dependency and enforces the deterministic authority hierarchy:
 *   Physical Switch > Manual App Command > Automation Rule > Scheduled Action.
 */
class EdgeAutomationService {
  /**
   * @param {Object} opts
   * @param {Object} opts.localExecutionService - LocalExecutionService
   * @param {Object} opts.automationService     - AutomationService (Phase 10/20)
   * @param {Object} opts.sceneService          - SceneService (Phase 10)
   * @param {Object} opts.scheduleRepo          - ScheduleRepository
   * @param {Object} opts.automationRepo        - AutomationRepository
   * @param {Object} opts.sceneRepo             - SceneRepository
   * @param {Object} [opts.eventBus]            - RealtimeEventBus
   */
  constructor({
    localExecutionService,
    automationService,
    sceneService,
    scheduleRepo,
    automationRepo,
    sceneRepo,
    eventBus = null
  }) {
    this.localExecutionService = localExecutionService;
    this.automationService = automationService;
    this.sceneService = sceneService;
    this.scheduleRepo = scheduleRepo;
    this.automationRepo = automationRepo;
    this.sceneRepo = sceneRepo;
    this.eventBus = eventBus;

    // Execution history for edge operations
    this._edgeExecutions = [];
  }

  /**
   * Execute a Scene locally at the edge across all constituent devices.
   */
  async executeSceneEdge({ homeId, userId = 'system_edge', sceneId }) {
    const startTime = Date.now();
    const executionId = `exec_scene_${uuidv4()}`;

    const scene = await this.sceneRepo.findById(sceneId);
    if (!scene || scene.home_id !== homeId) {
      throw new Error(`Scene ${sceneId} not found in home ${homeId}`);
    }

    const actions = scene.actions || [];
    const actionResults = [];
    let successfulCount = 0;
    let failedCount = 0;

    const actorContext = {
      userId,
      homeId,
      role: 'OWNER',
      source: 'EDGE_SCENE'
    };

    for (let i = 0; i < actions.length; i++) {
      const act = actions[i];
      const deviceId = act.deviceId || act.targetDeviceId;
      if (!deviceId) continue;

      const idempotencyKey = `${executionId}_act_${i}_${deviceId}`;
      const actionType = act.action || act.command || 'setPower';
      const params = act.params || act.parameters || { value: act.value ?? true };

      try {
        const result = await this.localExecutionService.executeCommand(actorContext, {
          commandId: uuidv4(),
          deviceId,
          homeId,
          channelIndex: act.channelIndex || null,
          action: actionType,
          params,
          idempotencyKey,
          preferredRoute: 'AUTO'
        });

        actionResults.push({
          deviceId,
          action: actionType,
          status: result.status,
          isConfirmedByDevice: result.isConfirmedByDevice
        });

        if (result.status === 'CONFIRMED') {
          successfulCount++;
        } else {
          failedCount++;
        }
      } catch (err) {
        failedCount++;
        actionResults.push({
          deviceId,
          action: actionType,
          status: 'FAILED',
          error: err.message
        });
      }
    }

    const status = failedCount === 0 && successfulCount > 0
      ? 'SUCCESS'
      : (successfulCount > 0 ? 'PARTIAL_SUCCESS' : (actions.length === 0 ? 'SUCCESS' : 'FAILED'));

    const record = {
      executionId,
      homeId,
      ruleType: 'SCENE',
      ruleId: sceneId,
      ruleName: scene.name,
      triggerSource: 'MANUAL_EDGE_TRIGGER',
      status,
      actionsTotal: actions.length,
      actionsSuccessful: successfulCount,
      actionsFailed: failedCount,
      actionResults,
      executionDurationMs: Date.now() - startTime,
      executedAt: new Date().toISOString()
    };

    this._edgeExecutions.push(record);
    return record;
  }

  /**
   * Evaluate and execute an automation locally on the edge when a trigger event arrives.
   */
  async evaluateAutomationEdge({ homeId, triggerEvent }) {
    const startTime = Date.now();
    const executionId = `exec_auto_${uuidv4()}`;

    // Delegate evaluation to existing AutomationService rule engine
    if (this.automationService && typeof this.automationService.evaluateRules === 'function') {
      const evalResult = await this.automationService.evaluateRules(homeId, triggerEvent);
      const record = {
        executionId,
        homeId,
        ruleType: 'AUTOMATION',
        ruleId: triggerEvent.ruleId || 'auto_evaluated',
        ruleName: 'Edge Triggered Automation',
        triggerSource: triggerEvent.source || 'LOCAL_EVENT',
        status: evalResult.executedCount > 0 ? 'SUCCESS' : 'SKIPPED_DEBOUNCE',
        actionsTotal: evalResult.totalActions || 1,
        actionsSuccessful: evalResult.executedCount || 0,
        actionsFailed: evalResult.failedCount || 0,
        actionResults: evalResult.results || [],
        executionDurationMs: Date.now() - startTime,
        executedAt: new Date().toISOString()
      };
      this._edgeExecutions.push(record);
      return record;
    }

    return {
      executionId,
      homeId,
      ruleType: 'AUTOMATION',
      ruleId: 'none',
      status: 'SUCCESS',
      actionsTotal: 0,
      actionsSuccessful: 0,
      actionsFailed: 0,
      executionDurationMs: Date.now() - startTime,
      executedAt: new Date().toISOString()
    };
  }

  /**
   * Execute a schedule locally on the edge.
   */
  async executeScheduleEdge({ homeId, scheduleId }) {
    const startTime = Date.now();
    const executionId = `exec_sched_${uuidv4()}`;

    const schedule = await this.scheduleRepo.findById(scheduleId);
    if (!schedule || schedule.home_id !== homeId) {
      throw new Error(`Schedule ${scheduleId} not found in home ${homeId}`);
    }

    if (!schedule.is_enabled) {
      return {
        executionId,
        homeId,
        ruleType: 'SCHEDULE',
        ruleId: scheduleId,
        ruleName: schedule.name,
        status: 'SKIPPED_MANUAL_OVERRIDE',
        actionsTotal: 0,
        actionsSuccessful: 0,
        actionsFailed: 0,
        executionDurationMs: 0,
        executedAt: new Date().toISOString()
      };
    }

    // Execute target action locally
    const actionResult = await this.localExecutionService.executeCommand({
      userId: 'system_schedule',
      homeId,
      role: 'OWNER',
      source: 'EDGE_SCHEDULE'
    }, {
      commandId: uuidv4(),
      deviceId: schedule.target_device_id,
      homeId,
      action: schedule.action || 'setPower',
      params: schedule.parameters || { value: true },
      idempotencyKey: `${executionId}_${schedule.target_device_id}`
    });

    const status = actionResult.status === 'CONFIRMED' ? 'SUCCESS' : 'FAILED';
    const record = {
      executionId,
      homeId,
      ruleType: 'SCHEDULE',
      ruleId: scheduleId,
      ruleName: schedule.name,
      triggerSource: 'LOCAL_CLOCK',
      status,
      actionsTotal: 1,
      actionsSuccessful: status === 'SUCCESS' ? 1 : 0,
      actionsFailed: status === 'FAILED' ? 1 : 0,
      actionResults: [actionResult],
      executionDurationMs: Date.now() - startTime,
      executedAt: new Date().toISOString()
    };

    this._edgeExecutions.push(record);
    return record;
  }

  getExecutionHistory({ homeId = null, limit = 50 } = {}) {
    let list = this._edgeExecutions;
    if (homeId) {
      list = list.filter(e => e.homeId === homeId);
    }
    return list.slice(-limit).reverse();
  }
}

module.exports = { EdgeAutomationService };
