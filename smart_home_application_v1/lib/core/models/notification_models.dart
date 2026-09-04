import 'package:flutter/foundation.dart';

enum NotificationType {
  deviceOffline,
  deviceRecovered,
  deviceStateChanged,
  physicalSwitchChanged,
  commandFailed,
  automationExecuted,
  automationFailed,
  sceneFailed,
  scheduleFailed,
  otaAvailable,
  otaStarted,
  otaSuccess,
  otaFailed,
  otaRolledBack,
  energyHigh,
  energyThresholdExceeded,
  unusualEnergyUsage,
  matterConnected,
  matterDisconnected,
  matterCommissioningFailed,
  securityAlert,
  securityEvent,
  accountEvent,
  homeMemberAdded,
  systemEvent;

  static NotificationType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'DEVICE_OFFLINE':
        return NotificationType.deviceOffline;
      case 'DEVICE_RECOVERED':
      case 'DEVICE_ONLINE':
        return NotificationType.deviceRecovered;
      case 'DEVICE_STATE_CHANGED':
        return NotificationType.deviceStateChanged;
      case 'PHYSICAL_SWITCH_CHANGED':
        return NotificationType.physicalSwitchChanged;
      case 'COMMAND_FAILED':
        return NotificationType.commandFailed;
      case 'AUTOMATION_EXECUTED':
        return NotificationType.automationExecuted;
      case 'AUTOMATION_FAILED':
        return NotificationType.automationFailed;
      case 'SCENE_FAILED':
        return NotificationType.sceneFailed;
      case 'SCHEDULE_FAILED':
        return NotificationType.scheduleFailed;
      case 'OTA_AVAILABLE':
        return NotificationType.otaAvailable;
      case 'OTA_STARTED':
        return NotificationType.otaStarted;
      case 'OTA_SUCCESS':
      case 'OTA_COMPLETED':
        return NotificationType.otaSuccess;
      case 'OTA_FAILED':
        return NotificationType.otaFailed;
      case 'OTA_ROLLED_BACK':
        return NotificationType.otaRolledBack;
      case 'ENERGY_HIGH':
        return NotificationType.energyHigh;
      case 'ENERGY_THRESHOLD_EXCEEDED':
        return NotificationType.energyThresholdExceeded;
      case 'UNUSUAL_ENERGY_USAGE':
        return NotificationType.unusualEnergyUsage;
      case 'MATTER_CONNECTED':
        return NotificationType.matterConnected;
      case 'MATTER_DISCONNECTED':
        return NotificationType.matterDisconnected;
      case 'MATTER_COMMISSIONING_FAILED':
        return NotificationType.matterCommissioningFailed;
      case 'SECURITY_ALERT':
        return NotificationType.securityAlert;
      case 'SECURITY_EVENT':
        return NotificationType.securityEvent;
      case 'ACCOUNT_EVENT':
        return NotificationType.accountEvent;
      case 'HOME_MEMBER_ADDED':
        return NotificationType.homeMemberAdded;
      case 'SYSTEM_EVENT':
      default:
        return NotificationType.systemEvent;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationType.deviceOffline:
        return 'DEVICE_OFFLINE';
      case NotificationType.deviceRecovered:
        return 'DEVICE_RECOVERED';
      case NotificationType.deviceStateChanged:
        return 'DEVICE_STATE_CHANGED';
      case NotificationType.physicalSwitchChanged:
        return 'PHYSICAL_SWITCH_CHANGED';
      case NotificationType.commandFailed:
        return 'COMMAND_FAILED';
      case NotificationType.automationExecuted:
        return 'AUTOMATION_EXECUTED';
      case NotificationType.automationFailed:
        return 'AUTOMATION_FAILED';
      case NotificationType.sceneFailed:
        return 'SCENE_FAILED';
      case NotificationType.scheduleFailed:
        return 'SCHEDULE_FAILED';
      case NotificationType.otaAvailable:
        return 'OTA_AVAILABLE';
      case NotificationType.otaStarted:
        return 'OTA_STARTED';
      case NotificationType.otaSuccess:
        return 'OTA_SUCCESS';
      case NotificationType.otaFailed:
        return 'OTA_FAILED';
      case NotificationType.otaRolledBack:
        return 'OTA_ROLLED_BACK';
      case NotificationType.energyHigh:
        return 'ENERGY_HIGH';
      case NotificationType.energyThresholdExceeded:
        return 'ENERGY_THRESHOLD_EXCEEDED';
      case NotificationType.unusualEnergyUsage:
        return 'UNUSUAL_ENERGY_USAGE';
      case NotificationType.matterConnected:
        return 'MATTER_CONNECTED';
      case NotificationType.matterDisconnected:
        return 'MATTER_DISCONNECTED';
      case NotificationType.matterCommissioningFailed:
        return 'MATTER_COMMISSIONING_FAILED';
      case NotificationType.securityAlert:
        return 'SECURITY_ALERT';
      case NotificationType.securityEvent:
        return 'SECURITY_EVENT';
      case NotificationType.accountEvent:
        return 'ACCOUNT_EVENT';
      case NotificationType.homeMemberAdded:
        return 'HOME_MEMBER_ADDED';
      case NotificationType.systemEvent:
        return 'SYSTEM_EVENT';
    }
  }
}

enum NotificationCategory {
  all,
  alert,
  automation,
  update,
  energy,
  security,
  matter,
  system;

  static NotificationCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'alert':
        return NotificationCategory.alert;
      case 'automation':
        return NotificationCategory.automation;
      case 'update':
        return NotificationCategory.update;
      case 'energy':
        return NotificationCategory.energy;
      case 'security':
        return NotificationCategory.security;
      case 'matter':
        return NotificationCategory.matter;
      case 'system':
        return NotificationCategory.system;
      default:
        return NotificationCategory.alert;
    }
  }

  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.alert:
        return 'Alerts';
      case NotificationCategory.automation:
        return 'Automations';
      case NotificationCategory.update:
        return 'Updates';
      case NotificationCategory.energy:
        return 'Energy';
      case NotificationCategory.security:
        return 'Security';
      case NotificationCategory.matter:
        return 'Matter';
      case NotificationCategory.system:
        return 'System';
    }
  }
}

enum NotificationPriority {
  critical,
  high,
  normal,
  low;

  static NotificationPriority fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CRITICAL':
        return NotificationPriority.critical;
      case 'HIGH':
        return NotificationPriority.high;
      case 'NORMAL':
        return NotificationPriority.normal;
      case 'LOW':
      default:
        return NotificationPriority.low;
    }
  }
}

enum NotificationSeverity {
  info,
  notice,
  warning,
  error,
  critical;

  static NotificationSeverity fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CRITICAL':
        return NotificationSeverity.critical;
      case 'ERROR':
        return NotificationSeverity.error;
      case 'WARNING':
        return NotificationSeverity.warning;
      case 'NOTICE':
        return NotificationSeverity.notice;
      case 'INFO':
      default:
        return NotificationSeverity.info;
    }
  }

  String get label {
    switch (this) {
      case NotificationSeverity.critical:
        return 'CRITICAL';
      case NotificationSeverity.error:
        return 'ERROR';
      case NotificationSeverity.warning:
        return 'WARNING';
      case NotificationSeverity.notice:
        return 'NOTICE';
      case NotificationSeverity.info:
        return 'INFO';
    }
  }
}

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    this.userId,
    this.homeId,
    required this.type,
    required this.category,
    required this.priority,
    this.severity = NotificationSeverity.info,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.data = const {},
    this.readAt,
    this.deliveryStatus = 'DELIVERED',
    this.actionType,
    this.actionTarget,
    this.actionState = 'NONE',
    this.actionPrimary,
    this.actionSecondary,
    this.isAggregated = false,
    this.aggregatedCount = 1,
    this.aggregatedIds = const [],
    this.decisionMetadata = const {},
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? homeId;
  final NotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final NotificationSeverity severity;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final String deliveryStatus;
  final String? actionType;
  final String? actionTarget;
  final String? actionState;
  final String? actionPrimary;
  final String? actionSecondary;
  final bool isAggregated;
  final int aggregatedCount;
  final List<String> aggregatedIds;
  final Map<String, dynamic> decisionMetadata;
  final DateTime createdAt;

  bool get isRead => readAt != null;
  bool get isCritical => priority == NotificationPriority.critical || severity == NotificationSeverity.critical;
  bool get hasAction => actionType != null && actionType!.isNotEmpty && actionState != 'ACTIONED';

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
    userId: json['user_id'] as String? ?? json['userId'] as String?,
    homeId: json['home_id'] as String? ?? json['homeId'] as String?,
    type: NotificationType.fromString(json['type'] as String?),
    category: NotificationCategory.fromString(json['category'] as String?),
    priority: NotificationPriority.fromString(json['priority'] as String?),
    severity: NotificationSeverity.fromString(json['severity'] as String? ?? (json['priority'] as String?)),
    title: json['title'] as String? ?? 'Notification',
    body: json['body'] as String? ?? '',
    entityType: json['entity_type'] as String? ?? json['entityType'] as String?,
    entityId: json['entity_id'] as String? ?? json['entityId'] as String?,
    data: (json['data_json'] as Map<String, dynamic>?) ?? (json['data'] as Map<String, dynamic>?) ?? const {},
    readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : (json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null),
    deliveryStatus: json['delivery_status'] as String? ?? json['deliveryStatus'] as String? ?? 'DELIVERED',
    actionType: json['action_type'] as String? ?? json['actionType'] as String?,
    actionTarget: json['action_target'] as String? ?? json['actionTarget'] as String?,
    actionState: json['action_state'] as String? ?? json['actionState'] as String? ?? 'NONE',
    actionPrimary: json['action_primary'] as String? ?? json['actionPrimary'] as String?,
    actionSecondary: json['action_secondary'] as String? ?? json['actionSecondary'] as String?,
    isAggregated: json['is_aggregated'] as bool? ?? json['isAggregated'] as bool? ?? false,
    aggregatedCount: json['aggregated_count'] as int? ?? json['aggregatedCount'] as int? ?? 1,
    aggregatedIds: (json['aggregated_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? (json['aggregatedIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    decisionMetadata: (json['decision_metadata'] as Map<String, dynamic>?) ?? (json['decisionMetadata'] as Map<String, dynamic>?) ?? const {},
    createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()) : (json['createdAt'] != null ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()) : DateTime.now()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'userId': userId,
    if (homeId != null) 'homeId': homeId,
    'type': type.toDbString(),
    'category': category.name,
    'priority': priority.name.toUpperCase(),
    'severity': severity.name.toUpperCase(),
    'title': title,
    'body': body,
    if (entityType != null) 'entityType': entityType,
    if (entityId != null) 'entityId': entityId,
    'data': data,
    if (readAt != null) 'readAt': readAt!.toIso8601String(),
    'deliveryStatus': deliveryStatus,
    if (actionType != null) 'actionType': actionType,
    if (actionTarget != null) 'actionTarget': actionTarget,
    'actionState': actionState,
    if (actionPrimary != null) 'actionPrimary': actionPrimary,
    if (actionSecondary != null) 'actionSecondary': actionSecondary,
    'isAggregated': isAggregated,
    'aggregatedCount': aggregatedCount,
    'aggregatedIds': aggregatedIds,
    'decisionMetadata': decisionMetadata,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationItem copyWith({
    DateTime? readAt,
    String? deliveryStatus,
    String? actionState,
    bool? isAggregated,
    int? aggregatedCount,
    List<String>? aggregatedIds,
  }) => NotificationItem(
    id: id,
    userId: userId,
    homeId: homeId,
    type: type,
    category: category,
    priority: priority,
    severity: severity,
    title: title,
    body: body,
    entityType: entityType,
    entityId: entityId,
    data: data,
    readAt: readAt ?? this.readAt,
    deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    actionType: actionType,
    actionTarget: actionTarget,
    actionState: actionState ?? this.actionState,
    isAggregated: isAggregated ?? this.isAggregated,
    aggregatedCount: aggregatedCount ?? this.aggregatedCount,
    aggregatedIds: aggregatedIds ?? this.aggregatedIds,
    createdAt: createdAt,
  );
}

@immutable
class PushTokenInfo {
  const PushTokenInfo({
    required this.pushToken,
    this.platform = 'android',
    this.deviceName,
  });

  final String pushToken;
  final String platform;
  final String? deviceName;

  factory PushTokenInfo.fromJson(Map<String, dynamic> json) => PushTokenInfo(
    pushToken: json['pushToken'] as String? ?? json['push_token'] as String? ?? '',
    platform: json['platform'] as String? ?? 'android',
    deviceName: json['deviceName'] as String? ?? json['device_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'pushToken': pushToken,
    'platform': platform,
    if (deviceName != null) 'deviceName': deviceName,
  };
}

@immutable
class UserNotificationPreferences {
  const UserNotificationPreferences({
    required this.userId,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.inAppEnabled = true,
    this.criticalAlerts = true,
    this.deviceOffline = true,
    this.deviceHealth = true,
    this.automationFailure = true,
    this.firmwareUpdates = true,
    this.energyAlerts = true,
    this.securityAlerts = true,
    this.matterAlerts = true,
    this.memberAlerts = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
  });

  final String userId;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool inAppEnabled;
  final bool criticalAlerts;
  final bool deviceOffline;
  final bool deviceHealth;
  final bool automationFailure;
  final bool firmwareUpdates;
  final bool energyAlerts;
  final bool securityAlerts;
  final bool matterAlerts;
  final bool memberAlerts;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;

  factory UserNotificationPreferences.fromJson(Map<String, dynamic> json) => UserNotificationPreferences(
    userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
    pushEnabled: json['pushEnabled'] as bool? ?? json['push_enabled'] as bool? ?? true,
    emailEnabled: json['emailEnabled'] as bool? ?? json['email_enabled'] as bool? ?? false,
    inAppEnabled: json['inAppEnabled'] as bool? ?? json['in_app_enabled'] as bool? ?? true,
    criticalAlerts: json['criticalAlerts'] as bool? ?? json['critical_alerts'] as bool? ?? true,
    deviceOffline: json['deviceOffline'] as bool? ?? json['device_offline'] as bool? ?? true,
    deviceHealth: json['deviceHealth'] as bool? ?? json['device_health'] as bool? ?? true,
    automationFailure: json['automationFailure'] as bool? ?? json['automation_failure'] as bool? ?? true,
    firmwareUpdates: json['firmwareUpdates'] as bool? ?? json['firmware_updates'] as bool? ?? true,
    energyAlerts: json['energyAlerts'] as bool? ?? json['energy_alerts'] as bool? ?? true,
    securityAlerts: json['securityAlerts'] as bool? ?? json['security_alerts'] as bool? ?? true,
    matterAlerts: json['matterAlerts'] as bool? ?? json['matter_alerts'] as bool? ?? true,
    memberAlerts: json['memberAlerts'] as bool? ?? json['member_alerts'] as bool? ?? true,
    quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? json['quiet_hours_enabled'] as bool? ?? false,
    quietHoursStart: json['quietHoursStart'] as String? ?? json['quiet_hours_start'] as String? ?? '22:00',
    quietHoursEnd: json['quietHoursEnd'] as String? ?? json['quiet_hours_end'] as String? ?? '07:00',
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'pushEnabled': pushEnabled,
    'emailEnabled': emailEnabled,
    'inAppEnabled': inAppEnabled,
    'criticalAlerts': criticalAlerts,
    'deviceOffline': deviceOffline,
    'deviceHealth': deviceHealth,
    'automationFailure': automationFailure,
    'firmwareUpdates': firmwareUpdates,
    'energyAlerts': energyAlerts,
    'securityAlerts': securityAlerts,
    'matterAlerts': matterAlerts,
    'memberAlerts': memberAlerts,
    'quietHoursEnabled': quietHoursEnabled,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
  };
}

typedef NotificationPreferences = UserNotificationPreferences;
