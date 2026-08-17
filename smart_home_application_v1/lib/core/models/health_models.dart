enum DeviceHealthState {
  healthy,
  attention,
  offline,
  stale,
  updating,
  unknown,
}

enum SignalStrength { strong, good, weak, unknown }

class DeviceHealthEntry {
  const DeviceHealthEntry({
    required this.deviceId,
    required this.name,
    required this.roomId,
    required this.roomName,
    required this.state,
    required this.signal,
    required this.lastSeen,
    required this.statusLine,
    required this.iconKey,
    this.reading,
  });

  final String deviceId;
  final String name;
  final String roomId;
  final String roomName;
  final DeviceHealthState state;
  final SignalStrength signal;
  final DateTime? lastSeen;
  final String statusLine;
  final String iconKey;
  final String? reading;

  int get sortPriority => switch (state) {
        DeviceHealthState.attention => 0,
        DeviceHealthState.offline => 1,
        DeviceHealthState.stale => 2,
        DeviceHealthState.updating => 3,
        DeviceHealthState.unknown => 4,
        DeviceHealthState.healthy => 5,
      };

  String get signalLabel => switch (signal) {
        SignalStrength.strong => 'Strong',
        SignalStrength.good => 'Good',
        SignalStrength.weak => 'Weak',
        SignalStrength.unknown => 'Unknown',
      };
}

class RoomHealthSummary {
  const RoomHealthSummary({
    required this.roomId,
    required this.roomName,
    required this.deviceCount,
    required this.issueCount,
    required this.iconKey,
  });

  final String roomId;
  final String roomName;
  final int deviceCount;
  final int issueCount;
  final String iconKey;

  bool get isHealthy => issueCount == 0;
  String get statusLabel =>
      isHealthy ? 'Healthy' : '$issueCount issue${issueCount == 1 ? '' : 's'}';
}

enum HomeHealthOverall { healthy, attention, offline, unknown }

class HomeHealthSummary {
  const HomeHealthSummary({
    required this.overall,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.totalDevices,
    required this.onlineCount,
    required this.attentionCount,
    required this.offlineCount,
    required this.lastChecked,
    required this.devices,
    required this.rooms,
  });

  final HomeHealthOverall overall;
  final String title;
  final String subtitle;
  final String statusLabel;
  final int totalDevices;
  final int onlineCount;
  final int attentionCount;
  final int offlineCount;
  final DateTime lastChecked;
  final List<DeviceHealthEntry> devices;
  final List<RoomHealthSummary> rooms;

  List<DeviceHealthEntry> get sortedDevices {
    final copy = List<DeviceHealthEntry>.from(devices);
    copy.sort((a, b) => a.sortPriority.compareTo(b.sortPriority));
    return copy;
  }
}
