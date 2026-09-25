import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:smart_home_application_v1/core/config/device_connection_config.dart';
import 'package:smart_home_application_v1/core/models/device_models.dart';
import 'package:smart_home_application_v1/core/repositories/ble_connection_repository.dart';
import 'package:smart_home_application_v1/core/repositories/connection_repository.dart';
import 'package:smart_home_application_v1/core/repositories/home_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/ble_preflight_service.dart';
import 'package:smart_home_application_v1/features/connection/presentation/home_connection_page.dart';
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

    testWidgets('HomeConnectionPage invokes system action when recovery button is tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var callCount = 0;
      Future<ConnectionResult> fakeConnect() async {
        callCount++;
        return const ConnectionResult(
          success: false,
          title: 'Bluetooth is turned off',
          message: 'Bluetooth is currently turned off. Turn it on to find your Smart Switch.',
          failureKind: ConnectionFailureKind.bluetoothDisabled,
        );
      }

      final actions = FakeSystemBleActions();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeConnectionPage(
            connectionState: HomeConnectionState.notConfigured,
            onStart: fakeConnect,
            systemBleActions: actions,
            repository: const PreviewHomeConnectionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Connect to start flow
      final connectBtn = find.widgetWithText(FilledButton, 'Connect your home');
      expect(connectBtn, findsOneWidget);
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(callCount, 1);

      // Fallback card renders cleanly without blocker UI
      expect(find.text('Bluetooth is turned off'), findsOneWidget);
      expect(find.text('Bluetooth is currently turned off. Turn it on to find your Smart Switch.'), findsOneWidget);

      // Tap recovery action button
      final recoveryBtn = find.widgetWithText(ElevatedButton, 'Turn on Bluetooth');
      expect(recoveryBtn, findsOneWidget);
      await tester.ensureVisible(recoveryBtn);
      await tester.tap(recoveryBtn);
      await tester.pumpAndSettle();

      expect(actions.requestBluetoothEnableCalled, isTrue);
    });

    testWidgets('HomeConnectionPage displays fallback card with [Allow Location] on Android <= 30 when Location permission is needed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<ConnectionResult> fakeConnect() async {
        return const ConnectionResult(
          success: false,
          title: 'Location permission needed',
          message: 'Android requires Location permission to discover nearby Bluetooth devices on this phone.',
          failureKind: ConnectionFailureKind.locationPermissionRequired,
        );
      }

      final actions = FakeSystemBleActions();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeConnectionPage(
            connectionState: HomeConnectionState.notConfigured,
            onStart: fakeConnect,
            systemBleActions: actions,
            repository: const PreviewHomeConnectionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final connectBtn = find.widgetWithText(FilledButton, 'Connect your home');
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(find.text('Location permission needed'), findsOneWidget);
      expect(find.text('Allow Location'), findsOneWidget);

      final allowBtn = find.widgetWithText(ElevatedButton, 'Allow Location');
      await tester.ensureVisible(allowBtn);
      await tester.tap(allowBtn);
      await tester.pumpAndSettle();

      expect(actions.requestLocationPermissionCalled, isTrue);
    });

    testWidgets('HomeConnectionPage automatically resumes preflight when app resumes from background', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var invocationCount = 0;
      Future<ConnectionResult> fakeConnect() async {
        invocationCount++;
        if (invocationCount == 1) {
          return const ConnectionResult(
            success: false,
            title: 'Bluetooth is turned off',
            message: 'Bluetooth is currently turned off.',
            failureKind: ConnectionFailureKind.bluetoothDisabled,
          );
        } else {
          return const ConnectionResult(
            success: false,
            title: 'No EH Home device found nearby',
            message: 'No EH Home device found nearby.',
            failureKind: ConnectionFailureKind.scanTimedOut,
          );
        }
      }

      final actions = FakeSystemBleActions()..bluetoothEnableResult = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeConnectionPage(
            connectionState: HomeConnectionState.notConfigured,
            onStart: fakeConnect,
            systemBleActions: actions,
            repository: const PreviewHomeConnectionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start connect -> fails with bluetoothDisabled
      final connectBtn = find.widgetWithText(FilledButton, 'Connect your home');
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();
      expect(invocationCount, 1);

      // Tap recovery button to open settings (marks pending recovery)
      final recoveryBtn = find.widgetWithText(ElevatedButton, 'Turn on Bluetooth');
      await tester.ensureVisible(recoveryBtn);
      await tester.tap(recoveryBtn);
      await tester.pumpAndSettle();

      // Simulate AppLifecycleState.resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Automatically re-executed connection flow
      expect(invocationCount, 2);
    });

    testWidgets('HomeConnectionPage does NOT trigger scan on resume if no flow was pending', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var invocationCount = 0;
      Future<ConnectionResult> fakeConnect() async {
        invocationCount++;
        return const ConnectionResult(
          success: true,
          title: 'Connected',
          message: 'Connected successfully',
        );
      }

      final actions = FakeSystemBleActions();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeConnectionPage(
            connectionState: HomeConnectionState.notConfigured,
            onStart: fakeConnect,
            systemBleActions: actions,
            repository: const PreviewHomeConnectionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate resume without pending operation
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(invocationCount, 0);
    });
  });
}
