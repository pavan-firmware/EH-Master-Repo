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

/// Accurate WCAG 2.1 Relative Luminance and Contrast Ratio calculation
double _luminance(Color c) {
  return c.computeLuminance();
}

double _wcagContrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDevice = ConnectedDeviceSummary(
    id: 'test-device-switch-adversarial',
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

  Widget buildTestBed({
    required ThemeMode mode,
    required HomeController homeController,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: EHAppTheme.lightTheme,
      darkTheme: EHAppTheme.darkTheme,
      themeMode: mode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: DeviceControlPage(
          device: testDevice,
          homeController: homeController,
        ),
      ),
    );
  }

  group('CHALLENGER STRESS SUITE: Milestone M1 Switch UI & Theme Rigor', () {
    // -------------------------------------------------------------------------
    // STRESS TEST 1: Strict WCAG 2.1 AA Contrast Ratios (Track, Thumb, Background)
    // -------------------------------------------------------------------------
    test('1. [Contrast Audit] Verify Light & Dark theme color contrast ratios', () {
      // 1.1 Light Theme Active Switch
      const lightThumbOn = EHColors.lightSwitchThumbOn; // #FFFFFF
      const lightTrackOn = EHColors.lightSwitchTrackOn; // #155CC8
      // Container background in device_control_page.dart line 337:
      const lightContainerBg = Color(0xFFF4F7FB);

      final lightThumbToTrack = _wcagContrastRatio(lightThumbOn, lightTrackOn);
      final lightTrackToBg = _wcagContrastRatio(lightTrackOn, lightContainerBg);

      expect(
        lightThumbToTrack,
        greaterThanOrEqualTo(3.0),
        reason: 'Light theme active thumb vs track ($lightThumbToTrack:1) must meet WCAG 3.0:1',
      );
      expect(
        lightTrackToBg,
        greaterThanOrEqualTo(3.0),
        reason: 'Light theme active track vs container background ($lightTrackToBg:1) must meet WCAG 3.0:1',
      );

      // 1.2 Dark Theme Active Switch
      const darkThumbOn = EHColors.darkSwitchThumbOn; // #F4F7FB
      const darkTrackOn = EHColors.darkSwitchTrackOn; // #2F6DB5
      // Container background in device_control_page.dart line 336:
      const darkContainerBg = Color(0xFF141F30);

      final darkThumbToTrack = _wcagContrastRatio(darkThumbOn, darkTrackOn);
      final darkTrackToBg = _wcagContrastRatio(darkTrackOn, darkContainerBg);

      expect(
        darkThumbToTrack,
        greaterThanOrEqualTo(3.0),
        reason: 'Dark theme active thumb vs track ($darkThumbToTrack:1) must meet WCAG 3.0:1',
      );
      expect(
        darkTrackToBg,
        greaterThanOrEqualTo(3.0),
        reason: 'Dark theme active track vs container background ($darkTrackToBg:1) must meet WCAG 3.0:1',
      );

      // 1.3 Dark Theme Inactive Switch Thumb vs Track
      const darkThumbOff = EHColors.darkSwitchThumbOff; // #AAB7C8
      const darkTrackOff = EHColors.darkSwitchTrackOff; // #26384E
      final darkThumbToTrackOff = _wcagContrastRatio(darkThumbOff, darkTrackOff);
      expect(
        darkThumbToTrackOff,
        greaterThanOrEqualTo(3.0),
        reason: 'Dark theme inactive thumb vs track ($darkThumbToTrackOff:1) must be distinct',
      );

      // 1.4 Light Theme Inactive Switch Outline Verification
      // Light track outline is lightBorderControl (#D8E0EC), width 1.0, ensuring track boundary visibility
      final lightThemeData = EHAppTheme.lightTheme.switchTheme;
      expect(lightThemeData.trackOutlineColor?.resolve({}), equals(EHColors.lightBorderControl));
      expect(lightThemeData.trackOutlineWidth?.resolve({}), equals(1.0));
      expect(lightThemeData.trackOutlineColor?.resolve({WidgetState.selected}), equals(Colors.transparent));
    });

    // -------------------------------------------------------------------------
    // STRESS TEST 2: Small Screen Boundaries (Ultra-compact 320x480 & 360x640)
    // -------------------------------------------------------------------------
    testWidgets(
      '2. [Geometry Stress] Ultra-small screen (320x480) opens settings sheet without overflow and allows toggle',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestBed(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        // On a 320x480 screen, scroll down in the body ListView to reach channel controls
        final editFinder = find.byTooltip('Rename Channel');
        await tester.scrollUntilVisible(
          editFinder,
          150.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(editFinder.first);
        await tester.pumpAndSettle();

        await tester.tap(editFinder.first);
        await tester.pumpAndSettle();

        // Bottom sheet must appear without RenderFlex overflow
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on 320x480 screen');

        // Locate Switch inside bottom sheet
        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);

        // Verify Switch is fully within screen bounds
        final switchRect = tester.getRect(switchFinder);
        expect(switchRect.left, greaterThanOrEqualTo(0.0));
        expect(switchRect.right, lessThanOrEqualTo(320.0));

        // Tap Switch to toggle ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);

        // Verify options expanded without RenderFlex overflow in 320x480 sheet
        expect(tester.takeException(), isNull);
        expect(find.text('Notify When'), findsOneWidget);

        // Tap Switch to toggle OFF
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // STRESS TEST 3: Extreme Accessibility Font Scaling (textScaler 2.0)
    // -------------------------------------------------------------------------
    testWidgets(
      '3. [Font Scaling Stress] Text scale factor 2.0 does NOT overflow and preserves Switch layout',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestBed(
            mode: ThemeMode.light,
            homeController: controller,
            textScale: 2.0, // 200% font scaling
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to channel edit button under large font scale
        final editFinder = find.byTooltip('Rename Channel');
        await tester.scrollUntilVisible(
          editFinder,
          150.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(editFinder.first);
        await tester.pumpAndSettle();

        await tester.tap(editFinder.first);
        await tester.pumpAndSettle();

        // Check for exceptions / overflow inside the sheet with 2.0 text scale
        expect(tester.takeException(), isNull, reason: 'TextScaler 2.0 must not throw layout overflow');

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);

        final switchSize = tester.getSize(switchFinder);
        expect(switchSize.width, greaterThan(30.0), reason: 'Switch must not be squished to zero width');
        expect(switchSize.height, greaterThan(20.0), reason: 'Switch must maintain valid height');

        // Verify tapping Switch works at 2.0 font scale
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    // -------------------------------------------------------------------------
    // STRESS TEST 4: Geometric Size & Hit Test Stability Across ON/OFF States
    // -------------------------------------------------------------------------
    testWidgets(
      '4. [Tap Target & Geometry] Switch hit testing and geometric dimensions remain stable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestBed(mode: ThemeMode.dark, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );
        final sheetFinder = find.byType(BottomSheet);

        final initialSize = tester.getSize(switchFinder);
        final initialSheetTop = tester.getTopLeft(sheetFinder).dy;
        final initialSwitchRelativeDy = tester.getTopLeft(switchFinder).dy - initialSheetTop;

        // Tap the center of the switch to toggle ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final onSize = tester.getSize(switchFinder);
        final onSheetTop = tester.getTopLeft(sheetFinder).dy;
        final onSwitchRelativeDy = tester.getTopLeft(switchFinder).dy - onSheetTop;

        // Size must not change between ON and OFF
        expect(onSize.width, equals(initialSize.width));
        expect(onSize.height, equals(initialSize.height));

        // Relative position within the sheet container must not shift
        expect((onSwitchRelativeDy - initialSwitchRelativeDy).abs(), lessThan(1.0));

        // Tap the switch again to toggle OFF
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Should have toggled back to false
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // STRESS TEST 5: Rapid Successive Toggling State Integrity
    // -------------------------------------------------------------------------
    testWidgets(
      '5. [Rapid Toggle Stress] Rapid successive toggling maintains state consistency',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestBed(mode: ThemeMode.light, homeController: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // Rapid 5 taps without waiting for settle
        for (int i = 0; i < 5; i++) {
          await tester.tap(switchFinder);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        // Odd number of taps (5) starting from false -> must be true
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
        expect(find.text('Notify When'), findsOneWidget);

        // One more tap -> false
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
        expect(find.text('Notify When'), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // STRESS TEST 6: Dynamic Theme Mode Invalidation (Light <-> Dark)
    // -------------------------------------------------------------------------
    testWidgets(
      '6. [Theme Switching Stress] Dynamic switch from Light to Dark theme updates Switch tokens immediately',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final modeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

        await tester.pumpWidget(
          ValueListenableBuilder<ThemeMode>(
            valueListenable: modeNotifier,
            builder: (context, currentMode, _) {
              return MaterialApp(
                theme: EHAppTheme.lightTheme,
                darkTheme: EHAppTheme.darkTheme,
                themeMode: currentMode,
                home: Scaffold(
                  body: DeviceControlPage(
                    device: testDevice,
                    homeController: controller,
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Rename Channel').first);
        await tester.pumpAndSettle();

        final switchFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Switch),
        );

        // Turn switch ON
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Check Light Theme effective track and thumb
        var theme = Theme.of(tester.element(switchFinder));
        var switchTheme = theme.switchTheme;
        expect(switchTheme.thumbColor?.resolve({WidgetState.selected}), equals(EHColors.lightSwitchThumbOn));
        expect(switchTheme.trackColor?.resolve({WidgetState.selected}), equals(EHColors.lightSwitchTrackOn));

        // Dynamically switch to Dark Theme
        modeNotifier.value = ThemeMode.dark;
        await tester.pumpAndSettle();

        // Check Dark Theme effective track and thumb
        theme = Theme.of(tester.element(switchFinder));
        switchTheme = theme.switchTheme;
        expect(switchTheme.thumbColor?.resolve({WidgetState.selected}), equals(EHColors.darkSwitchThumbOn));
        expect(switchTheme.trackColor?.resolve({WidgetState.selected}), equals(EHColors.darkSwitchTrackOn));
        expect(tester.widget<Switch>(switchFinder).value, isTrue);
      },
    );
  });
}
