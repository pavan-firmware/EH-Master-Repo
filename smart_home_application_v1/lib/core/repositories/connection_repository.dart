import '../config/device_connection_config.dart';

enum ConnectionStep { discovery, identification, pairing, wifi, verification }

enum ConnectionFailureKind {
  none,
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothPermissionRequired,
  bluetoothPermissionPermanentlyDenied,
  bluetoothDisabled,
  bluetoothUnavailable,
  locationPermissionRequired,
  locationPermissionPermanentlyDenied,
  locationServicesDisabled,
  bleUnsupported,
  bleInitializing,
  scanTimedOut,
  deviceNotFound,
  deviceDisconnected,
  unsupportedDevice,
  connectionFailed,
  unknown,
}

class ConnectionResult {
  const ConnectionResult({
    required this.success,
    required this.message,
    this.title,
    this.step = ConnectionStep.discovery,
    this.failureKind = ConnectionFailureKind.none,
    this.deviceId,
    this.serialNumber,
    this.displayName,
    this.channel,
  });

  final bool success;
  final String message;
  final String? title;
  final ConnectionStep step;
  final ConnectionFailureKind failureKind;
  final String? deviceId;
  final String? serialNumber;
  final String? displayName;
  final dynamic channel;

  bool get isPermanentlyDenied =>
      failureKind == ConnectionFailureKind.permissionPermanentlyDenied ||
      failureKind ==
          ConnectionFailureKind.bluetoothPermissionPermanentlyDenied ||
      failureKind ==
          ConnectionFailureKind.locationPermissionPermanentlyDenied;

  bool get canRetry => !success && !isPermanentlyDenied;

  String get recoveryAction => switch (failureKind) {
    ConnectionFailureKind.permissionDenied ||
    ConnectionFailureKind.bluetoothPermissionRequired =>
      'Allow Bluetooth',
    ConnectionFailureKind.permissionPermanentlyDenied ||
    ConnectionFailureKind.bluetoothPermissionPermanentlyDenied ||
    ConnectionFailureKind.locationPermissionPermanentlyDenied =>
      'Open app settings',
    ConnectionFailureKind.bluetoothDisabled ||
    ConnectionFailureKind.bluetoothUnavailable =>
      'Turn on Bluetooth',
    ConnectionFailureKind.locationPermissionRequired => 'Allow Location',
    ConnectionFailureKind.locationServicesDisabled => 'Turn on Location',
    ConnectionFailureKind.bleUnsupported => 'Unsupported',
    ConnectionFailureKind.bleInitializing => 'Wait',
    ConnectionFailureKind.scanTimedOut ||
    ConnectionFailureKind.deviceNotFound =>
      'Try again',
    ConnectionFailureKind.deviceDisconnected => 'Reconnect',
    ConnectionFailureKind.unsupportedDevice => 'Find another device',
    _ => 'Try again',
  };
}

class ConnectionFailure implements Exception {
  const ConnectionFailure(
    this.kind,
    this.message, {
    this.step = ConnectionStep.discovery,
  });

  final ConnectionFailureKind kind;
  final String message;
  final ConnectionStep step;
}

abstract interface class ConnectionRepository {
  Future<ConnectionResult> connect({required DeviceConnectionConfig config});
}
