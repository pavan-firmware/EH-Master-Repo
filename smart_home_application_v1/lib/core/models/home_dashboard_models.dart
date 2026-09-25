/// Dashboard domain types deliberately stay independent from BLE, Wi-Fi, or
/// cloud APIs. A repository/controller maps transport events into these values.
enum HomeDashboardState {
  loading,
  setupRequired,
  deviceFound,
  wifiRequired,
  ready,
  partial,
  warning,
  critical,
  offline,
  noInternet,
}

enum TelemetryFreshness { current, recent, stale, unknown }

enum ConnectivityCause {
  online,
  bleDisconnected,
  deviceOffline,
  wifiUnavailable,
  internetUnavailable,
  backendUnavailable,
  unknown,
}

enum ActuatorConfidence { confirmed, pending, failed, unavailable, unknown }

enum AlertSeverity { informational, maintenance, warning, critical }

enum PermissionLifecycle { granted, denied, permanentlyDenied, unavailable }

enum DeviceLifecycle {
  newDevice,
  configured,
  reset,
  removed,
  replaced,
  reProvisioned,
}

enum DashboardDataSource { live, cached, preview }

/// Immutable values provisioned at manufacturing time. These are never used as
/// the user-facing name shown in the dashboard.
class FactoryDeviceIdentity {
  const FactoryDeviceIdentity({
    required this.deviceId,
    required this.serialNumber,
    required this.model,
    required this.hardwareRevision,
  });

  final String deviceId;
  final String serialNumber;
  final String model;
  final String hardwareRevision;
}

/// Mutable customer-owned configuration kept separate from factory identity.
class UserDeviceConfiguration {
  const UserDeviceConfiguration({
    required this.displayName,
    required this.roomId,
    required this.lifecycle,
  });

  final String displayName;
  final String roomId;
  final DeviceLifecycle lifecycle;
}

class DashboardAlert {
  const DashboardAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.freshness,
    this.lastChecked,
  });

  final String title;
  final String message;
  final AlertSeverity severity;
  final TelemetryFreshness freshness;
  final DateTime? lastChecked;

  /// Safety data is only actionable when it was received from a current,
  /// trusted source. Cached/stale safety values are historical information.
  bool get canRepresentCurrentSafetyState =>
      freshness == TelemetryFreshness.current;

  String get safeDisplayMessage {
    if (severity == AlertSeverity.critical && !canRepresentCurrentSafetyState) {
      final checked = lastChecked == null
          ? ''
          : ' Last checked ${_timeLabel(lastChecked!)}.';
      return 'State unavailable.$checked';
    }
    return message;
  }
}

class RoomPreview {
  const RoomPreview({
    required this.id,
    required this.name,
    required this.deviceCount,
    this.devicesOnCount = 0,
    required this.summary,
    required this.status,
    required this.isAttention,
    required this.freshness,
    required this.iconKey,
  });

  final String id;
  final String name;
  final int deviceCount;
  final int devicesOnCount;
  final String summary;
  final String status;
  final bool isAttention;
  final TelemetryFreshness freshness;
  final String iconKey;
}

class SpaceOnSummary {
  const SpaceOnSummary({
    required this.spaceId,
    required this.spaceName,
    required this.icon,
    required this.devicesOnCount,
    required this.onDeviceNames,
  });

  final String spaceId;
  final String spaceName;
  final String icon;
  final int devicesOnCount;
  final List<String> onDeviceNames;
}

class SpaceAlertItem {
  const SpaceAlertItem({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.roomId,
    this.deviceId,
  });

  final String id;
  final String spaceId;
  final String spaceName;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String? roomId;
  final String? deviceId;
}

class UpcomingRoutineItem {
  const UpcomingRoutineItem({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.spaceIcon,
    required this.title,
    required this.timeLabel,
    required this.iconKey,
    required this.isEnabled,
  });

  final String id;
  final String spaceId;
  final String spaceName;
  final String spaceIcon;
  final String title;
  final String timeLabel;
  final String iconKey;
  final bool isEnabled;
}

class GroupControlItem {
  const GroupControlItem({
    required this.id,
    required this.spaceId,
    required this.label,
    required this.kind,
    required this.targetControlIds,
    this.isEnabled = true,
    this.isOn = false,
    this.value = 0.0,
  });

  final String id;
  final String spaceId;
  final String label;
  final QuickControlKind kind;
  final List<String> targetControlIds;
  final bool isEnabled;
  final bool isOn;
  final double value;

  GroupControlItem copyWith({
    String? id,
    String? spaceId,
    String? label,
    QuickControlKind? kind,
    List<String>? targetControlIds,
    bool? isEnabled,
    bool? isOn,
    double? value,
  }) {
    return GroupControlItem(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      targetControlIds: targetControlIds ?? this.targetControlIds,
      isEnabled: isEnabled ?? this.isEnabled,
      isOn: isOn ?? this.isOn,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'label': label,
        'kind': kind.name,
        'targetControlIds': targetControlIds,
        'isEnabled': isEnabled,
        'isOn': isOn,
        'value': value,
      };

  factory GroupControlItem.fromJson(Map<String, dynamic> json) {
    return GroupControlItem(
      id: json['id'] as String? ?? '',
      spaceId: json['spaceId'] as String? ?? 'home_default',
      label: json['label'] as String? ?? '',
      kind: QuickControlKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => QuickControlKind.switchControl,
      ),
      targetControlIds: (json['targetControlIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isEnabled: json['isEnabled'] as bool? ?? true,
      isOn: json['isOn'] as bool? ?? false,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum QuickControlKind { light, fan, mistMaker, curtain, socket, switchControl }

class QuickControlPreview {
  const QuickControlPreview({
    required this.id,
    required this.kind,
    required this.title,
    required this.value,
    required this.confidence,
    required this.isEnabled,
    this.roomName,
  });

  final String id;
  final QuickControlKind kind;
  final String title;
  final String value;
  final ActuatorConfidence confidence;
  final bool isEnabled;
  final String? roomName;

  String get label => title;
  bool get isOn => value.toLowerCase() == 'on';
  bool get supportsToggle =>
      kind == QuickControlKind.light ||
      kind == QuickControlKind.switchControl ||
      kind == QuickControlKind.socket ||
      kind == QuickControlKind.fan;
  bool get isAvailable => confidence != ActuatorConfidence.unavailable;
}

class RoutinePreview {
  const RoutinePreview({
    required this.name,
    required this.scheduleLabel,
    required this.actionCount,
  });

  final String name;
  final String scheduleLabel;
  final int actionCount;
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.state,
    required this.source,
    required this.connectivity,
    required this.telemetryFreshness,
    required this.devicesOnline,
    required this.deviceCount,
    required this.roomCount,
    required this.activeRoomCount,
    required this.networkLabel,
    required this.networkDetail,
    required this.securityLabel,
    required this.securityDetail,
    required this.rooms,
    required this.controls,
    this.allControls = const [],
    required this.routine,
    this.alert,
    this.primaryTitle,
    this.primaryMessage,
    this.primaryAction,
  });

  final HomeDashboardState state;
  final DashboardDataSource source;
  final ConnectivityCause connectivity;
  final TelemetryFreshness telemetryFreshness;
  final int devicesOnline;
  final int deviceCount;
  final int roomCount;
  final int activeRoomCount;
  final String networkLabel;
  final String networkDetail;
  final String securityLabel;
  final String securityDetail;
  final List<RoomPreview> rooms;
  final List<QuickControlPreview> controls;
  final List<QuickControlPreview> allControls;
  final RoutinePreview? routine;
  final DashboardAlert? alert;
  final String? primaryTitle;
  final String? primaryMessage;
  final String? primaryAction;

  bool get isSetupFlow => switch (state) {
    HomeDashboardState.setupRequired ||
    HomeDashboardState.deviceFound ||
    HomeDashboardState.wifiRequired => true,
    _ => false,
  };

  bool get canShowLiveSafetyAsNormal =>
      telemetryFreshness == TelemetryFreshness.current &&
      source == DashboardDataSource.live;

  factory HomeDashboardData.designPreview({
    required bool lightOn,
    required ActuatorConfidence lightConfidence,
  }) {
    return HomeDashboardData(
      state: HomeDashboardState.ready,
      source: DashboardDataSource.preview,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      devicesOnline: 11,
      deviceCount: 12,
      roomCount: 5,
      activeRoomCount: 4,
      networkLabel: 'Wi-Fi',
      networkDetail: 'Home Wi-Fi',
      securityLabel: 'Security',
      securityDetail: 'All sensors normal',
      alert: const DashboardAlert(
        title: 'Kitchen needs attention',
        message: 'Gas sensor inspection recommended.',
        severity: AlertSeverity.maintenance,
        freshness: TelemetryFreshness.current,
      ),
      rooms: const [
        RoomPreview(
          id: 'living',
          name: 'Living Room',
          deviceCount: 3,
          summary: '24°C · Light on',
          status: 'All normal',
          isAttention: false,
          freshness: TelemetryFreshness.current,
          iconKey: 'living',
        ),
        RoomPreview(
          id: 'kitchen',
          name: 'Kitchen',
          deviceCount: 2,
          summary: 'Gas sensor · Check',
          status: '1 needs attention',
          isAttention: true,
          freshness: TelemetryFreshness.current,
          iconKey: 'kitchen',
        ),
        RoomPreview(
          id: 'plant',
          name: 'Plant Corner',
          deviceCount: 2,
          summary: 'Soil moisture 42%',
          status: 'All normal',
          isAttention: false,
          freshness: TelemetryFreshness.current,
          iconKey: 'plant',
        ),
        RoomPreview(
          id: 'water',
          name: 'Water Tank',
          deviceCount: 1,
          summary: '72% full',
          status: 'All normal',
          isAttention: false,
          freshness: TelemetryFreshness.current,
          iconKey: 'water',
        ),
      ],
      controls: [
        QuickControlPreview(
          id: 'light',
          kind: QuickControlKind.light,
          title: 'Living Room\nLight',
          value: lightOn ? 'On' : 'Off',
          confidence: lightConfidence,
          isEnabled: false,
        ),
        const QuickControlPreview(
          id: 'fan',
          kind: QuickControlKind.fan,
          title: 'Bedroom Fan',
          value: 'Speed 40%',
          confidence: ActuatorConfidence.unknown,
          isEnabled: false,
        ),
        const QuickControlPreview(
          id: 'mist',
          kind: QuickControlKind.mistMaker,
          title: 'Kitchen\nMist Maker',
          value: 'Off',
          confidence: ActuatorConfidence.unknown,
          isEnabled: false,
        ),
        const QuickControlPreview(
          id: 'curtain',
          kind: QuickControlKind.curtain,
          title: 'Living Room\nCurtain',
          value: 'Open 60%',
          confidence: ActuatorConfidence.unknown,
          isEnabled: false,
        ),
      ],
      routine: const RoutinePreview(
        name: 'Good Night',
        scheduleLabel: '10:30 PM',
        actionCount: 4,
      ),
    );
  }

  factory HomeDashboardData.setup({
    required HomeDashboardState state,
    required String title,
    required String message,
    required String action,
    required ConnectivityCause connectivity,
  }) {
    return HomeDashboardData(
      state: state,
      source: DashboardDataSource.live,
      connectivity: connectivity,
      telemetryFreshness: TelemetryFreshness.unknown,
      devicesOnline:
          state == HomeDashboardState.deviceFound ||
              state == HomeDashboardState.wifiRequired
          ? 1
          : 0,
      deviceCount:
          state == HomeDashboardState.deviceFound ||
              state == HomeDashboardState.wifiRequired
          ? 1
          : 0,
      roomCount: 0,
      activeRoomCount: 0,
      networkLabel: 'Network',
      networkDetail: state == HomeDashboardState.wifiRequired
          ? 'Not configured'
          : 'Not configured',
      securityLabel: 'Security',
      securityDetail: 'Setup required',
      rooms: const [],
      controls: const [],
      routine: null,
      primaryTitle: title,
      primaryMessage: message,
      primaryAction: action,
    );
  }

  factory HomeDashboardData.liveDevice({
    required String deviceName,
    required String roomName,
    required bool lightOn,
    required ActuatorConfidence lightConfidence,
  }) {
    final cleanDeviceName = deviceName.startsWith('EH ')
        ? deviceName.substring(3).trim()
        : deviceName;
    return HomeDashboardData(
      state: HomeDashboardState.ready,
      source: DashboardDataSource.live,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      devicesOnline: 1,
      deviceCount: 1,
      roomCount: 1,
      activeRoomCount: 1,
      networkLabel: 'Wi-Fi',
      networkDetail: 'Connected',
      securityLabel: 'Security',
      securityDetail: 'Device online',
      rooms: [
        RoomPreview(
          id: roomName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
          name: roomName,
          deviceCount: 1,
          summary: lightOn ? 'Active' : 'Standby',
          status: 'Online',
          isAttention: false,
          freshness: TelemetryFreshness.current,
          iconKey: 'living',
        ),
      ],
      controls: [
        QuickControlPreview(
          id: 'light',
          kind: cleanDeviceName.toLowerCase().contains('socket') || cleanDeviceName.toLowerCase().contains('plug')
              ? QuickControlKind.socket
              : (cleanDeviceName.toLowerCase().contains('fan')
                  ? QuickControlKind.fan
                  : (cleanDeviceName.toLowerCase().contains('curtain')
                      ? QuickControlKind.curtain
                      : (cleanDeviceName.toLowerCase().contains('mist')
                          ? QuickControlKind.mistMaker
                          : (cleanDeviceName.toLowerCase().contains('light') || cleanDeviceName.toLowerCase().contains('bulb') || cleanDeviceName.toLowerCase().contains('lamp')
                              ? QuickControlKind.light
                              : QuickControlKind.switchControl)))),
          title: '$roomName\n$cleanDeviceName',
          value: lightOn ? 'On' : 'Off',
          confidence: lightConfidence,
          isEnabled: true,
        ),
      ],
      routine: null,
    );
  }

  factory HomeDashboardData.forLiveDevices({
    required List<dynamic> devices,
    required bool lightOn,
    required ActuatorConfidence lightConfidence,
    List<String>? selectedControlIds,
    Map<String, Map<int, bool>>? channelStates,
    Map<String, Map<int, String>>? channelLabels,
  }) {
    if (devices.isEmpty) {
      return HomeDashboardData.setup(
        state: HomeDashboardState.setupRequired,
        title: 'Connect your first device',
        message: 'Add a nearby device to get your home up and running.',
        action: 'Add a device',
        connectivity: ConnectivityCause.unknown,
      );
    }

    final Map<String, List<dynamic>> roomMap = {};
    for (final d in devices) {
      final room = (d.roomName as String? ?? 'Living Room').trim();
      roomMap.putIfAbsent(room.isEmpty ? 'Living Room' : room, () => []).add(d);
    }

    final rooms = roomMap.entries.map((entry) {
      final roomName = entry.key;
      final roomDevices = entry.value;
      final roomId = roomName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );
      int devicesOnCount = 0;
      for (final d in roomDevices) {
        bool isDevOn = false;
        for (int ch = 1; ch <= 4; ch++) {
          if (channelStates?[d.id]?[ch] ?? (ch == 1 ? lightOn : false)) {
            isDevOn = true;
            break;
          }
        }
        if (isDevOn) devicesOnCount++;
      }
      final anyChOnInRoom = devicesOnCount > 0;
      final allOffline = roomDevices.every((d) => d.online == false);

      return RoomPreview(
        id: roomId,
        name: roomName,
        deviceCount: roomDevices.length,
        devicesOnCount: devicesOnCount,
        summary: allOffline ? 'Offline' : (anyChOnInRoom ? '$devicesOnCount ON' : 'Standby'),
        status: allOffline ? 'Offline' : 'Online',
        isAttention: false,
        freshness: allOffline ? TelemetryFreshness.stale : TelemetryFreshness.current,
        iconKey: 'living',
      );
    }).toList();

    QuickControlKind inferKind(String devName, String devModel, String chLabel) {
      final labelLower = chLabel.toLowerCase();
      if (labelLower.contains('light') || labelLower.contains('bulb') || labelLower.contains('lamp')) {
        return QuickControlKind.light;
      }
      if (labelLower.contains('fan')) return QuickControlKind.fan;
      if (labelLower.contains('curtain') || labelLower.contains('blind')) return QuickControlKind.curtain;
      if (labelLower.contains('mist')) return QuickControlKind.mistMaker;
      if (labelLower.contains('socket') || labelLower.contains('plug') || labelLower.contains('outlet')) {
        return QuickControlKind.socket;
      }

      final devText = '${devName.toLowerCase()} ${devModel.toLowerCase()}';
      if (devText.contains('socket') || devText.contains('plug') || devText.contains('outlet')) {
        return QuickControlKind.socket;
      }
      if (devText.contains('fan')) return QuickControlKind.fan;
      if (devText.contains('curtain') || devText.contains('blind')) return QuickControlKind.curtain;
      if (devText.contains('mist')) return QuickControlKind.mistMaker;
      if (devText.contains('light') || devText.contains('bulb') || devText.contains('lamp')) {
        return QuickControlKind.light;
      }
      return QuickControlKind.switchControl;
    }

    final List<QuickControlPreview> allControls = [];
    for (final d in devices) {
      final rawName = d.name as String? ?? 'Smart Switch';
      final cleanName = rawName.startsWith('EH ')
          ? rawName.substring(3).trim()
          : rawName;
      final modelStr = (d.model as String? ?? '').toLowerCase();
      final nameStr = cleanName.toLowerCase();
      final isSocket = nameStr.contains('socket') || modelStr.contains('socket');
      final is4X = nameStr.contains('4x') || modelStr.contains('4x');
      final is3X = nameStr.contains('3x') || modelStr.contains('3x');
      final is2X = nameStr.contains('2x') || modelStr.contains('2x');
      final channelCount = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : 1));
      final isDevOnline = d.online == true;

      for (int ch = 1; ch <= channelCount; ch++) {
        final isChOn = channelStates?[d.id]?[ch] ?? (ch == 1 ? lightOn : false);
        final chPrefix = isSocket ? 'Socket' : 'Switch';
        final customName = channelLabels?[d.id]?[ch];
        final title = (customName != null && customName.trim().isNotEmpty)
            ? customName.trim()
            : '$chPrefix $ch';
        final kind = inferKind(cleanName, modelStr, title);
        allControls.add(
          QuickControlPreview(
            id: '${d.id}_ch$ch',
            kind: kind,
            title: title,
            value: isDevOnline ? (isChOn ? 'On' : 'Off') : 'Offline',
            confidence: isDevOnline ? lightConfidence : ActuatorConfidence.unavailable,
            isEnabled: isDevOnline,
            roomName: d.roomName,
          ),
        );
      }
    }

    final List<QuickControlPreview> controls = [];
    if (selectedControlIds != null) {
      for (final id in selectedControlIds) {
        final match = allControls.cast<QuickControlPreview?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
        if (match != null) {
          controls.add(match);
        }
      }
    }

    final onlineCount = devices.where((d) => d.online == true).length;

    return HomeDashboardData(
      state: HomeDashboardState.ready,
      source: DashboardDataSource.live,
      connectivity: onlineCount > 0 ? ConnectivityCause.online : ConnectivityCause.deviceOffline,
      telemetryFreshness: onlineCount > 0 ? TelemetryFreshness.current : TelemetryFreshness.stale,
      devicesOnline: onlineCount,
      deviceCount: devices.length,
      roomCount: roomMap.length,
      activeRoomCount: roomMap.length,
      networkLabel: 'Wi-Fi',
      networkDetail: onlineCount > 0 ? 'Connected' : 'Offline',
      securityLabel: 'Security',
      securityDetail: onlineCount == devices.length ? 'All devices online' : '$onlineCount of ${devices.length} online',
      rooms: rooms,
      controls: controls,
      allControls: allControls,
      routine: null,
    );
  }
}

String _timeLabel(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  return '${elapsed.inHours} hr ago';
}
