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

  factory HubDeviceInfo.fromJson(Map<String, dynamic> json) {
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

