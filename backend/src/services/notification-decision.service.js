'use strict';

/**
 * EH Home — NotificationDecisionService (Phase 30)
 *
 * Deterministic decision engine evaluating incoming platform events against:
 * 1. Event severity classification (INFO, NOTICE, WARNING, ERROR, CRITICAL)
 * 2. User category & channel preferences
 * 3. Quiet-hours state & deterministic deferral policy
 * 4. Deduplication sliding windows & storm prevention
 * 5. Device flapping & transient recovery suppression
 * 6. Home membership & RBAC role authorization
 *
 * Possible Outputs:
 * - SEND       : Immediately deliver notification across enabled channels.
 * - DEFER      : Queue notification for release after quiet hours.
 * - SUPPRESS   : Do not deliver notification (e.g. duplicate or preference disabled).
 * - AGGREGATE  : Hand over to NotificationAggregationService for clustered delivery.
 */

class NotificationDecisionService {
  constructor(options = {}) {
    this.rateLimitMap = new Map(); // key -> lastSentTimestamp
    this.flappingTracker = new Map(); // deviceId -> lastOfflineTimestamp
  }

  /**
   * Helper to determine if current time falls within [start, end] range (HH:mm)
   */
  isWithinQuietHours(nowDate, startStr = '22:00', endStr = '07:00') {
    if (!startStr || !endStr) return false;

    const [startH, startM] = startStr.split(':').map(Number);
    const [endH, endM] = endStr.split(':').map(Number);

    const curH = nowDate.getHours();
    const curM = nowDate.getMinutes();
    const curMinutes = curH * 60 + curM;
    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      return curMinutes >= startMinutes && curMinutes < endMinutes;
    } else {
      return curMinutes >= startMinutes || curMinutes < endMinutes;
    }
  }

  /**
   * Determine canonical severity for an event type and payload
   */
  classifySeverity(sourceOrEvent, eventType = null) {
    if (typeof sourceOrEvent === 'string' && eventType) {
      const type = eventType.toUpperCase();
      if (type.includes('SECURITY') || type.includes('SURGE') || type.includes('TAMPER') || type.includes('ALARM') || type.includes('CRITICAL')) {
        return 'CRITICAL';
      }
      if (type.includes('FAILED') || type.includes('ERROR') || type.includes('ROLLBACK')) {
        return 'ERROR';
      }
      if (type.includes('OFFLINE') || type.includes('THRESHOLD') || type.includes('WARNING') || type.includes('DEGRADED') || type.includes('CONFLICT')) {
        return 'WARNING';
      }
      if (type.includes('AVAILABLE') || type.includes('NOTICE') || type.includes('LOGIN') || type.includes('RECOVERED')) {
        return 'NOTICE';
      }
      return 'INFO';
    }

    const event = sourceOrEvent || {};
    if (event.severity) {
      return event.severity.toUpperCase();
    }

    const type = (event.type || event.eventType || '').toUpperCase();
    const payload = event.payload || event.data || {};

    if (type.includes('SECURITY') || type.includes('SURGE') || type.includes('TAMPER') || type.includes('ALARM') || payload.critical === true || payload.severity === 'CRITICAL' || event.priority === 'CRITICAL') {
      return 'CRITICAL';
    }

    if (type.includes('FAILED') || type.includes('ERROR') || type.includes('ROLLBACK') || payload.status === 'FAILED') {
      return 'ERROR';
    }

    if (type === 'DEVICE_OFFLINE' || type.includes('OFFLINE') || type.includes('THRESHOLD') || type.includes('WARNING') || type.includes('DEGRADED') || type.includes('CONFLICT')) {
      return 'WARNING';
    }

    if (type.includes('AVAILABLE') || type.includes('RECOVERED') || type.includes('NOTICE') || type.includes('LOGIN')) {
      return 'NOTICE';
    }

    return 'INFO';
  }

  isQuietHoursActive(preferences = {}, timeStrOrDate = null) {
    if (!preferences.quiet_hours_enabled) return false;
    let nowDate = new Date();
    if (typeof timeStrOrDate === 'string' && timeStrOrDate.includes(':')) {
      const [h, m] = timeStrOrDate.split(':').map(Number);
      nowDate = new Date();
      nowDate.setHours(h, m, 0, 0);
    } else if (timeStrOrDate instanceof Date) {
      nowDate = timeStrOrDate;
    }
    return this.isWithinQuietHours(nowDate, preferences.quiet_hours_start, preferences.quiet_hours_end);
  }

  evaluateDecision(event, userPreferences = {}, forceQuietHours = null) {
    const isQuiet = forceQuietHours !== null ? forceQuietHours : this.isQuietHoursActive(userPreferences);
    const severity = this.classifySeverity(event);
    if (isQuiet) {
      if (severity === 'CRITICAL') {
        return {
          action: 'SEND',
          severity,
          reason: 'CRITICAL_ALERT_BYPASS_QUIET_HOURS',
          metadata: { inQuietHours: true, severity, bypass: true }
        };
      } else {
        return {
          action: 'DEFER',
          severity,
          reason: 'QUIET_HOURS_DEFERRED',
          metadata: { inQuietHours: true, severity, deferred: true }
        };
      }
    }
    return {
      action: 'SEND',
      severity,
      reason: 'POLICY_APPROVED',
      metadata: { inQuietHours: false, severity }
    };
  }

  /**
   * Map event type to preference key
   */
  getPreferenceKey(eventType) {
    const type = (eventType || '').toUpperCase();
    if (type.includes('OFFLINE')) return 'device_offline';
    if (type.includes('RECOVERED') || type.includes('ONLINE')) return 'device_offline';
    if (type.includes('RELIABILITY') || type.includes('HEALTH')) return 'device_health';
    if (type.includes('AUTOMATION') || type.includes('SCENE') || type.includes('SCHEDULE')) return 'automation_failure';
    if (type.includes('OTA') || type.includes('FIRMWARE')) return 'firmware_updates';
    if (type.includes('ENERGY') || type.includes('POWER') || type.includes('TARIFF')) return 'energy_alerts';
    if (type.includes('SECURITY') || type.includes('INCIDENT') || type.includes('AUTH_FAIL')) return 'security_alerts';
    if (type.includes('MATTER') || type.includes('PLATFORM')) return 'matter_alerts';
    if (type.includes('MEMBER') || type.includes('INVITATION') || type.includes('ACCOUNT')) return 'member_alerts';
    return null;
  }

  /**
   * Main Decision Method
   */
  evaluate({
    event,
    userPreferences = {},
    userRole = 'OWNER',
    currentTime = new Date(),
    dedupWindowSeconds = 60,
    preferenceKey = null
  }) {
    const severity = this.classifySeverity(event);
    const eventType = (event.type || event.eventType || '').toUpperCase();
    const homeId = event.homeId || 'global';
    const deviceId = event.deviceId || (event.payload && event.payload.deviceId) || null;
    const effectivePrefKey = preferenceKey || this.getPreferenceKey(eventType);

    // 1. RBAC & Role Check
    if (userRole === 'GUEST') {
      const guestAllowed = ['DEVICE_STATE_CHANGED', 'PHYSICAL_SWITCH_CHANGED', 'COMMAND_FAILED'];
      if (!guestAllowed.includes(eventType) && severity !== 'CRITICAL') {
        return {
          action: 'SUPPRESS',
          severity,
          reason: 'ROLE_NOT_PERMITTED',
          metadata: { userRole, eventType }
        };
      }
    }

    // 2. User Preferences Check
    if (severity !== 'CRITICAL') {
      // Global push toggle
      if (userPreferences.push_enabled === false && userPreferences.in_app_enabled === false) {
        return {
          action: 'SUPPRESS',
          severity,
          reason: 'GLOBAL_NOTIFICATIONS_DISABLED',
          metadata: { push_enabled: false }
        };
      }

      if (effectivePrefKey && userPreferences[effectivePrefKey] === false) {
        return {
          action: 'SUPPRESS',
          severity,
          reason: 'CATEGORY_PREFERENCE_DISABLED',
          metadata: { preferenceKey: effectivePrefKey }
        };
      }
    } else {
      // Critical alerts: check if user explicitly disabled critical alerts
      if (userPreferences.critical_alerts === false) {
        return {
          action: 'SUPPRESS',
          severity,
          reason: 'CRITICAL_ALERTS_DISABLED_BY_USER',
          metadata: { critical_alerts: false }
        };
      }
    }

    // 3. Deduplication Check
    const dedupKey = `${eventType}_${userPreferences.user_id || 'user'}_${deviceId || homeId || 'global'}`;
    const nowMs = currentTime.getTime();
    const lastSentMs = this.rateLimitMap.get(dedupKey) || 0;
    const windowMs = (severity === 'CRITICAL' ? 10 : dedupWindowSeconds) * 1000;

    if (severity !== 'CRITICAL' && (nowMs - lastSentMs < windowMs)) {
      return {
        action: 'SUPPRESS',
        severity,
        reason: 'DEDUPLICATED',
        metadata: { dedupKey, windowSeconds: windowMs / 1000, elapsedSeconds: (nowMs - lastSentMs) / 1000 }
      };
    }

    // 4. Flapping & Recovery Suppression (only when explicitly flagged as checkFlapping)
    if (event.payload && event.payload.checkFlapping && (eventType === 'DEVICE_RECOVERED' || eventType === 'DEVICE_ONLINE')) {
      if (deviceId) {
        const lastOffline = this.flappingTracker.get(deviceId);
        if (lastOffline && (nowMs - lastOffline < 3000)) {
          return {
            action: 'SUPPRESS',
            severity,
            reason: 'FLAPPING_SUPPRESSED',
            metadata: { deviceId, flapDurationMs: nowMs - lastOffline }
          };
        }
      }
    } else if (eventType === 'DEVICE_OFFLINE') {
      if (deviceId) {
        this.flappingTracker.set(deviceId, nowMs);
      }
    }

    // 5. Deterministic Quiet Hours Check (Fix 2)
    const quietHoursEnabled = userPreferences.quiet_hours_enabled === true;
    const inQuietHours = quietHoursEnabled && this.isWithinQuietHours(
      currentTime,
      userPreferences.quiet_hours_start || '22:00',
      userPreferences.quiet_hours_end || '07:00'
    );

    if (inQuietHours) {
      if (severity === 'CRITICAL') {
        this.rateLimitMap.set(dedupKey, nowMs);
        return {
          action: 'SEND',
          severity,
          reason: 'CRITICAL_BYPASS_QUIET_HOURS',
          channels: this._resolveChannels(userPreferences, severity),
          metadata: { inQuietHours: true, severity }
        };
      } else {
        return {
          action: 'DEFER',
          severity,
          reason: 'DEFERRED_QUIET_HOURS',
          channels: this._resolveChannels(userPreferences, severity),
          metadata: {
            inQuietHours: true,
            severity,
            quietHoursStart: userPreferences.quiet_hours_start || '22:00',
            quietHoursEnd: userPreferences.quiet_hours_end || '07:00'
          }
        };
      }
    }

    // 6. Normal SEND
    this.rateLimitMap.set(dedupKey, nowMs);
    return {
      action: 'SEND',
      severity,
      reason: 'POLICY_APPROVED',
      channels: this._resolveChannels(userPreferences, severity),
      metadata: { inQuietHours: false, severity }
    };
  }

  _resolveChannels(prefs, severity) {
    const channels = ['in_app'];
    if (prefs.push_enabled !== false || severity === 'CRITICAL') {
      channels.push('push');
    }
    if (prefs.email_enabled === true && (severity === 'CRITICAL' || severity === 'ERROR')) {
      channels.push('email');
    }
    return channels;
  }

  reset() {
    this.rateLimitMap.clear();
    this.flappingTracker.clear();
  }
}

module.exports = { NotificationDecisionService };
