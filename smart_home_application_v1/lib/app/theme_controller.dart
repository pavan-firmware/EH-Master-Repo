import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages application-wide theme mode (System, Light, Dark) with persistence.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
    : _themeMode = initialMode {
    _loadPreference();
  }

  ThemeMode _themeMode;
  static const String _prefKey = 'eh_theme_mode_v2';

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _savePreference(mode);
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_prefKey);
      if (content == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      } else if (content == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      } else if (content == 'system') {
        _themeMode = ThemeMode.system;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _savePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }
}

/// Provides [ThemeController] down the widget tree.
class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.controller, required super.child});

  final ThemeController controller;

  static ThemeController of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<ThemeScope>()
        : context.getInheritedWidgetOfExactType<ThemeScope>();
    if (scope == null) {
      throw FlutterError(
        'ThemeScope.of() called with a context that does not contain a ThemeScope.',
      );
    }
    return scope.controller;
  }

  static ThemeController? maybeOf(BuildContext context, {bool listen = false}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<ThemeScope>()
        : context.getInheritedWidgetOfExactType<ThemeScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      controller.themeMode != oldWidget.controller.themeMode ||
      controller != oldWidget.controller;
}
