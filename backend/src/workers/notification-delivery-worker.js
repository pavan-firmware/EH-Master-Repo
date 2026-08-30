const RETRY_DELAYS_MS = [
  1000,    // 1s
  5000,    // 5s
  30000,   // 30s
  120000,  // 2m
  300000   // 5m
];

class NotificationDeliveryWorker {
  constructor({
    notificationRepository,
    pushProvider,
    pollIntervalMs = 2000,
    batchSize = 20
  }) {
    this.repo = notificationRepository;
    this.pushProvider = pushProvider;
    this.pollIntervalMs = pollIntervalMs;
    this.batchSize = batchSize;
    this.timer = null;
    this.isRunning = false;
    this.isProcessing = false;
  }

  start() {
    if (this.isRunning) return;
    this.isRunning = true;
    this.timer = setInterval(() => this.tick(), this.pollIntervalMs);
  }

  stop() {
    this.isRunning = false;
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async tick() {
    if (this.isProcessing || !this.pushProvider) return;
    this.isProcessing = true;

    try {
      const pendingItems = await this.repo.fetchPendingDeliveries(this.batchSize);

      for (const item of pendingItems) {
        await this.processItem(item);
      }
    } catch (err) {
      console.error('[NotificationDeliveryWorker] Error during poll cycle:', err.message);
    } finally {
      this.isProcessing = false;
    }
  }

  async processItem(item) {
    const notification = await this.repo.findById(item.notification_id);
    if (!notification) {
      // Notification was deleted or missing
      await this.repo.updateDeliveryStatus(item.id, {
        status: 'FAILED',
        lastError: 'NOTIFICATION_NOT_FOUND'
      });
      return;
    }

    let tokenRecord = null;
    if (item.token_id) {
      tokenRecord = await this.repo.db.findById('push_device_tokens', item.token_id);
    }

    if (!tokenRecord || !tokenRecord.is_active) {
      await this.repo.updateDeliveryStatus(item.id, {
        status: 'FAILED',
        lastError: 'TOKEN_INACTIVE_OR_REMOVED'
      });
      return;
    }

    const payload = {
      notificationId: notification.id,
      title: notification.title,
      body: notification.body,
      priority: notification.priority,
      category: notification.category,
      data: notification.data_json || {}
    };

    try {
      const result = await this.pushProvider.sendPush(tokenRecord, payload);

      if (result.success) {
        await this.repo.updateDeliveryStatus(item.id, {
          status: 'SENT',
          attempts: item.attempts + 1,
          lastError: null
        });

        // Update overall notification delivery status to DELIVERED
        await this.repo.db.update('notifications', notification.id, {
          delivery_status: 'DELIVERED'
        });
      } else {
        const nextAttempt = item.attempts + 1;

        if (result.invalidToken) {
          // Deactivate stale/invalid token
          await this.repo.db.update('push_device_tokens', tokenRecord.id, { is_active: false });
          await this.repo.updateDeliveryStatus(item.id, {
            status: 'FAILED',
            attempts: nextAttempt,
            lastError: result.error || 'INVALID_TOKEN'
          });
        } else if (nextAttempt >= item.max_attempts) {
          // Exceeded retry budget -> DEAD_LETTER
          await this.repo.updateDeliveryStatus(item.id, {
            status: 'DEAD_LETTER',
            attempts: nextAttempt,
            lastError: result.error || 'MAX_ATTEMPTS_EXCEEDED'
          });

          await this.repo.db.update('notifications', notification.id, {
            delivery_status: 'FAILED'
          });
        } else {
          // Schedule exponential backoff
          const delay = RETRY_DELAYS_MS[Math.min(nextAttempt - 1, RETRY_DELAYS_MS.length - 1)];
          const nextAttemptAt = new Date(Date.now() + delay).toISOString();

          await this.repo.updateDeliveryStatus(item.id, {
            status: 'RETRYING',
            attempts: nextAttempt,
            nextAttemptAt,
            lastError: result.error || 'DELIVERY_FAILED'
          });
        }
      }
    } catch (err) {
      const nextAttempt = item.attempts + 1;
      if (nextAttempt >= item.max_attempts) {
        await this.repo.updateDeliveryStatus(item.id, {
          status: 'DEAD_LETTER',
          attempts: nextAttempt,
          lastError: err.message
        });
      } else {
        const delay = RETRY_DELAYS_MS[Math.min(nextAttempt - 1, RETRY_DELAYS_MS.length - 1)];
        await this.repo.updateDeliveryStatus(item.id, {
          status: 'RETRYING',
          attempts: nextAttempt,
          nextAttemptAt: new Date(Date.now() + delay).toISOString(),
          lastError: err.message
        });
      }
    }
  }
}

module.exports = { NotificationDeliveryWorker, RETRY_DELAYS_MS };
