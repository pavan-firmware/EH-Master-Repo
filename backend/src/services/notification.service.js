const crypto = require('crypto');

class NotificationService {
  constructor({
    notificationRepository,
    homeRepository,
    userRepository,
    realtimeEventBus = null,
    pushProvider = null
  }) {
    this.repo = notificationRepository;
    this.homeRepo = homeRepository;
    this.userRepo = userRepository;
    this.eventBus = realtimeEventBus;
    this.pushProvider = pushProvider;
    this.rateLimitMap = new Map(); // key -> lastSentTimestamp

    if (this.eventBus) {
      this._subscribeToEventBus();
    }
  }

  _subscribeToEventBus() {
    this.eventBus.on('event', async (event) => {
      try {
        await this.handleAuthoritativeEvent(event);
      } catch (err) {
        console.error(`[NotificationService] Error handling event ${event.type}:`, err.message);
      }
    });
  }

  async handleAuthoritativeEvent(event) {
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
        } else if (payload.status === 'ONLINE' && payload.wasOffline) {
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
            version: payload.targetVersion
          });
        } else if (payload.status === 'FAILED') {
          await this.notifyOtaFailed({
            homeId,
            deviceId: deviceId || payload.deviceId,
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
          severity: payload.severity || 'HIGH',
          data: payload
        });
        break;

      default:
        break;
    }
  }

  // --- Specific Notification Creation Helpers ---

  async notifyDeviceOffline({ homeId, deviceId, deviceName, reason = null }) {
    return this.dispatchNotification({
      homeId,
      type: 'DEVICE_OFFLINE',
      category: 'alert',
      priority: 'HIGH',
      title: `${deviceName} is Offline`,
      body: `${deviceName} lost connection or powered down.${reason ? ` (${reason})` : ''}`,
      entityType: 'device',
      entityId: deviceId,
      preferenceKey: 'device_offline',
      dedupWindowSeconds: 60
    });
  }

  async notifyDeviceRecovered({ homeId, deviceId, deviceName }) {
    return this.dispatchNotification({
      homeId,
      type: 'DEVICE_RECOVERED',
      category: 'alert',
      priority: 'NORMAL',
      title: `${deviceName} Reconnected`,
      body: `${deviceName} is back online and responsive.`,
      entityType: 'device',
      entityId: deviceId,
      preferenceKey: 'device_offline',
      dedupWindowSeconds: 60
    });
  }

  async notifyCommandFailed({ homeId, deviceId, commandId, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'COMMAND_FAILED',
      category: 'alert',
      priority: 'HIGH',
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
      title: 'Automation Failed',
      body: `Routine "${automationName}" failed to complete: ${error || 'Unknown error'}`,
      entityType: 'automation',
      entityId: automationId,
      data: { error },
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
      title: 'Scene Execution Failed',
      body: `Scene "${sceneName}" failed: ${error || 'Execution timeout'}`,
      entityType: 'scene',
      entityId: sceneId,
      data: { error },
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
      title: 'Scheduled Task Failed',
      body: `Scheduled task "${scheduleName}" failed: ${error || 'Trigger error'}`,
      entityType: 'schedule',
      entityId: scheduleId,
      data: { error },
      preferenceKey: 'automation_failure',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaAvailable({ homeId, deviceId, version }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_AVAILABLE',
      category: 'update',
      priority: 'NORMAL',
      title: 'Firmware Update Available',
      body: `Firmware release ${version} is ready to install.`,
      entityType: 'device',
      entityId: deviceId,
      data: { version },
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
      title: 'Firmware Update Started',
      body: `Firmware update to v${version} started.`,
      entityType: 'device',
      entityId: deviceId,
      data: { version },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaSuccess({ homeId, deviceId, version }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_SUCCESS',
      category: 'update',
      priority: 'NORMAL',
      title: 'Firmware Update Succeeded',
      body: `Device successfully updated to firmware v${version}.`,
      entityType: 'device',
      entityId: deviceId,
      data: { version },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async notifyOtaFailed({ homeId, deviceId, error }) {
    return this.dispatchNotification({
      homeId,
      type: 'OTA_FAILED',
      category: 'update',
      priority: 'HIGH',
      title: 'Firmware Update Failed',
      body: `Device firmware update failed: ${error || 'Download error'}`,
      entityType: 'device',
      entityId: deviceId,
      data: { error },
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
      title: 'Firmware Rollback Detected',
      body: `Device firmware update rolled back to previous partition: ${error || 'Boot verification failed'}`,
      entityType: 'device',
      entityId: deviceId,
      data: { error },
      preferenceKey: 'firmware_updates',
      dedupWindowSeconds: 60
    });
  }

  async createNotification(params) {
    return this.dispatchNotification(params);
  }

  async notifySecurityEvent({ homeId, userId = null, title, message, severity = 'HIGH', data = {} }) {
    const priority = severity === 'CRITICAL' ? 'CRITICAL' : 'HIGH';
    return this.dispatchNotification({
      homeId,
      userId,
      type: 'SECURITY_EVENT',
      category: 'security',
      priority,
      title,
      body: message,
      entityType: 'security',
      entityId: data.incidentId || null,
      data,
      preferenceKey: 'critical_alerts',
      dedupWindowSeconds: 10
    });
  }

  // --- Core Dispatch Engine ---

  async dispatchNotification({
    homeId = null,
    userId = null,
    type,
    category = 'alert',
    priority = 'NORMAL',
    title,
    body,
    entityType = null,
    entityId = null,
    data = {},
    preferenceKey = null,
    dedupWindowSeconds = 30
  }) {
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

    const createdNotifications = [];

    for (const recipientId of recipientUserIds) {
      // 2. Deduplication & Rate Limiting check
      const rateLimitKey = `${type}_${recipientId}_${entityId || homeId || 'global'}`;
      const now = Date.now();
      const lastSent = this.rateLimitMap.get(rateLimitKey) || 0;

      if (priority !== 'CRITICAL' && (now - lastSent) < (dedupWindowSeconds * 1000)) {
        // Suppress duplicate within window
        continue;
      }
      this.rateLimitMap.set(rateLimitKey, now);

      // 3. User Preferences Check
      const prefs = await this.repo.getPreferences(recipientId);
      if (!prefs.push_enabled && priority !== 'CRITICAL') {
        // Global push disabled
        continue;
      }

      if (preferenceKey && prefs[preferenceKey] === false && priority !== 'CRITICAL') {
        // Specific preference category disabled
        continue;
      }

      // 4. Persist Notification
      const notificationId = `notif_${crypto.randomUUID()}`;
      const idempotencyKey = `${type}_${recipientId}_${entityId || homeId || '0'}_${Math.floor(now / (dedupWindowSeconds * 1000))}`;

      const notification = await this.repo.createNotification({
        id: notificationId,
        userId: recipientId,
        homeId,
        type,
        category,
        priority,
        title,
        body,
        entityType,
        entityId,
        data,
        deliveryStatus: 'PENDING',
        idempotencyKey
      });

      createdNotifications.push(notification);

      // 5. Enqueue Push Delivery for active device tokens
      const activeTokens = await this.repo.findActiveTokensForUser(recipientId);
      for (const token of activeTokens) {
        const deliveryId = `del_${crypto.randomUUID()}`;
        await this.repo.enqueueDelivery({
          id: deliveryId,
          notificationId: notification.id,
          tokenId: token.id,
          status: 'PENDING',
          maxAttempts: 5
        });
      }
    }

    return createdNotifications;
  }
}

module.exports = { NotificationService };
