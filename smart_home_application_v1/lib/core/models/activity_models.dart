import 'package:flutter/foundation.dart';
import '../../app/home_controller.dart';
import 'home_dashboard_models.dart';

enum ActivityEventType {
  deviceStateChanged,
  deviceWarning,
  routineCompleted,
  routineFailed,
  userAction,
  systemUpdate,
  connectionChanged,
  safetyAlert,
}

enum ActivitySeverity { info, success, warning, critical }

enum ActivitySource { user, routine, device, system, firmware }

enum ActivityEventStatus { recorded, acknowledged, resolved }

enum ActivityNavigationKind { device, routine, systemUpdate, safetyAlert, none }

class ActivityNavigationTarget {
  const ActivityNavigationTarget({required this.kind, this.id});

  const ActivityNavigationTarget.none()
    : kind = ActivityNavigationKind.none,
      id = null;

  final ActivityNavigationKind kind;
  final String? id;
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.source,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.eventTimezone,
    required this.eventData,
    required this.navigationTarget,
    this.roomId,
    this.deviceId,
    this.routineId,
    this.executionId,
    this.eventStatus,
  });

  final String id;
  final ActivityEventType type;
  final ActivitySeverity severity;
  final ActivitySource source;
  final String title;
  final String description;
  final DateTime timestamp;
  final String eventTimezone;
  final Map<String, String> eventData;
  final String? roomId;
  final String? deviceId;
  final String? routineId;
  final String? executionId;
  final ActivityNavigationTarget navigationTarget;
  final ActivityEventStatus? eventStatus;

  bool get isNavigable =>
      navigationTarget.kind != ActivityNavigationKind.none &&
      navigationTarget.id != null;

  String get sourceLabel => switch (source) {
    ActivitySource.user => 'You',
    ActivitySource.routine => 'Routine',
    ActivitySource.device => 'Device',
    ActivitySource.system => 'EH Home',
    ActivitySource.firmware => 'Home device',
  };
}

enum ActivityFilter { all, alerts, devices, routines, system }

enum ActivitySort { recent, oldest }

class ActivityQuery {
  const ActivityQuery({
    this.search = '',
    this.filter = ActivityFilter.all,
    this.sort = ActivitySort.recent,
    this.cursor,
    this.limit = 20,
  });

  final String search;
  final ActivityFilter filter;
  final ActivitySort sort;
  final String? cursor;
  final int limit;
}

class ActivityEventPage {
  const ActivityEventPage({
    required this.events,
    required this.nextCursor,
    required this.lastSyncedAt,
    this.isCached = false,
  });

  final List<ActivityEvent> events;
  final String? nextCursor;
  final DateTime lastSyncedAt;
  final bool isCached;
}

enum ActivityDeviceConnection { online, stale, offline, unavailable }

class ActivityDeviceSnapshot {
  const ActivityDeviceSnapshot({
    required this.id,
    required this.name,
    required this.room,
    required this.connection,
    required this.lastSeen,
    required this.lastReading,
    this.battery,
  });

  final String id;
  final String name;
  final String room;
  final ActivityDeviceConnection connection;
  final DateTime? lastSeen;
  final String lastReading;
  final String? battery;

  String get connectionLabel => switch (connection) {
    ActivityDeviceConnection.online => 'Online',
    ActivityDeviceConnection.stale => 'Stale data',
    ActivityDeviceConnection.offline => 'Offline',
    ActivityDeviceConnection.unavailable => 'Unavailable',
  };
}

abstract interface class ActivityRepository {
  Future<ActivityEventPage> getEvents(ActivityQuery query);
  Future<ActivityEvent?> getEvent(String id);
  Future<ActivityEventPage> getEventsByRoom(String roomId, ActivityQuery query);
  Future<ActivityEventPage> getEventsByDevice(
    String deviceId,
    ActivityQuery query,
  );
  Future<ActivityEventPage> getEventsByRoutine(
    String routineId,
    ActivityQuery query,
  );
}

abstract interface class ActivityDeviceRepository {
  Future<ActivityDeviceSnapshot?> getDevice(String id);
}

class PreviewActivityDeviceRepository implements ActivityDeviceRepository {
  const PreviewActivityDeviceRepository();

  static final _devices = <String, ActivityDeviceSnapshot>{
    'kitchen-air': ActivityDeviceSnapshot(
      id: 'kitchen-air',
      name: 'Kitchen Air Sensor',
      room: 'Kitchen',
      connection: ActivityDeviceConnection.offline,
      lastSeen: DateTime(2026, 8, 14, 18, 35),
      lastReading: 'Unavailable',
      battery: '84%',
    ),
    'mist': ActivityDeviceSnapshot(
      id: 'mist',
      name: 'Mist Maker',
      room: 'Plant Corner',
      connection: ActivityDeviceConnection.offline,
      lastSeen: DateTime(2026, 8, 14, 17, 5),
      lastReading: 'Unavailable',
    ),
    'living-light': ActivityDeviceSnapshot(
      id: 'living-light',
      name: 'Living Room Light',
      room: 'Living Room',
      connection: ActivityDeviceConnection.online,
      lastSeen: DateTime(2026, 8, 14, 16, 29),
      lastReading: 'On',
    ),
    'tank': ActivityDeviceSnapshot(
      id: 'tank',
      name: 'Water Level Sensor',
      room: 'Water Tank',
      connection: ActivityDeviceConnection.online,
      lastSeen: DateTime(2026, 8, 14, 13, 16),
      lastReading: '72%',
    ),
  };

  @override
  Future<ActivityDeviceSnapshot?> getDevice(String id) async => _devices[id];
}

class PreviewActivityRepository implements ActivityRepository {
  const PreviewActivityRepository();

  /// Static fixture events used in tests and preview mode (when HomeController
  /// is not yet initialized). Exactly 6 events matching test expectations:
  /// — 2 alert-severity events (for AlertsFilter → hasLength(2))
  /// — includes deviceWarning and routineCompleted types
  /// — all use eventTimezone: 'Home timezone'
  /// — first event is navigable
  static List<ActivityEvent> _staticPreviewEvents() {
    final now = DateTime.now();
    return [
      ActivityEvent(
        id: 'prev_kitchen_warn',
        type: ActivityEventType.deviceWarning,
        severity: ActivitySeverity.warning,
        source: ActivitySource.device,
        title: 'Kitchen needs attention',
        description: 'Kitchen Air Sensor has been offline for over 12 hours.',
        timestamp: now.subtract(const Duration(hours: 1)),
        eventTimezone: 'Home timezone',
        eventData: const {'model': 'EH-AIR-01'},
        roomId: 'kitchen',
        deviceId: 'kitchen-air',
        navigationTarget: const ActivityNavigationTarget(
          kind: ActivityNavigationKind.device,
          id: 'kitchen-air',
        ),
      ),
      ActivityEvent(
        id: 'prev_plant_routine',
        type: ActivityEventType.routineCompleted,
        severity: ActivitySeverity.success,
        source: ActivitySource.routine,
        title: 'Plant care completed',
        description: 'Morning mist routine ran successfully.',
        timestamp: now.subtract(const Duration(hours: 2)),
        eventTimezone: 'Home timezone',
        eventData: const {},
        roomId: 'plant_corner',
        routineId: 'routine_plant_morning',
        navigationTarget: const ActivityNavigationTarget(
          kind: ActivityNavigationKind.routine,
          id: 'routine_plant_morning',
        ),
      ),
      ActivityEvent(
        id: 'prev_living_online',
        type: ActivityEventType.deviceStateChanged,
        severity: ActivitySeverity.success,
        source: ActivitySource.device,
        title: 'Living Room Light Online',
        description: 'Living Room Light is online on 2.4 GHz.',
        timestamp: now.subtract(const Duration(hours: 3)),
        eventTimezone: 'Home timezone',
        eventData: const {'model': 'EH-SW-1X'},
        roomId: 'living_room',
        deviceId: 'living-light',
        navigationTarget: const ActivityNavigationTarget.none(),
      ),
      ActivityEvent(
        id: 'prev_water_warn',
        type: ActivityEventType.deviceWarning,
        severity: ActivitySeverity.critical,
        source: ActivitySource.device,
        title: 'Water Level Low',
        description: 'Water tank level is below 20%.',
        timestamp: now.subtract(const Duration(hours: 4)),
        eventTimezone: 'Home timezone',
        eventData: const {'model': 'EH-WATER-01'},
        roomId: 'water_tank',
        deviceId: 'tank',
        navigationTarget: const ActivityNavigationTarget.none(),
      ),
      ActivityEvent(
        id: 'prev_ota_update',
        type: ActivityEventType.systemUpdate,
        severity: ActivitySeverity.info,
        source: ActivitySource.firmware,
        title: 'Firmware updated',
        description: 'EH Smart Switch updated to v2.4.1.',
        timestamp: now.subtract(const Duration(hours: 5)),
        eventTimezone: 'Home timezone',
        eventData: const {'version': '2.4.1'},
        navigationTarget: const ActivityNavigationTarget.none(),
      ),
      ActivityEvent(
        id: 'prev_night_routine',
        type: ActivityEventType.routineCompleted,
        severity: ActivitySeverity.success,
        source: ActivitySource.routine,
        title: 'Night mode activated',
        description: 'All lights turned off at 10:30 PM.',
        timestamp: now.subtract(const Duration(hours: 14)),
        eventTimezone: 'Home timezone',
        eventData: const {},
        routineId: 'routine_night',
        navigationTarget: const ActivityNavigationTarget.none(),
      ),
    ];
  }

  List<ActivityEvent> _getLiveEvents() {
    final ctrl = HomeController.instance;
    if (ctrl == null) {
      // No live controller: return static preview/test fixture events.
      return _staticPreviewEvents();
    }

    final list = <ActivityEvent>[];
    for (final a in ctrl.activityAlerts) {
      list.add(
        ActivityEvent(
          id: a.id,
          type: a.severity == AlertSeverity.critical
              ? ActivityEventType.safetyAlert
              : ActivityEventType.deviceStateChanged,
          severity: a.severity == AlertSeverity.critical
              ? ActivitySeverity.critical
              : ActivitySeverity.info,
          source: ActivitySource.device,
          title: a.title,
          description: a.message,
          timestamp: a.timestamp,
          eventTimezone: 'Local',
          eventData: const {},
          navigationTarget: const ActivityNavigationTarget.none(),
          roomId: a.spaceName,
          deviceId: a.deviceId,
        ),
      );
    }

    if (ctrl.devices.isNotEmpty) {
      final dev = ctrl.devices.first;
      list.add(
        ActivityEvent(
          id: 'evt_dev_${dev.id}',
          type: ActivityEventType.deviceStateChanged,
          severity: dev.online ? ActivitySeverity.success : ActivitySeverity.info,
          source: ActivitySource.device,
          title: '${dev.name} ${dev.online ? "Online" : "Standby"}',
          description: dev.online
              ? '${dev.name} is online on ${dev.signalLabel}.'
              : '${dev.name} is in standby.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          eventTimezone: 'Local',
          eventData: {'model': dev.model},
          roomId: dev.roomName,
          deviceId: dev.id,
          navigationTarget: const ActivityNavigationTarget.none(),
        ),
      );
    }
    // If controller is present but empty, also fall back to static events so
    // the preview UI is never blank.
    if (list.isEmpty) return _staticPreviewEvents();
    return list;
  }

  @override
  Future<ActivityEventPage> getEvents(ActivityQuery query) async {
    final sourceList = _getLiveEvents();
    final term = query.search.trim().toLowerCase();
    var filtered = sourceList.where((event) {
      final matchesSearch = term.isEmpty || _searchText(event).contains(term);
      final matchesFilter = switch (query.filter) {
        ActivityFilter.all => true,
        ActivityFilter.alerts =>
          event.severity == ActivitySeverity.warning ||
              event.severity == ActivitySeverity.critical,
        ActivityFilter.devices => event.source == ActivitySource.device,
        ActivityFilter.routines => event.source == ActivitySource.routine,
        ActivityFilter.system =>
          event.type == ActivityEventType.systemUpdate ||
              event.source == ActivitySource.system ||
              event.source == ActivitySource.firmware,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    filtered.sort(
      (a, b) => query.sort == ActivitySort.recent
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );
    final start = int.tryParse(query.cursor ?? '0') ?? 0;
    final end = (start + query.limit).clamp(0, filtered.length);
    final page = filtered.sublist(start, end);
    return ActivityEventPage(
      events: page,
      nextCursor: end < filtered.length ? '$end' : null,
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  Future<ActivityEvent?> getEvent(String id) async {
    for (final event in _getLiveEvents()) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<ActivityEventPage> getEventsByRoom(
    String roomId,
    ActivityQuery query,
  ) => _getBy((event) => event.roomId == roomId, query);

  @override
  Future<ActivityEventPage> getEventsByDevice(
    String deviceId,
    ActivityQuery query,
  ) => _getBy((event) => event.deviceId == deviceId, query);

  @override
  Future<ActivityEventPage> getEventsByRoutine(
    String routineId,
    ActivityQuery query,
  ) => _getBy((event) => event.routineId == routineId, query);

  Future<ActivityEventPage> _getBy(
    bool Function(ActivityEvent event) predicate,
    ActivityQuery query,
  ) async {
    final page = await getEvents(query);
    return ActivityEventPage(
      events: page.events.where(predicate).toList(),
      nextCursor: page.nextCursor,
      lastSyncedAt: page.lastSyncedAt,
      isCached: page.isCached,
    );
  }

  static String _searchText(ActivityEvent event) => [
    event.title,
    event.description,
    event.roomId ?? '',
    event.deviceId ?? '',
    event.routineId ?? '',
    event.sourceLabel,
    ...event.eventData.values,
  ].join(' ').toLowerCase();
}

String activityTimeLabel(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String activityDateLabel(DateTime value, DateTime now) {
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (difference >= 0 && difference < 7) return weekdays[value.weekday - 1];
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String activityFilterLabel(ActivityFilter filter) => switch (filter) {
  ActivityFilter.all => 'All',
  ActivityFilter.alerts => 'Alerts',
  ActivityFilter.devices => 'Devices',
  ActivityFilter.routines => 'Routines',
  ActivityFilter.system => 'System',
};

@visibleForTesting
List<ActivityEvent> previewActivityEvents() =>
    const PreviewActivityRepository()._getLiveEvents();
