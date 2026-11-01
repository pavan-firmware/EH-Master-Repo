import 'dart:async';

import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/connection_models.dart';
import '../models/routine_models.dart';
import '../services/device_storage_service.dart';
import '../../app/home_controller.dart';

class CloudRoutineRepository implements RoutineRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudRoutineRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  void setActiveHomeId(String? homeId) => _activeHomeId = homeId;

  Future<String?> _resolveHomeId() async {
    if (_activeHomeId != null &&
        _activeHomeId!.isNotEmpty &&
        _activeHomeId != 'home_default' &&
        _activeHomeId != 'local-home') {
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
    return _activeHomeId ?? 'home_default';
  }

  @override
  Future<List<Routine>> getRoutines() async {
    final ctrl = HomeController.instance;
    if (ctrl != null && ctrl.isLocalMode) {
      return const PreviewRoutineRepository().getRoutines();
    }

    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) {
      return const PreviewRoutineRepository().getRoutines();
    }

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations');
      List items = [];
      if (res is List) {
        items = res;
      } else if (res is Map && res['data'] is List) {
        items = res['data'] as List;
      }
      final cloudRoutines = items
          .map<Routine>((item) => _mapToRoutine(item as Map<String, dynamic>))
          .where((r) => !DeviceStorageService.isRoutineDeleted(r.id, routineName: r.name))
          .toList();
      await PreviewRoutineRepository.syncWithCloudRoutines(cloudRoutines);
      return cloudRoutines;
    } catch (_) {}
    return const PreviewRoutineRepository().getRoutines();
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    final ctrl = HomeController.instance;
    if (ctrl != null && ctrl.isLocalMode) {
      return const PreviewRoutineRepository().getRoutine(id);
    }

    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) {
      return const PreviewRoutineRepository().getRoutine(id);
    }

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations/$id');
      if (res is Map<String, dynamic>) {
        final r = _mapToRoutine(res);
        PreviewRoutineRepository.registerCachedRoutines([r]);
        return r;
      }
    } catch (_) {}
    return const PreviewRoutineRepository().getRoutine(id);
  }

  @override
  Future<List<RoutineExecution>> getRecentExecutions(String id) async {
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return [];

    try {
      final res = await _apiClient.get('/api/v1/homes/$homeId/automations/$id/history');
      if (res is List) {
        return res.map<RoutineExecution>((e) {
          final map = e as Map<String, dynamic>;
          final startedAt = map['started_at'] != null
              ? DateTime.tryParse(map['started_at'].toString()) ?? DateTime.now()
              : DateTime.now();
          final completedAt = map['completed_at'] != null
              ? DateTime.tryParse(map['completed_at'].toString()) ?? startedAt
              : startedAt;
          final status = (map['status'] ?? 'SUCCESS').toString().toUpperCase();

          return RoutineExecution(
            id: map['id'] ?? 'exec_${DateTime.now().millisecondsSinceEpoch}',
            routineId: id,
            startedAt: startedAt,
            completedAt: completedAt,
            result: status == 'SUCCESS' ? RoutineExecutionResult.succeeded : RoutineExecutionResult.failed,
            message: map['message'] ?? (status == 'SUCCESS' ? 'Routine completed successfully' : 'Routine execution failed'),
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RepositoryResult> createRoutine(RoutineDraft draft) async {
    // 1. Immediately store in local repository for instant offline responsiveness & live execution
    await const PreviewRoutineRepository().createRoutine(draft);

    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.success;

    try {
      final triggerType = _mapTriggerType(draft.trigger?.kind);
      final triggerConfig = <String, dynamic>{
        'kind': draft.trigger?.kind.name ?? 'timeSchedule',
        'title': draft.trigger?.title ?? '',
        'detail': draft.trigger?.detail ?? '',
        'time': draft.trigger?.timeOfDay ?? '',
        'days': draft.schedule?.days ?? [],
        'label': draft.schedule?.label ?? draft.trigger?.detail ?? '',
        if (draft.trigger?.threshold != null) 'threshold': draft.trigger!.threshold,
        if (draft.trigger?.operator != null) 'operator': draft.trigger!.operator,
        if (draft.trigger?.unit != null) 'unit': draft.trigger!.unit,
      };

      final actionsList = draft.actions.map((a) {
        return {
          'deviceId': a.deviceId,
          'channel': a.channelIndex,
          'channelIndex': a.channelIndex,
          'action': 'setPower',
          'command': 'setPower',
          'params': {'value': a.targetState},
          'parameters': {'value': a.targetState, 'enabled': a.targetState},
          'targetState': a.targetState,
          'isToggle': a.isToggle,
          'pulseMinutes': a.pulseDurationMinutes,
          'title': a.title,
          'detail': a.detail,
        };
      }).toList();

      final res = await _apiClient.post(
        '/api/v1/homes/$homeId/automations',
        body: {
          'name': draft.name.trim(),
          'description': draft.schedule?.label ?? draft.trigger?.detail ?? 'Custom Routine',
          'triggerType': triggerType,
          'triggerConfig': triggerConfig,
          'conditions': draft.conditions.map((c) => c.toJson()).toList(),
          'actions': actionsList,
          'isEnabled': true,
        },
      );

      if (res is Map) {
        final autoData = res['data'] is Map ? res['data'] : (res['id'] != null ? res : null);
        if (autoData != null) {
          final cloudRoutine = _mapToRoutine(Map<String, dynamic>.from(autoData as Map));
          await PreviewRoutineRepository.addOrUpdateRoutine(cloudRoutine);
        }
      }
    } catch (_) {}
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft) async {
    // 1. Always update local storage first so changes are immediate
    await const PreviewRoutineRepository().updateRoutine(id, draft);
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.success;

    // 2. Sync full updated draft configuration to cloud
    try {
      final triggerConfig = <String, dynamic>{};
      String triggerType = 'TIME';
      if (draft.trigger != null) {
        if (draft.trigger!.timeOfDay != null) {
          triggerConfig['time'] = draft.trigger!.timeOfDay;
        }
        if (draft.trigger!.days.isNotEmpty) {
          triggerConfig['days'] = draft.trigger!.days;
        }
        if (draft.trigger!.threshold != null) {
          triggerConfig['threshold'] = draft.trigger!.threshold;
          triggerConfig['operator'] = draft.trigger!.operator;
        }
        if (draft.trigger!.kind == RoutineTriggerKind.soilMoisture) {
          triggerType = 'SOIL';
        } else if (draft.trigger!.kind == RoutineTriggerKind.waterLevel) {
          triggerType = 'TANK';
        } else if (draft.trigger!.kind == RoutineTriggerKind.temperature || draft.trigger!.kind == RoutineTriggerKind.humidity) {
          triggerType = 'CLIMATE';
        } else if (draft.trigger!.kind == RoutineTriggerKind.sunset || draft.trigger!.kind == RoutineTriggerKind.sunrise) {
          triggerType = 'SOLAR';
        } else if (draft.trigger!.kind == RoutineTriggerKind.manual) {
          triggerType = 'MANUAL';
        }
      }

      final actionsList = draft.actions.map((a) {
        return {
          'deviceId': a.deviceId,
          'action': a.isToggle ? 'toggle' : 'setPower',
          'channelIndex': a.channelIndex,
          'targetState': a.targetState,
          'isToggle': a.isToggle,
          'pulseDurationMinutes': a.pulseDurationMinutes,
          'parameters': {
            'value': a.targetState,
            'channel': a.channelIndex,
            'pulseDurationMinutes': a.pulseDurationMinutes,
          },
        };
      }).toList();

      await _apiClient.put(
        '/api/v1/homes/$homeId/automations/$id',
        body: {
          'name': draft.name.trim(),
          'description': draft.schedule?.label ?? draft.trigger?.detail ?? 'Custom Routine',
          'triggerType': triggerType,
          'triggerConfig': triggerConfig,
          'conditions': draft.conditions.map((c) => c.toJson()).toList(),
          'actions': actionsList,
        },
      );
      return RepositoryResult.success;
    } catch (e) {
      // Local and edge hardware persistence already succeeded; never block user with failure
      debugPrint('[CloudRoutineRepository] Cloud automation sync warning: $e');
      return RepositoryResult.success;
    }
  }

  @override
  Future<RepositoryResult> deleteRoutine(String id) async {
    final existingLocal = await const PreviewRoutineRepository().getRoutine(id);
    final routineName = existingLocal?.name.trim().toLowerCase() ?? '';
    await const PreviewRoutineRepository().deleteRoutine(id);
    final homeId = await _resolveHomeId();
    if (homeId != null && homeId.isNotEmpty) {
      try {
        await _apiClient.delete('/api/v1/homes/$homeId/automations/$id');
      } catch (_) {}
      try {
        final res = await _apiClient.get('/api/v1/homes/$homeId/automations');
        List items = [];
        if (res is List) {
          items = res;
        } else if (res is Map && res['data'] is List) {
          items = res['data'] as List;
        }
        for (final item in items) {
          if (item is Map) {
            final autoId = (item['id'] ?? '').toString();
            final autoName = (item['name'] ?? '').toString().trim().toLowerCase();
            final idMatches = (autoId == id || autoName == id.toLowerCase());
            final nameMatches = (routineName.isNotEmpty && (autoName == routineName || autoName.contains(routineName) || routineName.contains(autoName)));
            if (idMatches || nameMatches) {
              await _apiClient.delete('/api/v1/homes/$homeId/automations/$autoId');
            }
          }
        }
      } catch (_) {}
    }
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> enableRoutine(String id) async {
    return _toggleRoutine(id, true);
  }

  @override
  Future<RepositoryResult> disableRoutine(String id) async {
    return _toggleRoutine(id, false);
  }

  Future<RepositoryResult> _toggleRoutine(String id, bool enabled) async {
    if (enabled) {
      await const PreviewRoutineRepository().enableRoutine(id);
    } else {
      await const PreviewRoutineRepository().disableRoutine(id);
    }
    final homeId = await _resolveHomeId();
    if (homeId == null || homeId.isEmpty) return RepositoryResult.success;

    final ctrl = HomeController.instance;
    if (ctrl != null && ctrl.isLocalMode) {
      // In local LAN mode, don't block UI on remote cloud HTTP call
      unawaited(
        _apiClient
            .patch('/api/v1/homes/$homeId/automations/$id/toggle', body: {'isEnabled': enabled})
            .timeout(const Duration(milliseconds: 1500))
            .catchError((_) => null),
      );
      return RepositoryResult.success;
    }

    try {
      await _apiClient
          .patch('/api/v1/homes/$homeId/automations/$id/toggle', body: {'isEnabled': enabled})
          .timeout(const Duration(milliseconds: 2000));
    } catch (_) {}
    return RepositoryResult.success;
  }

  @override
  Future<RepositoryResult> executeRoutine(String id) async {
    // 1. Instantly trigger real physical hardware actuation via PreviewRoutineRepository
    await const PreviewRoutineRepository().executeRoutine(id);

    // 2. Post to backend runner if connected
    final homeId = await _resolveHomeId();
    if (homeId != null && homeId.isNotEmpty) {
      try {
        await _apiClient.post('/api/v1/homes/$homeId/automations/$id/run');
      } catch (_) {}
    }
    return RepositoryResult.success;
  }

  String _mapTriggerType(RoutineTriggerKind? kind) {
    switch (kind) {
      case RoutineTriggerKind.soilMoisture:
      case RoutineTriggerKind.waterLevel:
      case RoutineTriggerKind.temperature:
      case RoutineTriggerKind.humidity:
      case RoutineTriggerKind.ambientLight:
      case RoutineTriggerKind.motion:
      case RoutineTriggerKind.deviceState:
        return 'device_state';
      case RoutineTriggerKind.powerThreshold:
        return 'energy_threshold';
      case RoutineTriggerKind.sunset:
      case RoutineTriggerKind.sunrise:
      case RoutineTriggerKind.timeSchedule:
        return 'schedule';
      case RoutineTriggerKind.manual:
      default:
        return 'manual';
    }
  }

  Routine _mapToRoutine(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final name = map['name']?.toString() ?? 'Routine';
    final isEnabled = (map['isEnabled'] ?? map['is_enabled'] ?? true) == true;
    final createdAt = map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
        : (map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now());
    final updatedAt = map['updatedAt'] != null
        ? DateTime.tryParse(map['updatedAt'].toString()) ?? createdAt
        : (map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? createdAt : createdAt);

    final triggerType = (map['triggerType'] ?? map['trigger_type'] ?? 'schedule').toString();
    final triggerConfig = (map['triggerConfig'] is Map
            ? map['triggerConfig'] as Map
            : (map['trigger_config'] is Map ? map['trigger_config'] as Map : {}))
        .cast<String, dynamic>();

    // Decode trigger kind
    final kindName = triggerConfig['kind']?.toString() ?? triggerType;
    final kind = RoutineTriggerKind.values.firstWhere(
      (k) => k.name.toLowerCase() == kindName.toLowerCase(),
      orElse: () {
        if (triggerType == 'device_state') return RoutineTriggerKind.soilMoisture;
        if (triggerType == 'energy_threshold') return RoutineTriggerKind.powerThreshold;
        if (triggerType == 'manual') return RoutineTriggerKind.manual;
        return RoutineTriggerKind.timeSchedule;
      },
    );

    final timeStr = triggerConfig['time']?.toString() ?? '';
    final labelStr = triggerConfig['label']?.toString() ?? map['description']?.toString() ?? '';
    final daysList = (triggerConfig['days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String triggerTitle = triggerConfig['title']?.toString() ?? '';
    if (triggerTitle.isEmpty) {
      if (timeStr.isNotEmpty) {
        triggerTitle = 'Schedule: $timeStr';
      } else if (kind == RoutineTriggerKind.sunset) {
        triggerTitle = 'Sunset Routine';
      } else if (kind == RoutineTriggerKind.sunrise) {
        triggerTitle = 'Sunrise Routine';
      } else if (kind == RoutineTriggerKind.soilMoisture) {
        triggerTitle = 'Soil Moisture Trigger';
      } else if (kind == RoutineTriggerKind.waterLevel) {
        triggerTitle = 'Water Level Trigger';
      } else if (kind == RoutineTriggerKind.temperature) {
        triggerTitle = 'Temperature Trigger';
      } else if (kind == RoutineTriggerKind.humidity) {
        triggerTitle = 'Humidity Trigger';
      } else if (kind == RoutineTriggerKind.ambientLight) {
        triggerTitle = 'Darkness / Light Trigger';
      } else if (kind == RoutineTriggerKind.motion) {
        triggerTitle = 'Motion Trigger';
      } else if (kind == RoutineTriggerKind.deviceState) {
        triggerTitle = 'Switch Linkage Trigger';
      } else if (kind == RoutineTriggerKind.powerThreshold) {
        triggerTitle = 'Overload Protection';
      } else if (kind == RoutineTriggerKind.manual) {
        triggerTitle = 'Manual Shortcut';
      } else {
        triggerTitle = 'Automated Trigger';
      }
    }

    String triggerDetail = triggerConfig['detail']?.toString() ?? '';
    if (triggerDetail.isEmpty) {
      if (labelStr.isNotEmpty) {
        triggerDetail = labelStr;
      } else if (timeStr.isNotEmpty) {
        triggerDetail = '${daysList.join(", ")} · $timeStr';
      } else if (kind == RoutineTriggerKind.manual) {
        triggerDetail = 'Run on tap or voice command';
      } else {
        triggerDetail = 'Automated execution';
      }
    }

    // Decode actions
    final rawActions = (map['actions'] as List<dynamic>?) ?? [];
    final parsedActions = <RoutineAction>[];
    for (final act in rawActions) {
      if (act is! Map) continue;
      final devId = act['deviceId']?.toString() ?? act['device_id']?.toString() ?? '';
      final chIdx = (act['channelIndex'] ?? act['channel'] ?? 1) as int? ?? 1;
      final isToggle = act['isToggle'] == true;
      final params = act['params'] is Map ? act['params'] : (act['parameters'] is Map ? act['parameters'] : {});
      final tState = act['targetState'] is bool
          ? act['targetState'] as bool
          : ((params['value'] ?? params['enabled'] ?? true) == true);
      final pulse = act['pulseMinutes'] ?? act['pulseDurationMinutes'];
      final pulseInt = pulse != null ? int.tryParse(pulse.toString()) : null;
      final title = act['title']?.toString() ?? (chIdx == 0 ? 'All Channels' : 'Channel $chIdx');
      final detail = act['detail']?.toString() ??
          (isToggle
              ? 'Toggle'
              : '${tState ? "Turn ON" : "Turn OFF"}${pulseInt != null ? " ($pulseInt min)" : ""}');

      parsedActions.add(
        RoutineAction(
          kind: chIdx == 0 ? RoutineActionKind.allChannels : RoutineActionKind.switchChannel,
          title: title,
          detail: detail,
          deviceId: devId,
          channelIndex: chIdx,
          targetState: tState,
          isToggle: isToggle,
          pulseDurationMinutes: pulseInt,
        ),
      );
    }

    final scheduleLabel = labelStr.isNotEmpty
        ? labelStr
        : (timeStr.isNotEmpty ? '${daysList.join(", ")} at $timeStr' : 'Automated Trigger');

    final summary = parsedActions.isNotEmpty
        ? 'Runs: ${parsedActions.map((a) => a.detail).join(", ")}'
        : (map['description']?.toString() ?? 'Automated routine');

    return Routine(
      id: id,
      name: name,
      icon: map['icon']?.toString() ?? 'auto_awesome',
      isFavorite: (map['isFavorite'] ?? map['is_favorite'] ?? false) == true,
      enabled: isEnabled,
      availability: RoutineAvailability.available,
      trigger: RoutineTrigger(
        kind: kind,
        title: triggerTitle,
        detail: triggerDetail,
        threshold: (triggerConfig['threshold'] as num?)?.toDouble(),
        operator: triggerConfig['operator']?.toString() ?? '<',
        unit: triggerConfig['unit']?.toString() ?? '',
        timeOfDay: timeStr.isNotEmpty ? timeStr : null,
        days: daysList,
      ),
      conditions: const [],
      actions: parsedActions.isNotEmpty
          ? parsedActions
          : [
              const RoutineAction(
                kind: RoutineActionKind.switchChannel,
                title: 'Device Action',
                detail: 'Control channels',
                deviceId: '',
              ),
            ],
      schedule: RoutineSchedule(
        label: scheduleLabel,
        timezone: map['timezone']?.toString() ?? 'Home timezone',
        days: daysList,
      ),
      involvedDevices: () {
        final list = <RoutineDevice>[];
        final ctrl = HomeController.instance;
        if (ctrl != null) {
          for (final a in parsedActions) {
            ConnectedDeviceSummary? match;
            for (final d in ctrl.devices) {
              if (d.id == a.deviceId || (ctrl.devices.length == 1 && (a.deviceId.isEmpty || a.deviceId == 'default'))) {
                match = d;
                break;
              }
            }
            if (match != null && !list.any((d) => d.id == match!.id)) {
              list.add(
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
          if (list.isEmpty && ctrl.devices.isNotEmpty) {
            final first = ctrl.devices.first;
            list.add(
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
        return list;
      }(),
      lastExecution: () {
        if (map['lastExecution'] is Map) {
          try {
            return RoutineExecution.fromJson(Map<String, dynamic>.from(map['lastExecution'] as Map));
          } catch (_) {}
        }
        if (map['last_execution'] is Map) {
          try {
            return RoutineExecution.fromJson(Map<String, dynamic>.from(map['last_execution'] as Map));
          } catch (_) {}
        }
        return null;
      }(),
      nextRun: 'Active',
      createdAt: createdAt,
      updatedAt: updatedAt,
      summary: summary,
    );
  }
}
