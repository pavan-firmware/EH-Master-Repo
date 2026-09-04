'use strict';

/**
 * EH Home — NotificationTemplateService (Phase 30)
 *
 * Centralized template registry ensuring:
 * 1. Consumer-friendly, jargon-free notifications (stripping low-level protocol terms).
 * 2. Structured localization keys (e.g. device.offline.title, device.offline.body).
 * 3. Consistent actionable metadata attached to alerts.
 */

class NotificationTemplateService {
  constructor() {
    this.templates = new Map();
    this._initTemplates();
  }

  _initTemplates() {
    this.register('DEVICE_OFFLINE', {
      keyTitle: 'device.offline.title',
      keyBody: 'device.offline.body',
      defaultTitle: '{deviceName} is Offline',
      defaultBody: '{deviceName} lost connection or powered down.',
      category: 'alert',
      priority: 'HIGH',
      severity: 'WARNING',
      actionType: 'RECONNECT_DEVICE',
      actionPrimary: 'RECONNECT_DEVICE',
      actionSecondary: 'MUTE_ALERTS',
      cleanJargon: (reason) => {
        if (!reason) return null;
        if (reason.includes('MQTT') || reason.includes('transport') || reason.includes('socket')) {
          return 'connection timed out';
        }
        if (reason.includes('BLE') || reason.includes('adapter')) {
          return 'Bluetooth connection unavailable';
        }
        if (reason.includes('PING') || reason.includes('heartbeat')) {
          return 'device unresponsive';
        }
        return reason;
      }
    });

    this.register('DEVICE_RECOVERED', {
      keyTitle: 'device.recovered.title',
      keyBody: 'device.recovered.body',
      defaultTitle: '{deviceName} Reconnected',
      defaultBody: '{deviceName} is back online and responsive.',
      category: 'alert',
      priority: 'NORMAL',
      severity: 'NOTICE',
      actionType: 'VIEW_DEVICE'
    });

    this.register('COMMAND_FAILED', {
      keyTitle: 'command.failed.title',
      keyBody: 'command.failed.body',
      defaultTitle: 'Command Failed',
      defaultBody: 'Failed to update {deviceName}: {error}',
      category: 'alert',
      priority: 'HIGH',
      severity: 'ERROR',
      actionType: 'VIEW_DEVICE',
      cleanJargon: (error) => {
        if (!error) return 'Device unresponsive';
        if (error.includes('MQTT') || error.includes('timeout')) return 'Device did not respond in time';
        return error;
      }
    });

    this.register('AUTOMATION_FAILED', {
      keyTitle: 'automation.failed.title',
      keyBody: 'automation.failed.body',
      defaultTitle: 'Automation Failed',
      defaultBody: 'Routine "{automationName}" failed to complete: {error}',
      category: 'automation',
      priority: 'HIGH',
      severity: 'ERROR',
      actionType: 'VIEW_AUTOMATION'
    });

    this.register('OTA_AVAILABLE', {
      keyTitle: 'ota.available.title',
      keyBody: 'ota.available.body',
      defaultTitle: 'Firmware Update Available',
      defaultBody: 'Firmware version {version} is ready to install on {deviceName}.',
      category: 'update',
      priority: 'NORMAL',
      severity: 'NOTICE',
      actionType: 'REVIEW_UPDATE'
    });

    this.register('OTA_SUCCESS', {
      keyTitle: 'ota.success.title',
      keyBody: 'ota.success.body',
      defaultTitle: 'Firmware Updated Successfully',
      defaultBody: '{deviceName} was successfully updated to firmware v{version}.',
      category: 'update',
      priority: 'NORMAL',
      severity: 'NOTICE',
      actionType: 'VIEW_DEVICE'
    });

    this.register('OTA_FAILED', {
      keyTitle: 'ota.failed.title',
      keyBody: 'ota.failed.body',
      defaultTitle: 'Firmware Update Failed',
      defaultBody: 'Could not complete update on {deviceName}: {error}',
      category: 'update',
      priority: 'HIGH',
      severity: 'ERROR',
      actionType: 'REVIEW_UPDATE'
    });

    this.register('ENERGY_THRESHOLD_EXCEEDED', {
      keyTitle: 'energy.threshold.title',
      keyBody: 'energy.threshold.body',
      defaultTitle: 'High Energy Consumption Alert',
      defaultBody: '{deviceName} exceeded threshold: currently using {powerW}W (limit: {thresholdW}W).',
      category: 'energy',
      priority: 'HIGH',
      severity: 'WARNING',
      actionType: 'VIEW_ENERGY'
    });

    this.register('MATTER_DISCONNECTED', {
      keyTitle: 'matter.disconnected.title',
      keyBody: 'matter.disconnected.body',
      defaultTitle: 'Matter Integration Disconnected',
      defaultBody: '{deviceName} lost connection to your Matter smart home ecosystem.',
      category: 'matter',
      priority: 'HIGH',
      severity: 'WARNING',
      actionType: 'VIEW_INTEGRATIONS'
    });

    this.register('SECURITY_ALERT', {
      keyTitle: 'security.alert.title',
      keyBody: 'security.alert.body',
      defaultTitle: 'Security Alert',
      defaultBody: '{message}',
      category: 'security',
      priority: 'CRITICAL',
      severity: 'CRITICAL',
      actionType: 'VIEW_SECURITY'
    });
  }

  register(eventType, templateConfig) {
    this.templates.set(eventType.toUpperCase(), templateConfig);
  }

  render(eventType, params = {}) {
    const tmpl = this.templates.get(eventType.toUpperCase()) || {
      defaultTitle: params.title || eventType,
      defaultBody: params.body || params.message || '',
      category: params.category || 'system',
      priority: params.priority || 'NORMAL',
      severity: params.severity || 'INFO',
      actionType: params.actionType || null,
      actionPrimary: params.actionPrimary || params.actionType || null,
      actionSecondary: params.actionSecondary || null
    };

    let title = tmpl.defaultTitle;
    let body = tmpl.defaultBody;

    // Clean engineering jargon from error / reason if cleaner provided
    const cleanParams = { ...params };
    if (tmpl.cleanJargon) {
      if (cleanParams.reason) cleanParams.reason = tmpl.cleanJargon(cleanParams.reason);
      if (cleanParams.error) cleanParams.error = tmpl.cleanJargon(cleanParams.error);
    }

    // Replace placeholders {param}
    Object.keys(cleanParams).forEach(key => {
      const val = cleanParams[key];
      if (val !== undefined && val !== null) {
        title = title.replace(new RegExp(`\\{${key}\\}`, 'g'), String(val));
        body = body.replace(new RegExp(`\\{${key}\\}`, 'g'), String(val));
      }
    });

    return {
      title,
      body,
      category: tmpl.category,
      priority: tmpl.priority,
      severity: tmpl.severity,
      actionType: tmpl.actionType,
      actionPrimary: tmpl.actionPrimary || tmpl.actionType,
      actionSecondary: tmpl.actionSecondary || null,
      keyTitle: tmpl.keyTitle,
      keyBody: tmpl.keyBody
    };
  }
}

module.exports = { NotificationTemplateService };
