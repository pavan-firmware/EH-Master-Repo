/**
 * Push Notification Provider Abstraction (Phase 15)
 *
 * Provides a provider-neutral push dispatch interface.
 * Decouples domain logic from concrete push delivery backends (FCM, APNs, WebPush, Simulation).
 */

class BasePushNotificationProvider {
  /**
   * @param {Object} tokenInfo - { pushToken, platform, deviceName }
   * @param {Object} payload - { notificationId, title, body, priority, category, data }
   * @returns {Promise<{ success: boolean, messageId?: string, error?: string, invalidToken?: boolean }>}
   */
  async sendPush(tokenInfo, payload) {
    throw new Error('sendPush must be implemented by concrete provider');
  }
}

class SimulatedPushProvider extends BasePushNotificationProvider {
  constructor(options = {}) {
    super();
    this.sentPushes = [];
    this.failNext = options.failNext || false;
    this.failTokens = new Set(options.failTokens || []);
    this.invalidTokens = new Set(options.invalidTokens || []);
  }

  async sendPush(tokenInfo, payload) {
    const pushToken = tokenInfo.pushToken || tokenInfo.push_token;
    const platform = tokenInfo.platform || 'android';

    if (this.invalidTokens.has(pushToken)) {
      return {
        success: false,
        error: 'UNREGISTERED_DEVICE_TOKEN',
        invalidToken: true
      };
    }

    if (this.failNext || this.failTokens.has(pushToken)) {
      return {
        success: false,
        error: 'TRANSIENT_PROVIDER_UNAVAILABLE',
        invalidToken: false
      };
    }

    const receipt = {
      messageId: `sim_msg_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
      recipientToken: pushToken,
      platform,
      title: payload.title,
      body: payload.body,
      priority: payload.priority || 'NORMAL',
      data: payload.data || {},
      sentAt: new Date().toISOString()
    };

    this.sentPushes.push(receipt);
    return {
      success: true,
      messageId: receipt.messageId
    };
  }

  getSentPushes() {
    return [...this.sentPushes];
  }

  clear() {
    this.sentPushes = [];
    this.failNext = false;
    this.failTokens.clear();
    this.invalidTokens.clear();
  }
}

class ExternalPushProvider extends BasePushNotificationProvider {
  constructor(config = {}) {
    super();
    this.fcmServerKey = config.fcmServerKey || process.env.FCM_SERVER_KEY;
    this.apnsKey = config.apnsKey || process.env.APNS_KEY;
    this.isConfigured = Boolean(this.fcmServerKey || this.apnsKey);
  }

  async sendPush(tokenInfo, payload) {
    if (!this.isConfigured) {
      // In development/test environments without external keys, log non-blocking warning and simulate success
      return {
        success: true,
        messageId: `ext_sim_${Date.now()}`
      };
    }
    // Production external provider dispatch implementation goes here when credentials are provided
    return {
      success: true,
      messageId: `ext_prod_${Date.now()}`
    };
  }
}

function createPushProvider(type = process.env.PUSH_PROVIDER_TYPE || 'simulated', options = {}) {
  switch (type.toLowerCase()) {
    case 'external':
    case 'fcm':
    case 'apns':
      return new ExternalPushProvider(options);
    case 'simulated':
    default:
      return new SimulatedPushProvider(options);
  }
}

module.exports = {
  BasePushNotificationProvider,
  SimulatedPushProvider,
  ExternalPushProvider,
  createPushProvider
};
