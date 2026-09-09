import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/app/theme_controller.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';

void main() {
  group('Framework Lifecycle & Assertion Regression Tests', () {
    testWidgets('ThemeScope resolves theme and avoids unmounted inherited element leaks', (tester) async {
      final themeController = ThemeController(initialMode: ThemeMode.light);

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: themeController,
          builder: (context, _) => ThemeScope(
            controller: themeController,
            child: MaterialApp(
              theme: EHAppTheme.lightTheme,
              darkTheme: EHAppTheme.darkTheme,
              themeMode: themeController.themeMode,
              home: Builder(
                builder: (context) {
                  final isDark = ThemeScope.of(context).isDarkMode;
                  return Scaffold(
                    body: Center(
                      child: Text('Mode: ${isDark ? "Dark" : "Light"}'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mode: Light'), findsOneWidget);

      // Rapidly toggle theme
      themeController.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(find.text('Mode: Dark'), findsOneWidget);

      themeController.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(find.text('Mode: Light'), findsOneWidget);
    });

    testWidgets('Opening and closing modal dialog does not leave dangling controllers or framework assertions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController(text: 'Hello');
                        return AlertDialog(
                          title: const Text('Edit Dialog'),
                          content: TextField(controller: ctrl),
                          actions: [
                            TextButton(
                              onPressed: () {
                                ctrl.dispose();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Dialog'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Dialog'), findsNothing);
      expect(find.text('Open Dialog'), findsOneWidget);
    });
  });
}
