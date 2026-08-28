import '../config/device_connection_config.dart';

enum ConnectionStep { discovery, identification, pairing, wifi, verification }

enum ConnectionFailureKind {
  none,
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothUnavailable,
  scanTimedOut,
  deviceDisconnected,
  unsupportedDevice,
  unknown,
}

class ConnectionResult {
  const ConnectionResult({
    required this.success,
    required this.message,
    this.step = ConnectionStep.discovery,
    this.failureKind = ConnectionFailureKind.none,
    this.deviceId,
    this.serialNumber,
    this.displayName,
    this.channel,
  });

  final bool success;
  final String message;
  final ConnectionStep step;
  final ConnectionFailureKind failureKind;
  final String? deviceId;
  final String? serialNumber;
  final String? displayName;
  final dynamic channel;

  bool get canRetry =>
      !success &&
      failureKind != ConnectionFailureKind.permissionPermanentlyDenied;

  String get recoveryAction => switch (failureKind) {
    ConnectionFailureKind.permissionDenied => 'Allow Bluetooth',
    ConnectionFailureKind.permissionPermanentlyDenied => 'Open app settings',
    ConnectionFailureKind.bluetoothUnavailable => 'Turn on Bluetooth',
    ConnectionFailureKind.scanTimedOut => 'Try again',
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
