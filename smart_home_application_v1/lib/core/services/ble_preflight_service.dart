import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

enum BlePreflightStatus {
  ready,
  bluetoothPermissionRequired,
  bluetoothPermissionPermanentlyDenied,
  bluetoothDisabled,
  locationPermissionRequired,
  locationPermissionPermanentlyDenied,
  locationServicesDisabled,
  bleUnsupported,
  bleInitializing,
}

class BlePreflightResult {
  const BlePreflightResult({
    required this.status,
    required this.message,
    this.title,
    this.recoveryAction,
  });

  final BlePreflightStatus status;
  final String message;
  final String? title;
  final String? recoveryAction;

  bool get isReady => status == BlePreflightStatus.ready;

  static const readyResult = BlePreflightResult(
    status: BlePreflightStatus.ready,
    message: 'Bluetooth and system prerequisites are ready.',
    title: 'Ready',
  );

  @override
  String toString() => 'BlePreflightResult($status, message: $message)';
}

/// Abstraction for platform inspection and Android SDK level.
abstract class PlatformSdkInfo {
  TargetPlatform get platform => defaultTargetPlatform;
  bool get isWeb => kIsWeb;
  Future<int> getAndroidSdkVersion();
}

class DefaultPlatformSdkInfo implements PlatformSdkInfo {
  const DefaultPlatformSdkInfo({this.overrideAndroidSdkVersion});

  final int? overrideAndroidSdkVersion;
  static const MethodChannel _nativeChannel =
      MethodChannel('eh_home/system_ble');

  @override
  TargetPlatform get platform => defaultTargetPlatform;

  @override
  bool get isWeb => kIsWeb;

  @override
  Future<int> getAndroidSdkVersion() async {
    if (overrideAndroidSdkVersion != null) {
      return overrideAndroidSdkVersion!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final sdk =
            await _nativeChannel.invokeMethod<int>('getAndroidSdkVersion');
        if (sdk != null) return sdk;
      } catch (_) {}
    }
    return 33;
  }
}

/// Abstraction for permission inspection & requests.
abstract class PermissionDelegate {
  Future<PermissionStatus> checkStatus(Permission permission);
  Future<PermissionStatus> requestPermission(Permission permission);
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  );
  Future<ServiceStatus> checkLocationServiceStatus();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<bool> openBluetoothSettings();
}

class DefaultPermissionDelegate implements PermissionDelegate {
  const DefaultPermissionDelegate();

  @override
  Future<PermissionStatus> checkStatus(Permission permission) =>
      permission.status;

  @override
  Future<PermissionStatus> requestPermission(Permission permission) =>
      permission.request();

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) =>
      permissions.request();

  @override
  Future<ServiceStatus> checkLocationServiceStatus() =>
      Permission.location.serviceStatus;

  @override
  Future<bool> openAppSettings() => openAppSettings();

  @override
  Future<bool> openLocationSettings() async => openAppSettings();

  @override
  Future<bool> openBluetoothSettings() async => openAppSettings();
}

/// Abstraction for BLE adapter status and status stream.
abstract class BleStatusDelegate {
  BleStatus get status;
  Stream<BleStatus> get statusStream;
}

class DefaultBleStatusDelegate implements BleStatusDelegate {
  DefaultBleStatusDelegate(this._ble);
  final FlutterReactiveBle _ble;

  @override
  BleStatus get status => _ble.status;

  @override
  Stream<BleStatus> get statusStream => _ble.statusStream;
}

/// Abstraction for system actions (opening settings, requesting permissions, native radio enable).
abstract class SystemBleActions {
  Future<bool> requestBluetoothPermission();
  Future<bool> requestLocationPermission();
  Future<bool> requestBluetoothEnable();
  Future<bool> isBluetoothEnabled();
  Future<bool> isLocationEnabled();
  Future<bool> openAppSettings();
  Future<bool> openBluetoothSettings();
  Future<bool> openLocationSettings();
}

class DefaultSystemBleActions implements SystemBleActions {
  const DefaultSystemBleActions({
    PermissionDelegate? permissions,
    PlatformSdkInfo? platformSdkInfo,
  })  : _permissions = permissions ?? const DefaultPermissionDelegate(),
        _platformSdkInfo = platformSdkInfo ?? const DefaultPlatformSdkInfo();

  final PermissionDelegate _permissions;
  final PlatformSdkInfo _platformSdkInfo;

  static const MethodChannel _nativeChannel =
      MethodChannel('eh_home/system_ble');

  @override
  Future<bool> requestBluetoothPermission() async {
    if (_platformSdkInfo.isWeb) return false;
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      final sdk = await _platformSdkInfo.getAndroidSdkVersion();
      if (sdk >= 31) {
        final result = await _permissions.requestPermissions([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ]);
        return result[Permission.bluetoothScan]?.isGranted == true &&
            result[Permission.bluetoothConnect]?.isGranted == true;
      } else {
        final status =
            await _permissions.requestPermission(Permission.locationWhenInUse);
        return status.isGranted;
      }
    } else if (_platformSdkInfo.platform == TargetPlatform.iOS) {
      final status =
          await _permissions.requestPermission(Permission.bluetooth);
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> requestLocationPermission() async {
    final status =
        await _permissions.requestPermission(Permission.locationWhenInUse);
    return status.isGranted;
  }

  @override
  Future<bool> requestBluetoothEnable() async {
    if (_platformSdkInfo.isWeb) return false;
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      try {
        final enabled =
            await _nativeChannel.invokeMethod<bool>('requestBluetoothEnable');
        return enabled ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    if (_platformSdkInfo.isWeb) return false;
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      try {
        final enabled =
            await _nativeChannel.invokeMethod<bool>('isBluetoothEnabled');
        if (enabled != null) return enabled;
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<bool> isLocationEnabled() async {
    if (_platformSdkInfo.isWeb) return true;
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      try {
        final enabled =
            await _nativeChannel.invokeMethod<bool>('isLocationEnabled');
        if (enabled != null) return enabled;
      } catch (_) {}
    }
    final status = await _permissions.checkLocationServiceStatus();
    return status == ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() => _permissions.openAppSettings();

  @override
  Future<bool> openBluetoothSettings() async {
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      try {
        final opened =
            await _nativeChannel.invokeMethod<bool>('openBluetoothSettings');
        if (opened == true) return true;
      } catch (_) {}
    }
    return _permissions.openBluetoothSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    if (_platformSdkInfo.platform == TargetPlatform.android) {
      try {
        final opened =
            await _nativeChannel.invokeMethod<bool>('openLocationSettings');
        if (opened == true) return true;
      } catch (_) {}
    }
    return _permissions.openLocationSettings();
  }
}

/// Centralized production service for BLE pre-flight inspection and validation.
class BlePreflightService {
  BlePreflightService({
    PlatformSdkInfo? platformSdkInfo,
    PermissionDelegate? permissionDelegate,
    BleStatusDelegate? bleStatusDelegate,
    SystemBleActions? systemActions,
    FlutterReactiveBle? ble,
  })  : _platformSdkInfo = platformSdkInfo ?? const DefaultPlatformSdkInfo(),
        _permissionDelegate =
            permissionDelegate ?? const DefaultPermissionDelegate(),
        _bleStatusDelegate = bleStatusDelegate ??
            (ble != null ? DefaultBleStatusDelegate(ble) : null),
        _systemActions = systemActions ??
            DefaultSystemBleActions(
              permissions: permissionDelegate,
              platformSdkInfo: platformSdkInfo,
            );

  final PlatformSdkInfo _platformSdkInfo;
  final PermissionDelegate _permissionDelegate;
  final BleStatusDelegate? _bleStatusDelegate;
  final SystemBleActions _systemActions;

  SystemBleActions get systemActions => _systemActions;

  /// Runs the full deterministic BLE pre-flight sequence invoking real native OS dialogs.
  Future<BlePreflightResult> check({
    bool requestIfNeeded = true,
    Duration initTimeout = const Duration(seconds: 2),
  }) async {
    // 1. Platform Support Check
    if (_platformSdkInfo.isWeb) {
      _logPreflight(
        platform: 'web',
        result: 'ble_unsupported',
        details: 'Web browsers do not support native mobile BLE commissioning.',
      );
      return const BlePreflightResult(
        status: BlePreflightStatus.bleUnsupported,
        title: 'Bluetooth not supported',
        message: 'Bluetooth commissioning is only supported in the mobile app.',
      );
    }

    final platform = _platformSdkInfo.platform;

    // 2. Permission Check by Platform
    if (platform == TargetPlatform.android) {
      final sdk = await _platformSdkInfo.getAndroidSdkVersion();

      if (sdk >= 31) {
        // Android 12+ (API 31+): BLUETOOTH_SCAN and BLUETOOTH_CONNECT with neverForLocation
        var scanStatus = await _permissionDelegate.checkStatus(
          Permission.bluetoothScan,
        );
        var connectStatus = await _permissionDelegate.checkStatus(
          Permission.bluetoothConnect,
        );

        if (scanStatus.isPermanentlyDenied ||
            connectStatus.isPermanentlyDenied) {
          _logPreflight(
            platform: 'android',
            sdk: sdk,
            bluetoothPermission: 'permanently_denied',
            result: 'bluetooth_permission_permanently_denied',
          );
          return const BlePreflightResult(
            status: BlePreflightStatus.bluetoothPermissionPermanentlyDenied,
            title: 'Bluetooth permission is disabled',
            message:
                'Bluetooth access is disabled for EH Home. Enable it in Settings to connect your Smart Switch.',
            recoveryAction: 'Open Settings',
          );
        }

        if (!scanStatus.isGranted || !connectStatus.isGranted) {
          if (requestIfNeeded) {
            final requested = await _permissionDelegate.requestPermissions([
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
            ]);
            scanStatus =
                requested[Permission.bluetoothScan] ?? PermissionStatus.denied;
            connectStatus = requested[Permission.bluetoothConnect] ??
                PermissionStatus.denied;

            if (scanStatus.isPermanentlyDenied ||
                connectStatus.isPermanentlyDenied) {
              _logPreflight(
                platform: 'android',
                sdk: sdk,
                bluetoothPermission: 'permanently_denied_after_request',
                result: 'bluetooth_permission_permanently_denied',
              );
              return const BlePreflightResult(
                status: BlePreflightStatus.bluetoothPermissionPermanentlyDenied,
                title: 'Bluetooth permission is disabled',
                message:
                    'Bluetooth access is disabled for EH Home. Enable it in Settings to connect your Smart Switch.',
                recoveryAction: 'Open Settings',
              );
            }

            if (!scanStatus.isGranted || !connectStatus.isGranted) {
              _logPreflight(
                platform: 'android',
                sdk: sdk,
                bluetoothPermission: 'denied',
                result: 'bluetooth_permission_required',
              );
              return const BlePreflightResult(
                status: BlePreflightStatus.bluetoothPermissionRequired,
                title: 'Bluetooth permission needed',
                message:
                    'Bluetooth permission is required to find and connect to your Smart Switch.',
                recoveryAction: 'Allow Bluetooth',
              );
            }
          } else {
            _logPreflight(
              platform: 'android',
              sdk: sdk,
              bluetoothPermission: 'required',
              result: 'bluetooth_permission_required',
            );
            return const BlePreflightResult(
              status: BlePreflightStatus.bluetoothPermissionRequired,
              title: 'Bluetooth permission needed',
              message:
                  'Bluetooth permission is required to find and connect to your Smart Switch.',
              recoveryAction: 'Allow Bluetooth',
            );
          }
        }
      } else {
        // Android <= 30 (Android 11 and lower): Location permission is required for BLE scanning
        var locStatus = await _permissionDelegate.checkStatus(
          Permission.locationWhenInUse,
        );

        if (locStatus.isPermanentlyDenied) {
          _logPreflight(
            platform: 'android',
            sdk: sdk,
            locationPermission: 'permanently_denied',
            result: 'location_permission_permanently_denied',
          );
          return const BlePreflightResult(
            status: BlePreflightStatus.locationPermissionPermanentlyDenied,
            title: 'Location permission is disabled',
            message:
                'Location access is disabled for EH Home. Android requires it to discover nearby Bluetooth devices.',
            recoveryAction: 'Open Settings',
          );
        }

        if (!locStatus.isGranted && !locStatus.isLimited) {
          if (requestIfNeeded) {
            locStatus = await _permissionDelegate.requestPermission(
              Permission.locationWhenInUse,
            );
            if (locStatus.isPermanentlyDenied) {
              _logPreflight(
                platform: 'android',
                sdk: sdk,
                locationPermission: 'permanently_denied_after_request',
                result: 'location_permission_permanently_denied',
              );
              return const BlePreflightResult(
                status: BlePreflightStatus.locationPermissionPermanentlyDenied,
                title: 'Location permission is disabled',
                message:
                    'Location access is disabled for EH Home. Android requires it to discover nearby Bluetooth devices.',
                recoveryAction: 'Open Settings',
              );
            }
            if (!locStatus.isGranted && !locStatus.isLimited) {
              _logPreflight(
                platform: 'android',
                sdk: sdk,
                locationPermission: 'denied',
                result: 'location_permission_required',
              );
              return const BlePreflightResult(
                status: BlePreflightStatus.locationPermissionRequired,
                title: 'Location permission needed',
                message:
                    'Android requires Location permission to discover nearby Bluetooth devices.',
                recoveryAction: 'Allow Location',
              );
            }
          } else {
            _logPreflight(
              platform: 'android',
              sdk: sdk,
              locationPermission: 'required',
              result: 'location_permission_required',
            );
            return const BlePreflightResult(
              status: BlePreflightStatus.locationPermissionRequired,
              title: 'Location permission needed',
              message:
                  'Android requires Location permission to discover nearby Bluetooth devices.',
              recoveryAction: 'Allow Location',
            );
          }
        }

        // Check Location Service status (Android <= 30 only)
        final isLocEnabled = await _systemActions.isLocationEnabled();
        if (!isLocEnabled) {
          _logPreflight(
            platform: 'android',
            sdk: sdk,
            locationService: 'disabled',
            result: 'location_services_disabled',
          );
          if (requestIfNeeded) {
            await _systemActions.openLocationSettings();
          }
          return const BlePreflightResult(
            status: BlePreflightStatus.locationServicesDisabled,
            title: 'Location is turned off',
            message:
                'Location services must be turned on to discover nearby Bluetooth devices on this version of Android.',
            recoveryAction: 'Turn on Location',
          );
        }
      }
    } else if (platform == TargetPlatform.iOS) {
      var btStatus = await _permissionDelegate.checkStatus(
        Permission.bluetooth,
      );

      if (btStatus.isPermanentlyDenied || btStatus.isRestricted) {
        _logPreflight(
          platform: 'ios',
          bluetoothPermission: 'permanently_denied',
          result: 'bluetooth_permission_permanently_denied',
        );
        return const BlePreflightResult(
          status: BlePreflightStatus.bluetoothPermissionPermanentlyDenied,
          title: 'Bluetooth access is disabled',
          message:
              'Bluetooth access is disabled in iOS Settings. Enable it to find your Smart Switch.',
          recoveryAction: 'Open Settings',
        );
      }

      if (!btStatus.isGranted) {
        if (requestIfNeeded) {
          btStatus = await _permissionDelegate.requestPermission(
            Permission.bluetooth,
          );
          if (btStatus.isPermanentlyDenied || btStatus.isRestricted) {
            _logPreflight(
              platform: 'ios',
              bluetoothPermission: 'permanently_denied_after_request',
              result: 'bluetooth_permission_permanently_denied',
            );
            return const BlePreflightResult(
              status: BlePreflightStatus.bluetoothPermissionPermanentlyDenied,
              title: 'Bluetooth access is disabled',
              message:
                  'Bluetooth access is disabled in iOS Settings. Enable it to find your Smart Switch.',
              recoveryAction: 'Open Settings',
            );
          }
          if (!btStatus.isGranted) {
            _logPreflight(
              platform: 'ios',
              bluetoothPermission: 'denied',
              result: 'bluetooth_permission_required',
            );
            return const BlePreflightResult(
              status: BlePreflightStatus.bluetoothPermissionRequired,
              title: 'Bluetooth permission needed',
              message:
                  'Bluetooth access is needed to find and connect to your Smart Switch.',
              recoveryAction: 'Allow Bluetooth',
            );
          }
        } else {
          _logPreflight(
            platform: 'ios',
            bluetoothPermission: 'required',
            result: 'bluetooth_permission_required',
          );
          return const BlePreflightResult(
            status: BlePreflightStatus.bluetoothPermissionRequired,
            title: 'Bluetooth permission needed',
            message:
                'Bluetooth access is needed to find and connect to your Smart Switch.',
            recoveryAction: 'Allow Bluetooth',
          );
        }
      }
    }

    // 3. Bluetooth Radio & Adapter Status Check
    var isBtEnabled = await _systemActions.isBluetoothEnabled();
    if (_bleStatusDelegate != null &&
        _bleStatusDelegate.status == BleStatus.poweredOff) {
      isBtEnabled = false;
    }

    if (!isBtEnabled) {
      if (requestIfNeeded && platform == TargetPlatform.android) {
        // Trigger native Android ACTION_REQUEST_ENABLE popup
        final enabled = await _systemActions.requestBluetoothEnable();
        if (enabled) {
          isBtEnabled = await _systemActions.isBluetoothEnabled();
        }
      }

      if (!isBtEnabled) {
        _logPreflight(
          platform: platform.name,
          bluetoothState: 'poweredOff',
          result: 'bluetooth_disabled',
        );
        return const BlePreflightResult(
          status: BlePreflightStatus.bluetoothDisabled,
          title: 'Bluetooth is turned off',
          message:
              'Bluetooth is currently turned off. Turn it on to find your Smart Switch.',
          recoveryAction: 'Turn on Bluetooth',
        );
      }
    }

    if (_bleStatusDelegate != null) {
      var currentStatus = _bleStatusDelegate.status;

      if (currentStatus == BleStatus.unsupported) {
        _logPreflight(
          platform: platform.name,
          bluetoothState: 'unsupported',
          result: 'ble_unsupported',
        );
        return const BlePreflightResult(
          status: BlePreflightStatus.bleUnsupported,
          title: 'Bluetooth not supported',
          message: 'This device does not support Bluetooth Low Energy (BLE).',
        );
      }

      if (currentStatus == BleStatus.locationServicesDisabled &&
          platform == TargetPlatform.android) {
        final isLocOn = await _systemActions.isLocationEnabled();
        if (!isLocOn) {
          _logPreflight(
            platform: platform.name,
            bluetoothState: 'locationServicesDisabled',
            result: 'location_services_disabled',
          );
          return const BlePreflightResult(
            status: BlePreflightStatus.locationServicesDisabled,
            title: 'Location is turned off',
            message:
                'Location services are turned off. Turn on Location to discover nearby Bluetooth devices.',
            recoveryAction: 'Turn on Location',
          );
        }
      }

      // If status is still initializing, wait briefly with bounded timeout:
      if (currentStatus != BleStatus.ready &&
          currentStatus != BleStatus.poweredOff) {
        try {
          final readyStatus = await _bleStatusDelegate.statusStream
              .where((s) => s == BleStatus.ready || s == BleStatus.poweredOff)
              .first
              .timeout(initTimeout);

          if (readyStatus == BleStatus.poweredOff) {
            return const BlePreflightResult(
              status: BlePreflightStatus.bluetoothDisabled,
              title: 'Bluetooth is turned off',
              message:
                  'Bluetooth is currently turned off. Turn it on to find your Smart Switch.',
              recoveryAction: 'Turn on Bluetooth',
            );
          }
        } catch (_) {
          // Bounded timeout expired: do not freeze or trap user in custom card
        }
      }
    }

    _logPreflight(
      platform: platform.name,
      bluetoothState: 'ready',
      result: 'ready',
    );
    return BlePreflightResult.readyResult;
  }

  void _logPreflight({
    required String platform,
    int? sdk,
    String? bluetoothPermission,
    String? locationPermission,
    String? locationService,
    String? bluetoothState,
    required String result,
    String? details,
  }) {
    final buffer = StringBuffer('BLE_PREFLIGHT: platform=$platform');
    if (sdk != null) buffer.write(' sdk=$sdk');
    if (bluetoothPermission != null) {
      buffer.write(' bluetoothPermission=$bluetoothPermission');
    }
    if (locationPermission != null) {
      buffer.write(' locationPermission=$locationPermission');
    }
    if (locationService != null) {
      buffer.write(' locationService=$locationService');
    }
    if (bluetoothState != null) buffer.write(' bluetoothState=$bluetoothState');
    buffer.write(' result=$result');
    if (details != null) buffer.write(' details="$details"');
    debugPrint(buffer.toString());
  }
}
