import 'package:flutter/foundation.dart';

enum HubConnectionStatus {
  notConfigured,
  discovering,
  adopting,
  connected,
  unreachable,
}

enum HubDeviceCategory {
  switches,
  sockets,
  fans,
  lighting,
  controllers,
  sensors,
  others;

  String get displayLabel {
    switch (this) {
      case HubDeviceCategory.switches:
        return 'Switches';
      case HubDeviceCategory.sockets:
        return 'Sockets';
      case HubDeviceCategory.fans:
        return 'Fans';
      case HubDeviceCategory.lighting:
        return 'Lighting';
      case HubDeviceCategory.controllers:
        return 'Controllers';
      case HubDeviceCategory.sensors:
        return 'Sensors';
      case HubDeviceCategory.others:
        return 'Others';
    }
  }

  static HubDeviceCategory resolve({
    String? explicitCategory,
    String? model,
    String? name,
  }) {
    final exp = (explicitCategory ?? '').toLowerCase().trim();
    for (final val in HubDeviceCategory.values) {
      if (val.name == exp) return val;
    }
    final combined = '${model ?? ''} ${name ?? ''}'.toLowerCase();
    if (combined.contains('sensor') ||
        combined.contains('sn-') ||
        combined.contains('pir') ||
        combined.contains('temp')) {
      return HubDeviceCategory.sensors;
    }
    if (combined.contains('fan') || combined.contains('fn-') || combined.contains('ceiling')) {
      return HubDeviceCategory.fans;
    }
    if (combined.contains('light') ||
        combined.contains('bulb') ||
        combined.contains('strip') ||
        combined.contains('dimmer')) {
      return HubDeviceCategory.lighting;
    }
    if (combined.contains('socket') ||
        combined.contains('sk-') ||
        combined.contains('-sk') ||
        combined.contains('plug')) {
      return HubDeviceCategory.sockets;
    }
    if (combined.contains('controller') ||
        combined.contains('ir-') ||
        combined.contains('curtain') ||
        combined.contains('gate')) {
      return HubDeviceCategory.controllers;
    }
    if (combined.contains('switch') ||
        combined.contains('sw-') ||
        combined.contains('-sw') ||
        combined.contains('sw1') ||
        combined.contains('sw2') ||
        combined.contains('sw3') ||
        combined.contains('sw4')) {
      return HubDeviceCategory.switches;
    }
    return HubDeviceCategory.others;
  }
}

@immutable
class HubDeviceInfo {
  const HubDeviceInfo({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.macAddress,
    required this.roomName,
    required this.online,
    required this.activeRoutinesCount,
    required this.hasCriticalHardwareFallback,
    required this.latencyMs,
    this.model,
    this.firmwareVersion,
    this.category = HubDeviceCategory.switches,
    this.channelCount = 3,
    this.channels = const {1: false, 2: false, 3: false},
    this.capabilities = const {},
    this.telemetry = const {},
    this.rssiDbm,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final String ipAddress;
  final String macAddress;
  final String roomName;
  final bool online;
  final int activeRoutinesCount;
  final bool hasCriticalHardwareFallback;
  final int latencyMs;
  final String? model;
  final String? firmwareVersion;
  final HubDeviceCategory category;
  final int channelCount;
  final Map<int, bool> channels;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> telemetry;
  final int? rssiDbm;
  final DateTime? lastSeenAt;

  static bool isGenericAutoName(String raw) {
    final n = raw.trim();
    if (n.isEmpty) return true;
    if (RegExp(r'^(EH\s+)?(Switch|Socket|Device)\s*\([a-fA-F0-9]+\)$').hasMatch(n)) {
      return true;
    }
    if (RegExp(r'^(Smart\s+)?(Switch|Socket|Device)$', caseSensitive: false).hasMatch(n)) {
      return true;
    }
    return false;
  }

  /// Resolves a clean full product name + variant (e.g. `EH Smart Socket 2X`)
  /// when Hub only reported a short fallback like `EH Socket (b699)`, while
  /// preserving explicit user-assigned names.
  String resolveCanonicalName({String? appCustomName, String? appModelVariant}) {
    if (appCustomName != null &&
        appCustomName.trim().isNotEmpty &&
        !isGenericAutoName(appCustomName)) {
      return appCustomName.trim();
    }
    if (!isGenericAutoName(name)) {
      return name.trim();
    }
    final mStr = (appModelVariant ?? model ?? '').toUpperCase();
    final gangMatch = RegExp(r'(\d)\s*X').firstMatch(mStr);
    final gang = gangMatch != null
        ? int.tryParse(gangMatch.group(1)!) ?? channelCount
        : channelCount;
    final hasEm = mStr.contains('EM') || capabilities['energyMonitoring'] == true;
    final emTag = hasEm ? ' (EM)' : '';
    final suffix = id.length >= 4 ? ' · ${id.substring(id.length - 4).toUpperCase()}' : '';

    switch (category) {
      case HubDeviceCategory.sockets:
        return 'EH Smart Socket${gang > 0 ? ' ${gang}X' : ''}$emTag$suffix';
      case HubDeviceCategory.switches:
        return 'EH Smart Switch${gang > 0 ? ' ${gang}X' : ''}$emTag$suffix';
      case HubDeviceCategory.fans:
        return 'EH Smart Fan Controller$suffix';
      case HubDeviceCategory.lighting:
        return 'EH Smart Lighting${gang > 0 ? ' ${gang}X' : ''}$suffix';
      case HubDeviceCategory.controllers:
        return 'EH Smart Controller$suffix';
      case HubDeviceCategory.sensors:
        return 'EH Smart Sensor Node$suffix';
      case HubDeviceCategory.others:
        return 'EH Smart Device$suffix';
    }
  }

  HubDeviceInfo copyWith({
    String? id,
    String? name,
    String? ipAddress,
    String? macAddress,
    String? roomName,
    bool? online,
    int? activeRoutinesCount,
    bool? hasCriticalHardwareFallback,
    int? latencyMs,
    String? model,
    String? firmwareVersion,
    HubDeviceCategory? category,
    int? channelCount,
    Map<int, bool>? channels,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? telemetry,
    int? rssiDbm,
    bool clearRssi = false,
    DateTime? lastSeenAt,
  }) {
    return HubDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      roomName: roomName ?? this.roomName,
      online: online ?? this.online,
      activeRoutinesCount: activeRoutinesCount ?? this.activeRoutinesCount,
      hasCriticalHardwareFallback:
          hasCriticalHardwareFallback ?? this.hasCriticalHardwareFallback,
      latencyMs: latencyMs ?? this.latencyMs,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      category: category ?? this.category,
      channelCount: channelCount ?? this.channelCount,
      channels: channels ?? this.channels,
      capabilities: capabilities ?? this.capabilities,
      telemetry: telemetry ?? this.telemetry,
      rssiDbm: clearRssi ? null : (rssiDbm ?? this.rssiDbm),
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory HubDeviceInfo.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final chMap = <int, bool>{};
    if (rawChannels is Map) {
      rawChannels.forEach((k, v) {
        final idx = int.tryParse(k.toString()) ?? 1;
        chMap[idx] = v == true;
      });
    }

    final rawModel = json['model'] as String?;
    final rawName = json['name'] as String? ?? '';
    final cat = HubDeviceCategory.resolve(
      explicitCategory: json['category'] as String?,
      model: rawModel,
      name: rawName,
    );
    final rawCaps = json['capabilities'] is Map
        ? Map<String, dynamic>.from(json['capabilities'] as Map)
        : const <String, dynamic>{};
    final rawTel = json['telemetry'] is Map
        ? Map<String, dynamic>.from(json['telemetry'] as Map)
        : const <String, dynamic>{};

    final chCount = (json['channelCount'] as num?)?.toInt() ??
        (cat == HubDeviceCategory.sensors
            ? 0
            : (chMap.isNotEmpty ? chMap.length : (cat == HubDeviceCategory.sockets ? 2 : 3)));

    final resolved = HubDeviceInfo(
      id: json['id'] as String? ?? '',
      name: rawName.isNotEmpty ? rawName : 'Smart Device',
      ipAddress: json['ipAddress'] as String? ?? '',
      macAddress: json['macAddress'] as String? ?? '',
      roomName: json['roomName'] as String? ?? 'Unassigned',
      online: json['online'] as bool? ?? false,
      activeRoutinesCount: (json['activeRoutinesCount'] as num?)?.toInt() ?? 0,
      hasCriticalHardwareFallback:
          json['hasCriticalHardwareFallback'] as bool? ?? false,
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 3,
      model: rawModel,
      firmwareVersion: json['firmwareVersion'] as String?,
      category: cat,
      channelCount: chCount,
      channels: chMap,
      capabilities: rawCaps,
      telemetry: rawTel,
      rssiDbm: (json['rssiDbm'] as num?)?.toInt() ?? (json['rssi'] as num?)?.toInt(),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'].toString())
          : null,
    );
    return resolved.copyWith(name: resolved.resolveCanonicalName());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ipAddress': ipAddress,
        'macAddress': macAddress,
        'roomName': roomName,
        'online': online,
        'activeRoutinesCount': activeRoutinesCount,
        'hasCriticalHardwareFallback': hasCriticalHardwareFallback,
        'latencyMs': latencyMs,
        if (model != null) 'model': model,
        if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
        'category': category.name,
        'channelCount': channelCount,
        'channels': channels.map((k, v) => MapEntry(k.toString(), v)),
        'capabilities': capabilities,
        'telemetry': telemetry,
        if (rssiDbm != null) 'rssiDbm': rssiDbm,
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
      };
}

@immutable
class HubState {
  const HubState({
    required this.status,
    this.hubId = '',
    this.hostname = '',
    this.ipAddress = '',
    this.model = 'EH Smart Hub',
    this.firmwareVersion = '',
    this.uptime = '—',
    this.latencyMs = 0,
    this.connectedDevices = const [],
    this.standardRoutinesCount = 0,
    this.criticalRoutinesCount = 0,
    this.activeTimersCount = 0,
    this.storageEngine = 'atomic-wal',
    this.sdCardOverlayFsActive = false,
    this.localNtpSynced = false,
    this.rssiDbm,
  });

  final HubConnectionStatus status;
  final String hubId;
  final String hostname;
  final String ipAddress;
  final String model;
  final String firmwareVersion;
  final String uptime;
  final int latencyMs;
  final List<HubDeviceInfo> connectedDevices;
  final int standardRoutinesCount;
  final int criticalRoutinesCount;
  final int activeTimersCount;
  final String storageEngine;
  final bool sdCardOverlayFsActive;
  final bool localNtpSynced;
  final int? rssiDbm;

  bool get isLinked => status == HubConnectionStatus.connected;

  HubState copyWith({
    HubConnectionStatus? status,
    String? hubId,
    String? hostname,
    String? ipAddress,
    String? model,
    String? firmwareVersion,
    String? uptime,
    int? latencyMs,
    List<HubDeviceInfo>? connectedDevices,
    int? standardRoutinesCount,
    int? criticalRoutinesCount,
    int? activeTimersCount,
    String? storageEngine,
    bool? sdCardOverlayFsActive,
    bool? localNtpSynced,
    int? rssiDbm,
  }) {
    return HubState(
      status: status ?? this.status,
      hubId: hubId ?? this.hubId,
      hostname: hostname ?? this.hostname,
      ipAddress: ipAddress ?? this.ipAddress,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      uptime: uptime ?? this.uptime,
      latencyMs: latencyMs ?? this.latencyMs,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      standardRoutinesCount:
          standardRoutinesCount ?? this.standardRoutinesCount,
      criticalRoutinesCount:
          criticalRoutinesCount ?? this.criticalRoutinesCount,
      activeTimersCount: activeTimersCount ?? this.activeTimersCount,
      storageEngine: storageEngine ?? this.storageEngine,
      sdCardOverlayFsActive:
          sdCardOverlayFsActive ?? this.sdCardOverlayFsActive,
      localNtpSynced: localNtpSynced ?? this.localNtpSynced,
      rssiDbm: rssiDbm ?? this.rssiDbm,
    );
  }
}

@immutable
class CrossDeviceRule {
  const CrossDeviceRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.triggerDeviceId,
    required this.triggerChannel,
    this.triggerState,
    required this.actionDeviceId,
    required this.actionDeviceIp,
    required this.actionChannel,
    this.actionCommand = 'TOGGLE',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool enabled;
  final String triggerDeviceId;
  final int triggerChannel;
  final bool? triggerState; // true = ON, false = OFF, null = Any
  final String actionDeviceId;
  final String actionDeviceIp;
  final int actionChannel;
  final String actionCommand; // 'ON', 'OFF', 'TOGGLE'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CrossDeviceRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    String? triggerDeviceId,
    int? triggerChannel,
    bool? triggerState,
    bool clearTriggerState = false,
    String? actionDeviceId,
    String? actionDeviceIp,
    int? actionChannel,
    String? actionCommand,
  }) {
    return CrossDeviceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      triggerDeviceId: triggerDeviceId ?? this.triggerDeviceId,
      triggerChannel: triggerChannel ?? this.triggerChannel,
      triggerState: clearTriggerState ? null : (triggerState ?? this.triggerState),
      actionDeviceId: actionDeviceId ?? this.actionDeviceId,
      actionDeviceIp: actionDeviceIp ?? this.actionDeviceIp,
      actionChannel: actionChannel ?? this.actionChannel,
      actionCommand: actionCommand ?? this.actionCommand,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory CrossDeviceRule.fromJson(Map<String, dynamic> json) {
    return CrossDeviceRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Cross-Device Rule',
      enabled: json['enabled'] != false,
      triggerDeviceId: json['triggerDeviceId'] as String? ?? '',
      triggerChannel: (json['triggerChannel'] as num?)?.toInt() ?? 1,
      triggerState: json['triggerState'] as bool?,
      actionDeviceId: json['actionDeviceId'] as String? ?? '',
      actionDeviceIp: json['actionDeviceIp'] as String? ?? '',
      actionChannel: (json['actionChannel'] as num?)?.toInt() ?? 1,
      actionCommand: json['actionCommand'] as String? ?? 'TOGGLE',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'triggerDeviceId': triggerDeviceId,
        'triggerChannel': triggerChannel,
        'triggerState': triggerState,
        'actionDeviceId': actionDeviceId,
        'actionDeviceIp': actionDeviceIp,
        'actionChannel': actionChannel,
        'actionCommand': actionCommand,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

@immutable
class AutomationExecutionLog {
  const AutomationExecutionLog({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.triggerEvent,
    required this.actionSummary,
    required this.latencyMs,
    required this.status,
    required this.timestamp,
  });

  final String id;
  final String ruleId;
  final String ruleName;
  final String triggerEvent;
  final String actionSummary;
  final int latencyMs;
  final String status;
  final DateTime timestamp;

  factory AutomationExecutionLog.fromJson(Map<String, dynamic> json) {
    return AutomationExecutionLog(
      id: json['id'] as String? ?? '',
      ruleId: json['ruleId'] as String? ?? '',
      ruleName: json['ruleName'] as String? ?? '',
      triggerEvent: json['triggerEvent'] as String? ?? '',
      actionSummary: json['actionSummary'] as String? ?? '',
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'OK',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'triggerEvent': triggerEvent,
        'actionSummary': actionSummary,
        'latencyMs': latencyMs,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };
}

@immutable
class HubActiveTimer {
  const HubActiveTimer({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.deviceId,
    required this.channel,
    required this.targetState,
    required this.remainingSec,
    required this.fireAtEpoch,
  });

  final String id;
  final String routineId;
  final String routineName;
  final String deviceId;
  final int channel;
  final bool targetState;
  final int remainingSec;
  final int fireAtEpoch;

  factory HubActiveTimer.fromJson(Map<String, dynamic> json) {
    final fireAt = (json['fireAtEpoch'] as num?)?.toInt() ?? 0;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final computedRem = fireAt > nowSec ? (fireAt - nowSec) : 0;
    return HubActiveTimer(
      id: json['id'] as String? ?? '',
      routineId: json['routineId'] as String? ?? '',
      routineName: json['routineName'] as String? ?? 'Auto-Off Timer',
      deviceId: json['deviceId'] as String? ?? '',
      channel: (json['channel'] as num?)?.toInt() ?? 1,
      targetState: json['targetState'] as bool? ?? false,
      remainingSec: (json['remainingSec'] as num?)?.toInt() ?? computedRem,
      fireAtEpoch: fireAt,
    );
  }
}

@immutable
class HubBackupSummary {
  const HubBackupSummary({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.devicesCount,
    required this.routinesCount,
    required this.rulesCount,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final int devicesCount;
  final int routinesCount;
  final int rulesCount;

  factory HubBackupSummary.fromJson(Map<String, dynamic> json) {
    return HubBackupSummary(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Hub Backup',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      devicesCount: (json['devicesCount'] as num?)?.toInt() ?? 0,
      routinesCount: (json['routinesCount'] as num?)?.toInt() ?? 0,
      rulesCount: (json['rulesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class HubWebhookRule {
  const HubWebhookRule({
    required this.id,
    required this.name,
    required this.event,
    this.routineId,
    this.deviceId,
    this.channel = 1,
    this.state = true,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String event;
  final String? routineId;
  final String? deviceId;
  final int channel;
  final bool state;
  final bool enabled;

  factory HubWebhookRule.fromJson(Map<String, dynamic> json) {
    return HubWebhookRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Webhook Trigger',
      event: json['event'] as String? ?? 'voice.command',
      routineId: json['routineId'] as String?,
      deviceId: json['deviceId'] as String?,
      channel: (json['channel'] as num?)?.toInt() ?? 1,
      state: json['state'] != false,
      enabled: json['enabled'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'event': event,
        if (routineId != null) 'routineId': routineId,
        if (deviceId != null) 'deviceId': deviceId,
        'channel': channel,
        'state': state,
        'enabled': enabled,
      };
}
