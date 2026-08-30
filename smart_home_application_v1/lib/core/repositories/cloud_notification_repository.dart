import '../api/api_client.dart';
import '../models/notification_models.dart';
import 'notification_repository.dart';

class CloudNotificationRepository implements NotificationRepository {
  const CloudNotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<NotificationItem>> getNotifications({
    String? homeId,
    NotificationCategory? category,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      if (category != null && category != NotificationCategory.all) 'category': category.name,
      if (unreadOnly) 'unreadOnly': 'true',
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final path = queryString.isEmpty
        ? '/api/v1/notifications'
        : '/api/v1/notifications?$queryString';

    final response = await _apiClient.get(path);
    final list = response['data'] as List<dynamic>? ?? const [];
    return list
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getUnreadCount({String? homeId}) async {
    final path = (homeId != null && homeId.isNotEmpty)
        ? '/api/v1/notifications/unread-count?homeId=$homeId'
        : '/api/v1/notifications/unread-count';

    final response = await _apiClient.get(path);
    return response['unreadCount'] as int? ?? 0;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final response = await _apiClient.patch(
      '/api/v1/notifications/$notificationId/read',
      body: {},
    );
    return response['success'] as bool? ?? true;
  }

  @override
  Future<int> markAllAsRead({String? homeId}) async {
    final response = await _apiClient.post(
      '/api/v1/notifications/mark-all-read',
      body: {
        if (homeId != null && homeId.isNotEmpty) 'homeId': homeId,
      },
    );
    return response['markedCount'] as int? ?? 0;
  }

  @override
  Future<Map<String, bool>> getPreferences() async {
    final response = await _apiClient.get('/api/v1/notifications/preferences');
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return {
      'pushEnabled': data['push_enabled'] as bool? ?? data['pushEnabled'] as bool? ?? true,
      'criticalAlerts': data['critical_alerts'] as bool? ?? data['criticalAlerts'] as bool? ?? true,
      'deviceOffline': data['device_offline'] as bool? ?? data['deviceOffline'] as bool? ?? true,
      'automationFailure': data['automation_failure'] as bool? ?? data['automationFailure'] as bool? ?? true,
      'firmwareUpdates': data['firmware_updates'] as bool? ?? data['firmwareUpdates'] as bool? ?? true,
    };
  }

  @override
  Future<bool> updatePreferences(Map<String, bool> preferences) async {
    final response = await _apiClient.put(
      '/api/v1/notifications/preferences',
      body: {
        if (preferences.containsKey('pushEnabled')) 'push_enabled': preferences['pushEnabled'],
        if (preferences.containsKey('criticalAlerts')) 'critical_alerts': preferences['criticalAlerts'],
        if (preferences.containsKey('deviceOffline')) 'device_offline': preferences['deviceOffline'],
        if (preferences.containsKey('automationFailure')) 'automation_failure': preferences['automationFailure'],
        if (preferences.containsKey('firmwareUpdates')) 'firmware_updates': preferences['firmwareUpdates'],
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
