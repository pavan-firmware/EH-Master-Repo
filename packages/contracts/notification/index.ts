/**
 * EH Home Canonical Notification Contracts (v2.0 — Phase 30)
 */

export type NotificationType =
  | 'DEVICE_OFFLINE'
  | 'DEVICE_ONLINE'
  | 'DEVICE_RECOVERED'
  | 'DEVICE_STATE_CHANGED'
  | 'PHYSICAL_SWITCH_CHANGED'
  | 'COMMAND_FAILED'
  | 'AUTOMATION_EXECUTED'
  | 'AUTOMATION_FAILED'
  | 'SCENE_FAILED'
  | 'SCHEDULE_FAILED'
  | 'OTA_AVAILABLE'
  | 'OTA_STARTED'
  | 'OTA_SUCCESS'
  | 'OTA_FAILED'
  | 'OTA_ROLLED_BACK'
  | 'ENERGY_HIGH'
  | 'ENERGY_THRESHOLD_EXCEEDED'
  | 'UNUSUAL_ENERGY_USAGE'
  | 'MATTER_CONNECTED'
  | 'MATTER_DISCONNECTED'
  | 'MATTER_COMMISSIONING_FAILED'
  | 'SECURITY_EVENT'
  | 'SECURITY_ALERT'
  | 'ACCOUNT_EVENT'
  | 'HOME_MEMBER_ADDED'
  | 'SYSTEM_EVENT';

export type NotificationCategory =
  | 'alert'
  | 'automation'
  | 'update'
  | 'energy'
  | 'security'
  | 'matter'
  | 'system';

export type NotificationPriority =
  | 'CRITICAL'
  | 'HIGH'
  | 'NORMAL'
  | 'LOW';

export type NotificationSeverity =
  | 'INFO'
  | 'NOTICE'
  | 'WARNING'
  | 'ERROR'
  | 'CRITICAL';

export type NotificationDeliveryStatus =
  | 'CREATED'
  | 'QUEUED'
  | 'DISPATCHING'
  | 'DELIVERED'
  | 'READ'
  | 'ACTIONED'
  | 'SUPPRESSED'
  | 'DEFERRED'
  | 'EXPIRED'
  | 'FAILED'
  | 'PENDING';

export type NotificationActionType =
  | 'VIEW_DEVICE'
  | 'REVIEW_UPDATE'
  | 'VIEW_ENERGY'
  | 'VIEW_AUTOMATION'
  | 'VIEW_INTEGRATIONS'
  | 'VIEW_SECURITY'
  | 'ACKNOWLEDGE'
  | 'DISMISS'
  | 'CUSTOM';

export type NotificationActionState =
  | 'NONE'
  | 'PENDING'
  | 'ACTIONED'
  | 'DISMISSED';

export type PlatformEventSource =
  | 'device'
  | 'connectivity'
  | 'reliability'
  | 'ota'
  | 'energy'
  | 'automation'
  | 'matter'
  | 'security'
  | 'account'
  | 'system';

export interface PlatformEvent {
  schemaVersion: 1;
  eventId: string;
  eventType: string;
  source: PlatformEventSource;
  homeId: string;
  deviceId?: string | null;
  userId?: string | null;
  severity: NotificationSeverity;
  title: string;
  message?: string;
  data?: Record<string, any>;
  occurredAt: string;
}

export interface Notification {
  schemaVersion: 1;
  id: string;
  userId?: string | null;
  homeId?: string | null;
  type: NotificationType | string;
  category: NotificationCategory;
  priority: NotificationPriority;
  severity?: NotificationSeverity;
  title: string;
  body: string;
  entityType?: string | null;
  entityId?: string | null;
  data?: Record<string, any>;
  readAt?: string | null;
  deliveryStatus: NotificationDeliveryStatus;
  actionType?: NotificationActionType | string | null;
  actionTarget?: string | null;
  actionState?: NotificationActionState | null;
  isAggregated?: boolean;
  aggregatedCount?: number;
  aggregatedIds?: string[];
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
  schemaVersion?: 1;
  userId: string;
  pushEnabled: boolean;
  emailEnabled?: boolean;
  inAppEnabled?: boolean;
  criticalAlerts: boolean;
  deviceOffline: boolean;
  deviceHealth?: boolean;
  automationFailure: boolean;
  firmwareUpdates: boolean;
  energyAlerts?: boolean;
  securityAlerts?: boolean;
  matterAlerts?: boolean;
  memberAlerts?: boolean;
  quietHoursEnabled?: boolean;
  quietHoursStart?: string;
  quietHoursEnd?: string;
  updatedAt: string;
}

export interface NotificationDeliveryQueueItem {
  id: string;
  notificationId: string;
  tokenId?: string | null;
  channel?: 'push' | 'in_app' | 'email';
  status: 'PENDING' | 'SENT' | 'FAILED' | 'RETRYING' | 'DEAD_LETTER';
  attempts: number;
  maxAttempts: number;
  nextAttemptAt: string;
  lastError?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface NotificationAction {
  schemaVersion: 1;
  actionId: string;
  notificationId: string;
  userId: string;
  actionType: NotificationActionType | string;
  actionTarget?: string | null;
  actionState: 'PENDING' | 'ACTIONED' | 'DISMISSED' | 'FAILED';
  payload?: Record<string, any>;
  executedAt: string;
}

export interface NotificationAggregation {
  schemaVersion: 1;
  aggregationId: string;
  aggregationKey: string;
  homeId: string;
  roomId?: string | null;
  eventType: string;
  severity: NotificationSeverity;
  eventCount: number;
  aggregatedIds: string[];
  summaryTitle: string;
  summaryBody: string;
  windowSeconds?: number;
  createdAt: string;
  updatedAt?: string;
}
