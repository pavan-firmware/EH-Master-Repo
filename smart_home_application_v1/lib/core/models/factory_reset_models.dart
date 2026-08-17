enum FactoryResetState {
  idle,
  loadingImpact,
  impactReady,
  authorizationRequired,
  confirmationRequired,
  confirming,
  resetting,
  restarting,
  verifying,
  completed,
  unauthorized,
  unsupported,
  offline,
  timeout,
  failed,
  verificationFailed,
  cancelled,
}

class FactoryResetImpact {
  const FactoryResetImpact({
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
    required this.roomName,
    required this.online,
    required this.routineCount,
    required this.routineNames,
    required this.activityPreserved,
    required this.willHappen,
    required this.willNotHappen,
  });

  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final String roomName;
  final bool online;
  final int routineCount;
  final List<String> routineNames;
  final bool activityPreserved;
  final List<String> willHappen;
  final List<String> willNotHappen;
}

class FactoryResetResult {
  const FactoryResetResult({
    required this.success,
    required this.message,
    this.state = FactoryResetState.idle,
  });

  final bool success;
  final String message;
  final FactoryResetState state;
}
