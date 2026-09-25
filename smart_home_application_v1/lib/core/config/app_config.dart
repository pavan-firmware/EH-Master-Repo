import '../services/device_storage_service.dart';

/// Global Environment Configuration
///
/// Precedence:
/// 1. Runtime override via [setBaseUrl] (for tests / explicit runtime configuration)
/// 2. Persisted custom backend URL in [DeviceStorageService]
/// 3. Compile-time `--dart-define=BACKEND_BASE_URL=http://...`
/// 4. Local network production default (http://192.168.55.103:3000)
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

    final stored = DeviceStorageService.backendUrl;
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    return 'http://192.168.55.103:3000';
  }
}
