import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_home_application_v1/core/services/ble_preflight_service.dart';

class FakePlatformSdkInfo implements PlatformSdkInfo {
  FakePlatformSdkInfo({
    this.platform = TargetPlatform.android,
    this.isWeb = false,
    this.sdkVersion = 33,
  });

  @override
  final TargetPlatform platform;

  @override
  final bool isWeb;

  final int sdkVersion;

  @override
  Future<int> getAndroidSdkVersion() async => sdkVersion;
}

class FakePermissionDelegate implements PermissionDelegate {
  FakePermissionDelegate({
    Map<Permission, PermissionStatus>? initialStatuses,
    Map<Permission, ServiceStatus>? serviceStatuses,
    this.grantOnRequest = true,
  })  : statuses = Map<Permission, PermissionStatus>.from(initialStatuses ?? {}),
        serviceStatuses = Map<Permission, ServiceStatus>.from(serviceStatuses ?? {});

  final Map<Permission, PermissionStatus> statuses;
  final Map<Permission, ServiceStatus> serviceStatuses;
  final bool grantOnRequest;
  final List<Permission> requestedPermissions = [];
  bool appSettingsOpened = false;
  bool bluetoothSettingsOpened = false;
  bool locationSettingsOpened = false;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async {
    return statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    requestedPermissions.add(permission);
    if (grantOnRequest) {
      statuses[permission] = PermissionStatus.granted;
      return PermissionStatus.granted;
    }
    return statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestedPermissions.addAll(permissions);
    final result = <Permission, PermissionStatus>{};
    for (final p in permissions) {
      if (grantOnRequest) {
        statuses[p] = PermissionStatus.granted;
        result[p] = PermissionStatus.granted;
      } else {
        result[p] = statuses[p] ?? PermissionStatus.denied;
      }
    }
    return result;
  }

  @override
  Future<ServiceStatus> checkLocationServiceStatus() async {
    return serviceStatuses[Permission.location] ?? ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openBluetoothSettings() async {
    bluetoothSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }
}

class FakeBleStatusDelegate implements BleStatusDelegate {
  FakeBleStatusDelegate({BleStatus initialStatus = BleStatus.ready})
      : _status = initialStatus {
    _streamController = StreamController<BleStatus>.broadcast();
  }

  BleStatus _status;
  late final StreamController<BleStatus> _streamController;

  @override
  BleStatus get status => _status;

  @override
  Stream<BleStatus> get statusStream => _streamController.stream;

  void emitStatus(BleStatus newStatus) {
    _status = newStatus;
    _streamController.add(newStatus);
  }

  void dispose() {
    _streamController.close();
  }
}

class FakeSystemBleActions implements SystemBleActions {
  bool requestBluetoothPermissionCalled = false;
  bool requestLocationPermissionCalled = false;
  bool requestBluetoothEnableCalled = false;
  bool openAppSettingsCalled = false;
  bool openBluetoothSettingsCalled = false;
  bool openLocationSettingsCalled = false;

  bool bluetoothEnableResult = true;
  bool bluetoothEnabledState = true;
  bool locationEnabledState = true;

  @override
  Future<bool> requestBluetoothPermission() async {
    requestBluetoothPermissionCalled = true;
    return true;
  }

  @override
  Future<bool> requestLocationPermission() async {
    requestLocationPermissionCalled = true;
    return true;
  }

  @override
  Future<bool> requestBluetoothEnable() async {
    requestBluetoothEnableCalled = true;
    return bluetoothEnableResult;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    return bluetoothEnabledState;
  }

  @override
  Future<bool> isLocationEnabled() async {
    return locationEnabledState;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openBluetoothSettings() async {
    openBluetoothSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalled = true;
    return true;
  }
}

void main() {
  group('BlePreflightService Tests', () {
    test('1. Android 12+ (SDK 33) with Bluetooth granted and ready -> returns ready', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check();
      expect(result.status, BlePreflightStatus.ready);
      expect(result.isReady, isTrue);
    });

    test('2. Android 12+ (SDK 33) missing Bluetooth permission -> requests permissions and returns ready when granted', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check(requestIfNeeded: true);
      expect(permissions.requestedPermissions, contains(Permission.bluetoothScan));
      expect(permissions.requestedPermissions, contains(Permission.bluetoothConnect));
      expect(result.status, BlePreflightStatus.ready);
    });

    test('3. Android 12+ (SDK 33) Bluetooth permanently denied -> returns bluetoothPermissionPermanentlyDenied', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check(requestIfNeeded: false);
      expect(result.status, BlePreflightStatus.bluetoothPermissionPermanentlyDenied);
      expect(result.recoveryAction, 'Open Settings');
    });

    test('4. Android 12+ (SDK 33) Bluetooth radio powered off -> invokes native ACTION_REQUEST_ENABLE enable abstraction', () async {
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

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
        systemActions: systemActions,
      );

      final result = await service.check(requestIfNeeded: true);
      expect(systemActions.requestBluetoothEnableCalled, isTrue);
      expect(result.status, BlePreflightStatus.bluetoothDisabled);
      expect(result.title, 'Bluetooth is turned off');
      expect(result.recoveryAction, 'Turn on Bluetooth');
    });

    test('5. Android 12+ (SDK 33) MUST NOT block BLE solely because Location is denied or Location service is OFF', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        serviceStatuses: {
          Permission.location: ServiceStatus.disabled,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check();
      // On Android 12+ with neverForLocation, Location being denied is NOT a blocker
      expect(result.status, BlePreflightStatus.ready);
      expect(result.isReady, isTrue);
    });

    test('6. Android <=30 (SDK 30) missing Location permission -> requests Location permission', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check(requestIfNeeded: true);
      expect(permissions.requestedPermissions, contains(Permission.locationWhenInUse));
      expect(result.status, BlePreflightStatus.ready);
    });

    test('7. Android <=30 (SDK 30) Location permanently denied -> returns locationPermissionPermanentlyDenied', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check(requestIfNeeded: false);
      expect(result.status, BlePreflightStatus.locationPermissionPermanentlyDenied);
      expect(result.title, 'Location permission is disabled');
      expect(result.recoveryAction, 'Open Settings');
    });

    test('8. Android <=30 (SDK 30) Location service OFF -> returns locationServicesDisabled and calls location settings action', () async {
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

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
        systemActions: systemActions,
      );

      final result = await service.check(requestIfNeeded: true);
      expect(systemActions.openLocationSettingsCalled, isTrue);
      expect(result.status, BlePreflightStatus.locationServicesDisabled);
      expect(result.title, 'Location is turned off');
      expect(result.recoveryAction, 'Turn on Location');
    });

    test('9. iOS with Bluetooth granted and ready -> returns ready', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check();
      expect(result.status, BlePreflightStatus.ready);
      expect(result.isReady, isTrue);
    });

    test('10. iOS Bluetooth permanently denied -> returns bluetoothPermissionPermanentlyDenied', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.permanentlyDenied,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check(requestIfNeeded: false);
      expect(result.status, BlePreflightStatus.bluetoothPermissionPermanentlyDenied);
      expect(result.recoveryAction, 'Open Settings');
    });

    test('11. iOS Bluetooth powered off -> returns bluetoothDisabled', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.poweredOff);
      final systemActions = FakeSystemBleActions()..bluetoothEnabledState = false;

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
        systemActions: systemActions,
      );

      final result = await service.check(requestIfNeeded: false);
      expect(result.status, BlePreflightStatus.bluetoothDisabled);
      expect(result.title, 'Bluetooth is turned off');
      expect(result.recoveryAction, 'Turn on Bluetooth');
    });

    test('12. Web platform -> returns bleUnsupported', () async {
      final platform = FakePlatformSdkInfo(isWeb: true);
      final permissions = FakePermissionDelegate();
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.ready);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      final result = await service.check();
      expect(result.status, BlePreflightStatus.bleUnsupported);
      expect(result.title, 'Bluetooth not supported');
    });

    test('13. BLE initializing -> waits for status ready and returns ready', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final bleStatus = FakeBleStatusDelegate(initialStatus: BleStatus.unknown);

      final service = BlePreflightService(
        platformSdkInfo: platform,
        permissionDelegate: permissions,
        bleStatusDelegate: bleStatus,
      );

      // Transition to ready after 50ms
      Timer(const Duration(milliseconds: 50), () {
        bleStatus.emitStatus(BleStatus.ready);
      });

      final result = await service.check(initTimeout: const Duration(milliseconds: 500));
      expect(result.status, BlePreflightStatus.ready);
    });

    test('14. System actions abstraction delegates appropriately', () async {
      final platform = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final permissions = FakePermissionDelegate();
      final actions = DefaultSystemBleActions(
        permissions: permissions,
        platformSdkInfo: platform,
      );

      await actions.requestBluetoothPermission();
      expect(permissions.requestedPermissions, contains(Permission.bluetoothScan));

      await actions.openAppSettings();
      expect(permissions.appSettingsOpened, isTrue);

      await actions.openBluetoothSettings();
      expect(permissions.bluetoothSettingsOpened, isTrue);

      await actions.openLocationSettings();
      expect(permissions.locationSettingsOpened, isTrue);
    });
  });
}
