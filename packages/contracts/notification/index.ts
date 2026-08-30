/**
 * EH Home Canonical Notification Contracts (v1.0)
 */

export type NotificationType =
  | 'DEVICE_OFFLINE'
  | 'DEVICE_RECOVERED'
  | 'COMMAND_FAILED'
  | 'AUTOMATION_FAILED'
  | 'SCENE_FAILED'
  | 'SCHEDULE_FAILED'
  | 'OTA_AVAILABLE'
  | 'OTA_FAILED'
  | 'SECURITY_EVENT'
  | 'SYSTEM_EVENT';

export type NotificationCategory =
  | 'alert'
  | 'automation'
  | 'update'
  | 'security'
  | 'system';

export type NotificationPriority =
  | 'CRITICAL'
  | 'HIGH'
  | 'NORMAL'
  | 'LOW';

export type NotificationDeliveryStatus =
  | 'PENDING'
  | 'DELIVERED'
  | 'FAILED'
  | 'SUPPRESSED';

export interface Notification {
  schemaVersion: 1;
  id: string;
  userId?: string | null;
  homeId?: string | null;
  type: NotificationType;
  category: NotificationCategory;
  priority: NotificationPriority;
  title: string;
  body: string;
  entityType?: string | null;
  entityId?: string | null;
  data?: Record<string, any>;
  readAt?: string | null;
  deliveryStatus: NotificationDeliveryStatus;
  idempotencyKey?: string | null;
  createdAt: string;
}

export type PushPlatform = 'android' | 'ios' | 'web';

export interface PushDeviceToken {
  id: string;
  userId: string;
  pushToken: string;
  platform: PushPlatform;
  deviceName?: string | null;
  isActive: boolean;
  lastUsedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PushTokenRegistrationPayload {
  pushToken: string;
  platform?: PushPlatform;
  deviceName?: string | null;
}

export interface UserNotificationPreferences {
  userId: string;
  pushEnabled: boolean;
  criticalAlerts: boolean;
  deviceOffline: boolean;
  automationFailure: boolean;
  firmwareUpdates: boolean;
  updatedAt: string;
}

export interface NotificationDeliveryQueueItem {
  id: string;
  notificationId: string;
  tokenId?: string | null;
  status: 'PENDING' | 'SENT' | 'FAILED' | 'RETRYING' | 'DEAD_LETTER';
  attempts: number;
  maxAttempts: number;
  nextAttemptAt: string;
  lastError?: string | null;
  createdAt: string;
  updatedAt: string;
}
