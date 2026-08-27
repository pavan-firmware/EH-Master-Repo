import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Global Environment Configuration
///
/// Precedence:
/// 1. Compile-time `--dart-define=BACKEND_BASE_URL=http://...`
/// 2. Injected parameter in widget tree (for tests)
/// 3. Environment-aware default (physical Android LAN host, emulator host, or localhost)
class AppConfig {
  AppConfig._();

  static const String _definedBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Authoritative backend API base URL
  static String get backendBaseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      // Development LAN host IP for physical Android device connectivity
      return 'http://192.168.1.62:3000';
    }

    return 'http://localhost:3000';
  }
}
