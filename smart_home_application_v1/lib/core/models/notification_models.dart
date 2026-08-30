import 'package:flutter/foundation.dart';

enum NotificationType {
  deviceOffline,
  deviceRecovered,
  commandFailed,
  automationFailed,
  sceneFailed,
  scheduleFailed,
  otaAvailable,
  otaFailed,
  securityEvent,
  systemEvent;

  static NotificationType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'DEVICE_OFFLINE':
        return NotificationType.deviceOffline;
      case 'DEVICE_RECOVERED':
        return NotificationType.deviceRecovered;
      case 'COMMAND_FAILED':
        return NotificationType.commandFailed;
      case 'AUTOMATION_FAILED':
        return NotificationType.automationFailed;
      case 'SCENE_FAILED':
        return NotificationType.sceneFailed;
      case 'SCHEDULE_FAILED':
        return NotificationType.scheduleFailed;
      case 'OTA_AVAILABLE':
        return NotificationType.otaAvailable;
      case 'OTA_FAILED':
        return NotificationType.otaFailed;
      case 'SECURITY_EVENT':
        return NotificationType.securityEvent;
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
      case NotificationType.commandFailed:
        return 'COMMAND_FAILED';
      case NotificationType.automationFailed:
        return 'AUTOMATION_FAILED';
      case NotificationType.sceneFailed:
        return 'SCENE_FAILED';
      case NotificationType.scheduleFailed:
        return 'SCHEDULE_FAILED';
      case NotificationType.otaAvailable:
        return 'OTA_AVAILABLE';
      case NotificationType.otaFailed:
        return 'OTA_FAILED';
      case NotificationType.securityEvent:
        return 'SECURITY_EVENT';
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
  security,
  system;

  static NotificationCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'alert':
        return NotificationCategory.alert;
      case 'automation':
        return NotificationCategory.automation;
      case 'update':
        return NotificationCategory.update;
      case 'security':
        return NotificationCategory.security;
      case 'system':
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
      case NotificationCategory.security:
        return 'Security';
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

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    this.userId,
    this.homeId,
    required this.type,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.data = const {},
    this.readAt,
    this.deliveryStatus = 'DELIVERED',
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? homeId;
  final NotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final String deliveryStatus;
  final DateTime createdAt;

  bool get isRead => readAt != null;
  bool get isCritical => priority == NotificationPriority.critical;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
    userId: json['user_id'] as String? ?? json['userId'] as String?,
    homeId: json['home_id'] as String? ?? json['homeId'] as String?,
    type: NotificationType.fromString(json['type'] as String?),
    category: NotificationCategory.fromString(json['category'] as String?),
    priority: NotificationPriority.fromString(json['priority'] as String?),
    title: json['title'] as String? ?? 'Notification',
    body: json['body'] as String? ?? '',
    entityType: json['entity_type'] as String? ?? json['entityType'] as String?,
    entityId: json['entity_id'] as String? ?? json['entityId'] as String?,
    data: (json['data_json'] as Map<String, dynamic>?) ?? (json['data'] as Map<String, dynamic>?) ?? const {},
    readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : (json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null),
    deliveryStatus: json['delivery_status'] as String? ?? json['deliveryStatus'] as String? ?? 'DELIVERED',
    createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()) : (json['createdAt'] != null ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()) : DateTime.now()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'userId': userId,
    if (homeId != null) 'homeId': homeId,
    'type': type.toDbString(),
    'category': category.name,
    'priority': priority.name.toUpperCase(),
    'title': title,
    'body': body,
    if (entityType != null) 'entityType': entityType,
    if (entityId != null) 'entityId': entityId,
    'data': data,
    if (readAt != null) 'readAt': readAt!.toIso8601String(),
    'deliveryStatus': deliveryStatus,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationItem copyWith({
    DateTime? readAt,
    String? deliveryStatus,
  }) => NotificationItem(
    id: id,
    userId: userId,
    homeId: homeId,
    type: type,
    category: category,
    priority: priority,
    title: title,
    body: body,
    entityType: entityType,
    entityId: entityId,
    data: data,
    readAt: readAt ?? this.readAt,
    deliveryStatus: deliveryStatus ?? this.deliveryStatus,
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
