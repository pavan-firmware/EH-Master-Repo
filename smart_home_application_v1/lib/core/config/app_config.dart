import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Global Environment Configuration
///
/// Precedence:
/// 1. Runtime override via [setBaseUrl] (for tests / explicit runtime configuration)
/// 2. Compile-time `--dart-define=BACKEND_BASE_URL=http://...`
/// 3. Environment-aware safe defaults (Android emulator loopback, web localhost, or local host)
class AppConfig {
  AppConfig._();

  static String? _runtimeBaseUrl;

  static const String _definedBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Set or reset the runtime base URL override.
  static void setBaseUrl(String? url) {
    _runtimeBaseUrl = url;
  }

  /// Authoritative backend API base URL
  static String get backendBaseUrl {
    if (_runtimeBaseUrl != null && _runtimeBaseUrl!.isNotEmpty) {
      return _runtimeBaseUrl!;
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    try {
      if (Platform.isAndroid) {
        // Standard Android emulator loopback alias to host machine
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}

    return 'http://localhost:3000';
  }
}
