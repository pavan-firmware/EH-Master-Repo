import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/app.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';
import 'package:smart_home_application_v1/app/theme_controller.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';

void main() {
  group('Theme Tokens & Specification Verification', () {
    test('Dark theme tokens match EH Home brand specifications', () {
      const dark = EHThemeTokens.dark;
      expect(dark.isDark, isTrue);
      expect(dark.bgApp, const Color(0xFF07111F));
      expect(dark.bgSecondary, const Color(0xFF0B1728));
      expect(dark.surfaceCard, const Color(0xFF101F33));
      expect(dark.surfaceElevated, const Color(0xFF14263D));
      expect(dark.borderSubtle, const Color(0xFF1C3047));
      expect(dark.borderControl, const Color(0xFF26384E));
      expect(dark.textPrimary, const Color(0xFFF4F7FB));
      expect(dark.textSecondary, const Color(0xFFAAB7C8));
      expect(dark.textTertiary, const Color(0xFF718198));
      expect(dark.sectionHeading, const Color(0xFFAEBBCB));
      expect(dark.bluePrimary, const Color(0xFF3D82D6));
      expect(dark.blueDarker, const Color(0xFF2F6DB5));
      expect(dark.blueSelectedBg, const Color(0xFF17365B));
      expect(dark.blueSelectedText, const Color(0xFF78A9E5));
      expect(dark.gold, const Color(0xFFF4C95D));
      expect(dark.goldBright, const Color(0xFFFFD86A));
      expect(dark.goldContainer, const Color(0xFF332C18));
      expect(dark.success, const Color(0xFF2DBE73));
      expect(dark.successContainer, const Color(0xFF123A2A));
      expect(dark.warning, const Color(0xFFF08A24));
      expect(dark.warningContainer, const Color(0xFF3A2815));
      expect(dark.errorText, const Color(0xFFF06A55));
      expect(dark.errorContainer, const Color(0xFF3B1D1A));
      expect(dark.switchTrackOff, const Color(0xFF26384E));
      expect(dark.switchThumbOff, const Color(0xFFAAB7C8));
      expect(dark.switchTrackOn, const Color(0xFF2F6DB5));
      expect(dark.switchThumbOn, const Color(0xFFF4F7FB));
    });

    test('Light theme tokens preserve existing approved colors', () {
      const light = EHThemeTokens.light;
      expect(light.isDark, isFalse);
      expect(light.bgApp, const Color(0xFFF6F8FC));
      expect(light.surfaceCard, Colors.white);
      expect(light.textPrimary, const Color(0xFF102448));
      expect(light.textSecondary, const Color(0xFF65738C));
    });

    test('EHAppTheme builds both light and dark ThemeData with extensions', () {
      final darkTheme = EHAppTheme.darkTheme;
      final lightTheme = EHAppTheme.lightTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF07111F));
      expect(darkTheme.extension<EHThemeTokens>(), isNotNull);
      expect(darkTheme.extension<EHThemeTokens>()!.isDark, isTrue);

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF6F8FC));
      expect(lightTheme.extension<EHThemeTokens>(), isNotNull);
      expect(lightTheme.extension<EHThemeTokens>()!.isDark, isFalse);
    });
  });

  group('ThemeController & Mode Switching', () {
    test('ThemeController switches modes and notifies listeners', () {
      final controller = ThemeController();
      expect(controller.themeMode, ThemeMode.system);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notified, isTrue);

      notified = false;
      controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
      expect(notified, isTrue);

      controller.dispose();
    });

    testWidgets('App renders in Dark Theme and switches dynamically', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      final themeController = ThemeController();
      themeController.setThemeMode(ThemeMode.dark);

      final homeController = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );

      await tester.pumpWidget(
        SmartHomeApp(
          homeController: homeController,
          themeController: themeController,
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Verify widget rendered with Dark Theme background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFF07111F));

      // Switch to Light Theme
      themeController.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();

      final lightScaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(lightScaffold.backgroundColor, const Color(0xFFF6F8FC));

      homeController.dispose();
      themeController.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  });
}
