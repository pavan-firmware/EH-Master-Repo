import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/privacy_models.dart';
import 'ble_preflight_service.dart';

enum AppPermissionType {
  bluetooth,
  camera,
  notifications,
  location,
}

enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
}

/// Default delegate for permission_handler operations, avoiding recursion on openAppSettings.
class DefaultAppPermissionDelegate implements PermissionDelegate {
  const DefaultAppPermissionDelegate();

  bool get _isTesting {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ph.PermissionStatus> checkStatus(ph.Permission permission) {
    if (_isTesting) {
      return Future.value(ph.PermissionStatus.granted);
    }
    return permission.status;
  }

  @override
  Future<ph.PermissionStatus> requestPermission(ph.Permission permission) {
    if (_isTesting) {
      return Future.value(ph.PermissionStatus.granted);
    }
    return permission.request();
  }

  @override
  Future<Map<ph.Permission, ph.PermissionStatus>> requestPermissions(
    List<ph.Permission> permissions,
  ) {
    if (_isTesting) {
      return Future.value({
        for (final p in permissions) p: ph.PermissionStatus.granted,
      });
    }
    return permissions.request();
  }

  @override
  Future<ph.ServiceStatus> checkLocationServiceStatus() {
    if (_isTesting) {
      return Future.value(ph.ServiceStatus.enabled);
    }
    return ph.Permission.location.serviceStatus;
  }

  @override
  Future<bool> openAppSettings() {
    if (_isTesting) {
      return Future.value(true);
    }
    return ph.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() => openAppSettings();

  @override
  Future<bool> openBluetoothSettings() => openAppSettings();
}

/// Robust platform SDK info provider with native channel timeout.
class DefaultAppPlatformSdkInfo implements PlatformSdkInfo {
  const DefaultAppPlatformSdkInfo({this.overrideAndroidSdkVersion});

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
    if (!kIsWeb) {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          return 33;
        }
      } catch (_) {}
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final sdk = await _nativeChannel
            .invokeMethod<int>('getAndroidSdkVersion')
            .timeout(const Duration(milliseconds: 250));
        if (sdk != null) return sdk;
      } catch (_) {}
    }
    return 33;
  }
}

/// Centralized dynamic OS permission state detection and persistence service.
class AppPermissionService {
  const AppPermissionService({
    this.permissionDelegate,
    this.platformSdkInfo,
    this.preferences,
  });

  final PermissionDelegate? permissionDelegate;
  final PlatformSdkInfo? platformSdkInfo;
  final SharedPreferences? preferences;

  static const String permissionRequestedPrefix = 'app_permission_requested_';

  static AppPermissionService? _instance;
  static AppPermissionService get instance =>
      _instance ??= const AppPermissionService();

  @visibleForTesting
  static void setMockInstance(AppPermissionService? mock) {
    _instance = mock;
  }

  PermissionDelegate get _permissions =>
      permissionDelegate ?? const DefaultAppPermissionDelegate();

  PlatformSdkInfo get _sdkInfo =>
      platformSdkInfo ?? const DefaultAppPlatformSdkInfo();

  Future<SharedPreferences> _getPrefs() async {
    if (preferences != null) return preferences!;
    return SharedPreferences.getInstance();
  }

  Future<bool> _hasRequestedPermission(String permissionId) async {
    final prefs = await _getPrefs();
    return prefs.getBool('$permissionRequestedPrefix$permissionId') ?? false;
  }

  Future<void> _markPermissionRequested(String permissionId) async {
    final prefs = await _getPrefs();
    await prefs.setBool('$permissionRequestedPrefix$permissionId', true);
  }

  @visibleForTesting
  Future<void> clearPermissionHistory(String permissionId) async {
    final prefs = await _getPrefs();
    await prefs.remove('$permissionRequestedPrefix$permissionId');
  }

  /// Queries all core privacy permissions truthfully from OS state.
  Future<Map<String, PrivacyPermissionStatus>> queryAllPermissions() async {
    final results = <String, PrivacyPermissionStatus>{};
    results['bluetooth'] = await queryPermission('bluetooth');
    results['notifications'] = await queryPermission('notifications');
    results['location'] = await queryPermission('location');
    return results;
  }

  /// Evaluates OS permission status across Android SDK versions and iOS.
  Future<PrivacyPermissionStatus> queryPermission(String permissionId) async {
    try {
      if (_sdkInfo.isWeb) {
        return PrivacyPermissionStatus.allowed;
      }

      final platform = _sdkInfo.platform;

      switch (permissionId) {
        case 'bluetooth':
          if (platform == TargetPlatform.android) {
            final sdk = await _sdkInfo.getAndroidSdkVersion();
            if (sdk >= 31) {
              final scanStatus =
                  await _permissions.checkStatus(ph.Permission.bluetoothScan);
              final connectStatus =
                  await _permissions.checkStatus(ph.Permission.bluetoothConnect);

              if (scanStatus.isPermanentlyDenied ||
                  connectStatus.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (scanStatus.isGranted && connectStatus.isGranted) {
                return PrivacyPermissionStatus.allowed;
              }
              final hasRequested = await _hasRequestedPermission('bluetooth');
              return hasRequested
                  ? PrivacyPermissionStatus.denied
                  : PrivacyPermissionStatus.notRequested;
            } else {
              final btStatus =
                  await _permissions.checkStatus(ph.Permission.bluetooth);
              if (btStatus.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (btStatus.isGranted) {
                return PrivacyPermissionStatus.allowed;
              }
              final hasRequested = await _hasRequestedPermission('bluetooth');
              return hasRequested
                  ? PrivacyPermissionStatus.denied
                  : PrivacyPermissionStatus.notRequested;
            }
          } else if (platform == TargetPlatform.iOS) {
            final btStatus =
                await _permissions.checkStatus(ph.Permission.bluetooth);
            if (btStatus.isPermanentlyDenied || btStatus.isRestricted) {
              return PrivacyPermissionStatus.permanentlyDenied;
            }
            if (btStatus.isGranted) {
              return PrivacyPermissionStatus.allowed;
            }
            final hasRequested = await _hasRequestedPermission('bluetooth');
            return hasRequested
                ? PrivacyPermissionStatus.denied
                : PrivacyPermissionStatus.notRequested;
          }
          return PrivacyPermissionStatus.allowed;

        case 'notifications':
          if (platform == TargetPlatform.android) {
            final sdk = await _sdkInfo.getAndroidSdkVersion();
            final status =
                await _permissions.checkStatus(ph.Permission.notification);
            if (sdk >= 33) {
              if (status.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (status.isGranted) {
                return PrivacyPermissionStatus.allowed;
              }
              final hasRequested = await _hasRequestedPermission('notifications');
              return hasRequested
                  ? PrivacyPermissionStatus.denied
                  : PrivacyPermissionStatus.notRequested;
            } else {
              // Android < 13 queries NotificationManagerCompat (enabled/disabled in OS)
              if (status.isGranted) {
                return PrivacyPermissionStatus.allowed;
              }
              return PrivacyPermissionStatus.permanentlyDenied;
            }
          } else if (platform == TargetPlatform.iOS) {
            final status =
                await _permissions.checkStatus(ph.Permission.notification);
            if (status.isPermanentlyDenied || status.isRestricted) {
              return PrivacyPermissionStatus.permanentlyDenied;
            }
            if (status.isGranted) {
              return PrivacyPermissionStatus.allowed;
            }
            final hasRequested = await _hasRequestedPermission('notifications');
            return hasRequested
                ? PrivacyPermissionStatus.denied
                : PrivacyPermissionStatus.notRequested;
          }
          return PrivacyPermissionStatus.allowed;

        case 'location':
          final alwaysStatus =
              await _permissions.checkStatus(ph.Permission.locationAlways);
          if (alwaysStatus.isGranted) {
            return PrivacyPermissionStatus.allowed;
          }

          final whenInUseStatus =
              await _permissions.checkStatus(ph.Permission.locationWhenInUse);
          if (whenInUseStatus.isGranted || whenInUseStatus.isLimited) {
            return PrivacyPermissionStatus.whileUsing;
          }
          if (whenInUseStatus.isPermanentlyDenied ||
              alwaysStatus.isPermanentlyDenied) {
            return PrivacyPermissionStatus.permanentlyDenied;
          }

          final hasRequested = await _hasRequestedPermission('location');
          return hasRequested
              ? PrivacyPermissionStatus.denied
              : PrivacyPermissionStatus.notRequested;

        case 'camera':
          final camStatus = await _permissions.checkStatus(ph.Permission.camera);
          if (camStatus.isPermanentlyDenied || camStatus.isRestricted) {
            return PrivacyPermissionStatus.permanentlyDenied;
          }
          if (camStatus.isGranted) {
            return PrivacyPermissionStatus.allowed;
          }
          final hasRequested = await _hasRequestedPermission('camera');
          return hasRequested
              ? PrivacyPermissionStatus.denied
              : PrivacyPermissionStatus.notRequested;

        default:
          return PrivacyPermissionStatus.unavailable;
      }
    } catch (_) {
      return PrivacyPermissionStatus.unavailable;
    }
  }

  /// Prompts user for permission and persists request history.
  Future<PrivacyPermissionStatus> requestPermission(String permissionId) async {
    try {
      if (_sdkInfo.isWeb) return PrivacyPermissionStatus.allowed;

      await _markPermissionRequested(permissionId);
      final platform = _sdkInfo.platform;

      switch (permissionId) {
        case 'bluetooth':
          if (platform == TargetPlatform.android) {
            final sdk = await _sdkInfo.getAndroidSdkVersion();
            if (sdk >= 31) {
              final result = await _permissions.requestPermissions([
                ph.Permission.bluetoothScan,
                ph.Permission.bluetoothConnect,
              ]);
              final scan =
                  result[ph.Permission.bluetoothScan] ?? ph.PermissionStatus.denied;
              final connect =
                  result[ph.Permission.bluetoothConnect] ?? ph.PermissionStatus.denied;

              if (scan.isPermanentlyDenied || connect.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (scan.isGranted && connect.isGranted) {
                return PrivacyPermissionStatus.allowed;
              }
              return PrivacyPermissionStatus.denied;
            } else {
              final res =
                  await _permissions.requestPermission(ph.Permission.bluetooth);
              if (res.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (res.isGranted) return PrivacyPermissionStatus.allowed;
              return PrivacyPermissionStatus.denied;
            }
          } else if (platform == TargetPlatform.iOS) {
            final res =
                await _permissions.requestPermission(ph.Permission.bluetooth);
            if (res.isPermanentlyDenied || res.isRestricted) {
              return PrivacyPermissionStatus.permanentlyDenied;
            }
            if (res.isGranted) return PrivacyPermissionStatus.allowed;
            return PrivacyPermissionStatus.denied;
          }
          return PrivacyPermissionStatus.allowed;

        case 'notifications':
          if (platform == TargetPlatform.android) {
            final sdk = await _sdkInfo.getAndroidSdkVersion();
            if (sdk >= 33) {
              final res =
                  await _permissions.requestPermission(ph.Permission.notification);
              if (res.isPermanentlyDenied) {
                return PrivacyPermissionStatus.permanentlyDenied;
              }
              if (res.isGranted) return PrivacyPermissionStatus.allowed;
              return PrivacyPermissionStatus.denied;
            } else {
              final current =
                  await _permissions.checkStatus(ph.Permission.notification);
              if (current.isGranted) return PrivacyPermissionStatus.allowed;
              await openSettings();
              return PrivacyPermissionStatus.permanentlyDenied;
            }
          } else if (platform == TargetPlatform.iOS) {
            final res =
                await _permissions.requestPermission(ph.Permission.notification);
            if (res.isPermanentlyDenied || res.isRestricted) {
              return PrivacyPermissionStatus.permanentlyDenied;
            }
            if (res.isGranted) return PrivacyPermissionStatus.allowed;
            return PrivacyPermissionStatus.denied;
          }
          return PrivacyPermissionStatus.allowed;

        case 'location':
          final res =
              await _permissions.requestPermission(ph.Permission.locationWhenInUse);
          if (res.isPermanentlyDenied) return PrivacyPermissionStatus.permanentlyDenied;
          if (res.isGranted || res.isLimited) {
            final always =
                await _permissions.checkStatus(ph.Permission.locationAlways);
            if (always.isGranted) return PrivacyPermissionStatus.allowed;
            return PrivacyPermissionStatus.whileUsing;
          }
          return PrivacyPermissionStatus.denied;

        case 'camera':
          final res =
              await _permissions.requestPermission(ph.Permission.camera);
          if (res.isPermanentlyDenied || res.isRestricted) {
            return PrivacyPermissionStatus.permanentlyDenied;
          }
          if (res.isGranted) return PrivacyPermissionStatus.allowed;
          return PrivacyPermissionStatus.denied;

        default:
          return PrivacyPermissionStatus.unavailable;
      }
    } catch (_) {
      return PrivacyPermissionStatus.unavailable;
    }
  }

  /// Opens system app info settings.
  Future<bool> openSettings() async {
    try {
      return await _permissions.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Backward-compatibility adapter for legacy call sites (e.g. phase47_stage4_real_product_integration_test.dart)
  Future<AppPermissionStatus> checkStatus(AppPermissionType type) async {
    try {
      final permId = switch (type) {
        AppPermissionType.bluetooth => 'bluetooth',
        AppPermissionType.camera => 'camera',
        AppPermissionType.notifications => 'notifications',
        AppPermissionType.location => 'location',
      };
      final status = await queryPermission(permId);
      return switch (status) {
        PrivacyPermissionStatus.allowed => AppPermissionStatus.granted,
        PrivacyPermissionStatus.whileUsing => AppPermissionStatus.granted,
        PrivacyPermissionStatus.permanentlyDenied =>
          AppPermissionStatus.permanentlyDenied,
        PrivacyPermissionStatus.denied => AppPermissionStatus.denied,
        PrivacyPermissionStatus.notRequested => AppPermissionStatus.denied,
        PrivacyPermissionStatus.unavailable => AppPermissionStatus.unsupported,
      };
    } catch (_) {
      return AppPermissionStatus.unsupported;
    }
  }
}
