import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/features/connection/presentation/device_provisioning_page.dart';
import 'package:smart_home_application_v1/features/onboarding/presentation/qr_scanner_dialog.dart';
import 'package:smart_home_application_v1/features/settings/presentation/add_device_page.dart';

class _EmptySettingsRepository extends PreviewSettingsRepository {
  const _EmptySettingsRepository();

  @override
  Future<List<DiscoveredRoomDevice>> getNearbyDevices() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add a Device Redesign Tests', () {
    testWidgets('1. AddDevicePage renders scanning card, nearby devices and need help section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDevicePage(
            repository: PreviewSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Add a device'), findsOneWidget);

      // Scanning Card & Header
      expect(find.text('Nearby devices'), findsOneWidget);
      expect(find.text('Scan finished'), findsOneWidget);

      // Devices list (Page 1 in PDF)
      expect(find.text('EH Smart Switch 3X'), findsOneWidget);
      expect(find.text('Strong signal'), findsOneWidget);
      expect(find.text('EH Smart Switch 5X'), findsOneWidget);
      expect(find.text('Good signal'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Connect'), findsNWidgets(2));

      // Need Help section
      expect(find.text('NEED HELP?'), findsOneWidget);
      expect(find.text('Make sure Bluetooth is on'), findsWidgets);
      expect(find.text('Power on your device'), findsOneWidget);
      expect(find.text('View troubleshooting guide'), findsOneWidget);
    });

    testWidgets('2. AddDevicePage empty state renders Bluetooth icon, helper text and Rescan button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDevicePage(
            repository: _EmptySettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No nearby devices found'), findsOneWidget);
      expect(find.text('Make sure Bluetooth is on, your device is powered and in pairing mode, and close to your phone.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Rescan'), findsOneWidget);
    });

    testWidgets('3. Tapping Connect opens DeviceSetupPage in Ready Preview stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDevicePage(
            repository: PreviewSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final connectBtn = find.widgetWithText(FilledButton, 'Connect').first;
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      // DeviceSetupPage Ready Preview (Page 3 of redesign)
      expect(find.byType(DeviceSetupPage), findsOneWidget);
      expect(find.text('EH Smart Switch 3X'), findsWidgets);
      expect(find.text('Set up device'), findsOneWidget);
      expect(find.text('Powered on and ready. Tap Proceed to connect it to your Wi-Fi.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Proceed'), findsOneWidget);
    });

    testWidgets('4. Proceed button in DeviceSetupPage animates into Wi-Fi Form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeviceSetupPage(
            deviceName: 'EH Smart Switch 3X',
            deviceId: 'dev-3x',
            imageUrl: 'assets/products/smart_switch_3x/hero.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Proceed
      await tester.tap(find.widgetWithText(FilledButton, 'Proceed'));
      await tester.pumpAndSettle();

      // Wi-Fi form is now displayed (Page 4 of redesign)
      expect(find.text('Connected over Bluetooth'), findsOneWidget);
      expect(find.text('Setup instructions'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Wi-Fi Network (SSID)'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Connect & Provision'), findsOneWidget);
    });

    testWidgets('5. Wi-Fi QR parsing strictly parses Wi-Fi payloads and rejects verification payloads', (tester) async {
      // Valid Wi-Fi QR
      const validWifiQr = 'WIFI:T:WPA;S:HomeNetwork;P:SuperSecret123;;';
      final wifiPayload = WifiQrPayload.tryParse(validWifiQr);
      expect(wifiPayload, isNotNull);
      expect(wifiPayload!.ssid, 'HomeNetwork');
      expect(wifiPayload.password, 'SuperSecret123');

      // Device verification QR should fail Wi-Fi parsing
      const deviceVerificationQr = '{"deviceId":"eh-123","secret":"abc","version":"1.0"}';
      expect(WifiQrPayload.tryParse(deviceVerificationQr), isNull);

      // Random text should fail
      expect(WifiQrPayload.tryParse('invalid-qr-code'), isNull);
    });
  });
}
