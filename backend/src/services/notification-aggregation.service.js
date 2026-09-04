'use strict';

/**
 * EH Home — NotificationAggregationService (Phase 30)
 *
 * Sliding-window aggregation of repeated/correlated events to prevent alert fatigue.
 *
 * Example:
 * 3 devices going offline in the same room/home produce:
 * "3 devices in Living Room are offline."
 * Drill-down data preserves individual device IDs and timestamps.
 */

class NotificationAggregationService {
  constructor(options = {}) {
    this.windowSeconds = options.windowSeconds || 60;
    // Map<aggregationKey, { events: Array, firstSeenAt: number, timer: Timeout }>
    this.activeAggregations = new Map();
  }

  /**
   * Generates a deterministic aggregation key based on homeId, eventType, and optional roomId/cluster
   */
  getAggregationKey({ homeId, eventType, roomId = null, fleetId = null }) {
    if (fleetId) {
      return `agg:${homeId}:fleet:${fleetId}:${eventType}`;
    }
    if (roomId) {
      return `agg:${homeId}:room:${roomId}:${eventType}`;
    }
    return `agg:${homeId}:${eventType}`;
  }

  /**
   * Check if an event can/should be aggregated.
   */
  shouldAggregate(eventType) {
    const type = (eventType || '').toUpperCase();
    return (
      type.includes('OFFLINE') ||
      type.includes('OTA_') ||
      type.includes('RECOVERED') ||
      type.includes('ONLINE') ||
      type.includes('ENERGY')
    );
  }

  /**
   * Ingest an event into an active aggregation window.
   * Returns aggregated notification payload if threshold met, or null if buffering.
   */
  ingest({ homeId, roomId = null, eventType, deviceId = null, deviceName = null, severity = 'WARNING', data = {} }) {
    if (!this.shouldAggregate(eventType)) {
      return null;
    }

    const key = this.getAggregationKey({ homeId, eventType, roomId });
    const now = Date.now();
    let cluster = this.activeAggregations.get(key);

    if (!cluster) {
      cluster = {
        key,
        homeId,
        roomId,
        eventType,
        severity,
        firstSeenAt: now,
        lastSeenAt: now,
        items: []
      };
      this.activeAggregations.set(key, cluster);
    }

    // Check if device already in this window
    const existing = cluster.items.find(i => i.deviceId === deviceId);
    if (!existing) {
      cluster.items.push({
        deviceId,
        deviceName: deviceName || deviceId || 'Smart Device',
        data,
        timestamp: new Date().toISOString()
      });
      cluster.lastSeenAt = now;
    }

    // If cluster has multiple items (>= 2), produce aggregated notification payload
    if (cluster.items.length >= 2) {
      return this.buildAggregatedNotification(cluster);
    }

    return null;
  }

  /**
   * Construct the aggregated notification representation
   */
  buildAggregatedNotification(cluster) {
    const count = cluster.items.length;
    const deviceNames = cluster.items.map(i => i.deviceName);
    const deviceIds = cluster.items.map(i => i.deviceId).filter(Boolean);
    const type = cluster.eventType.toUpperCase();

    let title;
    let body;

    if (type.includes('OFFLINE')) {
      title = `${count} devices are offline`;
      body = `${deviceNames.slice(0, 3).join(', ')}${count > 3 ? ` and ${count - 3} more` : ''} lost connection.`;
    } else if (type.includes('OTA_SUCCESS') || type.includes('OTA_COMPLETED')) {
      title = `${count} devices updated`;
      body = `Firmware update completed successfully on ${count} devices.`;
    } else if (type.includes('RECOVERED') || type.includes('ONLINE')) {
      title = `${count} devices back online`;
      body = `${deviceNames.slice(0, 3).join(', ')}${count > 3 ? ` and ${count - 3} more` : ''} reconnected.`;
    } else {
      title = `${count} ${cluster.eventType} events`;
      body = `Multiple related alerts detected for: ${deviceNames.slice(0, 3).join(', ')}.`;
    }

    return {
      isAggregated: true,
      aggregatedCount: count,
      aggregatedIds: deviceIds,
      title,
      body,
      homeId: cluster.homeId,
      roomId: cluster.roomId,
      type: cluster.eventType,
      severity: cluster.severity,
      data: {
        aggregatedCount: count,
        aggregatedDeviceIds: deviceIds,
        deviceNames,
        clusterKey: cluster.key
      }
    };
  }

  recordEvent(clusterKey, event) {
    let cluster = this.activeAggregations.get(clusterKey);
    if (!cluster) {
      cluster = {
        key: clusterKey,
        events: [],
        firstSeenAt: Date.now(),
        lastSeenAt: Date.now()
      };
      this.activeAggregations.set(clusterKey, cluster);
    }
    cluster.events.push(event);
    cluster.lastSeenAt = Date.now();
    return cluster.events.length >= 3;
  }

  getCluster(clusterKey) {
    return this.activeAggregations.get(clusterKey) || null;
  }

  drainCluster(clusterKey) {
    const cluster = this.activeAggregations.get(clusterKey);
    if (!cluster) return [];
    this.activeAggregations.delete(clusterKey);
    return cluster.events || [];
  }

  /**
   * Reset / clear windows (useful for testing or after dispatch)
   */
  clearCluster(key) {
    this.activeAggregations.delete(key);
  }

  reset() {
    this.activeAggregations.clear();
  }
}

module.exports = { NotificationAggregationService };
