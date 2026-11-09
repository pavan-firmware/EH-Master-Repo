import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:smart_home_application_v1/core/config/device_connection_config.dart';
import 'package:smart_home_application_v1/core/repositories/ble_connection_repository.dart';
import 'package:smart_home_application_v1/core/repositories/connection_repository.dart';
import 'package:smart_home_application_v1/core/services/ble_preflight_service.dart';
import 'package:smart_home_application_v1/features/onboarding/ble/ble_commissioning_channel.dart';

import 'ble_preflight_service_test.dart';

class FakeBleCommissioningChannel extends BleCommissioningChannel {
  bool scanCalled = false;
  bool connectCalled = false;
  bool shouldTimeout = false;
  Exception? scanException;

  @override
  Future<DiscoveredDevice> scanForSingleDevice({
    String namePrefix = 'EH-',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    scanCalled = true;
    if (scanException != null) {
      throw scanException!;
    }
    if (shouldTimeout) {
      throw TimeoutException('Scan timeout');
    }
    return DiscoveredDevice(
      id: 'mock-ble-id-001',
      name: 'EH-SW3X-2026W12-00001',
      serviceData: const {},
      serviceUuids: const [],
      manufacturerData: Uint8List(0),
      rssi: -55,
    );
  }

  @override
  Future<void> connect(String deviceId, [String? deviceName]) async {
    connectCalled = true;
  }

  @override
  void dispose() {}
}

void main() {
  group('BLE Connection Flow & Regression Tests', () {
    test('BleConnectionRepository returns bluetoothDisabled when BT is powered off', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.poweredOff);
      final systemActions = FakeSystemBleActions()
        ..bluetoothEnableResult = false
        ..bluetoothEnabledState = false;
      final preflight = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
        systemActions: systemActions,
      );

      final fakeChannel = FakeBleCommissioningChannel();
      final repo = BleConnectionRepository(
        preflightService: preflight,
        channel: fakeChannel,
      );

      final result = await repo.connect(
        config: deviceConnectionConfig,
      );

      expect(result.success, isFalse);
      expect(result.failureKind, ConnectionFailureKind.bluetoothDisabled);
      expect(result.recoveryAction, 'Turn on Bluetooth');
      expect(fakeChannel.scanCalled, isFalse);
    });

    test('BleConnectionRepository gracefully maps reactive_ble Location Services disabled (code 4) scan error', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);
      final preflight = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final fakeChannel = FakeBleCommissioningChannel()
        ..scanException = Exception('GenericFailure<ScanFailure>(code: ScanFailure.unknown, message: "Location Services disabled (code 4)")');

      final repo = BleConnectionRepository(
        preflightService: preflight,
        channel: fakeChannel,
      );

      final result = await repo.connect(
        config: deviceConnectionConfig,
      );

      expect(result.success, isFalse);
      expect(result.failureKind, ConnectionFailureKind.locationServicesDisabled);
      expect(result.title, 'Location is turned off');
      expect(result.recoveryAction, 'Turn on Location');
    });

    test('BleConnectionRepository gracefully maps reactive_ble Bluetooth disabled (code 1) scan error', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);
      final preflight = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final fakeChannel = FakeBleCommissioningChannel()
        ..scanException = Exception('GenericFailure<ScanFailure>(code: ScanFailure.unknown, message: "Bluetooth disabled (code 1)")');

      final repo = BleConnectionRepository(
        preflightService: preflight,
        channel: fakeChannel,
      );

      final result = await repo.connect(
        config: deviceConnectionConfig,
      );

      expect(result.success, isFalse);
      expect(result.failureKind, ConnectionFailureKind.bluetoothDisabled);
      expect(result.title, 'Bluetooth is turned off');
      expect(result.recoveryAction, 'Turn on Bluetooth');
    });

    test('BleConnectionRepository returns locationServicesDisabled on Android <= 30 when location service is OFF', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
        serviceStatuses: {
          Permission.location: ServiceStatus.disabled,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);
      final systemActions = FakeSystemBleActions()..locationEnabledState = false;
      final preflight = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
        systemActions: systemActions,
      );

      final fakeChannel = FakeBleCommissioningChannel();
      final repo = BleConnectionRepository(
        preflightService: preflight,
        channel: fakeChannel,
      );

      final result = await repo.connect(
        config: deviceConnectionConfig,
      );

      expect(result.success, isFalse);
      expect(result.failureKind, ConnectionFailureKind.locationServicesDisabled);
      expect(result.recoveryAction, 'Turn on Location');
      expect(fakeChannel.scanCalled, isFalse);
    });

    test('BleConnectionRepository returns scanTimedOut only after all prerequisites are satisfied', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);
      final preflight = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final fakeChannel = FakeBleCommissioningChannel()..shouldTimeout = true;
      final repo = BleConnectionRepository(
        preflightService: preflight,
        channel: fakeChannel,
      );

      // In tests without physical ESP32, scan times out cleanly
      final result = await repo.connect(
        config: deviceConnectionConfig,
      );

      expect(result.success, isFalse);
      expect(result.failureKind, ConnectionFailureKind.scanTimedOut);
      expect(result.message, contains('No EH Home device found nearby'));
      expect(result.recoveryAction, 'Try again');
      expect(fakeChannel.scanCalled, isTrue);
    });
  });
}
