'use strict';

const crypto = require('crypto');
const { NotificationDecisionService } = require('./notification-decision.service');
const { NotificationAggregationService } = require('./notification-aggregation.service');
const { NotificationTemplateService } = require('./notification-template.service');
const { NotificationDeliveryService } = require('./notification-delivery.service');

/**
 * EH Home — NotificationService (Phase 15 + Phase 30 Unified Architecture)
 *
 * Core notification platform responsible for:
 * 1. Authoritative event ingestion across all subsystems (devices, energy, OTA, automations, Matter, security).
 * 2. Deterministic policy evaluation (NotificationDecisionService).
 * 3. Cluster & storm aggregation (NotificationAggregationService).
 * 4. Human-friendly template formatting (NotificationTemplateService).
 * 5. Provider-neutral multi-channel delivery (NotificationDeliveryService).
 * 6. Action recording and quiet-hours deferred release.
 *
 * Downstream Fault Isolation Invariant (FIX 3):
 * All notification handling is strictly downstream of authoritative state.
 * Any notification processing error is caught and isolated; it NEVER fails or breaks
 * originating device commands, automations, OTA, Matter, or energy operations.
 */

class NotificationService {
  constructor({
    notificationRepository,
    homeRepository,
    userRepository,
    realtimeEventBus = null,
    pushProvider = null,
    emailProvider = null,
    decisionService = null,
    aggregationService = null,
    templateService = null,
    deliveryService = null
  }) {
    this.repo = notificationRepository;
    this.homeRepo = homeRepository;
    this.userRepo = userRepository;
    this.eventBus = realtimeEventBus;
    this.pushProvider = pushProvider;
    this.emailProvider = emailProvider;

    this.decisionService = decisionService || new NotificationDecisionService();
    this.rateLimitMap = this.decisionService.rateLimitMap;
    this.aggregationService = aggregationService || new NotificationAggregationService();
    this.templateService = templateService || new NotificationTemplateService();
    this.deliveryService = deliveryService || new NotificationDeliveryService({
      notificationRepository: this.repo,
      realtimeEventBus: this.eventBus,
      pushProvider: this.pushProvider,
      emailProvider: this.emailProvider
    });

    if (this.eventBus) {
      this._subscribeToEventBus();
    }
  }

  _subscribeToEventBus() {
    if (typeof this.eventBus.on === 'function') {
      this.eventBus.on('event', async (event) => {
        try {
          await this.handleAuthoritativeEvent(event);
        } catch (err) {
          console.error(`[NotificationService] Error handling event ${event.type}:`, err.message);
        }
      });
    }
  }

  /**
   * Authoritative Event Ingestion Pipeline
   */
  async handleAuthoritativeEvent(event) {
    if (!event) return;
    try {
      const { type, homeId, deviceId, payload = {} } = event;

      switch (type) {
        case 'device.availability':
          if (payload.status === 'OFFLINE') {
            await this.notifyDeviceOffline({
              homeId,
              deviceId: deviceId || payload.deviceId,
              deviceName: payload.deviceName || 'Smart Device',
              reason: payload.reason
            });
          } else if (payload.status === 'ONLINE' && (payload.wasOffline || payload.status === 'ONLINE')) {
            await this.notifyDeviceRecovered({
              homeId,
              deviceId: deviceId || payload.deviceId,
              deviceName: payload.deviceName || 'Smart Device'
            });
          }
          break;

        case 'command.receipt':
          if (payload.status === 'FAILED' || payload.status === 'TIMEOUT') {
            await this.notifyCommandFailed({
              homeId,
              deviceId: deviceId || payload.deviceId,
              commandId: payload.commandId,
              error: payload.error || payload.status
            });
          }
          break;

        case 'automation.executed':
          if (payload.status === 'FAILED') {
            await this.notifyAutomationFailed({
              homeId,
              automationId: payload.automationId,
              automationName: payload.name || 'Automation Rule',
              error: payload.error
            });
          }
          break;

        case 'ota.event':
          if (payload.status === 'AVAILABLE') {
            await this.notifyOtaAvailable({
              homeId,
              deviceId: deviceId || payload.deviceId,
              version: payload.targetVersion || payload.version
            });
          } else if (payload.status === 'STARTED') {
            await this.notifyOtaStarted({
              homeId,
              deviceId: deviceId || payload.deviceId,
              version: payload.targetVersion || payload.version
            });
          } else if (payload.status === 'SUCCESS' || payload.status === 'COMPLETED') {
            await this.notifyOtaSuccess({
              homeId,
              deviceId: deviceId || payload.deviceId,
              version: payload.targetVersion || payload.version
            });
          } else if (payload.status === 'FAILED') {
            await this.notifyOtaFailed({
              homeId,
              deviceId: deviceId || payload.deviceId,
              error: payload.error
            });
          } else if (payload.status === 'ROLLED_BACK') {
            await this.notifyOtaRolledBack({
              homeId,
              deviceId: deviceId || payload.deviceId,
              error: payload.error
            });
          }
          break;

        case 'energy.alert':
        case 'energy.threshold':
          await this.notifyEnergyAlert({
            homeId,
            deviceId: deviceId || payload.deviceId,
            deviceName: payload.deviceName || 'Smart Device',
            powerW: payload.powerW || payload.currentPower,
            thresholdW: payload.thresholdW || payload.thresholdLimit
          });
          break;

        case 'reliability.incident':
          await this.notifyReliabilityAlert({
            homeId,
            deviceId: deviceId || payload.deviceId,
            deviceName: payload.deviceName || 'Smart Device',
            issue: payload.issue || payload.reason,
            recoveryAttempted: payload.recoveryAttempted
          });
          break;

        case 'matter.event':
          if (payload.status === 'DISCONNECTED' || payload.status === 'FAILED') {
            await this.notifyMatterEvent({
              homeId,
              deviceId: deviceId || payload.deviceId,
              deviceName: payload.deviceName || 'Matter Device',
              status: payload.status,
              error: payload.error
            });
          }
          break;

        case 'security.alert':
          await this.notifySecurityEvent({
            homeId,
            userId: payload.userId,
            title: payload.title || 'Security Alert',
            message: payload.message || 'A security event was detected in your home.',
            severity: payload.severity || 'CRITICAL',
            data: payload
          });
          break;

        default:
          break;
      }
    } catch (err) {
      // Downstream isolation: never let notification handling fail caller
      console.error('[NotificationService] Error in handleAuthoritativeEvent:', err.message);
    }
  }

  // --- Specific Domain Notification Helpers ---

  async notifyDeviceOffline({ homeId, deviceId, deviceName, reason = null }) {
    return this.dispatchNotification({
      homeId,
      type: 'DEVICE_OFFLINE',
      category: 'alert',
      priority: 'HIGH',
      severity: 'WARNING',
      title: `${deviceName} is Offline`,
      body: `${deviceName} lost connection or powered down.${reason ? ` (${reason})` : ''}`,
      entityType: 'device',
      entityId: deviceId,
      preferenceKey: 'device_offline',
      dedupWindowSeconds: 60,
      data: { deviceId, deviceName, reason }
    });
  }

  async notifyDeviceRecovered({ homeId, deviceId, deviceName }) {
    return this.dispatchNotification({
      homeId,
      type: 'DEVICE_RECOVERED',
      category: 'alert',
      priority: 'NORMAL',
      severity: 'NOTICE',
      title: `${deviceName} Reconnected`,
      body: `${deviceName} is back online and responsive.`,
      entityType: 'device',
      entityId: deviceId,
      preferenceKey: 'device_offline',
      dedupWindowSeconds: 60,
      data: { deviceId, deviceName }
    });
  }

  async notifyCommandFailed({ homeId, deviceId, commandId, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'COMMAND_FAILED',
      category: 'alert',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Command Failed',
      body: `Failed to execute control on device: ${error || 'Device unresponsive'}`,
      entityType: 'device',
      entityId: deviceId,
      data: { commandId, error },
      preferenceKey: 'critical_alerts',
      dedupWindowSeconds: 15
    });
  }

  async notifyAutomationFailed({ homeId, automationId, automationName, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'AUTOMATION_FAILED',
      category: 'automation',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Automation Failed',
      body: `Routine "${automationName}" failed to complete: ${error || 'Unknown error'}`,
      entityType: 'automation',
      entityId: automationId,
      data: { automationId, error },
      preferenceKey: 'automation_failure',
      dedupWindowSeconds: 60
    });
  }

  async notifySceneFailed({ homeId, sceneId, sceneName, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'SCENE_FAILED',
      category: 'automation',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Scene Execution Failed',
      body: `Scene "${sceneName}" failed: ${error || 'Execution timeout'}`,
      entityType: 'scene',
      entityId: sceneId,
      data: { sceneId, error },
      preferenceKey: 'automation_failure',
      dedupWindowSeconds: 60
    });
  }

  async notifyScheduleFailed({ homeId, scheduleId, scheduleName, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'SCHEDULE_FAILED',
      category: 'automation',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Scheduled Task Failed',
      body: `Scheduled task "${scheduleName}" failed: ${error || 'Trigger error'}`,
      entityType: 'schedule',
      entityId: scheduleId,
      data: { scheduleId, error },
      preferenceKey: 'automation_failure',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaAvailable({ homeId, deviceId, version, deviceName = 'Smart Device' }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_AVAILABLE',
      category: 'update',
      priority: 'NORMAL',
      severity: 'NOTICE',
      title: 'Firmware Update Available',
      body: `Firmware release ${version} is ready to install on ${deviceName}.`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, version },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 300
    });
  }

  async notifyOtaStarted({ homeId, deviceId, version }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_STARTED',
      category: 'update',
      priority: 'NORMAL',
      severity: 'INFO',
      title: 'Firmware Update Started',
      body: `Firmware update to v${version} started.`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, version },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaSuccess({ homeId, deviceId, version, deviceName = 'Smart Device' }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_SUCCESS',
      category: 'update',
      priority: 'NORMAL',
      severity: 'NOTICE',
      title: 'Firmware Update Succeeded',
      body: `${deviceName} successfully updated to firmware v${version}.`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, version },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaFailed({ homeId, deviceId, error, deviceName = 'Smart Device' }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_FAILED',
      category: 'update',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Firmware Update Failed',
      body: `Firmware update failed on ${deviceName}: ${error || 'Download error'}`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, error },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaRolledBack({ homeId, deviceId, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_ROLLED_BACK',
      category: 'update',
      priority: 'HIGH',
      severity: 'ERROR',
      title: 'Firmware Rollback Detected',
      body: `Device firmware rolled back to previous partition: ${error || 'Boot verification failed'}`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, error },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyEnergyAlert({ homeId, deviceId, deviceName, powerW, thresholdW }) {
    return this.dispatchNotification({
      homeId,
      type: 'ENERGY_THRESHOLD_EXCEEDED',
      category: 'energy',
      priority: 'HIGH',
      severity: 'WARNING',
      title: 'High Energy Consumption Alert',
      body: `${deviceName} exceeded consumption threshold: ${powerW}W (limit: ${thresholdW}W).`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, powerW, thresholdW },
      preferenceKey: 'energy_alerts',
      dedupWindowSeconds: 60
    });
  }

  async notifyReliabilityAlert({ homeId, deviceId, deviceName, issue, recoveryAttempted = false }) {
    return this.dispatchNotification({
      homeId,
      type: 'RELIABILITY_INCIDENT',
      category: 'alert',
      priority: 'HIGH',
      severity: 'WARNING',
      title: 'Device Health Alert',
      body: `${deviceName} encountered connectivity issue: ${issue}.${recoveryAttempted ? ' Automatic self-healing initiated.' : ''}`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, issue, recoveryAttempted },
      preferenceKey: 'device_health',
      dedupWindowSeconds: 60
    });
  }

  async notifyMatterEvent({ homeId, deviceId, deviceName, status, error = null }) {
    return this.dispatchNotification({
      homeId,
      type: 'MATTER_DISCONNECTED',
      category: 'matter',
      priority: 'HIGH',
      severity: 'WARNING',
      title: 'Matter Integration Disconnected',
      body: `${deviceName} lost connection to your Matter smart home fabric.${error ? ` (${error})` : ''}`,
      entityType: 'device',
      entityId: deviceId,
      data: { deviceId, status, error },
      preferenceKey: 'matter_alerts',
      dedupWindowSeconds: 60
    });
  }

  async notifySecurityEvent({ homeId, userId = null, title, message, severity = 'CRITICAL', data = {} }) {
    return this.dispatchNotification({
      homeId,
      userId,
      type: 'SECURITY_EVENT',
      category: 'security',
      priority: severity === 'CRITICAL' ? 'CRITICAL' : 'HIGH',
      severity,
      title,
      body: message,
      entityType: 'security',
      entityId: data.incidentId || null,
      data,
      preferenceKey: 'critical_alerts',
      dedupWindowSeconds: 10
    });
  }

  async createNotification(params) {
    return this.dispatchNotification(params);
  }

  // --- Normalized Platform Event Ingestion (Section 2) ---
  async ingestPlatformEvent(platformEvent) {
    try {
      if (this.repo && typeof this.repo.recordPlatformEvent === 'function') {
        await this.repo.recordPlatformEvent(platformEvent);
      }
      return this.handleAuthoritativeEvent({
        type: platformEvent.eventType,
        homeId: platformEvent.homeId,
        deviceId: platformEvent.deviceId,
        payload: {
          ...platformEvent.data,
          title: platformEvent.title,
          message: platformEvent.message,
          severity: platformEvent.severity
        }
      });
    } catch (err) {
      console.error('[NotificationService] IngestPlatformEvent error:', err.message);
      return null;
    }
  }

  async publishPlatformEvent(event) {
    if (!event) return null;
    try {
      let recordedEvent = null;
      if (this.repo && typeof this.repo.recordPlatformEvent === 'function') {
        recordedEvent = await this.repo.recordPlatformEvent({
          id: event.id || `pevt_${crypto.randomUUID()}`,
          homeId: event.homeId,
          deviceId: event.deviceId,
          userId: event.userId,
          source: event.source || 'DEVICE_STATE',
          eventType: event.eventType || event.type,
          severity: event.severity || 'INFO',
          title: event.title || 'Platform Event',
          message: event.message || event.body || '',
          data: event.payload || event.data || {}
        });
      }

      const notifs = await this.dispatchNotification({
        homeId: event.homeId,
        userId: event.userId,
        type: event.eventType || event.type,
        category: event.category || 'alert',
        severity: event.severity,
        priority: event.priority || (event.severity === 'CRITICAL' ? 'CRITICAL' : 'NORMAL'),
        title: event.title,
        body: event.message || event.body,
        entityType: event.deviceId ? 'device' : (event.entityType || 'system'),
        entityId: event.deviceId || event.entityId,
        data: event.payload || event.data || {},
        currentTime: event.currentTime || new Date()
      });

      if (notifs && notifs.length > 0) {
        return notifs[0];
      }
      return null;
    } catch (err) {
      console.error('[NotificationService] publishPlatformEvent error (isolated):', err.message);
      return null;
    }
  }

  // --- Core Dispatch Engine with Deterministic Decisions & Downstream Isolation ---

  async dispatchNotification({
    homeId = null,
    userId = null,
    type,
    category = 'alert',
    priority = 'NORMAL',
    severity = null,
    title,
    body,
    entityType = null,
    entityId = null,
    data = {},
    preferenceKey = null,
    dedupWindowSeconds = 30,
    actionType = null,
    actionTarget = null,
    actionPrimary = null,
    actionSecondary = null,
    currentTime = new Date()
  }) {
    try {
      // 1. Resolve target recipients
      const recipientUserIds = new Set();
      if (userId) {
        recipientUserIds.add(userId);
      } else if (homeId) {
        if (this.homeRepo && typeof this.homeRepo.getMembershipsForHome === 'function') {
          const members = await this.homeRepo.getMembershipsForHome(homeId);
          members.forEach(m => recipientUserIds.add(m.user_id));
        } else if (this.homeRepo && typeof this.homeRepo.findMembersByHomeId === 'function') {
          const members = await this.homeRepo.findMembersByHomeId(homeId);
          members.forEach(m => recipientUserIds.add(m.user_id));
        } else if (this.homeRepo && typeof this.homeRepo.getHome === 'function') {
          const home = await this.homeRepo.getHome(homeId);
          if (home && home.owner_id) recipientUserIds.add(home.owner_id);
        } else if (this.homeRepo && typeof this.homeRepo.findById === 'function') {
          const home = await this.homeRepo.findById(homeId);
          if (home && home.owner_id) recipientUserIds.add(home.owner_id);
        } else if (this.repo && this.repo.db) {
          const memberships = await this.repo.db.find('home_memberships', m => m.home_id === homeId);
          memberships.forEach(m => recipientUserIds.add(m.user_id));
        }
      }

      if (recipientUserIds.size === 0 && userId) {
        recipientUserIds.add(userId);
      }

      // Check alert aggregation if multiple devices are affected
      let aggregatedPayload = null;
      if (homeId && entityId) {
        aggregatedPayload = this.aggregationService.ingest({
          homeId,
          eventType: type,
          deviceId: entityId,
          deviceName: data.deviceName || title,
          severity: severity || priority,
          data
        });
      }

      const tmpl = this.templateService.render(type, {
        ...data,
        title,
        body,
        deviceName: data.deviceName || title,
        severity: severity || priority
      });
      const effectiveTitle = aggregatedPayload ? aggregatedPayload.title : (title || tmpl.title);
      const effectiveBody = aggregatedPayload ? aggregatedPayload.body : (body || tmpl.body);
      const effectiveData = aggregatedPayload ? { ...data, ...aggregatedPayload.data } : data;
      const isAggregated = !!aggregatedPayload;
      const aggregatedCount = aggregatedPayload ? aggregatedPayload.aggregatedCount : 1;
      const aggregatedIds = aggregatedPayload ? aggregatedPayload.aggregatedIds : [];
      const effectiveActionPrimary = actionPrimary || tmpl.actionPrimary || actionType || (entityType === 'device' ? 'VIEW_DEVICE' : null);
      const effectiveActionSecondary = actionSecondary || tmpl.actionSecondary || null;

      const createdNotifications = [];

      for (const recipientId of recipientUserIds) {
        // 2. Load recipient preferences & role
        const prefs = await this.repo.getPreferences(recipientId);

        let userRole = 'OWNER';
        if (this.homeRepo && homeId) {
          if (typeof this.homeRepo.getMembershipsForHome === 'function') {
            const members = await this.homeRepo.getMembershipsForHome(homeId);
            const m = members.find(mem => mem.user_id === recipientId);
            if (m && m.role) userRole = m.role;
          }
        }

        // 3. Deterministic Decision Engine Evaluation (Fix 2)
        const decision = this.decisionService.evaluate({
          event: {
            type,
            homeId,
            deviceId: entityId,
            severity: severity || priority,
            priority,
            payload: data
          },
          userPreferences: prefs,
          userRole,
          currentTime,
          dedupWindowSeconds,
          preferenceKey
        });

        if (decision.action === 'SUPPRESS') {
          // Suppressed due to duplicate, flapping, or user preference toggle
          continue;
        }

        const now = currentTime.getTime();
        const notificationId = `notif_${crypto.randomUUID()}`;
        const idempotencyKey = `${type}_${recipientId}_${entityId || homeId || '0'}_${Math.floor(now / (dedupWindowSeconds * 1000))}`;

        // 4. Persistence
        const deliveryStatus = decision.action === 'DEFER' ? 'DEFERRED' : 'DELIVERED';
        const effectiveSeverity = decision.severity || severity || (priority === 'CRITICAL' ? 'CRITICAL' : 'INFO');

        const notification = await this.repo.createNotification({
          id: notificationId,
          userId: recipientId,
          homeId,
          type,
          category,
          priority: effectiveSeverity === 'CRITICAL' ? 'CRITICAL' : (priority || 'NORMAL'),
          severity: effectiveSeverity,
          title: effectiveTitle,
          body: effectiveBody,
          entityType,
          entityId,
          data: effectiveData,
          deliveryStatus,
          actionType: actionType || effectiveActionPrimary,
          actionTarget: actionTarget || entityId,
          actionState: 'NONE',
          actionPrimary: effectiveActionPrimary,
          actionSecondary: effectiveActionSecondary,
          isAggregated,
          aggregatedCount,
          aggregatedIds,
          decisionMetadata: decision.metadata || {},
          idempotencyKey
        });

        createdNotifications.push(notification);

        // 5. Downstream Multi-Channel Dispatch (if SEND)
        if (decision.action === 'SEND') {
          const activeTokens = await this.repo.findActiveTokensForUser(recipientId);
          await this.deliveryService.dispatch({
            notification,
            channels: decision.channels || ['in_app', 'push'],
            activeTokens
          });
        }
      }

      return createdNotifications;
    } catch (err) {
      // Downstream failure isolation (Fix 3): never throw to originating operations
      console.error('[NotificationService] DispatchNotification error (isolated):', err.message);
      return [];
    }
  }

  /**
   * Releases quiet-hours deferred notifications once quiet hours are over.
   */
  async releaseDeferredNotifications(userId = null, homeId = null) {
    try {
      const deferred = await this.repo.findDeferredNotifications(userId, homeId);
      const released = [];

      for (const notif of deferred) {
        const prefs = await this.repo.getPreferences(notif.user_id);
        const activeTokens = await this.repo.findActiveTokensForUser(notif.user_id);

        await this.repo.updateNotification(notif.id, {
          delivery_status: 'DELIVERED'
        });

        await this.deliveryService.dispatch({
          notification: notif,
          channels: ['in_app', 'push'],
          activeTokens
        });

        released.push(notif.id);
      }

      return released;
    } catch (err) {
      console.error('[NotificationService] ReleaseDeferredNotifications error:', err.message);
      return [];
    }
  }

  async deliverDeferredNotifications(userId = null, homeId = null) {
    const released = await this.releaseDeferredNotifications(userId, homeId);
    return Array.isArray(released) ? released.length : 0;
  }

  /**
   * Action Recording for interactive user clicks (Section 13 & 36)
   */
  async recordAction({ notificationId, userId, actionType, payload = {} }) {
    const notif = await this.repo.findById(notificationId);
    if (!notif) {
      throw new Error(`Notification ${notificationId} not found`);
    }
    if (notif.user_id && notif.user_id !== userId) {
      throw new Error(`Unauthorized action on notification ${notificationId}`);
    }

    return this.repo.recordAction({
      notificationId,
      userId,
      actionType,
      actionTarget: notif.action_target,
      payload,
      actionState: 'ACTIONED'
    });
  }

  async performAction(notificationId, actionType, options = {}) {
    try {
      const notif = await this.repo.findById(notificationId);
      if (!notif) {
        return { success: false, error: 'Notification not found' };
      }
      const { userId = null, payload = null, ...rest } = options;
      const effectivePayload = (payload && typeof payload === 'object' && Object.keys(payload).length > 0)
        ? payload
        : rest;

      const actionRecord = await this.repo.createAction({
        id: `act_${crypto.randomUUID()}`,
        notificationId,
        userId: userId || notif.user_id,
        actionType,
        actionTarget: notif.action_target || notif.entity_id,
        status: 'EXECUTED',
        payload: effectivePayload
      });
      return {
        success: true,
        actionId: actionRecord.id,
        actionType,
        status: 'EXECUTED',
        notificationId
      };
    } catch (err) {
      console.error('[NotificationService] performAction error (isolated):', err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Retention management: removes notifications older than retentionMs, preserving CRITICAL.
   */
  async cleanExpiredNotifications(retentionMs = 30 * 24 * 60 * 60 * 1000) {
    const cutoff = new Date(Date.now() - retentionMs).toISOString();
    return this.repo.cleanExpiredNotifications(cutoff, true);
  }
}

module.exports = { NotificationService };
