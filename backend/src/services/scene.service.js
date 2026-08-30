'use strict';

/**
 * EH Home — SceneService (Phase 10)
 *
 * Manages multi-device scene definitions and orchestrates simultaneous command execution
 * across devices and channels using the authenticated DeviceCommandService pipeline.
 */

const crypto = require('crypto');

class SceneService {
  constructor({ sceneRepo, homeAuthService, deviceCommandService, eventBus = null, logRepo = null }) {
    this.sceneRepo = sceneRepo;
    this.homeAuthService = homeAuthService;
    this.deviceCommandService = deviceCommandService;
    this.eventBus = eventBus;
    this.logRepo = logRepo;
  }

  async createScene({ homeId, userId, name, description = null, icon = 'scene_default', actions = [] }) {
    if (!name || name.trim() === '') {
      const err = new Error('Scene name is required');
      err.statusCode = 400;
      throw err;
    }

    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }

    const sceneId = `scene_${crypto.randomUUID()}`;
    return this.sceneRepo.createScene({
      id: sceneId,
      homeId,
      name: name.trim(),
      description,
      icon,
      isActive: false,
      actions: Array.isArray(actions) ? actions : []
    });
  }

  async listScenes({ homeId, userId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    return this.sceneRepo.findByHomeId(homeId);
  }

  async getScene({ homeId, userId, sceneId }) {
    if (this.homeAuthService) {
      await this.homeAuthService.requireMembership(userId, homeId);
    }
    const scene = await this.sceneRepo.findById(sceneId);
    if (!scene || scene.home_id !== homeId) {
      const err = new Error(`Scene ${sceneId} not found in home ${homeId}`);
      err.statusCode = 404;
      throw err;
    }
    return scene;
  }

  async updateScene({ homeId, userId, sceneId, updates }) {
    await this.getScene({ homeId, userId, sceneId });
    return this.sceneRepo.updateScene(sceneId, updates);
  }

  async deleteScene({ homeId, userId, sceneId }) {
    await this.getScene({ homeId, userId, sceneId });
    return this.sceneRepo.deleteScene(sceneId);
  }

  async runScene({ homeId, userId, sceneId, executionIdentity = null }) {
    const scene = await this.getScene({ homeId, userId, sceneId });
    const execId = executionIdentity || `scene_exec_${crypto.randomUUID()}`;
    const startTime = Date.now();

    const targetResults = [];
    let successCount = 0;
    let failCount = 0;

    const actorContext = {
      userId: userId || 'system_scene',
      homeId,
      role: 'OWNER'
    };

    for (let i = 0; i < (scene.actions || []).length; i++) {
      const act = scene.actions[i];
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
        source: 'SCENE'
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
    } else if (failCount > 0 && successCount === 0 && (scene.actions || []).length > 0) {
      overallStatus = 'failed';
    }

    const durationMs = Date.now() - startTime;

    // Persist execution history if logRepo is attached
    if (this.logRepo) {
      await this.logRepo.createLog({
        id: `log_${crypto.randomUUID()}`,
        homeId,
        sceneId,
        triggerSource: 'manual_scene',
        status: overallStatus,
        executionIdentity: execId,
        targetResults,
        durationMs
      });
    }

    // Publish realtime execution event
    if (this.eventBus) {
      this.eventBus.publish({
        type: 'scene.executed',
        homeId,
        payload: {
          sceneId,
          sceneName: scene.name,
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
      sceneId,
      status: overallStatus,
      executionIdentity: execId,
      durationMs,
      targetResults
    };
  }
}

module.exports = { SceneService };
