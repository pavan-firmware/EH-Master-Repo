import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'home_controller.dart';
import 'theme_controller.dart';
import '../features/splash/presentation/splash_screen.dart';

class SmartHomeApp extends StatefulWidget {
  const SmartHomeApp({
    super.key,
    this.homeController,
    this.themeController,
  });

  final HomeController? homeController;
  final ThemeController? themeController;

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
  }

  @override
  void dispose() {
    if (widget.themeController == null) {
      _themeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return ThemeScope(
          controller: _themeController,
          child: MaterialApp(
            title: 'EH Home',
            debugShowCheckedModeBanner: false,
            theme: EHAppTheme.lightTheme,
            darkTheme: EHAppTheme.darkTheme,
            themeMode: _themeController.themeMode,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final systemUiStyle = isDark
                  ? const SystemUiOverlayStyle(
                      statusBarColor: EHColors.darkBgApp,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemNavigationBarColor: EHColors.darkSurfaceNav,
                      systemNavigationBarIconBrightness: Brightness.light,
                    )
                  : const SystemUiOverlayStyle(
                      statusBarColor: EHColors.lightBgApp,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      systemNavigationBarColor: Colors.black,
                      systemNavigationBarIconBrightness: Brightness.light,
                    );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemUiStyle,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: SplashScreen(homeController: widget.homeController),
          ),
        );
      },
    );
  }
}
