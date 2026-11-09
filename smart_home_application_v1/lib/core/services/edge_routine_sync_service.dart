import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/routine_models.dart';
import 'local_lan_device_service.dart';
import '../../app/home_controller.dart';
import 'device_storage_service.dart';
import '../../features/hub/data/hub_repository.dart';

/// Production-Grade Edge Routine Synchronization Service
///
/// Bridges the Flutter Routine Engine with the on-chip ESP32 Edge Routine Engine.
/// Translates app-level routines into hardware-level `edge_routine_t` payloads,
/// computing bitmasks, pulse intervals, and schedule hours/minutes.
///
/// Ensures routines execute directly on the ESP32 microcontroller even when
/// the phone is offline, asleep, or disconnected from the internet.
class EdgeRoutineSyncService {
  EdgeRoutineSyncService._();
  static final EdgeRoutineSyncService instance = EdgeRoutineSyncService._();

  /// Converts days string list into ESP32 7-bit days mask:
  /// Standard POSIX tm_wday:
  /// Bit 0: Sun (1)
  /// Bit 1: Mon (2)
  /// Bit 2: Tue (4)
  /// Bit 3: Wed (8)
  /// Bit 4: Thu (16)
  /// Bit 5: Fri (32)
  /// Bit 6: Sat (64)
  /// All days = 0x7F (127)
  static int computeDaysMask(List<dynamic> days) {
    if (days.isEmpty) return 0x7F;
    int mask = 0;
    for (final day in days) {
      final d = day.toString().toLowerCase().trim();
      if (d.startsWith('sun') || d == '0' || d == '7') {
        mask |= (1 << 0);
      } else if (d.startsWith('mon') || d == '1') {
        mask |= (1 << 1);
      } else if (d.startsWith('tue') || d == '2') {
        mask |= (1 << 2);
      } else if (d.startsWith('wed') || d == '3') {
        mask |= (1 << 3);
      } else if (d.startsWith('thu') || d == '4') {
        mask |= (1 << 4);
      } else if (d.startsWith('fri') || d == '5') {
        mask |= (1 << 5);
      } else if (d.startsWith('sat') || d == '6') {
        mask |= (1 << 6);
      }
    }
    return mask == 0 ? 0x7F : mask;
  }

  /// Extracts 24-hour hour and minute from routine trigger / schedule
  static (int hour, int minute) parseTimeOfDay(RoutineTrigger trigger, RoutineSchedule schedule) {
    final candidateStr = trigger.timeOfDay ??
        (trigger.detail.isNotEmpty ? trigger.detail : schedule.label);

    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false);
    final match = timeRegex.firstMatch(candidateStr);
    if (match != null) {
      int h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final ampm = match.group(3)?.toUpperCase();
      if (ampm == 'PM' && h < 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;
      return (h.clamp(0, 23), m.clamp(0, 59));
    }

    // Default to morning 07:00 if unparseable
    return (7, 0);
  }

  /// Resolves the local IP address for a device across storage, cache, and LAN service
  String? resolveDeviceIp(String targetDeviceId) {
    final lanService = LocalLanDeviceService.instance;
    // 1. Direct lookup
    if (targetDeviceId.isNotEmpty &&
        targetDeviceId != 'default' &&
        targetDeviceId != 'primary_switch') {
      final directIp = lanService.getDeviceIp(targetDeviceId);
      if (directIp != null && directIp.isNotEmpty) return directIp;
    }

    // 2. Controller live devices
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      for (final dev in ctrl.devices) {
        if (targetDeviceId.isEmpty ||
            targetDeviceId == 'default' ||
            targetDeviceId == 'primary_switch' ||
            dev.id == targetDeviceId) {
          final ip = lanService.getDeviceIp(dev.id);
          if (ip != null && ip.isNotEmpty) return ip;
        }
      }
    }

    // 3. Fallback to any active discovered IP on local network
    final allIps = DeviceStorageService.getAllCachedDeviceIps();
    if (allIps.isNotEmpty) {
      return allIps.values.first;
    }

    return null;
  }

  /// Generates a clean, unique, and deterministic ID for an action on the ESP32 (max 36 chars)
  static String extractCoreId(String routineId) {
    var core = routineId.replaceAll(RegExp(r'^(rt_|routine_)+'), '');
    core = core.replaceAll(RegExp(r'(_ch\d+|_a\d+_c\d+)+$'), '');
    core = core.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (core.length > 18) {
      core = core.substring(core.length - 18);
    }
    return core.isEmpty ? 'rt' : core;
  }

  /// Builds a unique ID for each action and channel within a routine (<= 36 chars)
  static String buildEdgeRoutineId(String routineId, int actionIndex, int channel) {
    final core = extractCoreId(routineId);
    final id = 'rt_${core}_a${actionIndex}_c$channel';
    return id.length > 36 ? id.substring(0, 36) : id;
  }

  /// Syncs an entire Routine to target physical ESP32 boards on local LAN
  Future<bool> syncRoutineToEdge(Routine routine, {bool? forceEnabled}) async {
    final isEnabled = forceEnabled ?? routine.enabled;
    final (hour, minute) = parseTimeOfDay(routine.trigger, routine.schedule);
    final daysMask = computeDaysMask(
      routine.trigger.days.isNotEmpty ? routine.trigger.days : routine.schedule.days,
    );

    // 0 = MANUAL, 1 = TIMER, 2 = SCHEDULE
    int triggerType = 2; // Default to SCHEDULE
    if (routine.trigger.kind == RoutineTriggerKind.manual) {
      triggerType = 0;
    }

    final routineCore = extractCoreId(routine.id);
    bool anySuccess = false;

    // Collect target IPs
    final targetIps = <String>{};
    for (final action in routine.actions) {
      final ip = resolveDeviceIp(action.deviceId);
      if (ip != null && ip.isNotEmpty) {
        targetIps.add(ip);
      } else {
        debugPrint('[EDGE-SYNC] No IP found for device ${action.deviceId}. Triggering background discovery...');
        unawaited(LocalLanDeviceService.instance.autoDiscoverDevices());
      }
    }

    // Determine the expected set of edge IDs across all actions and channels
    final expectedEdgeIdsByIp = <String, Set<String>>{};
    for (final ip in targetIps) {
      expectedEdgeIdsByIp[ip] = <String>{};
    }

    for (int i = 0; i < routine.actions.length; i++) {
      final action = routine.actions[i];
      final targetIp = resolveDeviceIp(action.deviceId);
      if (targetIp == null || targetIp.isEmpty) continue;

      final channelsToSync = action.channelIndex == 0
          ? [1, 2, 3, 4]
          : [action.channelIndex.clamp(1, 4)];

      for (final ch in channelsToSync) {
        final edgeId = buildEdgeRoutineId(routine.id, i, ch);
        expectedEdgeIdsByIp[targetIp]?.add(edgeId);
      }
    }

    // Clean up stale or obsolete routine IDs on target boards belonging to this routine
    for (final ip in targetIps) {
      try {
        final existingOnBoard = await LocalLanDeviceService.instance.fetchLocalRoutines(
          deviceId: '',
          explicitIp: ip,
        );
        if (existingOnBoard != null) {
          final expected = expectedEdgeIdsByIp[ip] ?? <String>{};
          for (final existing in existingOnBoard) {
            final eId = existing['id']?.toString() ?? '';
            // If the routine ID on the board belongs to this routine core, but is NOT in the new expected set:
            if (eId.contains(routineCore) || eId == routine.id || eId.startsWith('rt_$routineCore') || eId.contains(routine.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))) {
              if (!expected.contains(eId)) {
                debugPrint('[EDGE-SYNC] Pruning stale edge routine "$eId" on $ip');
                await LocalLanDeviceService.instance.sendLocalRoutineDelete(
                  deviceId: '',
                  routineId: eId,
                  explicitIp: ip,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[EDGE-SYNC] Error checking stale routines on $ip: $e');
      }
    }

    // Now upsert each action cleanly
    for (int i = 0; i < routine.actions.length; i++) {
      final action = routine.actions[i];
      final targetIp = resolveDeviceIp(action.deviceId);
      if (targetIp == null || targetIp.isEmpty) continue;

      final pulseSec = (action.pulseDurationMinutes ?? 0) * 60;
      final effectiveTriggerType = (pulseSec > 0 && triggerType != 2) ? 1 : triggerType;

      final channelsToSync = action.channelIndex == 0
          ? [1, 2, 3, 4]
          : [action.channelIndex.clamp(1, 4)];

      for (final ch in channelsToSync) {
        final edgeId = buildEdgeRoutineId(routine.id, i, ch);

        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final payload = {
          'id': edgeId,
          'name': routine.name,
          'channel': ch,
          'channelIndex': ch,
          'power': action.targetState,
          'targetPower': action.targetState,
          'isToggle': action.isToggle,
          'toggle': action.isToggle,
          'triggerType': effectiveTriggerType,
          'durationSec': pulseSec,
          'hour': hour,
          'minute': minute,
          'daysMask': daysMask,
          'enabled': isEnabled,
          'unix_time': nowSec,
          'epoch': nowSec,
        };

        debugPrint('[EDGE-SYNC] Pushing routine action $i on CH$ch to ESP32 at $targetIp: $payload');
        final ok = await LocalLanDeviceService.instance.sendLocalRoutineUpsert(
          deviceId: action.deviceId,
          routinePayload: payload,
          explicitIp: targetIp,
        );
        if (ok) anySuccess = true;
      }
    }

    return anySuccess;
  }

  /// Disarms or disables a routine on the physical ESP32
  Future<bool> disableRoutineOnEdge(Routine routine) async {
    return syncRoutineToEdge(routine, forceEnabled: false);
  }

  /// Deletes a routine on the physical ESP32 board
  Future<bool> deleteRoutineFromEdge(Routine routine) async {
    final routineCore = extractCoreId(routine.id);
    bool anySuccess = false;

    // Collect target IPs
    final targetIps = <String>{};
    for (final action in routine.actions) {
      final ip = resolveDeviceIp(action.deviceId);
      if (ip != null && ip.isNotEmpty) targetIps.add(ip);
    }

    for (final ip in targetIps) {
      try {
        final existingOnBoard = await LocalLanDeviceService.instance.fetchLocalRoutines(
          deviceId: '',
          explicitIp: ip,
        );
        if (existingOnBoard != null) {
          for (final existing in existingOnBoard) {
            final eId = existing['id']?.toString() ?? '';
            if (eId.contains(routineCore) || eId == routine.id || eId.startsWith('rt_$routineCore') || eId.contains(routine.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))) {
              debugPrint('[EDGE-SYNC] Deleting routine "$eId" from board $ip');
              final ok = await LocalLanDeviceService.instance.sendLocalRoutineDelete(
                deviceId: '',
                routineId: eId,
                explicitIp: ip,
              );
              if (ok) anySuccess = true;
            }
          }
        }
      } catch (e) {
        debugPrint('[EDGE-SYNC] Error deleting routines on $ip: $e');
      }

      // Also send explicit canonical IDs as fallback
      for (int i = 0; i < routine.actions.length; i++) {
        final action = routine.actions[i];
        final channelsToSync = action.channelIndex == 0 ? [1, 2, 3, 4] : [action.channelIndex.clamp(1, 4)];
        for (final ch in channelsToSync) {
          final edgeId = buildEdgeRoutineId(routine.id, i, ch);
          await LocalLanDeviceService.instance.sendLocalRoutineDelete(
            deviceId: action.deviceId,
            routineId: edgeId,
            explicitIp: ip,
          );
        }
      }
    }

    return anySuccess;
  }

  /// Reconciles all local routines in storage with connected edge boards on LAN
  /// Checks whether a routine is currently running or within its active execution/pulse window
  /// Checks whether a routine is currently running or within its active execution/pulse window
  bool isRoutineCurrentlyActive(Routine routine, {int? targetChannel, bool? currentPower}) {
    if (!routine.enabled) return false;
    final now = DateTime.now();

    // 1. Identify relevant actions
    final relevantActions = targetChannel != null
        ? routine.actions.where((a) => a.channelIndex == 0 || a.channelIndex == targetChannel).toList()
        : routine.actions;

    if (relevantActions.isEmpty) return false;

    // 2. Check if any relevant action has an active pulse/auto-off timer
    int maxPulseSec = 0;
    for (final act in relevantActions) {
      if (act.pulseDurationMinutes != null && act.pulseDurationMinutes! > 0) {
        final sec = act.pulseDurationMinutes! * 60;
        if (sec > maxPulseSec) {
          maxPulseSec = sec;
        }
      }
    }

    // A routine without any auto-off timer (one-shot command) completes immediately
    // and should not lock the channel UI with an active routine warning overlay.
    if (maxPulseSec == 0) {
      return false;
    }

    // 3. Physical hardware state validation:
    // If the physical channel power is provided and is NOT in the target active state,
    // the routine's pulse has already completed (e.g. turned OFF after 1-minute auto-off).
    if (currentPower != null) {
      final targetPwr = relevantActions.first.targetState;
      if (currentPower != targetPwr) {
        return false;
      }
    }

    // 4. Time schedule check
    if (routine.trigger.kind == RoutineTriggerKind.timeSchedule) {
      final (h, m) = parseTimeOfDay(routine.trigger, routine.schedule);
      if (h >= 0 && m >= 0) {
        // Check days match
        if (routine.trigger.days.isNotEmpty) {
          const dayMap = {1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat', 7: 'sun'};
          final curDay = dayMap[now.weekday] ?? '';
          final dayMatches = routine.trigger.days.any((d) => d.toString().toLowerCase().startsWith(curDay));
          if (!dayMatches) return false;
        }

        final scheduleStart = DateTime(now.year, now.month, now.day, h, m);
        final scheduleEnd = scheduleStart.add(Duration(seconds: maxPulseSec));

        // Active only strictly during the schedule pulse duration
        if (now.isAfter(scheduleStart) && now.isBefore(scheduleEnd)) {
          return true;
        }
      }
    }

    // 5. Recent execution within pulse duration window
    if (routine.lastExecution != null) {
      final execTime = routine.lastExecution!.completedAt;
      final diffSec = now.difference(execTime).inSeconds;
      if (diffSec >= 0 && diffSec < maxPulseSec) {
        return true;
      }
    }

    return false;
  }


  /// Reconciles all local routines in storage with connected edge boards on LAN
  Future<void> reconcileAllRoutinesToEdge({bool force = false}) async {
    try {
      final isHubActive = LiveHubRepository.isLinked && LiveHubRepository.isHubActive;
      final routines = await const PreviewRoutineRepository().getRoutines();
      debugPrint('[EDGE-SYNC] Reconciling ${routines.length} routines (isHubActive=$isHubActive)...');
      for (final routine in routines) {
        // CRITICAL FIX: If a routine is currently running on the board, DO NOT POST routine upsert
        // which resets the ESP32 on-chip timer and stops the routine mid-operation!
        if (!force && isRoutineCurrentlyActive(routine)) {
          debugPrint('[EDGE-SYNC] Skipping reconcile for active routine "${routine.name}" to prevent interrupting running on-chip pulse.');
          continue;
        }
        if (isHubActive && !routine.isCritical) {
          // Master spec: Hub is active and this routine is standard comfort -> MUST NOT exist on ESP32 flash!
          await deleteRoutineFromEdge(routine);
          continue;
        }
        if (routine.enabled) {
          await syncRoutineToEdge(routine);
        } else {
          await disableRoutineOnEdge(routine);
        }
      }
    } catch (e) {
      debugPrint('[EDGE-SYNC] Reconcile error: $e');
    }
  }

  /// Discovers and syncs routines directly from the physical ESP32 board into the app
  Future<int> syncRoutinesFromEdgeToApp({String? targetDeviceId}) async {
    try {
      final ctrl = HomeController.instance;
      final devId = targetDeviceId ?? (ctrl?.devices.isNotEmpty == true ? ctrl!.devices.first.id : '');
      if (devId.isEmpty) return 0;

      final edgeRoutines = await LocalLanDeviceService.instance.fetchLocalRoutines(deviceId: devId);
      if (edgeRoutines == null) return 0;

      debugPrint('[EDGE-SYNC] Read ${edgeRoutines.length} routine(s) from ESP32 on LAN: $edgeRoutines');
      final repo = const PreviewRoutineRepository();
      
      // Clean up any test routines that were removed from the chip
      await repo.removeRoutineLocalOnly('test_sched_1');

      int syncedCount = 0;
      final existingRoutines = await repo.getRoutines();

      // Group edge raw items by logical routine (using core ID or name)
      final groupedEdgeRoutines = <String, List<Map<String, dynamic>>>{};
      for (final raw in edgeRoutines) {
        final id = raw['id']?.toString() ?? '';
        if (id.isEmpty || id == 'test_sched_1') continue;

        final core = extractCoreId(id);
        final name = raw['name']?.toString() ?? 'Edge Routine';
        final groupKey = core.isNotEmpty && core != 'rt' ? core : name.trim().toLowerCase();
        groupedEdgeRoutines.putIfAbsent(groupKey, () => []).add(raw);
      }

      for (final entry in groupedEdgeRoutines.entries) {
        final groupKey = entry.key;
        final items = entry.value;
        if (items.isEmpty) continue;

        final firstRaw = items.first;
        final name = firstRaw['name']?.toString() ?? 'Edge Routine';

        // Check if this routine already exists in app storage
        Routine? existing;
        for (final r in existingRoutines) {
          if (r.id == groupKey ||
              extractCoreId(r.id) == groupKey ||
              r.name.trim().toLowerCase() == name.trim().toLowerCase()) {
            existing = r;
            break;
          }
        }

        final anyEnabledOnHardware = items.any((it) => it['enabled'] == true);

        if (existing != null) {
          // Routine already exists in app with full user-configured actions!
          // NEVER overwrite or truncate the multi-action list!
          if (existing.enabled != anyEnabledOnHardware) {
            final updated = existing.copyWith(enabled: anyEnabledOnHardware);
            await repo.upsertRoutineFromEdge(updated);
          }
          syncedCount++;
          continue;
        }

        // Routine is newly discovered from board: reconstruct all actions
        final hr = (firstRaw['hour'] as num?)?.toInt() ?? 7;
        final min = (firstRaw['minute'] as num?)?.toInt() ?? 0;
        final daysMask = (firstRaw['daysMask'] as num?)?.toInt() ?? 0x7F;

        final dayNames = <String>[];
        const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        for (int b = 0; b < 7; b++) {
          if ((daysMask & (1 << b)) != 0) {
            dayNames.add(dayLabels[b]);
          }
        }
        final timeStr = '${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';

        final actions = <RoutineAction>[];
        for (final rawAction in items) {
          final ch = (rawAction['channelIndex'] as num?)?.toInt() ?? 1;
          final targetPwr = rawAction['targetPower'] as bool? ?? true;
          final isToggle = rawAction['isToggle'] as bool? ?? false;
          final durSec = (rawAction['durationSec'] as num?)?.toInt() ?? 0;
          final pulseMinutes = durSec > 0 ? (durSec / 60).round() : null;

          final actionWord = isToggle ? 'Toggle' : (targetPwr ? 'Turn On' : 'Turn Off');
          final pulseSuffix = pulseMinutes != null ? ' ($pulseMinutes m timer)' : '';

          actions.add(
            RoutineAction(
              kind: ch == 0 ? RoutineActionKind.allChannels : RoutineActionKind.switchChannel,
              title: 'Channel $ch • $actionWord',
              detail: '$actionWord Channel $ch$pulseSuffix',
              deviceId: devId,
              channelIndex: ch,
              targetState: targetPwr,
              isToggle: isToggle,
              pulseDurationMinutes: pulseMinutes,
            ),
          );
        }

        final routine = Routine.fromJson({
          'id': 'rt_$groupKey',
          'name': name,
          'icon': 'timer',
          'isFavorite': false,
          'enabled': anyEnabledOnHardware,
          'trigger': {
            'kind': 'timeSchedule',
            'title': 'Scheduled Trigger',
            'detail': timeStr,
            'timeOfDay': timeStr,
            'days': dayNames,
          },
          'schedule': {
            'label': timeStr,
            'days': dayNames,
            'timezone': 'IST',
          },
          'actions': actions.map((a) => a.toJson()).toList(),
        });

        await repo.upsertRoutineFromEdge(routine);
        syncedCount++;
      }

      if (ctrl != null) {
        ctrl.notifyListeners();
      }
      return syncedCount;
    } catch (e) {
      debugPrint('[EDGE-SYNC] syncRoutinesFromEdgeToApp error: $e');
      return 0;
    }
  }
}
