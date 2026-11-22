import 'package:flutter/foundation.dart';

enum HubConnectionStatus {
  notConfigured,
  discovering,
  adopting,
  connected,
  unreachable,
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
    this.channelCount = 3,
    this.channels = const {1: false, 2: false, 3: false},
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
  final int channelCount;
  final Map<int, bool> channels;

  factory HubDeviceInfo.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final chMap = <int, bool>{};
    if (rawChannels is Map) {
      rawChannels.forEach((k, v) {
        final idx = int.tryParse(k.toString()) ?? 1;
        chMap[idx] = v == true;
      });
    } else {
      chMap[1] = false;
      chMap[2] = false;
      chMap[3] = false;
    }

    return HubDeviceInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Smart Switch',
      ipAddress: json['ipAddress'] as String? ?? '',
      macAddress: json['macAddress'] as String? ?? '',
      roomName: json['roomName'] as String? ?? 'Unassigned',
      online: json['online'] as bool? ?? true,
      activeRoutinesCount: (json['activeRoutinesCount'] as num?)?.toInt() ?? 0,
      hasCriticalHardwareFallback:
          json['hasCriticalHardwareFallback'] as bool? ?? false,
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 3,
      channelCount: (json['channelCount'] as num?)?.toInt() ?? (chMap.isNotEmpty ? chMap.length : 3),
      channels: chMap,
    );
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
        'channelCount': channelCount,
        'channels': channels,
      };
}

@immutable
class HubState {
  const HubState({
    required this.status,
    this.hubId = 'eh-hub-pi3b',
    this.hostname = 'eh-hub.local',
    this.ipAddress = '192.168.0.174',
    this.model = 'EH-HUB-V1-PI (Raspberry Pi 3B+ Platform)',
    this.firmwareVersion = 'v1.0.0-phase51',
    this.uptime = '14 days, 6 hours',
    this.latencyMs = 3,
    this.connectedDevices = const [],
    this.standardRoutinesCount = 7,
    this.criticalRoutinesCount = 1,
    this.sdCardOverlayFsActive = true,
    this.localNtpSynced = true,
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
  final bool sdCardOverlayFsActive;
  final bool localNtpSynced;

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
    bool? sdCardOverlayFsActive,
    bool? localNtpSynced,
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
      sdCardOverlayFsActive:
          sdCardOverlayFsActive ?? this.sdCardOverlayFsActive,
      localNtpSynced: localNtpSynced ?? this.localNtpSynced,
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
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
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

