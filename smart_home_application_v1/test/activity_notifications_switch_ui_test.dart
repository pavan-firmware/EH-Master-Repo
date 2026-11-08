import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/core/models/connection_models.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/services/device_storage_service.dart';
import 'package:smart_home_application_v1/core/theme/app_colors.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/devices/presentation/device_control_page.dart';

/// Helper to compute WCAG 2.1 contrast ratio between two colors.
double _calculateContrastRatio(Color c1, Color c2) {
  final l1 = c1.computeLuminance();
  final l2 = c2.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDevice = ConnectedDeviceSummary(
    id: 'test-device-switch-001',
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
    controller = HomeController(
      storageService: storage,
      connectionRepository: const UnavailableConnectionRepository(),
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

  group('Milestone M1: Accessible Activity Notifications Toggle UI Tests', () {
    testWidgets(
      '1. Activity Notifications Switch exists in channel settings bottom sheet',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        // Find and tap channel 1 edit button
        final editButton = find.byTooltip('Rename Channel').first;
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Verify bottom sheet opened
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Control 1 Settings'), findsOneWidget);

        // Verify Activity Notifications section
        expect(find.text('Activity Notifications'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

        // Verify the Switch widget exists inside bottom sheet
        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);

        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isFalse, reason: 'Initial switch state must be OFF');

        // Sub-options are collapsed when switch is OFF
        expect(find.text('Notify When'), findsNothing);
        expect(find.text('Custom Alert Message (Optional)'), findsNothing);
      },
    );

    testWidgets(
      '2. Light Theme: Active switch has high-contrast white circular thumb clearly delineated against blue track',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);

        // Toggle Switch ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Defect check: Switch must NOT override activeThumbColor to bluePrimary (which caused solid blue pill)
        expect(
          switchWidget.activeThumbColor,
          isNot(equals(EHColors.lightBluePrimary)),
          reason: 'Switch must not override activeThumbColor with bluePrimary; delegates to theme',
        );
        expect(
          switchWidget.activeThumbColor,
          isNull,
          reason: 'Switch.adaptive should not define inline activeThumbColor override',
        );

        // Color resolution
        final theme = Theme.of(tester.element(switchFinder));
        final switchTheme = theme.switchTheme;

        final effectiveThumbColor = switchWidget.thumbColor?.resolve({WidgetState.selected})
            ?? switchWidget.activeThumbColor
            ?? switchTheme.thumbColor?.resolve({WidgetState.selected});

        final effectiveTrackColor = switchWidget.trackColor?.resolve({WidgetState.selected})
            ?? switchWidget.activeTrackColor
            ?? switchTheme.trackColor?.resolve({WidgetState.selected});

        expect(effectiveThumbColor, isNotNull);
        expect(effectiveTrackColor, isNotNull);

        // Assertion 2.1: Thumb color is NOT equal to track color
        expect(
          effectiveThumbColor,
          isNot(equals(effectiveTrackColor)),
          reason: 'In Light Theme, active thumb color must not match active track color',
        );

        // Assertion 2.2: Thumb is white (circular thumb clearly delineated)
        expect(effectiveThumbColor, equals(EHColors.lightSwitchThumbOn));
        expect(effectiveThumbColor, equals(const Color(0xFFFFFFFF)));

        // Assertion 2.3: Track is brand blue
        expect(effectiveTrackColor, equals(EHColors.lightSwitchTrackOn));
        expect(effectiveTrackColor, equals(const Color(0xFF155CC8)));

        // Assertion 2.4: WCAG graphical contrast ratio exceeds 3:1 (actual ~6.56:1)
        final ratio = _calculateContrastRatio(effectiveThumbColor!, effectiveTrackColor!);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: 'Active switch thumb must maintain >=3:1 contrast against track in Light Theme',
        );
      },
    );

    testWidgets(
      '3. Dark Theme: Active switch has high-contrast white circular thumb clearly delineated against blue track',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.dark, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);

        // Toggle Switch ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Defect check: Switch must NOT override activeThumbColor to blue
        expect(
          switchWidget.activeThumbColor,
          isNot(equals(EHColors.darkBluePrimary)),
          reason: 'Switch must not override activeThumbColor in Dark Theme',
        );
        expect(
          switchWidget.activeThumbColor,
          isNull,
          reason: 'Switch.adaptive should not define inline activeThumbColor override',
        );

        final theme = Theme.of(tester.element(switchFinder));
        final switchTheme = theme.switchTheme;

        final effectiveThumbColor = switchWidget.thumbColor?.resolve({WidgetState.selected})
            ?? switchWidget.activeThumbColor
            ?? switchTheme.thumbColor?.resolve({WidgetState.selected});

        final effectiveTrackColor = switchWidget.trackColor?.resolve({WidgetState.selected})
            ?? switchWidget.activeTrackColor
            ?? switchTheme.trackColor?.resolve({WidgetState.selected});

        expect(effectiveThumbColor, isNotNull);
        expect(effectiveTrackColor, isNotNull);

        // Assertion 3.1: Thumb color is NOT equal to track color
        expect(
          effectiveThumbColor,
          isNot(equals(effectiveTrackColor)),
          reason: 'In Dark Theme, active thumb color must not match active track color',
        );

        // Assertion 3.2: Thumb is crisp bright white (circular thumb clearly delineated)
        expect(effectiveThumbColor, equals(EHColors.darkSwitchThumbOn));
        expect(effectiveThumbColor, equals(const Color(0xFFF4F7FB)));

        // Assertion 3.3: Track is deep blue
        expect(effectiveTrackColor, equals(EHColors.darkSwitchTrackOn));
        expect(effectiveTrackColor, equals(const Color(0xFF2F6DB5)));

        // Assertion 3.4: WCAG graphical contrast ratio exceeds 3:1 (actual ~4.90:1)
        final ratio = _calculateContrastRatio(effectiveThumbColor!, effectiveTrackColor!);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: 'Active switch thumb must maintain >=3:1 contrast against track in Dark Theme',
        );
      },
    );

    testWidgets(
      '4. Consistent size, shape, alignment, and distinguishability between enabled and disabled states and across themes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Part A: Light Theme state consistency
        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        final sheetFinder = find.byType(BottomSheet);

        final lightOffSize = tester.getSize(switchFinder);
        final lightOffPosition = tester.getTopLeft(switchFinder);
        final lightOffSheetTop = tester.getTopLeft(sheetFinder).dy;
        final lightOffRelativeDy = lightOffPosition.dy - lightOffSheetTop;

        // Toggle ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final lightOnSize = tester.getSize(switchFinder);
        final lightOnPosition = tester.getTopLeft(switchFinder);
        final lightOnSheetTop = tester.getTopLeft(sheetFinder).dy;
        final lightOnRelativeDy = lightOnPosition.dy - lightOnSheetTop;

        // Assert size consistency between ON and OFF
        expect(lightOnSize.width, equals(lightOffSize.width),
            reason: 'Switch width must remain identical between ON and OFF states');
        expect(lightOnSize.height, equals(lightOffSize.height),
            reason: 'Switch height must remain identical between ON and OFF states');

        // Assert alignment consistency
        expect(
          (lightOnPosition.dx - lightOffPosition.dx).abs(),
          lessThan(1.0),
          reason: 'Switch horizontal alignment must remain stable',
        );
        expect(
          (lightOnRelativeDy - lightOffRelativeDy).abs(),
          lessThan(1.0),
          reason: 'Switch vertical alignment relative to sheet container must remain stable',
        );

        // Dismiss sheet
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Part B: Dark Theme size consistency
        await tester.pumpWidget(
          buildApp(mode: ThemeMode.dark, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final darkSwitchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        final darkOffSize = tester.getSize(darkSwitchFinder);

        // Assert size consistency across themes
        expect(darkOffSize.width, equals(lightOffSize.width),
            reason: 'Switch size must be consistent between Light and Dark themes');
        expect(darkOffSize.height, equals(lightOffSize.height),
            reason: 'Switch size must be consistent between Light and Dark themes');

        // Part C: Visual Distinguishability between ON and OFF states
        final darkTheme = Theme.of(tester.element(darkSwitchFinder));
        final darkSwitchTheme = darkTheme.switchTheme;

        final offTrack = darkSwitchTheme.trackColor?.resolve({});
        final onTrack = darkSwitchTheme.trackColor?.resolve({WidgetState.selected});
        expect(offTrack, isNot(equals(onTrack)),
            reason: 'Track color must clearly distinguish ON and OFF states');
        expect(offTrack, equals(EHColors.darkSwitchTrackOff));
        expect(onTrack, equals(EHColors.darkSwitchTrackOn));

        // Part D: Track Outline Color & Width resolution
        final offOutline = darkSwitchTheme.trackOutlineColor?.resolve({});
        final onOutline = darkSwitchTheme.trackOutlineColor?.resolve({WidgetState.selected});
        expect(offOutline, equals(EHColors.darkBorderControl),
            reason: 'Unselected switch must show subtle border control outline for visibility');
        expect(onOutline, equals(Colors.transparent),
            reason: 'Selected switch track outline must be transparent');

        final offOutlineWidth = darkSwitchTheme.trackOutlineWidth?.resolve({});
        final onOutlineWidth = darkSwitchTheme.trackOutlineWidth?.resolve({WidgetState.selected});
        expect(offOutlineWidth, equals(1.0));
        expect(onOutlineWidth, equals(0.0));

        // Part E: Disabled State Support
        final disabledOffTrack = darkSwitchTheme.trackColor?.resolve({WidgetState.disabled});
        final disabledOnTrack = darkSwitchTheme.trackColor?.resolve({WidgetState.disabled, WidgetState.selected});
        expect(disabledOffTrack, equals(EHColors.darkSwitchTrackOff.withValues(alpha: 0.38)));
        expect(disabledOnTrack, equals(EHColors.darkSwitchTrackOn.withValues(alpha: 0.38)));

        final disabledOffThumb = darkSwitchTheme.thumbColor?.resolve({WidgetState.disabled});
        final disabledOnThumb = darkSwitchTheme.thumbColor?.resolve({WidgetState.disabled, WidgetState.selected});
        expect(disabledOffThumb, equals(EHColors.darkSwitchThumbOff.withValues(alpha: 0.65)));
        expect(disabledOnThumb, equals(EHColors.darkSwitchThumbOn.withValues(alpha: 0.65)));

        final disabledOutline = darkSwitchTheme.trackOutlineColor?.resolve({WidgetState.disabled});
        expect(disabledOutline, equals(EHColors.darkBorderControl.withValues(alpha: 0.38)));

        // Light Theme Outline & Disabled State Support
        final lightTheme = EHAppTheme.lightTheme;
        final lightSwitchTheme = lightTheme.switchTheme;
        expect(lightSwitchTheme.trackOutlineColor?.resolve({}), equals(EHColors.lightBorderControl));
        expect(lightSwitchTheme.trackOutlineColor?.resolve({WidgetState.selected}), equals(Colors.transparent));
        expect(lightSwitchTheme.trackColor?.resolve({WidgetState.disabled}), equals(EHColors.lightSwitchTrackOff.withValues(alpha: 0.38)));
        expect(lightSwitchTheme.trackColor?.resolve({WidgetState.disabled, WidgetState.selected}), equals(EHColors.lightSwitchTrackOn.withValues(alpha: 0.38)));
      },
    );

    testWidgets(
      '5. Notification logic: toggle callback expands options, persists alert config, and updates UI without regressions',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // Initial: switch is OFF, sub-options not visible
        expect(find.text('Notify When'), findsNothing);

        // 5.1 Toggle switch ON -> sub-options expand
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(find.text('Notify When'), findsOneWidget);
        expect(find.text('ON Only'), findsOneWidget);
        expect(find.text('OFF Only'), findsOneWidget);
        expect(find.text('Both ON/OFF'), findsOneWidget);
        expect(find.text('Custom Alert Message (Optional)'), findsOneWidget);

        // 5.2 Select trigger condition: ON Only
        await tester.tap(find.text('ON Only'));
        await tester.pumpAndSettle();

        // 5.3 Enter custom alert message
        final textFieldFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ).last;
        await tester.enterText(textFieldFinder, 'Geyser running!');
        await tester.pumpAndSettle();

        // 5.4 Save settings
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        // Verify bottom sheet closed
        expect(find.byType(BottomSheet), findsNothing);

        // Verify controller state updated
        final savedConfig = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(savedConfig.enabled, isTrue);
        expect(savedConfig.alertOnTurnOn, isTrue);
        expect(savedConfig.alertOnTurnOff, isFalse);
        expect(savedConfig.customMessage, equals('Geyser running!'));

        // Verify SnackBar confirmation message appears
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Settings saved for'), findsOneWidget);

        // Verify device control page channel card updates with alert indicator
        expect(find.textContaining('Alert: ON only • "Geyser running!"'), findsOneWidget);

        // 5.5 Reopen sheet and toggle OFF
        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final reopenedSwitchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(reopenedSwitchFinder).value, isTrue);

        // Toggle OFF
        await tester.tap(reopenedSwitchFinder);
        await tester.pumpAndSettle();

        // Verify options collapse
        expect(find.text('Notify When'), findsNothing);

        // Save disabled state
        await tester.ensureVisible(find.text('Save Settings'));
        await tester.tap(find.text('Save Settings'));
        await tester.pumpAndSettle();

        final disabledConfig = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(disabledConfig.enabled, isFalse);

        // Subtitle indicator is removed
        expect(find.textContaining('Alert:'), findsNothing);
      },
    );

    testWidgets(
      '6. Notification logic: cancel dismisses sheet without mutating alert configuration',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildApp(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // Toggle ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(find.text('Notify When'), findsOneWidget);

        // Tap Cancel
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify bottom sheet closed and config remains disabled
        expect(find.byType(BottomSheet), findsNothing);
        final config = controller.getChannelAlertConfig(testDevice.id, 1);
        expect(config.enabled, isFalse, reason: 'Canceling must not persist toggled state');
      },
    );
  });
}
