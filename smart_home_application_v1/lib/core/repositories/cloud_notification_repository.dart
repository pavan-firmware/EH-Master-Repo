import '../api/api_client.dart';
import '../models/notification_models.dart';
import 'notification_repository.dart';
import 'local_notification_repository.dart';

import '../services/device_storage_service.dart';

class CloudNotificationRepository implements NotificationRepository {
  const CloudNotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    NotificationSeverity? severity,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final localItems = await LocalNotificationRepository().getNotifications(
      homeId: homeId,
      category: category,
      severity: severity,
      limit: limit,
      offset: offset,
      unreadOnly: unreadOnly,
    );

    final deletedIds = DeviceStorageService.deletedNotificationIds;
    final readIds = DeviceStorageService.readNotificationIds;

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
        if (category != null && category != NotificationCategory.all) 'category': category.name,
        if (severity != null) 'severity': severity.name.toUpperCase(),
        if (unreadOnly) 'unreadOnly': 'true',
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final path = queryString.isEmpty
          ? '/api/v1/notifications'
          : '/api/v1/notifications?$queryString';

      final response = await _apiClient.get(path);
      final rawData = response['data'];
      final list = (rawData is List<dynamic>
              ? rawData
              : (rawData is Map<String, dynamic> ? (rawData['notifications'] as List<dynamic>?) : null)) ??
          (response['notifications'] as List<dynamic>?) ??
          const [];

      final merged = <NotificationItem>[...localItems];
      final seenIds = localItems.map((e) => e.id).toSet();
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          var item = NotificationItem.fromJson(e);
          if (deletedIds.contains(item.id)) continue;
          if (readIds.contains(item.id) && !item.isRead) {
            item = item.copyWith(readAt: DateTime.now());
          }
          if (seenIds.add(item.id)) {
            merged.add(item);
          }
        }
      }
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged.take(limit).toList();
    } catch (_) {
      return localItems;
    }
  }

  @override
  Future<int> getUnreadCount({String? homeId}) async {
    final localCount = await LocalNotificationRepository().getUnreadCount(homeId: homeId);
    try {
      final path = (homeId != null && homeId.isNotEmpty)
          ? '/api/v1/notifications/unread-count?homeId=$homeId'
          : '/api/v1/notifications/unread-count';

      final response = await _apiClient.get(path);
      final rawCount = response['unreadCount'] ??
          (response['data'] is Map<String, dynamic> ? response['data']['unreadCount'] : null);
      final count = rawCount as int? ?? 0;
      return count > localCount ? count : localCount;
    } catch (_) {
      return localCount;
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    await DeviceStorageService.markNotificationAsRead(notificationId);
    try {
      final response = await _apiClient.patch(
        '/api/v1/notifications/$notificationId/read',
        body: {},
      );
      return response['success'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<int> markAllAsRead({String? homeId}) async {
    await LocalNotificationRepository().markAllAsRead(homeId: homeId);
    try {
      final response = await _apiClient.post(
        '/api/v1/notifications/mark-all-read',
        body: {
          if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
        },
      );
      return response['markedCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<bool> deleteNotification(String notificationId) async {
    await LocalNotificationRepository().deleteNotification(notificationId);
    try {
      await _apiClient.delete('/api/v1/notifications/$notificationId');
    } catch (_) {}
    return true;
  }

  @override
  Future<int> deleteNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return 0;
    await LocalNotificationRepository().deleteNotifications(notificationIds);
    try {
      await _apiClient.post(
        '/api/v1/notifications/batch-delete',
        body: {'ids': notificationIds},
      );
    } catch (_) {}
    return notificationIds.length;
  }

  @override
  Future<int> clearAllNotifications({String? homeId}) async {
    final count = await LocalNotificationRepository().clearAllNotifications(homeId: homeId);
    try {
      await _apiClient.post(
        '/api/v1/notifications/clear-all',
        body: {
          if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
        },
      );
    } catch (_) {}
    return count;
  }

  @override
  Future<bool> performAction(
    String notificationId,
    String actionType, {
    Map<String, dynamic>? payload,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/notifications/$notificationId/action',
      body: {
        'actionType': actionType,
        'payload': ?payload,
      },
    );
    return response['success'] as bool? ?? true;
  }

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    final response = await _apiClient.get('/api/v1/notifications/preferences');
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return {
      'pushEnabled': data['push_enabled'] as bool? ?? data['pushEnabled'] as bool? ?? true,
      'emailEnabled': data['email_enabled'] as bool? ?? data['emailEnabled'] as bool? ?? false,
      'inAppEnabled': data['in_app_enabled'] as bool? ?? data['inAppEnabled'] as bool? ?? true,
      'criticalAlerts': data['critical_alerts'] as bool? ?? data['criticalAlerts'] as bool? ?? true,
      'deviceOffline': data['device_offline'] as bool? ?? data['deviceOffline'] as bool? ?? true,
      'deviceHealth': data['device_health'] as bool? ?? data['deviceHealth'] as bool? ?? true,
      'automationFailure': data['automation_failure'] as bool? ?? data['automationFailure'] as bool? ?? true,
      'firmwareUpdates': data['firmware_updates'] as bool? ?? data['firmwareUpdates'] as bool? ?? true,
      'energyAlerts': data['energy_alerts'] as bool? ?? data['energyAlerts'] as bool? ?? true,
      'securityAlerts': data['security_alerts'] as bool? ?? data['securityAlerts'] as bool? ?? true,
      'matterAlerts': data['matter_alerts'] as bool? ?? data['matterAlerts'] as bool? ?? true,
      'memberAlerts': data['member_alerts'] as bool? ?? data['memberAlerts'] as bool? ?? true,
      'quietHoursEnabled': data['quiet_hours_enabled'] as bool? ?? data['quietHoursEnabled'] as bool? ?? false,
      'quietHoursStart': data['quiet_hours_start'] as String? ?? data['quietHoursStart'] as String? ?? '22:00',
      'quietHoursEnd': data['quiet_hours_end'] as String? ?? data['quietHoursEnd'] as String? ?? '07:00',
    };
  }

  @override
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    final response = await _apiClient.put(
      '/api/v1/notifications/preferences',
      body: {
        if (preferences.containsKey('pushEnabled')) 'push_enabled': preferences['pushEnabled'],
        if (preferences.containsKey('emailEnabled')) 'email_enabled': preferences['emailEnabled'],
        if (preferences.containsKey('inAppEnabled')) 'in_app_enabled': preferences['inAppEnabled'],
        if (preferences.containsKey('criticalAlerts')) 'critical_alerts': preferences['criticalAlerts'],
        if (preferences.containsKey('deviceOffline')) 'device_offline': preferences['deviceOffline'],
        if (preferences.containsKey('deviceHealth')) 'device_health': preferences['deviceHealth'],
        if (preferences.containsKey('automationFailure')) 'automation_failure': preferences['automationFailure'],
        if (preferences.containsKey('firmwareUpdates')) 'firmware_updates': preferences['firmwareUpdates'],
        if (preferences.containsKey('energyAlerts')) 'energy_alerts': preferences['energyAlerts'],
        if (preferences.containsKey('securityAlerts')) 'security_alerts': preferences['securityAlerts'],
        if (preferences.containsKey('matterAlerts')) 'matter_alerts': preferences['matterAlerts'],
        if (preferences.containsKey('memberAlerts')) 'member_alerts': preferences['memberAlerts'],
        if (preferences.containsKey('quietHoursEnabled')) 'quiet_hours_enabled': preferences['quietHoursEnabled'],
        if (preferences.containsKey('quietHoursStart')) 'quiet_hours_start': preferences['quietHoursStart'],
        if (preferences.containsKey('quietHoursEnd')) 'quiet_hours_end': preferences['quietHoursEnd'],
      },
    );
    return response['success'] as bool? ?? true;
  }

  @override
  Future<bool> registerPushToken(
    String token, {
    String platform = 'android',
    String? deviceName,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/notifications/push-tokens',
      body: {
        'pushToken': token,
        'platform': platform,
        'deviceName': ?deviceName,
      },
    );
    return response['success'] as bool? ?? true;
  }

  @override
  Future<bool> removePushToken(String token) async {
    final encodedToken = Uri.encodeComponent(token);
    final response = await _apiClient.delete(
      '/api/v1/notifications/push-tokens/$encodedToken',
    );
    return response['success'] as bool? ?? true;
  }
}
