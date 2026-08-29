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
    required this.summary,
    required this.status,
    required this.isAttention,
    required this.freshness,
    required this.iconKey,
  });

  final String id;
  final String name;
  final int deviceCount;
  final String summary;
  final String status;
  final bool isAttention;
  final TelemetryFreshness freshness;
  final String iconKey;
}

enum QuickControlKind { light, fan, mistMaker, curtain }

class QuickControlPreview {
  const QuickControlPreview({
    required this.id,
    required this.kind,
    required this.title,
    required this.value,
    required this.confidence,
    required this.isEnabled,
  });

  final String id;
  final QuickControlKind kind;
  final String title;
  final String value;
  final ActuatorConfidence confidence;
  final bool isEnabled;
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
          kind: QuickControlKind.light,
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
    List<QuickControlPreview>? customControls,
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
      final roomId = roomName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      return RoomPreview(
        id: roomId,
        name: roomName,
        deviceCount: roomDevices.length,
        summary: lightOn ? 'Active' : 'Standby',
        status: 'Online',
        isAttention: false,
        freshness: TelemetryFreshness.current,
        iconKey: 'living',
      );
    }).toList();

    final controls = customControls != null && customControls.isNotEmpty
        ? customControls
        : devices.map((d) {
            final rawName = d.name as String? ?? 'Smart Switch 3X';
            final cleanName = rawName.startsWith('EH ') ? rawName.substring(3).trim() : rawName;
            final roomName = d.roomName as String? ?? 'Room';
            return QuickControlPreview(
              id: d.id as String? ?? 'dev',
              kind: QuickControlKind.light,
              title: '$roomName\n$cleanName',
              value: lightOn ? 'On' : 'Off',
              confidence: lightConfidence,
              isEnabled: true,
            );
          }).toList();

    return HomeDashboardData(
      state: HomeDashboardState.ready,
      source: DashboardDataSource.live,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      devicesOnline: devices.where((d) => d.online == true).length,
      deviceCount: devices.length,
      roomCount: roomMap.length,
      activeRoomCount: roomMap.length,
      networkLabel: 'Wi-Fi',
      networkDetail: 'Connected',
      securityLabel: 'Security',
      securityDetail: 'All devices online',
      rooms: rooms,
      controls: controls,
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
