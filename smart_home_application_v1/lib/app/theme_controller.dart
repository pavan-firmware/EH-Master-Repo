import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Manages application-wide theme mode (System, Light, Dark) with persistence.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
      : _themeMode = initialMode {
    _loadPreference();
  }

  ThemeMode _themeMode;
  static const String _prefFileName = 'eh_home_theme_mode.txt';

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
      final file = await _getPrefFile();
      if (await file.exists()) {
        final content = (await file.readAsString()).trim();
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
      }
    } catch (_) {
      // Ignored for environments without local filesystem access
    }
  }

  Future<void> _savePreference(ThemeMode mode) async {
    try {
      final file = await _getPrefFile();
      await file.writeAsString(mode.name);
    } catch (_) {
      // Ignored for environments without local filesystem access
    }
  }

  Future<File> _getPrefFile() async {
    final dir = Directory.systemTemp;
    return File('${dir.path}/$_prefFileName');
  }
}

/// Provides [ThemeController] down the widget tree.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ThemeController controller;

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    if (scope == null) {
      throw FlutterError('ThemeScope.of() called with a context that does not contain a ThemeScope.');
    }
    return scope.controller;
  }

  static ThemeController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => controller != oldWidget.controller;
}
