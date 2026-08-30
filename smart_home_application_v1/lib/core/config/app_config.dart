import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Global Environment Configuration
///
/// Precedence:
/// 1. Compile-time `--dart-define=BACKEND_BASE_URL=http://...`
/// 2. Injected parameter in widget tree (for tests)
/// 3. Environment-aware default for local development
class AppConfig {
  AppConfig._();

  /// Target environment: 'development', 'staging', or 'production'
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String _definedBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'development';

  /// Authoritative backend API base URL
  static String get backendBaseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (isProduction) {
      throw StateError(
        'Production build requires explicit --dart-define=BACKEND_BASE_URL=https://<your-domain>',
      );
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (Platform.isAndroid) {
      // Development LAN host IP fallback for local testing
      return 'http://192.168.1.8:3000';
    }

    return 'http://localhost:3000';
  }
}

