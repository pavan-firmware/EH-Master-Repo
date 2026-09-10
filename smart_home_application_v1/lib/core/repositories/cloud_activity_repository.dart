import '../api/api_client.dart';
import '../models/activity_models.dart';

class CloudActivityRepository implements ActivityRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudActivityRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
      return _activeHomeId;
    }
    try {
      final res = await _apiClient.get('/api/v1/homes');
      List<dynamic>? list;
      if (res is List) {
        list = res;
      } else if (res is Map && res['data'] is List) {
        list = res['data'] as List<dynamic>;
      }
      if (list != null && list.isNotEmpty) {
        final first = list.first;
        if (first is Map && first['id'] != null) {
          _activeHomeId = first['id'].toString();
          return _activeHomeId;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<ActivityEventPage> getEvents(ActivityQuery query) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) {
      return ActivityEventPage(
        events: const [],
        nextCursor: null,
        lastSyncedAt: DateTime.now(),
        isCached: false,
      );
    }

    try {
      final res = await _apiClient.get('/api/v1/notifications?homeId=$homeId');
      final List<ActivityEvent> events = [];

      List rawList = [];
      if (res is Map && res['notifications'] is List) {
        rawList = res['notifications'] as List;
      } else if (res is List) {
        rawList = res;
      }

      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          events.add(_mapToEvent(item));
        }
      }

      // If search query is applied
      final filtered = events.where((e) {
        if (query.search.isEmpty) return true;
        final q = query.search.toLowerCase();
        return e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q);
      }).toList();

      return ActivityEventPage(
        events: filtered,
        nextCursor: null,
        lastSyncedAt: DateTime.now(),
        isCached: false,
      );
    } catch (_) {
      return ActivityEventPage(
        events: const [],
        nextCursor: null,
        lastSyncedAt: DateTime.now(),
        isCached: false,
      );
    }
  }

  @override
  Future<ActivityEvent?> getEvent(String id) async {
    final page = await getEvents(const ActivityQuery());
    final matches = page.events.where((e) => e.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<ActivityEventPage> getEventsByRoom(String roomId, ActivityQuery query) async {
    final page = await getEvents(query);
    final roomEvents = page.events.where((e) => e.roomId == roomId).toList();
    return ActivityEventPage(
      events: roomEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  @override
  Future<ActivityEventPage> getEventsByDevice(String deviceId, ActivityQuery query) async {
    final page = await getEvents(query);
    final devEvents = page.events.where((e) => e.deviceId == deviceId).toList();
    return ActivityEventPage(
      events: devEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  @override
  Future<ActivityEventPage> getEventsByRoutine(String routineId, ActivityQuery query) async {
    final page = await getEvents(query);
    final routineEvents = page.events.where((e) => e.routineId == routineId).toList();
    return ActivityEventPage(
      events: routineEvents,
      nextCursor: null,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  ActivityEvent _mapToEvent(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? 'evt_${DateTime.now().millisecondsSinceEpoch}';
    final title = map['title']?.toString() ?? 'Activity';
    final message = map['message']?.toString() ?? map['body']?.toString() ?? '';
    final severityStr = (map['severity'] ?? 'INFO').toString().toUpperCase();

    ActivitySeverity severity = ActivitySeverity.info;
    if (severityStr == 'WARNING') severity = ActivitySeverity.warning;
    if (severityStr == 'CRITICAL' || severityStr == 'ERROR') severity = ActivitySeverity.critical;
    if (severityStr == 'SUCCESS') severity = ActivitySeverity.success;

    final createdAt = map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final typeStr = (map['type'] ?? 'DEVICE_STATE').toString().toUpperCase();
    ActivityEventType type = ActivityEventType.deviceStateChanged;
    if (typeStr == 'ALERT' || typeStr == 'SAFETY_ALERT') {
      type = ActivityEventType.safetyAlert;
    } else if (typeStr == 'WARNING' || typeStr == 'DEVICE_WARNING') {
      type = ActivityEventType.deviceWarning;
    } else if (typeStr == 'ROUTINE_COMPLETED') {
      type = ActivityEventType.routineCompleted;
    } else if (typeStr == 'ROUTINE_FAILED') {
      type = ActivityEventType.routineFailed;
    } else if (typeStr == 'SYSTEM_UPDATE') {
      type = ActivityEventType.systemUpdate;
    }

    return ActivityEvent(
      id: id,
      type: type,
      severity: severity,
      source: ActivitySource.system,
      title: title,
      description: message,
      timestamp: createdAt,
      eventTimezone: 'UTC',
      eventData: const {},
      navigationTarget: const ActivityNavigationTarget.none(),
      roomId: map['room_id']?.toString(),
      deviceId: map['device_id']?.toString(),
    );
  }
}

class CloudActivityDeviceRepository implements ActivityDeviceRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudActivityDeviceRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  @override
  Future<ActivityDeviceSnapshot?> getDevice(String id) async {
    if (_activeHomeId == null || _activeHomeId!.isEmpty) return null;
    try {
      final res = await _apiClient.get('/api/v1/homes/$_activeHomeId/devices/$id');
      if (res is Map<String, dynamic>) {
        final name = res['displayName'] ?? res['label'] ?? res['customName'] ?? 'Smart Device';
        final room = res['roomName'] ?? 'Home';
        final isOnline = res['connectionState'] == 'ONLINE';

        return ActivityDeviceSnapshot(
          id: id,
          name: name.toString(),
          room: room.toString(),
          connection: isOnline ? ActivityDeviceConnection.online : ActivityDeviceConnection.offline,
          lastSeen: DateTime.now(),
          lastReading: isOnline ? 'Active' : 'Offline',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
