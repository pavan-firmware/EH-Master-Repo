import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/connection_repository.dart';

void main() {
  group('dashboard lifecycle contract', () {
    test('declares every explicit dashboard state', () {
      expect(
        HomeDashboardState.values,
        containsAll(<HomeDashboardState>[
          HomeDashboardState.loading,
          HomeDashboardState.setupRequired,
          HomeDashboardState.deviceFound,
          HomeDashboardState.wifiRequired,
          HomeDashboardState.ready,
          HomeDashboardState.partial,
          HomeDashboardState.warning,
          HomeDashboardState.critical,
          HomeDashboardState.offline,
          HomeDashboardState.noInternet,
        ]),
      );
    });

    test('preview keeps factory identity separate from user configuration', () {
      const factory = FactoryDeviceIdentity(
        deviceId: 'SH-8EF248',
        serialNumber: 'SN-000000248',
        model: 'SH-NODE-V1',
        hardwareRevision: 'REV-A',
      );
      const user = UserDeviceConfiguration(
        displayName: 'Bedroom Mist Maker',
        roomId: 'bedroom',
        lifecycle: DeviceLifecycle.configured,
      );

      expect(factory.deviceId, isNot(user.displayName));
      expect(user.roomId, 'bedroom');
    });
  });

  group('reliability contract', () {
    test('connection failures provide direct recovery actions', () {
      const permanentlyDenied = ConnectionResult(
        success: false,
        message: 'Permission denied',
        failureKind: ConnectionFailureKind.permissionPermanentlyDenied,
      );
      const bluetoothOff = ConnectionResult(
        success: false,
        message: 'Bluetooth unavailable',
        failureKind: ConnectionFailureKind.bluetoothUnavailable,
      );

      expect(permanentlyDenied.recoveryAction, 'Open app settings');
      expect(permanentlyDenied.canRetry, isFalse);
      expect(bluetoothOff.recoveryAction, 'Turn on Bluetooth');
      expect(bluetoothOff.canRetry, isTrue);
    });

    test('actuator confidence has explicit pending and unavailable states', () {
      expect(ActuatorConfidence.values, contains(ActuatorConfidence.pending));
      expect(
        ActuatorConfidence.values,
        contains(ActuatorConfidence.unavailable),
      );
      expect(ActuatorConfidence.values, contains(ActuatorConfidence.failed));
    });

    test('telemetry freshness separates current values from stale values', () {
      expect(TelemetryFreshness.values, contains(TelemetryFreshness.current));
      expect(TelemetryFreshness.values, contains(TelemetryFreshness.stale));
      expect(
        ConnectivityCause.values,
        contains(ConnectivityCause.backendUnavailable),
      );
      expect(
        PermissionLifecycle.values,
        contains(PermissionLifecycle.permanentlyDenied),
      );
    });
  });
}
