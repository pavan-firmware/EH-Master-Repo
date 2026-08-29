enum DeviceConnection { online, stale, offline }

enum HomeConnectionState {
  notConfigured,
  connecting,
  connected,
  offline,
  failed,
}

enum CommandState { accepted, executing, succeeded, failed, expired }

enum DeviceLifecycleState {
  factory,
  provisioning,
  claimable,
  claimed,
  configuring,
  active,
  offline,
  resetPending,
  decommissioned,
}

class DeviceStateSnapshot {
  const DeviceStateSnapshot({
    required this.deviceId,
    required this.connectionState,
    this.desiredState = const {},
    this.reportedState = const {},
    this.actualState = const {},
    this.lastSeenAt,
  });

  final String deviceId;
  final DeviceConnection connectionState;
  final Map<String, dynamic> desiredState;
  final Map<String, dynamic> reportedState;
  final Map<String, dynamic> actualState;
  final DateTime? lastSeenAt;
}

enum FirmwareJobState {
  idle,
  preflight,
  scheduled,
  downloading,
  verifying,
  staging,
  installing,
  rebooting,
  validating,
  complete,
  rolledBack,
  failed,
}

class DeviceCapability {
  const DeviceCapability({required this.id, required this.label});

  final String id;
  final String label;
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.id,
    required this.name,
    required this.roomName,
    required this.hardwareRevision,
    required this.connection,
    required this.capabilities,
    required this.reportedAt,
    this.firmwareVersion = '1.0.0',
  });

  final String id;
  final String name;
  final String roomName;
  final String hardwareRevision;
  final DeviceConnection connection;
  final List<DeviceCapability> capabilities;
  final DateTime reportedAt;
  final String firmwareVersion;
}

class CommandReceipt {
  const CommandReceipt({
    required this.commandId,
    required this.state,
    this.message,
  });

  final String commandId;
  final CommandState state;
  final String? message;
}

class FirmwareRelease {
  const FirmwareRelease({
    required this.version,
    required this.title,
    required this.summary,
    required this.tags,
    required this.publishedAt,
    this.required = false,
  });

  final String version;
  final String title;
  final String summary;
  final List<String> tags;
  final DateTime publishedAt;
  final bool required;
}

class FirmwareJob {
  const FirmwareJob({
    required this.state,
    required this.progress,
    this.release,
    this.message,
  });

  final FirmwareJobState state;
  final int progress;
  final FirmwareRelease? release;
  final String? message;
}
