import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/models/home_dashboard_models.dart';
import 'package:smart_home_application_v1/core/repositories/fake_home_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/devices/presentation/device_control_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDevice = ConnectedDeviceSummary(
    id: 'test-device-switch-stress-01',
    name: 'EH Smart Switch 4X',
    model: 'eh-smart-switch-4x',
    firmware: '1.0.0',
    connectedVia: 'Wi-Fi (Local)',
    signalLabel: 'Local Wi-Fi',
    roomName: 'Living Room',
    online: true,
  );

  late DeviceStorageService storage;
  late HomeController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = DeviceStorageService();
    await storage.clearAllDevices();
    await storage.saveDevice(testDevice);
    for (final dId in [testDevice.id, testDevice.name, 'esp32_device']) {
      for (int ch = 1; ch <= 8; ch++) {
        await DeviceStorageService.saveChannelAlertConfig(
          dId,
          ch,
          const ChannelAlertConfig(enabled: false),
        );
      }
    }
    await DeviceStorageService.setConnectionRoutingMode('cloudOnly');
    controller = HomeController(
      storageService: storage,
      repository: FakeHomeRepository(),
      connectionRepository: const UnavailableConnectionRepository(),
      autoSync: false,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildApp({
    required ThemeMode mode,
    required HomeController homeController,
  }) {
    return MaterialApp(
      theme: EHAppTheme.lightTheme,
      darkTheme: EHAppTheme.darkTheme,
      themeMode: mode,
      home: Scaffold(
        body: DeviceControlPage(
          device: testDevice,
          homeController: homeController,
        ),
      ),
    );
  }

  group('Milestone M1: Adversarial Notification State & Behavior Stress Tests', () {
    testWidgets(
      'STRESS-1: Adversarial Cancel & Close Icon Isolation without State Leakage',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        // 1. Initial State: Channel 1 has no alert indicator
        expect(find.textContaining('Alert:'), findsNothing);

        // Open Channel 1 bottom sheet
        final editButton = find.byTooltip('Rename Channel').first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<Switch>(switchFinder).value, isFalse);

        // 2. Toggle ON, pick 'ON Only', type custom alert message
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(find.text('Notify When'), findsOneWidget);

        await tester.tap(find.text('ON Only'));
        await tester.pumpAndSettle();

        final msgField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(msgField, '⚠️ Adversarial Alert Leakage Test');
        await tester.pumpAndSettle();

        // 3. Dismiss via close icon (top right)
        final closeIconFinder = find.byIcon(Icons.close_rounded);
        expect(closeIconFinder, findsOneWidget);
        await tester.tap(closeIconFinder);
        await tester.pumpAndSettle();

        // Verify sheet is closed
        expect(find.byType(BottomSheet), findsNothing);

        // Verify state is NOT leaked or persisted
        final configAfterClose = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(configAfterClose.enabled, isFalse, reason: 'Dismissing via close icon must NOT enable alert');
        expect(find.textContaining('Alert:'), findsNothing, reason: 'UI must show no alert subtitle after close icon dismissal');

        // 4. Reopen sheet and verify clean initial state
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final switchFinder2 = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(switchFinder2).value, isFalse, reason: 'Switch must remain OFF on reopen');
        expect(find.text('Notify When'), findsNothing, reason: 'Sub-options must remain collapsed');

        // 5. Toggle ON again, enter message, and tap 'Cancel' OutlinedButton
        await tester.tap(switchFinder2);
        await tester.pumpAndSettle();

        final msgField2 = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(msgField2, 'Cancelled modification');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        final configAfterCancel = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(configAfterCancel.enabled, isFalse, reason: 'Dismissing via Cancel button must NOT persist changes');
        expect(find.textContaining('Alert:'), findsNothing);
      },
    );

    testWidgets(
      'STRESS-2: Trigger Configuration Matrix, Custom Message Formatting, and Empty Message Fallback',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.dark, homeController: controller),
        );
        await tester.pumpAndSettle();

        final editButton = find.byTooltip('Rename Channel').first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // 1. Toggle ON -> Select 'OFF Only'
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('OFF Only'));
        await tester.pumpAndSettle();

        // 2. Enter custom message with special characters and symbols
        final msgField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        const testCustomMsg = '⚠️ Geyser > 65°C & Boiling!';
        await tester.enterText(msgField, testCustomMsg);
        await tester.pumpAndSettle();

        // 3. Save Settings
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // 4. Verify controller persistence
        final savedCfg = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(savedCfg.enabled, isTrue);
        expect(savedCfg.alertOnTurnOn, isFalse);
        expect(savedCfg.alertOnTurnOff, isTrue);
        expect(savedCfg.customMessage, equals(testCustomMsg));

        // 5. Verify UI channel card subtitle
        expect(
          find.textContaining('Alert: OFF only • "$testCustomMsg"'),
          findsOneWidget,
          reason: 'Channel card subtitle must accurately reflect OFF only trigger and quoted custom message',
        );

        // 6. Reopen sheet: verify populated state
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final reopenedSwitch = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(reopenedSwitch).value, isTrue);

        // 7. Change trigger to 'Both ON/OFF' and clear custom message
        await tester.tap(find.text('Both ON/OFF'));
        await tester.pumpAndSettle();

        final reopenedMsgField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(reopenedMsgField, '');
        await tester.pumpAndSettle();

        // Save updated settings
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // 8. Verify controller persistence with empty custom message
        final updatedCfg = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(updatedCfg.enabled, isTrue);
        expect(updatedCfg.alertOnTurnOn, isTrue);
        expect(updatedCfg.alertOnTurnOff, isTrue);
        expect(updatedCfg.customMessage, isEmpty);

        // 9. Verify UI channel card subtitle displays clean 'Alert: ON & OFF' without empty quotes
        expect(find.textContaining('Alert: ON & OFF'), findsOneWidget);
        expect(find.textContaining('Alert: ON & OFF • ""'), findsNothing);
      },
    );

    testWidgets(
      'STRESS-3: Multi-Channel Independence and Cross-Channel Isolation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        final editButtons = find.byTooltip('Rename Channel');
        expect(editButtons, findsAtLeastNWidgets(4));

        // Configure Channel 1: ON Only, 'Ch1 Alert'
        await tester.tap(editButtons.at(0));
        await tester.pumpAndSettle();
        var switchFinder = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Switch));
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ON Only'));
        await tester.pumpAndSettle();
        var msgField = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).last;
        await tester.enterText(msgField, 'Ch1 Alert');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // Configure Channel 2: OFF Only, 'Ch2 Alert'
        await tester.tap(editButtons.at(1));
        await tester.pumpAndSettle();
        switchFinder = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Switch));
        // Verify Channel 2 opened in fresh OFF state
        expect(tester.widget<Switch>(switchFinder).value, isFalse, reason: 'Channel 2 must start OFF');
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OFF Only'));
        await tester.pumpAndSettle();
        msgField = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).last;
        await tester.enterText(msgField, 'Ch2 Alert');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // Configure Channel 3: Both ON/OFF, empty message
        await tester.tap(editButtons.at(2));
        await tester.pumpAndSettle();
        switchFinder = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Switch));
        expect(tester.widget<Switch>(switchFinder).value, isFalse, reason: 'Channel 3 must start OFF');
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Both ON/OFF'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // Channel 4 is left untouched

        // Verify independent controller configs
        final cfg1 = controller.getChannelAlertConfig(testDevice.id, 1);
        final cfg2 = controller.getChannelAlertConfig(testDevice.id, 2);
        final cfg3 = controller.getChannelAlertConfig(testDevice.id, 3);
        final cfg4 = controller.getChannelAlertConfig(testDevice.id, 4);

        expect(cfg1.enabled, isTrue);
        expect(cfg1.alertOnTurnOn, isTrue);
        expect(cfg1.alertOnTurnOff, isFalse);
        expect(cfg1.customMessage, equals('Ch1 Alert'));

        expect(cfg2.enabled, isTrue);
        expect(cfg2.alertOnTurnOn, isFalse);
        expect(cfg2.alertOnTurnOff, isTrue);
        expect(cfg2.customMessage, equals('Ch2 Alert'));

        expect(cfg3.enabled, isTrue);
        expect(cfg3.alertOnTurnOn, isTrue);
        expect(cfg3.alertOnTurnOff, isTrue);
        expect(cfg3.customMessage, isEmpty);

        expect(cfg4.enabled, isFalse);

        // Verify UI subtitles coexist without interference
        expect(find.textContaining('Alert: ON only • "Ch1 Alert"'), findsOneWidget);
        expect(find.textContaining('Alert: OFF only • "Ch2 Alert"'), findsOneWidget);
        expect(find.textContaining('Alert: ON & OFF'), findsOneWidget);

        // Reopen Channel 2 and cancel -> verify Channel 1 and 2 remain unaffected
        await tester.tap(editButtons.at(1));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(controller.getChannelAlertConfig(testDevice.id, 1).customMessage, equals('Ch1 Alert'));
        expect(controller.getChannelAlertConfig(testDevice.id, 2).customMessage, equals('Ch2 Alert'));
      },
    );

    testWidgets(
      'STRESS-4: Rapid Switch Toggling & Trigger Cycling State Thrashing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        final editButton = find.byTooltip('Rename Channel').first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // Perform 5 alternating taps on the Switch (starts OFF -> ON -> OFF -> ON -> OFF -> ON)
        for (int i = 0; i < 5; i++) {
          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
        }

        expect(tester.widget<Switch>(switchFinder).value, isTrue,
            reason: 'Odd number of deliberate taps from OFF must result in ON state');
        expect(find.text('Notify When'), findsOneWidget);

        // Cycle through trigger buttons repeatedly (6 full cycles = 18 state transitions)
        for (int i = 0; i < 6; i++) {
          await tester.tap(find.text('ON Only'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OFF Only'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Both ON/OFF'));
          await tester.pumpAndSettle();
        }
        // End explicitly on 'ON Only'
        await tester.tap(find.text('ON Only'));
        await tester.pumpAndSettle();

        // Toggle switch OFF and ON 2 times
        for (int i = 0; i < 2; i++) {
          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
          await tester.tap(switchFinder);
          await tester.pumpAndSettle();
        }

        expect(tester.widget<Switch>(switchFinder).value, isTrue);

        // Enter message and save
        final msgField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(msgField, 'Thrash Survivor Message');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // Assert final persisted state is completely clean and uncorrupted
        final finalCfg = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(finalCfg.enabled, isTrue);
        expect(finalCfg.customMessage, equals('Thrash Survivor Message'));
        expect(finalCfg.alertOnTurnOn, isTrue);
      },
    );

    testWidgets(
      'STRESS-5: End-to-End Channel Alert Event Dispatching & Trigger Filtering',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Configure Channel 1: ON Only
        await DeviceStorageService.saveChannelAlertConfig(
          testDevice.id,
          1,
          const ChannelAlertConfig(
            enabled: true,
            alertOnTurnOn: true,
            alertOnTurnOff: false,
            customMessage: 'Geyser is running hot!',
          ),
        );

        // Configure Channel 2: OFF Only
        await DeviceStorageService.saveChannelAlertConfig(
          testDevice.id,
          2,
          const ChannelAlertConfig(
            enabled: true,
            alertOnTurnOn: false,
            alertOnTurnOff: true,
            customMessage: 'Main pump turned off',
          ),
        );

        // Configure Channel 3: Disabled
        await DeviceStorageService.saveChannelAlertConfig(
          testDevice.id,
          3,
          const ChannelAlertConfig(enabled: false),
        );

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        // 1. Toggle Channel 1 ON -> matches 'ON Only' -> Warning Alert SHOULD be recorded
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 1, value: true));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        var warningAlerts = controller.activityAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
        expect(warningAlerts.length, equals(1));
        expect(warningAlerts.first.message, equals('Geyser is running hot!'));

        // 2. Toggle Channel 1 OFF -> does not match 'ON Only' -> NO new warning alert should be recorded
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 1, value: false));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        warningAlerts = controller.activityAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
        expect(warningAlerts.length, equals(1),
            reason: 'Turning OFF Channel 1 must not trigger alert configured for ON Only');

        // 3. Toggle Channel 2 ON -> does not match 'OFF Only' -> NO new warning alert should be recorded
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 2, value: true));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        warningAlerts = controller.activityAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
        expect(warningAlerts.length, equals(1),
            reason: 'Turning ON Channel 2 must not trigger alert configured for OFF Only');

        // 4. Toggle Channel 2 OFF -> matches 'OFF Only' -> Warning Alert SHOULD be recorded
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 2, value: false));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        warningAlerts = controller.activityAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
        expect(warningAlerts.length, equals(2));
        expect(warningAlerts.first.message, equals('Main pump turned off'));

        // 5. Toggle Channel 3 ON and OFF -> Alert disabled -> NO new warning alerts recorded
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 3, value: true));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        unawaited(controller.setDeviceChannelPower(deviceId: testDevice.id, channelIndex: 3, value: false));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        warningAlerts = controller.activityAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
        expect(warningAlerts.length, equals(2),
            reason: 'Channel with alerts disabled must never trigger activity alerts');
      },
    );

    testWidgets(
      'STRESS-6: Channel Renaming with Notification Toggle Concurrency and Subtitle Update',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        final editButton = find.byTooltip('Rename Channel').first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // 1. Rename channel to 'Master Geyser'
        final nameField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).first;
        await tester.enterText(nameField, 'Master Geyser');
        await tester.pumpAndSettle();

        // 2. Enable notifications, select 'Both ON/OFF', and set message
        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Both ON/OFF'));
        await tester.pumpAndSettle();

        final msgField = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(msgField, 'Geyser auto-protection');
        await tester.pumpAndSettle();

        // 3. Save Settings
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // 4. Verify renamed channel label in UI and controller
        expect(find.text('Master Geyser'), findsAtLeastNWidgets(1));
        expect(controller.getDeviceChannelName(testDevice.id, 1), equals('Master Geyser'));

        // 5. Verify alert configuration persisted with new name
        final cfg = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(cfg.enabled, isTrue);
        expect(cfg.alertOnTurnOn, isTrue);
        expect(cfg.alertOnTurnOff, isTrue);
        expect(cfg.customMessage, equals('Geyser auto-protection'));

        // 6. Verify channel card displays renamed channel name and alert indicator simultaneously
        expect(find.textContaining('Alert: ON & OFF • "Geyser auto-protection"'), findsOneWidget);
      },
    );
  });
}
