import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  static final Map<String, ({Routine routine, DateTime expiresAt})> _activeChannelRoutines = {};

  static String _normId(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void registerActiveRoutineExecution(
    Routine routine, {
    int? targetChannel,
    int pulseDurationSeconds = 60,
  }) {
    final effectiveSec = pulseDurationSeconds > 0 ? pulseDurationSeconds : 60;
    final expiresAt = DateTime.now().add(Duration(seconds: effectiveSec));
    final chSet = <int>{};
    if (targetChannel != null && targetChannel > 0) {
      chSet.add(targetChannel);
    } else if (targetChannel == 0) {
      chSet.addAll([1, 2, 3, 4]);
    } else if (routine.actions.isNotEmpty) {
      for (final a in routine.actions) {
        if (a.channelIndex == 0 || a.kind == RoutineActionKind.allChannels) {
          chSet.addAll([1, 2, 3, 4]);
        } else {
          chSet.add(a.channelIndex.clamp(1, 4));
        }
      }
    } else {
      chSet.add(1);
    }

    final isGlobalTarget = routine.actions.any((a) =>
        a.deviceId.isEmpty || a.deviceId == 'all' || a.deviceId == 'all_sockets');

    for (final ch in chSet) {
      for (final dev in routine.involvedDevices) {
        _activeChannelRoutines['${dev.id}_$ch'] = (routine: routine, expiresAt: expiresAt);
        _activeChannelRoutines['${dev.id.toLowerCase()}_$ch'] = (routine: routine, expiresAt: expiresAt);
        final norm = _normId(dev.id);
        if (norm.isNotEmpty) {
          _activeChannelRoutines['${norm}_$ch'] = (routine: routine, expiresAt: expiresAt);
        }
      }
      for (final a in routine.actions) {
        if (a.deviceId.isNotEmpty && a.deviceId != 'all' && a.deviceId != 'all_sockets') {
          _activeChannelRoutines['${a.deviceId}_$ch'] = (routine: routine, expiresAt: expiresAt);
          _activeChannelRoutines['${a.deviceId.toLowerCase()}_$ch'] = (routine: routine, expiresAt: expiresAt);
          final norm = _normId(a.deviceId);
          if (norm.isNotEmpty) {
            _activeChannelRoutines['${norm}_$ch'] = (routine: routine, expiresAt: expiresAt);
          }
        }
      }
      if (isGlobalTarget) {
        _activeChannelRoutines['ALL_$ch'] = (routine: routine, expiresAt: expiresAt);
      }
    }
    HomeController.instance?.refreshRoutineWarningState();
  }

  /// Returns an actively running routine override (e.g. from Test Run, schedule fire,
  /// or live hardware RUNNING state) if one is currently active on [deviceId]/[channel].
  Routine? getActiveOverrideRoutine(String deviceId, int channel) {
    final now = DateTime.now();
    final norm = _normId(deviceId);
    final keysToCheck = <String>[
      '${deviceId}_$channel',
      '${deviceId.toLowerCase()}_$channel',
      if (norm.isNotEmpty) '${norm}_$channel',
      'ALL_$channel',
    ];
    for (final key in keysToCheck) {
      final entry = _activeChannelRoutines[key];
      if (entry != null) {
        if (!now.isBefore(entry.expiresAt)) {
          _activeChannelRoutines.remove(key);
          continue;
        }
        // Check if routine was disabled in PreviewRoutineRepository after registration
        final r = entry.routine;
        if (!r.id.startsWith('test_')) {
          final live = PreviewRoutineRepository.liveRoutines.cast<Routine?>().firstWhere(
            (lr) => lr != null && (lr.id == r.id || extractCoreId(lr.id) == extractCoreId(r.id)),
            orElse: () => null,
          );
          if (live != null && !live.enabled) {
            _activeChannelRoutines.remove(key);
            continue;
          }
        }
        return r;
      }
    }
    return null;
  }

  void clearActiveRoutineExecution(String deviceId, int channel) {
    final norm = _normId(deviceId);
    _activeChannelRoutines.remove('${deviceId}_$channel');
    _activeChannelRoutines.remove('${deviceId.toLowerCase()}_$channel');
    if (norm.isNotEmpty) {
      _activeChannelRoutines.remove('${norm}_$channel');
    }
    _activeChannelRoutines.remove('ALL_$channel');
    HomeController.instance?.refreshRoutineWarningState();
  }

  /// Applies live running routine state reported inside ESP32 UDP broadcasts.
  void ingestHardwareActiveRoutines(
    String deviceId,
    List<Map<String, dynamic>>? activeList,
  ) {
    if (deviceId.isEmpty || activeList == null) return;
    final normDev = _normId(deviceId);
    final activeChannels = <int>{};
    for (final item in activeList) {
      final ch = (item['channelIndex'] as num?)?.toInt() ?? 1;
      final remSec = (item['remainingSec'] as num?)?.toInt() ?? 60;
      final rId = item['id']?.toString() ?? '';
      final rName = item['name']?.toString() ?? 'Edge Routine';
      activeChannels.add(ch);
      final rCore = extractCoreId(rId);
      final matched = PreviewRoutineRepository.liveRoutines.cast<Routine?>().firstWhere(
        (lr) =>
            lr != null &&
            (lr.id == rId ||
                (rCore.isNotEmpty && extractCoreId(lr.id) == rCore) ||
                lr.name.trim().toLowerCase() == rName.trim().toLowerCase()),
        orElse: () => null,
      );
      if (matched != null && !matched.enabled) {
        continue;
      }
      final effectiveRoutine = matched ??
          Routine(
            id: rId.isNotEmpty ? rId : 'edge_${normDev}_ch$ch',
            name: rName,
            icon: 'timer',
            isFavorite: false,
            enabled: true,
            availability: RoutineAvailability.available,
            trigger: const RoutineTrigger(
              kind: RoutineTriggerKind.timeSchedule,
              title: 'Hardware Schedule',
              detail: 'Active',
            ),
            conditions: const [],
            actions: [
              RoutineAction(
                kind: RoutineActionKind.switchChannel,
                title: 'Channel $ch',
                detail: 'Hardware Routine',
                deviceId: deviceId,
                channelIndex: ch,
                targetState: true,
              ),
            ],
            schedule: const RoutineSchedule(label: 'Active', days: [], timezone: 'IST'),
            involvedDevices: [
              RoutineDevice(
                id: deviceId,
                name: deviceId,
                room: '',
                online: true,
                capabilities: const [],
              ),
            ],
            lastExecution: null,
            nextRun: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            summary: rName,
          );
      registerActiveRoutineExecution(
        effectiveRoutine,
        targetChannel: ch,
        pulseDurationSeconds: remSec > 0 ? remSec : 60,
      );
    }
    for (int ch = 1; ch <= 4; ch++) {
      if (!activeChannels.contains(ch)) {
        final existing = getActiveOverrideRoutine(deviceId, ch);
        if (existing != null && !existing.id.startsWith('test_')) {
          clearActiveRoutineExecution(deviceId, ch);
        }
      }
    }
  }

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
    var core = routineId.replaceAll(RegExp(r'^(rt_|routine_|auto_|xrule_)+'), '');
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

  /// Syncs an entire Routine to the Smart Home Hub LAN scheduler API
  Future<bool> syncRoutineToHub(Routine routine, {bool? forceEnabled}) async {
    final isEnabled = forceEnabled ?? routine.enabled;
    final (hour, minute) = parseTimeOfDay(routine.trigger, routine.schedule);
    final daysMask = computeDaysMask(
      routine.trigger.days.isNotEmpty ? routine.trigger.days : routine.schedule.days,
    );
    final triggerType = routine.trigger.kind == RoutineTriggerKind.manual ? 0 : 2;
    final hostCandidates = LiveHubRepository.getCandidateHosts(LiveHubRepository.activeHost);
    if (hostCandidates.isEmpty) return false;

    bool anySuccess = false;
    final client = http.Client();
    try {
      for (int i = 0; i < routine.actions.length; i++) {
        final act = routine.actions[i];
        if (act.deviceId.isEmpty) continue;
        final pulseSec = (act.pulseDurationMinutes ?? 0) * 60;
        final hubRoutineId = routine.actions.length == 1
            ? routine.id
            : '${routine.id}_a${i}_c${act.channelIndex}';
        final payload = jsonEncode({
          'id': hubRoutineId,
          'name': routine.name,
          'deviceId': act.deviceId,
          'channel': act.channelIndex,
          'targetState': act.targetState,
          'power': act.targetState,
          'value': act.targetState,
          'isToggle': act.isToggle,
          'toggle': act.isToggle,
          'durationSec': pulseSec,
          'triggerType': (pulseSec > 0 && triggerType != 2) ? 1 : triggerType,
          'hour': hour,
          'minute': minute,
          'daysMask': daysMask,
          'enabled': isEnabled,
          'criticalHardwareFallback': routine.isCritical,
        });

        for (final host in hostCandidates.take(4)) {
          try {
            final res = await client
                .post(
                  Uri.parse('http://$host:4210/api/v1/routines'),
                  headers: {'Content-Type': 'application/json'},
                  body: payload,
                )
                .timeout(const Duration(milliseconds: 900));
            if (res.statusCode == 200 || res.statusCode == 201) {
              anySuccess = true;
              break;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
    return anySuccess;
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

    // Clean up stale or obsolete routine IDs on target boards belonging to this routine (or same-name duplicates)
    final normRoutineName = routine.name.trim().toLowerCase();
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
            final eName = existing['name']?.toString().trim().toLowerCase() ?? '';
            final matchesById = eId.contains(routineCore) ||
                eId == routine.id ||
                eId.startsWith('rt_$routineCore') ||
                eId.contains(routine.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''));
            final matchesByName = normRoutineName.isNotEmpty && eName == normRoutineName;
            if ((matchesById || matchesByName) && !expected.contains(eId)) {
              debugPrint('[EDGE-SYNC] Pruning stale/duplicate edge routine "$eId" ($eName) on $ip');
              await LocalLanDeviceService.instance.sendLocalRoutineDelete(
                deviceId: '',
                routineId: eId,
                explicitIp: ip,
              );
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
  bool isRoutineCurrentlyActive(Routine routine, {int? targetChannel, bool? currentPower}) {
    if (!routine.enabled) return false;
    final now = DateTime.now();

    // 0. Explicit in-memory active routine execution check (registered on schedule trigger, test run, or hardware RUNNING state)
    final checkChannels = targetChannel != null ? [targetChannel] : [1, 2, 3, 4];
    final isGlobalTarget = routine.actions.any((a) =>
        a.deviceId.isEmpty || a.deviceId == 'all' || a.deviceId == 'all_sockets');
    for (final ch in checkChannels) {
      final keysToCheck = <String>[
        if (isGlobalTarget) 'ALL_$ch',
        for (final dev in routine.involvedDevices) ...[
          '${dev.id}_$ch',
          '${dev.id.toLowerCase()}_$ch',
          if (_normId(dev.id).isNotEmpty) '${_normId(dev.id)}_$ch',
        ],
        for (final a in routine.actions)
          if (a.deviceId.isNotEmpty && a.deviceId != 'all' && a.deviceId != 'all_sockets') ...[
            '${a.deviceId}_$ch',
            '${a.deviceId.toLowerCase()}_$ch',
            if (_normId(a.deviceId).isNotEmpty) '${_normId(a.deviceId)}_$ch',
          ],
      ];
      for (final key in keysToCheck) {
        final active = _activeChannelRoutines[key];
        if (active != null) {
          if (now.isBefore(active.expiresAt)) {
            if (active.routine.id == routine.id ||
                extractCoreId(active.routine.id) == extractCoreId(routine.id)) {
              return true;
            }
          } else {
            _activeChannelRoutines.remove(key);
          }
        }
      }
    }

    // 1. Identify relevant actions
    final relevantActions = targetChannel != null
        ? routine.actions.where((a) => a.channelIndex == 0 || a.channelIndex == targetChannel).toList()
        : routine.actions;

    if (relevantActions.isEmpty) return false;

    // 2. Check active pulse/execution duration window (60s window for no-timer ON/OFF/Toggle actions when triggered)
    int maxPulseSec = 0;
    for (final act in relevantActions) {
      if (act.pulseDurationMinutes != null && act.pulseDurationMinutes! > 0) {
        final sec = act.pulseDurationMinutes! * 60;
        if (sec > maxPulseSec) {
          maxPulseSec = sec;
        }
      }
    }
    final effectiveWindowSec = maxPulseSec > 0 ? maxPulseSec : 60;

    // 3. Physical hardware state check for timed ON/OFF pulses after 10s telemetry settling
    // (Skip for Toggle since state flips, and skip for continuous ON/OFF actions without a pulse timer.)
    if (currentPower != null && maxPulseSec > 0 && targetChannel != null) {
      final act = relevantActions.first;
      if (!act.isToggle) {
        final (h, m) = parseTimeOfDay(routine.trigger, routine.schedule);
        final scheduleStart = DateTime(now.year, now.month, now.day, h, m);
        final elapsedFromSchedule = now.difference(scheduleStart).inSeconds;
        final elapsedFromExec = routine.lastExecution != null
            ? now.difference(routine.lastExecution!.completedAt).inSeconds
            : 9999;
        final withinSettlingGrace =
            (elapsedFromSchedule >= 0 && elapsedFromSchedule < 10) ||
            (elapsedFromExec >= 0 && elapsedFromExec < 10);
        if (!withinSettlingGrace && currentPower != act.targetState) {
          return false;
        }
      }
    }

    // 4. Time schedule check
    if (routine.trigger.kind == RoutineTriggerKind.timeSchedule) {
      final (h, m) = parseTimeOfDay(routine.trigger, routine.schedule);
      if (h >= 0 && m >= 0) {
        if (routine.trigger.days.isNotEmpty) {
          const dayMap = {1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat', 7: 'sun'};
          final curDay = dayMap[now.weekday] ?? '';
          final dayMatches = routine.trigger.days.any((d) => d.toString().toLowerCase().startsWith(curDay));
          if (!dayMatches) return false;
        }

        final scheduleStart = DateTime(now.year, now.month, now.day, h, m);
        final scheduleEnd = scheduleStart.add(Duration(seconds: effectiveWindowSec));

        if (!now.isBefore(scheduleStart) && now.isBefore(scheduleEnd)) {
          return true;
        }
      }
    }

    // 5. Recent execution within pulse/execution window
    if (routine.lastExecution != null) {
      final execTime = routine.lastExecution!.completedAt;
      final diffSec = now.difference(execTime).inSeconds;
      if (diffSec >= 0 && diffSec < effectiveWindowSec) {
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
        if (routine.trigger.kind == RoutineTriggerKind.deviceState) {
          continue; // Cross-device rules are synced via /api/v1/peer-rules, not timed 07:00 routines
        }
        // CRITICAL FIX: If a routine is currently running on the board, DO NOT POST routine upsert
        // which resets the ESP32 on-chip timer and stops the routine mid-operation!
        if (!force && isRoutineCurrentlyActive(routine)) {
          debugPrint('[EDGE-SYNC] Skipping reconcile for active routine "${routine.name}" to prevent interrupting running on-chip pulse.');
          continue;
        }
        if (isHubActive && !routine.isCritical) {
          // Master spec: Hub is active and this routine is standard comfort -> MUST NOT exist on ESP32 flash!
          await deleteRoutineFromEdge(routine);
          await syncRoutineToHub(routine);
          continue;
        }
        if (isHubActive) {
          await syncRoutineToHub(routine);
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
      await repo.removeRoutineLocalOnly('rt_1793441276621_a0_c1');
      await repo.removeRoutineLocalOnly('1793441276621');

      int syncedCount = 0;
      final existingRoutines = await repo.getRoutines();

      // Group edge raw items by logical routine (using core ID or normalized name)
      final groupedEdgeRoutines = <String, List<Map<String, dynamic>>>{};
      for (final raw in edgeRoutines) {
        final id = raw['id']?.toString() ?? '';
        if (id.isEmpty || id == 'test_sched_1') continue;

        final rawName = raw['name']?.toString() ?? 'Edge Routine';
        final lowerName = rawName.trim().toLowerCase();
        // Clean up legacy bogus 07:00 Cross-Device entries that were erroneously pushed to /api/v1/routines
        if (id.startsWith('xrule_') || lowerName.contains('cross-device rule')) {
          unawaited(LocalLanDeviceService.instance.sendLocalRoutineDelete(
            deviceId: devId,
            routineId: id,
          ));
          continue;
        }

        final core = extractCoreId(id);
        final groupKey = core.isNotEmpty && core != 'rt'
            ? core
            : 'name:$lowerName';
        groupedEdgeRoutines.putIfAbsent(groupKey, () => []).add(raw);
      }

      bool runningStateChanged = false;

      for (final entry in groupedEdgeRoutines.entries) {
        final groupKey = entry.key;
        final items = entry.value;
        if (items.isEmpty) continue;

        final firstRaw = items.first;
        final name = firstRaw['name']?.toString() ?? 'Edge Routine';
        final normName = name.trim().toLowerCase();

        // Check if this routine already exists in app storage (by ID, core ID, or exact name)
        Routine? existing;
        for (final r in existingRoutines) {
          if (r.id == groupKey ||
              extractCoreId(r.id) == groupKey ||
              (normName.isNotEmpty && r.name.trim().toLowerCase() == normName)) {
            existing = r;
            break;
          }
        }

        final anyEnabledOnHardware = items.any((it) => it['enabled'] == true);
        final runningItem = items.cast<Map<String, dynamic>?>().firstWhere(
          (it) => it != null && it['state']?.toString().toUpperCase() == 'RUNNING',
          orElse: () => null,
        );

        if (existing != null) {
          // App state is authoritative for user toggles: NEVER let stale/duplicate enabled NVS entries
          // silently re-enable a disabled routine on pull-to-refresh!
          final pendingToggle = DeviceStorageService.getPendingRoutineToggle(
            existing.id,
            routineName: existing.name,
          );
          final authoritativeEnabled = pendingToggle ?? existing.enabled;
          var effectiveExisting = existing;
          if (pendingToggle != null && existing.enabled != pendingToggle) {
            effectiveExisting = existing.copyWith(enabled: pendingToggle);
            await repo.upsertRoutineFromEdge(effectiveExisting);
          }
          if (anyEnabledOnHardware != authoritativeEnabled || items.length > 1) {
            // Hardware has stale toggle state or duplicate slots -> push authoritative app state down
            unawaited(syncRoutineToEdge(effectiveExisting, forceEnabled: authoritativeEnabled));
          }
          if (runningItem != null && effectiveExisting.enabled) {
            final remSec = (runningItem['remainingSec'] as num?)?.toInt() ?? 0;
            final ch = (runningItem['channelIndex'] as num?)?.toInt() ?? 1;
            final prev = getActiveOverrideRoutine(devId, ch);
            registerActiveRoutineExecution(
              effectiveExisting,
              targetChannel: ch,
              pulseDurationSeconds: remSec > 0 ? remSec : 60,
            );
            if (prev == null || prev.id != effectiveExisting.id) {
              runningStateChanged = true;
            }
          } else {
            for (final it in items) {
              final ch = (it['channelIndex'] as num?)?.toInt() ?? 1;
              final prev = getActiveOverrideRoutine(devId, ch);
              if (prev != null &&
                  (prev.id == effectiveExisting.id ||
                      extractCoreId(prev.id) == extractCoreId(effectiveExisting.id))) {
                clearActiveRoutineExecution(devId, ch);
                runningStateChanged = true;
              }
            }
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
        if (runningItem != null && routine.enabled) {
          final remSec = (runningItem['remainingSec'] as num?)?.toInt() ?? 0;
          final ch = (runningItem['channelIndex'] as num?)?.toInt() ?? 1;
          registerActiveRoutineExecution(
            routine,
            targetChannel: ch,
            pulseDurationSeconds: remSec > 0 ? remSec : 60,
          );
        }
        syncedCount++;
      }

      if (ctrl != null) {
        if (runningStateChanged) {
          ctrl.refreshRoutineWarningState();
        }
        ctrl.notifyListeners();
      }
      return syncedCount;
    } catch (e) {
      debugPrint('[EDGE-SYNC] syncRoutinesFromEdgeToApp error: $e');
      return 0;
    }
  }
}
