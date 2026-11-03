import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/privacy_models.dart';
import 'package:smart_home_application_v1/core/services/app_permission_service.dart';
import 'package:smart_home_application_v1/core/services/ble_preflight_service.dart';

/// Adversarial mock delegate for fine-grained permission control and fault injection.
class AdversarialPermissionDelegate implements PermissionDelegate {
  AdversarialPermissionDelegate({
    Map<Permission, PermissionStatus>? statuses,
    Map<Permission, ServiceStatus>? serviceStatuses,
    Map<Permission, PermissionStatus>? requestResponses,
    this.throwOnCheck = false,
    this.throwOnRequest = false,
    this.throwOnOpenSettings = false,
  })  : statuses = Map<Permission, PermissionStatus>.from(statuses ?? {}),
        serviceStatuses =
            Map<Permission, ServiceStatus>.from(serviceStatuses ?? {}),
        requestResponses =
            Map<Permission, PermissionStatus>.from(requestResponses ?? {});

  final Map<Permission, PermissionStatus> statuses;
  final Map<Permission, ServiceStatus> serviceStatuses;
  final Map<Permission, PermissionStatus> requestResponses;
  final bool throwOnCheck;
  final bool throwOnRequest;
  final bool throwOnOpenSettings;

  final List<Permission> requestedPermissions = [];
  bool appSettingsOpened = false;
  bool bluetoothSettingsOpened = false;
  bool locationSettingsOpened = false;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async {
    if (throwOnCheck) {
      throw StateError('Simulated checkStatus failure for $permission');
    }
    return statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    if (throwOnRequest) {
      throw StateError('Simulated requestPermission failure for $permission');
    }
    requestedPermissions.add(permission);
    final response = requestResponses[permission] ?? PermissionStatus.granted;
    statuses[permission] = response;
    return response;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    if (throwOnRequest) {
      throw StateError('Simulated requestPermissions failure for $permissions');
    }
    requestedPermissions.addAll(permissions);
    final result = <Permission, PermissionStatus>{};
    for (final p in permissions) {
      final status = requestResponses[p] ?? PermissionStatus.granted;
      statuses[p] = status;
      result[p] = status;
    }
    return result;
  }

  @override
  Future<ServiceStatus> checkLocationServiceStatus() async {
    return serviceStatuses[Permission.location] ?? ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async {
    if (throwOnOpenSettings) {
      throw StateError('Simulated openAppSettings failure');
    }
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

/// Adversarial mock platform SDK info provider with configurable platform and SDK version.
class AdversarialPlatformSdkInfo implements PlatformSdkInfo {
  AdversarialPlatformSdkInfo({
    this.platform = TargetPlatform.android,
    this.isWeb = false,
    this.sdkVersion = 33,
    this.throwOnGetSdk = false,
  });

  @override
  final TargetPlatform platform;

  @override
  final bool isWeb;

  final int sdkVersion;
  final bool throwOnGetSdk;

  @override
  Future<int> getAndroidSdkVersion() async {
    if (throwOnGetSdk) {
      throw StateError('Simulated getAndroidSdkVersion failure');
    }
    return sdkVersion;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ===========================================================================
  // GROUP 1: Android SDK Levels (29, 30, 31, 32, 33, 34) Comprehensive Matrix
  // ===========================================================================
  group('Adversarial Matrix — Android SDK Levels (29, 30, 31, 32, 33, 34)', () {
    const legacySdkLevels = [29, 30]; // Android 10, Android 11
    const modernSdkLevels = [31, 32, 33, 34]; // Android 12, 12L, 13, 14

    for (final sdkLevel in legacySdkLevels) {
      test('SDK $sdkLevel (Android < 12): Bluetooth uses legacy Permission.bluetooth', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        // Granted
        final delegateGranted = AdversarialPermissionDelegate(
          statuses: {Permission.bluetooth: PermissionStatus.granted},
        );
        final serviceGranted = AppPermissionService(
          permissionDelegate: delegateGranted,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceGranted.queryPermission('bluetooth'),
          PrivacyPermissionStatus.allowed,
        );

        // Denied (unrequested)
        final delegateDenied = AdversarialPermissionDelegate(
          statuses: {Permission.bluetooth: PermissionStatus.denied},
        );
        final serviceDenied = AppPermissionService(
          permissionDelegate: delegateDenied,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceDenied.queryPermission('bluetooth'),
          PrivacyPermissionStatus.notRequested,
        );

        // Permanently denied
        final delegatePermDenied = AdversarialPermissionDelegate(
          statuses: {Permission.bluetooth: PermissionStatus.permanentlyDenied},
        );
        final servicePermDenied = AppPermissionService(
          permissionDelegate: delegatePermDenied,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await servicePermDenied.queryPermission('bluetooth'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });

      test('SDK $sdkLevel (Android < 13): Notifications evaluate system status (permanentlyDenied when off)', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );

        // Enabled
        final delegateEnabled = AdversarialPermissionDelegate(
          statuses: {Permission.notification: PermissionStatus.granted},
        );
        final serviceEnabled = AppPermissionService(
          permissionDelegate: delegateEnabled,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceEnabled.queryPermission('notifications'),
          PrivacyPermissionStatus.allowed,
        );

        // Disabled (cannot be prompted at runtime, must open system settings)
        final delegateDisabled = AdversarialPermissionDelegate(
          statuses: {Permission.notification: PermissionStatus.denied},
        );
        final serviceDisabled = AppPermissionService(
          permissionDelegate: delegateDisabled,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceDisabled.queryPermission('notifications'),
          PrivacyPermissionStatus.permanentlyDenied,
        );

        // Requesting disabled notifications on Android < 13 opens settings and returns permanentlyDenied
        final reqResult = await serviceDisabled.requestPermission('notifications');
        expect(reqResult, PrivacyPermissionStatus.permanentlyDenied);
        expect(delegateDisabled.appSettingsOpened, isTrue);
      });
    }

    for (final sdkLevel in modernSdkLevels) {
      test('SDK $sdkLevel (Android 12+): Bluetooth checks both bluetoothScan and bluetoothConnect', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );

        // Both granted -> allowed
        final delegateGranted = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.granted,
          },
        );
        final serviceGranted = AppPermissionService(
          permissionDelegate: delegateGranted,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceGranted.queryPermission('bluetooth'),
          PrivacyPermissionStatus.allowed,
        );

        // Both denied (unrequested) -> notRequested
        final delegateDenied = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.denied,
          },
        );
        final serviceDenied = AppPermissionService(
          permissionDelegate: delegateDenied,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceDenied.queryPermission('bluetooth'),
          PrivacyPermissionStatus.notRequested,
        );

        // Both permanently denied -> permanentlyDenied
        final delegatePermDenied = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final servicePermDenied = AppPermissionService(
          permissionDelegate: delegatePermDenied,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await servicePermDenied.queryPermission('bluetooth'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });
    }

    // Modern Android 13 & 14 Notification Dialog Runtime Matrix
    for (final sdkLevel in [33, 34]) {
      test('SDK $sdkLevel (Android 13+): Runtime POST_NOTIFICATIONS dialog handling', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );

        // Unrequested denied -> notRequested
        final delegateUnreq = AdversarialPermissionDelegate(
          statuses: {Permission.notification: PermissionStatus.denied},
        );
        final serviceUnreq = AppPermissionService(
          permissionDelegate: delegateUnreq,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        expect(
          await serviceUnreq.queryPermission('notifications'),
          PrivacyPermissionStatus.notRequested,
        );

        // Request denied -> denied
        final delegateDeny = AdversarialPermissionDelegate(
          statuses: {Permission.notification: PermissionStatus.denied},
          requestResponses: {Permission.notification: PermissionStatus.denied},
        );
        final serviceDeny = AppPermissionService(
          permissionDelegate: delegateDeny,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        final resDeny = await serviceDeny.requestPermission('notifications');
        expect(resDeny, PrivacyPermissionStatus.denied);
        expect(
          await serviceDeny.queryPermission('notifications'),
          PrivacyPermissionStatus.denied,
        );

        // Request permanently denied -> permanentlyDenied
        final delegatePerm = AdversarialPermissionDelegate(
          statuses: {Permission.notification: PermissionStatus.permanentlyDenied},
          requestResponses: {
            Permission.notification: PermissionStatus.permanentlyDenied,
          },
        );
        final servicePerm = AppPermissionService(
          permissionDelegate: delegatePerm,
          platformSdkInfo: sdk,
          preferences: prefs,
        );
        final resPerm = await servicePerm.requestPermission('notifications');
        expect(resPerm, PrivacyPermissionStatus.permanentlyDenied);
        expect(
          await servicePerm.queryPermission('notifications'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });
    }
  });

  // ===========================================================================
  // GROUP 2: Asymmetric Bluetooth Permissions on Android 12+ (SDK 31..34)
  // ===========================================================================
  group('Adversarial Matrix — Asymmetric Bluetooth Permissions on Android 12+', () {
    for (final sdkLevel in [31, 32, 33, 34]) {
      test('SDK $sdkLevel: scan granted, connect denied (unrequested) -> notRequested', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.denied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        expect(
          await service.queryPermission('bluetooth'),
          PrivacyPermissionStatus.notRequested,
        );
      });

      test('SDK $sdkLevel: connect granted, scan denied (unrequested) -> notRequested', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        expect(
          await service.queryPermission('bluetooth'),
          PrivacyPermissionStatus.notRequested,
        );
      });

      test('SDK $sdkLevel: scan granted, connect denied (previously requested) -> denied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.denied,
          },
          requestResponses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.denied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        // Perform request
        final reqResult = await service.requestPermission('bluetooth');
        expect(reqResult, PrivacyPermissionStatus.denied);

        // Query status afterward
        final queryResult = await service.queryPermission('bluetooth');
        expect(queryResult, PrivacyPermissionStatus.denied);
      });

      test('SDK $sdkLevel: connect granted, scan denied (previously requested) -> denied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.granted,
          },
          requestResponses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        final reqResult = await service.requestPermission('bluetooth');
        expect(reqResult, PrivacyPermissionStatus.denied);

        final queryResult = await service.queryPermission('bluetooth');
        expect(queryResult, PrivacyPermissionStatus.denied);
      });

      test('SDK $sdkLevel: scan granted, connect permanentlyDenied -> permanentlyDenied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        expect(
          await service.queryPermission('bluetooth'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });

      test('SDK $sdkLevel: connect granted, scan permanentlyDenied -> permanentlyDenied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
            Permission.bluetoothConnect: PermissionStatus.granted,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        expect(
          await service.queryPermission('bluetooth'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });

      test('SDK $sdkLevel: scan denied, connect permanentlyDenied -> permanentlyDenied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.denied,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        expect(
          await service.queryPermission('bluetooth'),
          PrivacyPermissionStatus.permanentlyDenied,
        );
      });

      test('SDK $sdkLevel: requestPermission returns permanentlyDenied when either is permanentlyDenied', () async {
        final sdk = AdversarialPlatformSdkInfo(
          platform: TargetPlatform.android,
          sdkVersion: sdkLevel,
        );
        final delegate = AdversarialPermissionDelegate(
          statuses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.denied,
          },
          requestResponses: {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
          },
        );
        final service = AppPermissionService(
          permissionDelegate: delegate,
          platformSdkInfo: sdk,
          preferences: prefs,
        );

        final result = await service.requestPermission('bluetooth');
        expect(result, PrivacyPermissionStatus.permanentlyDenied);
      });
    }
  });

  // ===========================================================================
  // GROUP 3: Location Granularity & Background vs Foreground Matrix
  // ===========================================================================
  group('Adversarial Matrix — Location Granularities', () {
    test('Both granted: locationAlways granted and locationWhenInUse granted -> allowed', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Foreground only: locationWhenInUse granted and locationAlways denied -> whileUsing', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.whileUsing);
    });

    test('Foreground limited: locationWhenInUse limited and locationAlways denied -> whileUsing', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.limited,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.whileUsing);
    });

    test('Background only: locationAlways granted and locationWhenInUse denied -> allowed', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Neither granted, unrequested: both denied -> notRequested', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.notRequested);
    });

    test('Neither granted, previously requested: both denied -> denied', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      await service.requestPermission('location');
      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.denied);
    });

    test('Foreground permanently denied: locationWhenInUse permanentlyDenied -> permanentlyDenied', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Both permanently denied -> permanentlyDenied', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.permanentlyDenied,
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('requestPermission location: granted with always granted -> allowed', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final res = await service.requestPermission('location');
      expect(res, PrivacyPermissionStatus.allowed);
    });

    test('requestPermission location: granted with always denied -> whileUsing', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final res = await service.requestPermission('location');
      expect(res, PrivacyPermissionStatus.whileUsing);
    });

    test('requestPermission location: limited -> whileUsing', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.locationWhenInUse: PermissionStatus.limited,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final res = await service.requestPermission('location');
      expect(res, PrivacyPermissionStatus.whileUsing);
    });

    test('requestPermission location: permanentlyDenied -> permanentlyDenied', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.locationWhenInUse: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final res = await service.requestPermission('location');
      expect(res, PrivacyPermissionStatus.permanentlyDenied);
    });
  });

  // ===========================================================================
  // GROUP 4: Hostile SharedPreferences, Corrupted Data & Concurrent Stress
  // ===========================================================================
  group('Adversarial Matrix — Hostile SharedPreferences & Concurrency', () {
    test('Empty SharedPreferences: returns notRequested for unrequested denied permissions', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
          Permission.notification: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
          Permission.camera: PermissionStatus.denied,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(await service.queryPermission('bluetooth'), PrivacyPermissionStatus.notRequested);
      expect(await service.queryPermission('notifications'), PrivacyPermissionStatus.notRequested);
      expect(await service.queryPermission('location'), PrivacyPermissionStatus.notRequested);
      expect(await service.queryPermission('camera'), PrivacyPermissionStatus.notRequested);
    });

    test('Corrupted String stored in SharedPreferences: gracefully handled without unhandled exception', () async {
      await prefs.setString(
        '${AppPermissionService.permissionRequestedPrefix}bluetooth',
        'MALFORMED_CORRUPTED_VALUE',
      );

      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      // Does not throw unhandled exception; top-level catch handles type error
      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.unavailable);

      // Subsequent requestPermission repairs and overwrites corrupted data
      await service.requestPermission('bluetooth');
      expect(
        prefs.getBool('${AppPermissionService.permissionRequestedPrefix}bluetooth'),
        isTrue,
      );
    });

    test('Corrupted Int stored in SharedPreferences: gracefully handled and repaired', () async {
      await prefs.setInt(
        '${AppPermissionService.permissionRequestedPrefix}notifications',
        99999,
      );

      final delegate = AdversarialPermissionDelegate(
        statuses: {Permission.notification: PermissionStatus.denied},
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.unavailable);

      // Request repairs the key
      await service.requestPermission('notifications');
      expect(
        prefs.getBool('${AppPermissionService.permissionRequestedPrefix}notifications'),
        isTrue,
      );
    });

    test('clearPermissionHistory is idempotent and handles non-existent keys safely', () async {
      final service = AppPermissionService(preferences: prefs);

      // Should not throw even when key does not exist
      await service.clearPermissionHistory('bluetooth');
      await service.clearPermissionHistory('bluetooth');
      await service.clearPermissionHistory('unknown_id');
      expect(prefs.getBool('${AppPermissionService.permissionRequestedPrefix}bluetooth'), isNull);
    });

    test('Concurrent stress: 100 concurrent queries resolve cleanly without race conditions', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final futures = <Future<dynamic>>[];
      for (int i = 0; i < 25; i++) {
        futures.add(service.queryPermission('bluetooth'));
        futures.add(service.queryPermission('notifications'));
        futures.add(service.queryPermission('location'));
        futures.add(service.queryAllPermissions());
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(100));

      for (int i = 0; i < 100; i += 4) {
        expect(results[i], PrivacyPermissionStatus.allowed);
        expect(results[i + 1], PrivacyPermissionStatus.allowed);
        expect(results[i + 2], PrivacyPermissionStatus.whileUsing);
        final map = results[i + 3] as Map<String, PrivacyPermissionStatus>;
        expect(map['bluetooth'], PrivacyPermissionStatus.allowed);
        expect(map['notifications'], PrivacyPermissionStatus.allowed);
        expect(map['location'], PrivacyPermissionStatus.whileUsing);
      }
    });
  });

  // ===========================================================================
  // GROUP 5: State Transitions (notRequested -> denied -> permanentlyDenied -> allowed)
  // ===========================================================================
  group('Adversarial Matrix — Permission State Transitions', () {
    test('State trajectory: notRequested -> denied upon first user rejection', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      // Phase 1: Not requested initially
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.notRequested,
      );

      // Phase 2: User rejects permission
      final requestRes = await service.requestPermission('bluetooth');
      expect(requestRes, PrivacyPermissionStatus.denied);

      // Phase 3: Query reflects denied, not notRequested
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.denied,
      );
    });

    test('State trajectory: denied -> permanentlyDenied upon "Never ask again"', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
        requestResponses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      // Mark previously requested
      await prefs.setBool(
        '${AppPermissionService.permissionRequestedPrefix}bluetooth',
        true,
      );
      expect(await service.queryPermission('bluetooth'), PrivacyPermissionStatus.denied);

      // User selects "Don't ask again"
      final res = await service.requestPermission('bluetooth');
      expect(res, PrivacyPermissionStatus.permanentlyDenied);
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.permanentlyDenied,
      );
    });

    test('State trajectory: OS Settings grant -> allowed, then OS revocation -> denied (not notRequested)', () async {
      final delegate = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
        },
      );
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      // Initially permanently denied
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.permanentlyDenied,
      );

      // User goes to settings and grants
      delegate.statuses[Permission.bluetoothScan] = PermissionStatus.granted;
      delegate.statuses[Permission.bluetoothConnect] = PermissionStatus.granted;
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.allowed,
      );

      // User subsequently revokes in OS settings: status becomes denied, NOT notRequested
      // because persistent flag was recorded when request occurred
      await prefs.setBool(
        '${AppPermissionService.permissionRequestedPrefix}bluetooth',
        true,
      );
      delegate.statuses[Permission.bluetoothScan] = PermissionStatus.denied;
      delegate.statuses[Permission.bluetoothConnect] = PermissionStatus.denied;
      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.denied,
      );
    });
  });

  // ===========================================================================
  // GROUP 6: Platform Edge Cases & Fault Injection
  // ===========================================================================
  group('Adversarial Matrix — Platform Edge Cases & Fault Injection', () {
    test('Web platform always returns allowed for all permissions', () async {
      final sdk = AdversarialPlatformSdkInfo(isWeb: true);
      final delegate = AdversarialPermissionDelegate();
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(await service.queryPermission('bluetooth'), PrivacyPermissionStatus.allowed);
      expect(await service.queryPermission('notifications'), PrivacyPermissionStatus.allowed);
      expect(await service.queryPermission('location'), PrivacyPermissionStatus.allowed);
      expect(await service.queryPermission('camera'), PrivacyPermissionStatus.allowed);
      expect(await service.requestPermission('bluetooth'), PrivacyPermissionStatus.allowed);
    });

    test('iOS platform: Bluetooth restricted -> permanentlyDenied', () async {
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = AdversarialPermissionDelegate(
        statuses: {Permission.bluetooth: PermissionStatus.restricted},
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.permanentlyDenied,
      );
    });

    test('iOS platform: Notification restricted -> permanentlyDenied', () async {
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = AdversarialPermissionDelegate(
        statuses: {Permission.notification: PermissionStatus.restricted},
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(
        await service.queryPermission('notifications'),
        PrivacyPermissionStatus.permanentlyDenied,
      );
    });

    test('Fault injection: checkStatus throwing StateError returns unavailable', () async {
      final delegate = AdversarialPermissionDelegate(throwOnCheck: true);
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.unavailable,
      );
    });

    test('Fault injection: requestPermission throwing StateError returns unavailable', () async {
      final delegate = AdversarialPermissionDelegate(throwOnRequest: true);
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(
        await service.requestPermission('bluetooth'),
        PrivacyPermissionStatus.unavailable,
      );
    });

    test('Fault injection: platform SDK throwing StateError returns unavailable', () async {
      final sdk = AdversarialPlatformSdkInfo(throwOnGetSdk: true);
      final delegate = AdversarialPermissionDelegate();
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(
        await service.queryPermission('bluetooth'),
        PrivacyPermissionStatus.unavailable,
      );
    });

    test('openSettings handles platform errors safely', () async {
      final delegate = AdversarialPermissionDelegate(throwOnOpenSettings: true);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final result = await service.openSettings();
      expect(result, isFalse);
    });

    test('checkStatus legacy adapter maps all 6 PrivacyPermissionStatus correctly', () async {
      final sdk = AdversarialPlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);

      // allowed -> granted
      final d1 = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final s1 = AppPermissionService(permissionDelegate: d1, platformSdkInfo: sdk, preferences: prefs);
      expect(await s1.checkStatus(AppPermissionType.bluetooth), AppPermissionStatus.granted);

      // whileUsing -> granted
      final d2 = AdversarialPermissionDelegate(
        statuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final s2 = AppPermissionService(permissionDelegate: d2, platformSdkInfo: sdk, preferences: prefs);
      expect(await s2.checkStatus(AppPermissionType.location), AppPermissionStatus.granted);

      // permanentlyDenied -> permanentlyDenied
      final d3 = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final s3 = AppPermissionService(permissionDelegate: d3, platformSdkInfo: sdk, preferences: prefs);
      expect(await s3.checkStatus(AppPermissionType.bluetooth), AppPermissionStatus.permanentlyDenied);

      // denied -> denied
      await prefs.setBool('${AppPermissionService.permissionRequestedPrefix}bluetooth', true);
      final d4 = AdversarialPermissionDelegate(
        statuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
      );
      final s4 = AppPermissionService(permissionDelegate: d4, platformSdkInfo: sdk, preferences: prefs);
      expect(await s4.checkStatus(AppPermissionType.bluetooth), AppPermissionStatus.denied);

      // notRequested -> denied
      await prefs.clear();
      final s5 = AppPermissionService(permissionDelegate: d4, platformSdkInfo: sdk, preferences: prefs);
      expect(await s5.checkStatus(AppPermissionType.bluetooth), AppPermissionStatus.denied);

      // unavailable -> unsupported
      final d6 = AdversarialPermissionDelegate(throwOnCheck: true);
      final s6 = AppPermissionService(permissionDelegate: d6, platformSdkInfo: sdk, preferences: prefs);
      expect(await s6.checkStatus(AppPermissionType.bluetooth), AppPermissionStatus.unsupported);
    });
  });
}
