'use strict';

/**
 * EH Home — Canonical MQTT Topic Builder & Parser (Phase 6)
 *
 * Single source-of-truth for all topic construction and parsing.
 * ALL Phase 6 backend, transport, and test code MUST use this module.
 * Never hard-code topic strings elsewhere.
 *
 * Canonical topic scheme: eh/v1/devices/{deviceId}/{category}
 *
 * Parser strictly rejects:
 *   - MQTT wildcards: '+' or '#'
 *   - Malformed deviceId (must be canonical UUID)
 *   - Empty path segments
 *   - Unexpected extra path segments
 *   - Unknown categories
 */

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const TOPIC_CATEGORIES = Object.freeze({
  COMMANDS:         'commands',
  COMMAND_RECEIPTS: 'command-receipts',
  STATE:            'state',
  EVENTS:           'events',
  TELEMETRY:        'telemetry',
  AVAILABILITY:     'availability',
});

const QOS_POLICY = Object.freeze({
  commands:         { qos: 1, retain: false },
  'command-receipts': { qos: 1, retain: false },
  state:            { qos: 1, retain: false },
  events:           { qos: 1, retain: false },
  telemetry:        { qos: 0, retain: false },
  availability:     { qos: 1, retain: true  },
});

const TOPIC_PREFIX = 'eh/v1/devices';

/** Validate canonical UUID format. Throws if invalid. */
function _assertValidDeviceId(deviceId) {
  if (!deviceId || typeof deviceId !== 'string') {
    throw new Error('deviceId must be a non-empty string');
  }
  if (!UUID_REGEX.test(deviceId)) {
    throw new Error(`deviceId '${deviceId}' is not a canonical UUID (expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)`);
  }
}

/** Validate a known topic category. Throws if invalid. */
function _assertValidCategory(category) {
  const valid = Object.values(TOPIC_CATEGORIES);
  if (!valid.includes(category)) {
    throw new Error(`Unknown topic category '${category}'. Valid categories: ${valid.join(', ')}`);
  }
}

/** Assert topic string contains no MQTT wildcards. */
function _assertNoWildcards(topic) {
  if (topic.includes('+') || topic.includes('#')) {
    throw new Error(`Topic '${topic}' must not contain MQTT wildcards ('+' or '#')`);
  }
}

// ---------------------------------------------------------------------------
// Topic Builders
// ---------------------------------------------------------------------------

const MqttTopicBuilder = Object.freeze({
  commands(deviceId)        { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/commands`; },
  commandReceipts(deviceId) { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/command-receipts`; },
  state(deviceId)           { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/state`; },
  events(deviceId)          { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/events`; },
  telemetry(deviceId)       { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/telemetry`; },
  availability(deviceId)    { _assertValidDeviceId(deviceId); return `${TOPIC_PREFIX}/${deviceId}/availability`; },

  /**
   * Returns subscribe topic for backend to receive data from ALL devices for a given category.
   * Uses '+' wildcard — backend-only, never published.
   */
  backendSubscribe(category) {
    _assertValidCategory(category);
    return `${TOPIC_PREFIX}/+/${category}`;
  },

  /** Returns QoS and retain policy for a category. */
  qosPolicy(category) {
    _assertValidCategory(category);
    return QOS_POLICY[category];
  }
});

// ---------------------------------------------------------------------------
// Topic Parser
// ---------------------------------------------------------------------------

const MqttTopicParser = Object.freeze({
  /**
   * Parses a canonical device topic string.
   * Returns: { deviceId, category }
   * Throws: descriptive Error on any violation.
   *
   * Rejects:
   *   - '+' or '#' wildcards (policy violation)
   *   - Segment count != 5 (eh / v1 / devices / {deviceId} / {category})
   *   - Incorrect prefix
   *   - Malformed UUID deviceId
   *   - Unknown category
   *   - Empty segments
   */
  parse(topic) {
    if (!topic || typeof topic !== 'string') {
      throw new Error('Topic must be a non-empty string');
    }

    // Wildcard rejection
    _assertNoWildcards(topic);

    const segments = topic.split('/');

    // Must have exactly 5 segments: eh, v1, devices, {deviceId}, {category}
    if (segments.length !== 5) {
      throw new Error(`Topic '${topic}' has ${segments.length} segments; expected exactly 5 (eh/v1/devices/{deviceId}/{category})`);
    }

    // Check for empty segments
    for (let i = 0; i < segments.length; i++) {
      if (segments[i] === '') {
        throw new Error(`Topic '${topic}' contains an empty segment at position ${i}`);
      }
    }

    const [prefix0, prefix1, prefix2, deviceId, category] = segments;

    if (prefix0 !== 'eh' || prefix1 !== 'v1' || prefix2 !== 'devices') {
      throw new Error(`Topic '${topic}' has incorrect prefix; expected 'eh/v1/devices/...'`);
    }

    if (!UUID_REGEX.test(deviceId)) {
      throw new Error(`Topic '${topic}' contains malformed deviceId '${deviceId}'; expected canonical UUID`);
    }

    _assertValidCategory(category);

    return { deviceId, category };
  },

  /**
   * Returns true if the topic is a valid device topic for the given deviceId.
   * Returns false (never throws) — safe for use in conditional checks.
   */
  isValidForDevice(topic, deviceId) {
    try {
      const parsed = MqttTopicParser.parse(topic);
      return parsed.deviceId === deviceId;
    } catch (_) {
      return false;
    }
  }
});

module.exports = {
  MqttTopicBuilder,
  MqttTopicParser,
  TOPIC_CATEGORIES,
  QOS_POLICY,
};
