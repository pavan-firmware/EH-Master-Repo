import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/models/privacy_models.dart';
import 'package:smart_home_application_v1/core/services/app_permission_service.dart';

import 'ble_preflight_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AppPermissionService — Bluetooth Matrix', () {
    test('Android 12+ (SDK 33): both scan and connect granted -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Android 12+ (SDK 33): scan granted, connect denied, not requested -> notRequested', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.notRequested);
    });

    test('Android 12+ (SDK 33): scan granted, connect denied, previously requested -> denied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
        grantOnRequest: false,
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      await service.requestPermission('bluetooth');

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.denied);
    });

    test('Android 12+ (SDK 33): scan permanentlyDenied -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.permanentlyDenied,
          Permission.bluetoothConnect: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Android 12+ (SDK 33): connect permanentlyDenied -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Android 11 (SDK 30): legacy bluetooth granted -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Android 11 (SDK 30): legacy bluetooth unrequested -> notRequested', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.notRequested);
    });

    test('Android 11 (SDK 30): legacy bluetooth permanentlyDenied -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 30);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('iOS: bluetooth granted -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('iOS: bluetooth restricted -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetooth: PermissionStatus.restricted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('bluetooth');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });
  });

  group('AppPermissionService — Notifications Matrix', () {
    test('Android 13+ (SDK 33): notification granted -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Android 13+ (SDK 33): notification unrequested -> notRequested', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.notRequested);
    });

    test('Android 13+ (SDK 33): notification permanentlyDenied -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Android 13+ (SDK 33): notification denied after request -> denied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.denied,
        },
        grantOnRequest: false,
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      await service.requestPermission('notifications');

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.denied);
    });

    test('Android 12 (SDK 31): system notifications disabled -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 31);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Android 12 (SDK 31): system notifications enabled -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 31);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('iOS: notification granted -> allowed', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('iOS: notification permanentlyDenied -> permanentlyDenied', () async {
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.iOS);
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.notification: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      final status = await service.queryPermission('notifications');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });
  });

  group('AppPermissionService — Location Matrix', () {
    test('Location: locationAlways granted -> allowed', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
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

    test('Location: locationWhenInUse granted -> whileUsing', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
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

    test('Location: locationWhenInUse limited -> whileUsing', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
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

    test('Location: unrequested -> notRequested', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
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

    test('Location: denied after request -> denied', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        grantOnRequest: false,
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      await service.requestPermission('location');

      final status = await service.queryPermission('location');
      expect(status, PrivacyPermissionStatus.denied);
    });

    test('Location: permanentlyDenied -> permanentlyDenied', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
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
  });

  group('AppPermissionService — Camera Matrix & Edge Cases', () {
    test('Camera: granted -> allowed', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.camera: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('camera');
      expect(status, PrivacyPermissionStatus.allowed);
    });

    test('Camera: not requested -> notRequested', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.camera: PermissionStatus.denied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('camera');
      expect(status, PrivacyPermissionStatus.notRequested);
    });

    test('Camera: permanentlyDenied -> permanentlyDenied', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.camera: PermissionStatus.permanentlyDenied,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('camera');
      expect(status, PrivacyPermissionStatus.permanentlyDenied);
    });

    test('Unknown permission ID -> unavailable', () async {
      final delegate = FakePermissionDelegate();
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final status = await service.queryPermission('unknown_feature');
      expect(status, PrivacyPermissionStatus.unavailable);
    });
  });

  group('AppPermissionService — Requests & SharedPreferences Tracking', () {
    test('requestPermission marks history and returns updated status', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.denied,
        },
        grantOnRequest: true,
      );
      final sdk = FakePlatformSdkInfo(platform: TargetPlatform.android, sdkVersion: 33);
      final service = AppPermissionService(
        permissionDelegate: delegate,
        platformSdkInfo: sdk,
        preferences: prefs,
      );

      expect(prefs.getBool('${AppPermissionService.permissionRequestedPrefix}bluetooth'), isNull);

      final result = await service.requestPermission('bluetooth');
      expect(result, PrivacyPermissionStatus.allowed);
      expect(prefs.getBool('${AppPermissionService.permissionRequestedPrefix}bluetooth'), isTrue);

      await service.clearPermissionHistory('bluetooth');
      expect(prefs.getBool('${AppPermissionService.permissionRequestedPrefix}bluetooth'), isNull);
    });

    test('requestPermission for location returns whileUsing when in-use granted', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.locationAlways: PermissionStatus.denied,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        grantOnRequest: true,
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final result = await service.requestPermission('location');
      expect(result, PrivacyPermissionStatus.whileUsing);
    });
  });

  group('AppPermissionService — queryAllPermissions & Legacy Compatibility', () {
    test('queryAllPermissions returns map of bluetooth, notifications, and location', () async {
      final delegate = FakePermissionDelegate(
        initialStatuses: {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.notification: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
      );
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final map = await service.queryAllPermissions();
      expect(map.keys, containsAll(['bluetooth', 'notifications', 'location']));
      expect(map['bluetooth'], PrivacyPermissionStatus.allowed);
      expect(map['notifications'], PrivacyPermissionStatus.allowed);
      expect(map['location'], PrivacyPermissionStatus.whileUsing);
    });

    test('openSettings invokes delegate openAppSettings', () async {
      final delegate = FakePermissionDelegate();
      final service = AppPermissionService(
        permissionDelegate: delegate,
        preferences: prefs,
      );

      final result = await service.openSettings();
      expect(result, isTrue);
      expect(delegate.appSettingsOpened, isTrue);
    });

    test('legacy checkStatus and const constructor are preserved', () async {
      const legacyService = AppPermissionService();
      final status = await legacyService.checkStatus(AppPermissionType.bluetooth);
      expect(status, isNotNull);
    });
  });

  group('Privacy Models Unit Verification', () {
    test('PrivacyPermissionStatus labels and helpers', () {
      expect(PrivacyPermissionStatus.allowed.label, 'Allowed');
      expect(PrivacyPermissionStatus.whileUsing.label, 'While using the app');
      expect(PrivacyPermissionStatus.denied.label, 'Denied');
      expect(PrivacyPermissionStatus.notRequested.label, 'Not requested');
      expect(PrivacyPermissionStatus.permanentlyDenied.label, 'Permanently denied');
      expect(PrivacyPermissionStatus.unavailable.label, 'Unavailable');

      expect(PrivacyPermissionStatus.allowed.isGranted, isTrue);
      expect(PrivacyPermissionStatus.whileUsing.isGranted, isTrue);
      expect(PrivacyPermissionStatus.denied.isGranted, isFalse);
      expect(PrivacyPermissionStatus.permanentlyDenied.isGranted, isFalse);

      expect(PrivacyPermissionStatus.denied.isDenied, isTrue);
      expect(PrivacyPermissionStatus.permanentlyDenied.isDenied, isTrue);
      expect(PrivacyPermissionStatus.allowed.isDenied, isFalse);

      expect(PrivacyPermissionStatus.permanentlyDenied.isPermanentlyDenied, isTrue);
      expect(PrivacyPermissionStatus.denied.isPermanentlyDenied, isFalse);
    });

    test('PrivacyPermission copyWith and equality', () {
      const p1 = PrivacyPermission(
        id: 'loc',
        title: 'Location',
        description: 'Desc',
        status: PrivacyPermissionStatus.notRequested,
      );

      final p2 = p1.copyWith(status: PrivacyPermissionStatus.whileUsing);
      expect(p2.status, PrivacyPermissionStatus.whileUsing);
      expect(p2.statusLabel, 'While using the app');

      const p3 = PrivacyPermission(
        id: 'loc',
        title: 'Location',
        description: 'Desc',
        status: PrivacyPermissionStatus.notRequested,
      );
      expect(p1, equals(p3));
      expect(p1.hashCode, equals(p3.hashCode));
      expect(p1 == p2, isFalse);
    });
  });
}
