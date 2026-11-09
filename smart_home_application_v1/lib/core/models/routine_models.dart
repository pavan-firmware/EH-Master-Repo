import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/home_controller.dart';
import '../models/connection_models.dart';
import '../services/device_storage_service.dart';
import '../services/edge_routine_sync_service.dart';
import '../services/change_tracking_service.dart';
import '../../features/hub/data/hub_repository.dart';

enum RoutineAvailability { available, partiallyAvailable, unavailable }

enum RoutineExecutionResult { succeeded, failed }

enum RoutineValidationState {
  valid,
  incomplete,
  invalid,
  conflict,
  unsupported,
}

enum RoutineTriggerKind {
  timeSchedule,
  sunset,
  sunrise,
  soilMoisture,
  waterLevel,
  temperature,
  humidity,
  ambientLight,
  motion,
  deviceState,
  powerThreshold,
  manual,
}

enum RoutineActionKind {
  mistMaker,
  light,
  notification,
  switchChannel,
  allChannels,
}

class DeviceCapabilityInfo {
  const DeviceCapabilityInfo({
    required this.id,
    required this.type,
    required this.readable,
    required this.writable,
    required this.operations,
  });

  final String id;
  final String type;
  final bool readable;
  final bool writable;
  final List<String> operations;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'readable': readable,
    'writable': writable,
    'operations': operations,
  };

  factory DeviceCapabilityInfo.fromJson(Map<String, dynamic> json) => DeviceCapabilityInfo(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? '',
    readable: json['readable'] as bool? ?? false,
    writable: json['writable'] as bool? ?? false,
    operations: (json['operations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class RoutineDevice {
  const RoutineDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.online,
    required this.capabilities,
  });

  final String id;
  final String name;
  final String room;
  final bool online;
  final List<DeviceCapabilityInfo> capabilities;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'room': room,
    'online': online,
    'capabilities': capabilities.map((c) => c.toJson()).toList(),
  };

  factory RoutineDevice.fromJson(Map<String, dynamic> json) => RoutineDevice(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    room: json['room'] as String? ?? '',
    online: json['online'] as bool? ?? true,
    capabilities: (json['capabilities'] as List<dynamic>?)
            ?.map((e) => DeviceCapabilityInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class RoutineTrigger {
  const RoutineTrigger({
    required this.kind,
    required this.title,
    required this.detail,
    this.threshold,
    this.operator = '<',
    this.unit = '',
    this.timeOfDay,
    this.days = const [],
    this.sourceDeviceId,
    this.sourceChannelIndex,
  });

  final RoutineTriggerKind kind;
  final String title;
  final String detail;
  final double? threshold;
  final String operator;
  final String unit;
  final String? timeOfDay;
  final List<String> days;
  final String? sourceDeviceId;
  final int? sourceChannelIndex;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'detail': detail,
    'threshold': threshold,
    'operator': operator,
    'unit': unit,
    'timeOfDay': timeOfDay,
    'days': days,
    'sourceDeviceId': sourceDeviceId,
    'sourceChannelIndex': sourceChannelIndex,
  };

  factory RoutineTrigger.fromJson(Map<String, dynamic> json) => RoutineTrigger(
    kind: RoutineTriggerKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => RoutineTriggerKind.timeSchedule,
    ),
    title: json['title'] as String? ?? 'Scheduled Trigger',
    detail: json['detail'] as String? ?? '',
    threshold: (json['threshold'] as num?)?.toDouble(),
    operator: json['operator'] as String? ?? '<',
    unit: json['unit'] as String? ?? '',
    timeOfDay: json['timeOfDay'] as String?,
    days: (json['days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    sourceDeviceId: json['sourceDeviceId'] as String?,
    sourceChannelIndex: (json['sourceChannelIndex'] as num?)?.toInt(),
  );
}

class RoutineCondition {
  const RoutineCondition({required this.title, required this.detail});
  final String title;
  final String detail;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
  };

  factory RoutineCondition.fromJson(Map<String, dynamic> json) => RoutineCondition(
    title: json['title'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
  );
}

class RoutineAction {
  const RoutineAction({
    required this.kind,
    required this.title,
    required this.detail,
    required this.deviceId,
    this.channelIndex = 1,
    this.targetState = true,
    this.isToggle = false,
    this.pulseDurationMinutes,
    this.delaySeconds,
    this.targetRoomName,
  });

  final RoutineActionKind kind;
  final String title;
  final String detail;
  final String deviceId;
  final int channelIndex;
  final bool targetState;
  final bool isToggle;
  final int? pulseDurationMinutes;
  final int? delaySeconds;
  final String? targetRoomName;

  RoutineAction copyWith({
    RoutineActionKind? kind,
    String? title,
    String? detail,
    String? deviceId,
    int? channelIndex,
    bool? targetState,
    bool? isToggle,
    int? pulseDurationMinutes,
    int? delaySeconds,
    String? targetRoomName,
  }) => RoutineAction(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    detail: detail ?? this.detail,
    deviceId: deviceId ?? this.deviceId,
    channelIndex: channelIndex ?? this.channelIndex,
    targetState: targetState ?? this.targetState,
    isToggle: isToggle ?? this.isToggle,
    pulseDurationMinutes: pulseDurationMinutes ?? this.pulseDurationMinutes,
    delaySeconds: delaySeconds ?? this.delaySeconds,
    targetRoomName: targetRoomName ?? this.targetRoomName,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'detail': detail,
    'deviceId': deviceId,
    'channelIndex': channelIndex,
    'targetState': targetState,
    'isToggle': isToggle,
    if (pulseDurationMinutes != null) 'pulseDurationMinutes': pulseDurationMinutes,
    if (delaySeconds != null) 'delaySeconds': delaySeconds,
    if (targetRoomName != null) 'targetRoomName': targetRoomName,
  };

  factory RoutineAction.fromJson(Map<String, dynamic> json) => RoutineAction(
    kind: RoutineActionKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => RoutineActionKind.switchChannel,
    ),
    title: json['title'] as String? ?? 'Device Action',
    detail: json['detail'] as String? ?? '',
    deviceId: json['deviceId'] as String? ?? '',
    channelIndex: (json['channelIndex'] as num?)?.toInt() ?? 1,
    targetState: json['targetState'] as bool? ?? true,
    isToggle: json['isToggle'] as bool? ?? false,
    pulseDurationMinutes: (json['pulseDurationMinutes'] as num?)?.toInt(),
    delaySeconds: (json['delaySeconds'] as num?)?.toInt(),
    targetRoomName: json['targetRoomName'] as String?,
  );
}

class RoutineSchedule {
  const RoutineSchedule({
    required this.label,
    required this.timezone,
    this.days = const [],
  });

  final String label;
  final String timezone;
  final List<String> days;

  Map<String, dynamic> toJson() => {
    'label': label,
    'timezone': timezone,
    'days': days,
  };

  factory RoutineSchedule.fromJson(Map<String, dynamic> json) => RoutineSchedule(
    label: json['label'] as String? ?? 'Daily',
    timezone: json['timezone'] as String? ?? 'Home timezone',
    days: (json['days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class RoutineExecution {
  const RoutineExecution({
    required this.id,
    required this.routineId,
    required this.startedAt,
    required this.completedAt,
    required this.result,
    required this.message,
    this.failureReason,
    this.affectedDevices = const [],
  });

  final String id;
  final String routineId;
  final DateTime startedAt;
  final DateTime completedAt;
  final RoutineExecutionResult result;
  final String message;
  final String? failureReason;
  final List<String> affectedDevices;

  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'result': result.name,
    'message': message,
    'failureReason': failureReason,
    'affectedDevices': affectedDevices,
  };

  factory RoutineExecution.fromJson(Map<String, dynamic> json) => RoutineExecution(
    id: json['id'] as String? ?? '',
    routineId: json['routineId'] as String? ?? '',
    startedAt: json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    completedAt: json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    result: json['result'] == RoutineExecutionResult.failed.name
        ? RoutineExecutionResult.failed
        : RoutineExecutionResult.succeeded,
    message: json['message'] as String? ?? '',
    failureReason: json['failureReason'] as String?,
    affectedDevices: (json['affectedDevices'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.icon,
    required this.isFavorite,
    required this.enabled,
    required this.availability,
    required this.trigger,
    required this.conditions,
    required this.actions,
    required this.schedule,
    required this.involvedDevices,
    required this.lastExecution,
    required this.nextRun,
    required this.createdAt,
    required this.updatedAt,
    required this.summary,
    this.isCritical = false,
  });

  final String id;
  final String name;
  final String icon;
  final bool isFavorite;
  final bool enabled;
  final RoutineAvailability availability;
  final RoutineTrigger trigger;
  final List<RoutineCondition> conditions;
  final List<RoutineAction> actions;
  final RoutineSchedule schedule;
  final List<RoutineDevice> involvedDevices;
  final RoutineExecution? lastExecution;
  final String? nextRun;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String summary;
  final bool isCritical;

  Routine copyWith({
    String? id,
    String? name,
    String? icon,
    bool? isFavorite,
    bool? enabled,
    RoutineAvailability? availability,
    RoutineTrigger? trigger,
    List<RoutineCondition>? conditions,
    List<RoutineAction>? actions,
    RoutineSchedule? schedule,
    List<RoutineDevice>? involvedDevices,
    RoutineExecution? lastExecution,
    String? nextRun,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? summary,
    bool? isCritical,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isFavorite: isFavorite ?? this.isFavorite,
      enabled: enabled ?? this.enabled,
      availability: availability ?? this.availability,
      trigger: trigger ?? this.trigger,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      schedule: schedule ?? this.schedule,
      involvedDevices: involvedDevices ?? this.involvedDevices,
      lastExecution: lastExecution ?? this.lastExecution,
      nextRun: nextRun ?? this.nextRun,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      summary: summary ?? this.summary,
      isCritical: isCritical ?? this.isCritical,
    );
  }

  String get availabilityLabel => switch (availability) {
    RoutineAvailability.available => 'Ready to run',
    RoutineAvailability.partiallyAvailable => 'Some devices unavailable',
    RoutineAvailability.unavailable => 'Device unavailable',
  };

  String get statusLabel => enabled ? 'Enabled' : 'Disabled';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'isFavorite': isFavorite,
    'enabled': enabled,
    'availability': availability.name,
    'trigger': trigger.toJson(),
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'actions': actions.map((a) => a.toJson()).toList(),
    'schedule': schedule.toJson(),
    'involvedDevices': involvedDevices.map((d) => d.toJson()).toList(),
    'lastExecution': lastExecution?.toJson(),
    'nextRun': nextRun,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'summary': summary,
    'isCritical': isCritical,
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Routine',
    icon: json['icon'] as String? ?? 'auto_awesome',
    isFavorite: json['isFavorite'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
    isCritical: json['isCritical'] as bool? ?? false,
    availability: RoutineAvailability.values.firstWhere(
      (a) => a.name == json['availability'],
      orElse: () => RoutineAvailability.available,
    ),
    trigger: json['trigger'] != null
        ? RoutineTrigger.fromJson(Map<String, dynamic>.from(json['trigger'] as Map))
        : const RoutineTrigger(
            kind: RoutineTriggerKind.timeSchedule,
            title: 'Scheduled Trigger',
            detail: 'Scheduled',
          ),
    conditions: (json['conditions'] as List<dynamic>?)
            ?.map((e) => RoutineCondition.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [],
    actions: (json['actions'] as List<dynamic>?)
            ?.map((e) => RoutineAction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [],
    schedule: json['schedule'] != null
        ? RoutineSchedule.fromJson(Map<String, dynamic>.from(json['schedule'] as Map))
        : const RoutineSchedule(label: 'Daily', timezone: 'Home timezone'),
    involvedDevices: (json['involvedDevices'] as List<dynamic>?)
            ?.map((e) => RoutineDevice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [],
    lastExecution: json['lastExecution'] != null
        ? RoutineExecution.fromJson(Map<String, dynamic>.from(json['lastExecution'] as Map))
        : null,
    nextRun: json['nextRun'] as String? ?? 'Scheduled',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    summary: json['summary'] as String? ?? '',
  );
}

class RoutineDraft {
  RoutineDraft({
    this.name = '',
    this.icon = 'auto_awesome',
    this.isFavorite = false,
    this.trigger,
    this.conditions = const [],
    this.actions = const [],
    this.schedule,
    this.validation = const RoutineValidation(),
    this.isCritical = false,
  });

  String name;
  String icon;
  bool isFavorite;
  RoutineTrigger? trigger;
  List<RoutineCondition> conditions;
  List<RoutineAction> actions;
  RoutineSchedule? schedule;
  RoutineValidation validation;
  bool isCritical;
}

class RoutineValidation {
  const RoutineValidation({
    this.state = RoutineValidationState.incomplete,
    this.errors = const [],
    this.warnings = const [],
  });

  final RoutineValidationState state;
  final List<String> errors;
  final List<String> warnings;
  bool get isValid => state == RoutineValidationState.valid;
}

enum RepositoryResult {
  success,
  unavailable,
  unauthorized,
  unsupported,
  failed,
}

abstract class RoutineRepository {
  Future<List<Routine>> getRoutines();
  Future<Routine?> getRoutine(String id);
  Future<List<RoutineExecution>> getRecentExecutions(String id);
  Future<RepositoryResult> createRoutine(RoutineDraft draft);
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft);
  Future<RepositoryResult> deleteRoutine(String id);
  Future<RepositoryResult> enableRoutine(String id);
  Future<RepositoryResult> disableRoutine(String id);
  Future<RepositoryResult> executeRoutine(String id);
}

class PreviewRoutineRepository implements RoutineRepository {
  const PreviewRoutineRepository();

  static const String _storageKey = 'eh_user_routines_v2';
  static final List<Routine> _routines = [];
  static final List<Routine> _cachedRoutines = [];
  static final Map<String, List<RoutineExecution>> _history = {};
  static bool _hydrated = false;

  /// In-memory view of current live routines for quick active status lookup across UI
  static List<Routine> get liveRoutines =>
      List.unmodifiable(_routines.isNotEmpty ? _routines : _cachedRoutines);

  static void registerCachedRoutines(List<Routine> routines) {
    for (final r in routines) {
      final idx = _cachedRoutines.indexWhere((c) => c.id == r.id);
      if (idx >= 0) {
        _cachedRoutines[idx] = r;
      } else {
        _cachedRoutines.add(r);
      }
    }
  }

  static Future<void> syncWithCloudRoutines(List<Routine> routines) async {
    await _ensureHydrated();
    final validRoutines = routines.where((r) => !DeviceStorageService.isRoutineDeleted(r.id, routineName: r.name)).toList();
    _routines.clear();
    _routines.addAll(validRoutines);
    _cachedRoutines.clear();
    _cachedRoutines.addAll(validRoutines);
    await _persist();
  }

  static Future<void> addOrUpdateRoutine(Routine routine) async {
    await _ensureHydrated();
    final idx = _routines.indexWhere((r) => r.id == routine.id || r.name.toLowerCase() == routine.name.toLowerCase());
    if (idx >= 0) {
      _routines[idx] = routine;
    } else {
      _routines.insert(0, routine);
    }
    final cIdx = _cachedRoutines.indexWhere((r) => r.id == routine.id || r.name.toLowerCase() == routine.name.toLowerCase());
    if (cIdx >= 0) {
      _cachedRoutines[cIdx] = routine;
    } else {
      _cachedRoutines.insert(0, routine);
    }
    await _persist();
  }

  static Future<void> _ensureHydrated() async {
    if (_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr) as List<dynamic>;
        _routines.clear();
        for (final item in decoded) {
          if (item is Map) {
            final r = Routine.fromJson(Map<String, dynamic>.from(item));
            if (!DeviceStorageService.isRoutineDeleted(r.id, routineName: r.name)) {
              _routines.add(r);
            }
          }
        }
      }
    } catch (_) {}
    _hydrated = true;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _routines.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {}
  }

  @override
  Future<List<Routine>> getRoutines() async {
    await _ensureHydrated();
    return List.unmodifiable(_routines);
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    await _ensureHydrated();
    for (final routine in _routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  @override
  Future<List<RoutineExecution>> getRecentExecutions(String id) async =>
      _history[id] ?? [];

  @override
  Future<RepositoryResult> createRoutine(RoutineDraft draft) async {
    await _ensureHydrated();
    final id = 'routine_${DateTime.now().millisecondsSinceEpoch}';
    final routineName = draft.name.trim().isNotEmpty ? draft.name.trim() : 'Custom Routine';
    await DeviceStorageService.removeDeletedRoutine(id);
    await DeviceStorageService.removeDeletedRoutine(routineName);
    
    // Resolve involved devices dynamically
    final involvedList = <RoutineDevice>[];
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final a in draft.actions) {
        ConnectedDeviceSummary? match;
        for (final d in ctrl.devices) {
          if (d.id == a.deviceId) {
            match = d;
            break;
          }
        }
        if (match != null && !involvedList.any((d) => d.id == match!.id)) {
          involvedList.add(
            RoutineDevice(
              id: match.id,
              name: match.name,
              room: match.roomName,
              online: match.online,
              capabilities: const [],
            ),
          );
        }
      }
    }

    final newRoutine = Routine(
      id: id,
      name: routineName,
      icon: draft.icon.isNotEmpty ? draft.icon : 'auto_awesome',
      isFavorite: draft.isFavorite,
      enabled: true,
      availability: RoutineAvailability.available,
      trigger: draft.trigger ??
          const RoutineTrigger(
            kind: RoutineTriggerKind.timeSchedule,
            title: 'Schedule Trigger',
            detail: 'Active schedule',
          ),
      conditions: draft.conditions,
      actions: draft.actions,
      schedule: draft.schedule ??
          const RoutineSchedule(
            label: 'Daily',
            timezone: 'Home timezone',
          ),
      involvedDevices: involvedList,
      lastExecution: null,
      nextRun: 'Scheduled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      summary: draft.actions.isNotEmpty
          ? 'Runs: ${draft.actions.map((a) => a.detail).join(", ")}'
          : 'Runs automated routine on schedule.',
      isCritical: draft.isCritical,
    );

    _routines.insert(0, newRoutine);
    await _persist();
    await ChangeTrackingService.instance.recordChange(
      entityType: 'routine',
      entityId: id,
      field: 'routine',
      oldValue: null,
      newValue: routineName,
      changeType: ChangeType.created,
    );
    final isHub = LiveHubRepository.isLinked && LiveHubRepository.isHubActive;
    if (!isHub || newRoutine.isCritical) {
      unawaited(EdgeRoutineSyncService.instance.syncRoutineToEdge(newRoutine));
    } else {
      unawaited(EdgeRoutineSyncService.instance.deleteRoutineFromEdge(newRoutine));
    }
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft) async {
    await _ensureHydrated();
    final idx = _routines.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final old = _routines[idx];
      final involvedList = <RoutineDevice>[];
      final ctrl = HomeController.instance;
      final actionsToInspect = draft.actions.isNotEmpty ? draft.actions : old.actions;
      if (ctrl != null) {
        for (final a in actionsToInspect) {
          ConnectedDeviceSummary? match;
          for (final d in ctrl.devices) {
            if (d.id == a.deviceId || (ctrl.devices.length == 1 && (a.deviceId.isEmpty || a.deviceId == 'default'))) {
              match = d;
              break;
            }
          }
          if (match != null && !involvedList.any((d) => d.id == match!.id)) {
            involvedList.add(
              RoutineDevice(
                id: match.id,
                name: match.name,
                room: match.roomName,
                online: match.online,
                capabilities: const [],
              ),
            );
          }
        }
        if (involvedList.isEmpty && ctrl.devices.isNotEmpty) {
          final first = ctrl.devices.first;
          involvedList.add(
            RoutineDevice(
              id: first.id,
              name: first.name,
              room: first.roomName,
              online: first.online,
              capabilities: const [],
            ),
          );
        }
      }

      _routines[idx] = Routine(
        id: old.id,
        name: draft.name.trim().isNotEmpty ? draft.name.trim() : old.name,
        icon: draft.icon.isNotEmpty ? draft.icon : old.icon,
        isFavorite: draft.isFavorite,
        enabled: old.enabled,
        availability: old.availability,
        trigger: draft.trigger ?? old.trigger,
        conditions: old.conditions,
        actions: draft.actions.isNotEmpty ? draft.actions : old.actions,
        schedule: draft.schedule ?? old.schedule,
        involvedDevices: involvedList.isNotEmpty ? involvedList : old.involvedDevices,
        lastExecution: old.lastExecution,
        nextRun: old.nextRun,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        summary: draft.actions.isNotEmpty
            ? 'Runs: ${draft.actions.map((a) => a.detail).join(", ")}'
            : old.summary,
        isCritical: draft.isCritical,
      );
      await _persist();
      await ChangeTrackingService.instance.recordChange(
        entityType: 'routine',
        entityId: id,
        field: 'routine',
        oldValue: old.name,
        newValue: draft.name.trim().isNotEmpty ? draft.name.trim() : old.name,
        changeType: ChangeType.modified,
      );
      final isHub = LiveHubRepository.isLinked && LiveHubRepository.isHubActive;
      if (!isHub || _routines[idx].isCritical) {
        unawaited(EdgeRoutineSyncService.instance.syncRoutineToEdge(_routines[idx]));
      } else {
        unawaited(EdgeRoutineSyncService.instance.deleteRoutineFromEdge(_routines[idx]));
      }
    }
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> deleteRoutine(String id) async {
    await _ensureHydrated();
    final toRemove = _routines.where((r) => r.id == id).toList();
    final oldName = toRemove.isNotEmpty ? toRemove.first.name : id;
    _routines.removeWhere((r) => r.id == id);
    _cachedRoutines.removeWhere((r) => r.id == id);
    for (final r in toRemove) {
      await DeviceStorageService.markRoutineDeleted(r.id, routineName: r.name);
      _routines.removeWhere((x) => x.name.toLowerCase() == r.name.toLowerCase());
      _cachedRoutines.removeWhere((x) => x.name.toLowerCase() == r.name.toLowerCase());
      try {
        await EdgeRoutineSyncService.instance.deleteRoutineFromEdge(r);
      } catch (_) {}
    }
    await DeviceStorageService.markRoutineDeleted(id);
    _history.remove(id);
    await _persist();
    await ChangeTrackingService.instance.recordChange(
      entityType: 'routine',
      entityId: id,
      field: 'routine',
      oldValue: oldName,
      newValue: null,
      changeType: ChangeType.deleted,
    );
    return RepositoryResult.success;
  }

  /// Upsert a routine discovered/read from the physical ESP32 board
  Future<void> upsertRoutineFromEdge(Routine routine) async {
    await _ensureHydrated();
    if (DeviceStorageService.isRoutineDeleted(routine.id, routineName: routine.name)) {
      debugPrint('[EDGE-SYNC] Routine "${routine.name}" (${routine.id}) is deleted. Purging from hardware.');
      unawaited(EdgeRoutineSyncService.instance.deleteRoutineFromEdge(routine));
      return;
    }
    final routineCore = EdgeRoutineSyncService.extractCoreId(routine.id);
    final idx = _routines.indexWhere((r) {
      if (r.id == routine.id) return true;
      final rCore = EdgeRoutineSyncService.extractCoreId(r.id);
      if (rCore == routineCore) return true;
      if (r.name.trim().toLowerCase() == routine.name.trim().toLowerCase()) return true;
      return false;
    });

    if (idx >= 0) {
      final existing = _routines[idx];
      // CRITICAL: If the existing app routine already has actions, never let a partial/single action
      // from the edge overwrite all actions! Preserve rich multi-action composition.
      if (existing.actions.length >= routine.actions.length && existing.actions.isNotEmpty) {
        _routines[idx] = existing.copyWith(
          enabled: routine.enabled,
        );
      } else {
        _routines[idx] = routine;
      }
    } else {
      _routines.add(routine);
    }
    await _persist();
  }

  /// Remove a routine locally without firing a redundant edge delete call
  Future<void> removeRoutineLocalOnly(String id) async {
    await _ensureHydrated();
    _routines.removeWhere((r) => r.id == id);
    _cachedRoutines.removeWhere((r) => r.id == id);
    _history.remove(id);
    await _persist();
  }

  @override
  Future<RepositoryResult> enableRoutine(String id) async {
    await _ensureHydrated();
    final idx = _routines.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final old = _routines[idx];
      _routines[idx] = Routine(
        id: old.id,
        name: old.name,
        icon: old.icon,
        isFavorite: old.isFavorite,
        enabled: true,
        availability: old.availability,
        trigger: old.trigger,
        conditions: old.conditions,
        actions: old.actions,
        schedule: old.schedule,
        involvedDevices: old.involvedDevices,
        lastExecution: old.lastExecution,
        nextRun: old.nextRun,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        summary: old.summary,
      );
      await _persist();
      await ChangeTrackingService.instance.recordChange(
        entityType: 'routine',
        entityId: id,
        field: 'enabled',
        oldValue: 'false',
        newValue: 'true',
        changeType: ChangeType.modified,
      );
      unawaited(EdgeRoutineSyncService.instance.syncRoutineToEdge(_routines[idx]));
    }
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> disableRoutine(String id) async {
    await _ensureHydrated();
    final idx = _routines.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final old = _routines[idx];
      _routines[idx] = Routine(
        id: old.id,
        name: old.name,
        icon: old.icon,
        isFavorite: old.isFavorite,
        enabled: false,
        availability: old.availability,
        trigger: old.trigger,
        conditions: old.conditions,
        actions: old.actions,
        schedule: old.schedule,
        involvedDevices: old.involvedDevices,
        lastExecution: old.lastExecution,
        nextRun: old.nextRun,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        summary: old.summary,
      );
      await _persist();
      await ChangeTrackingService.instance.recordChange(
        entityType: 'routine',
        entityId: id,
        field: 'enabled',
        oldValue: 'true',
        newValue: 'false',
        changeType: ChangeType.modified,
      );
      unawaited(EdgeRoutineSyncService.instance.disableRoutineOnEdge(_routines[idx]));
    }
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> executeRoutine(String id) async {
    await _ensureHydrated();
    Routine? routine = await getRoutine(id);
    if (routine == null) {
      for (final r in _cachedRoutines) {
        if (r.id == id) {
          routine = r;
          break;
        }
      }
    }
    if (routine == null) return RepositoryResult.failed;
    final now = DateTime.now();

    // 1. Dispatch actual device commands dynamically via HomeController
    try {
      final ctrl = HomeController.instance;
      if (ctrl != null) {
        for (final action in routine.actions) {
          final targetDevId = action.deviceId.isNotEmpty &&
                  action.deviceId != 'default' &&
                  action.deviceId != 'all' &&
                  action.deviceId != 'all_sockets'
              ? action.deviceId
              : (ctrl.devices.isNotEmpty ? ctrl.devices.first.id : '');

          if (targetDevId.isEmpty) continue;

          bool finalValue = action.targetState;
          if (action.isToggle) {
            final cur = ctrl.getDeviceChannelPower(targetDevId, action.channelIndex);
            finalValue = !cur;
          }

          if (action.channelIndex == 0 || action.kind == RoutineActionKind.allChannels) {
            for (int ch = 1; ch <= 4; ch++) {
              await ctrl.setDeviceChannelPower(
                deviceId: targetDevId,
                channelIndex: ch,
                value: finalValue,
                isToggle: action.isToggle,
              );
            }
          } else {
            await ctrl.setDeviceChannelPower(
              deviceId: targetDevId,
              channelIndex: action.channelIndex,
              value: finalValue,
              isToggle: action.isToggle,
            );
          }

          if (action.pulseDurationMinutes != null && action.pulseDurationMinutes! > 0 && finalValue == true) {
            final pulseMins = action.pulseDurationMinutes!;
            Future.delayed(Duration(minutes: pulseMins), () {
              if (action.channelIndex == 0 || action.kind == RoutineActionKind.allChannels) {
                for (int ch = 1; ch <= 4; ch++) {
                  ctrl.setDeviceChannelPower(deviceId: targetDevId, channelIndex: ch, value: false);
                }
              } else {
                ctrl.setDeviceChannelPower(deviceId: targetDevId, channelIndex: action.channelIndex, value: false);
              }
            });
          }
        }

        ctrl.recordActivityEvent(
          title: 'Routine: ${routine.name}',
          message: 'Executed ${routine.actions.length} action(s) for ${routine.name}.',
        );
      }
    } catch (_) {}

    // 2. Track execution history
    final historyList = _history.putIfAbsent(id, () => []);
    final execution = RoutineExecution(
      id: 'exec_${now.millisecondsSinceEpoch}',
      routineId: id,
      startedAt: now,
      completedAt: DateTime.now(),
      result: RoutineExecutionResult.succeeded,
      message: 'Routine executed successfully.',
    );
    historyList.insert(0, execution);
    if (historyList.length > 20) historyList.removeLast();

    // Persist lastExecution on the Routine object itself
    final idx = _routines.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _routines[idx] = _routines[idx].copyWith(
        lastExecution: execution,
        updatedAt: DateTime.now(),
      );
      await _persist();
    }

    return RepositoryResult.success;
  }

  static List<RoutineExecution> getAllRecentExecutions() {
    final all = <RoutineExecution>[];
    for (final list in _history.values) {
      all.addAll(list);
    }
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all;
  }

  static String? getRoutineNameById(String id) {
    for (final r in _routines) {
      if (r.id == id) return r.name;
    }
    for (final r in _cachedRoutines) {
      if (r.id == id) return r.name;
    }
    return null;
  }
}

class RoutineValidator {
  const RoutineValidator();

  RoutineValidation validate(RoutineDraft draft) {
    final errors = <String>[];
    final warnings = <String>[];
    if (draft.name.trim().isEmpty) {
      errors.add('Choose a name for this routine.');
    }
    if (draft.trigger == null) {
      errors.add('Choose what should trigger it.');
    }
    if (draft.actions.isEmpty) {
      errors.add('Choose at least one action.');
    }
    final state = errors.isNotEmpty
        ? RoutineValidationState.incomplete
        : RoutineValidationState.valid;
    return RoutineValidation(state: state, errors: errors, warnings: warnings);
  }
}
