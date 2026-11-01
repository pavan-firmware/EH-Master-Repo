import '../services/device_storage_service.dart';

/// Global Environment Configuration
///
/// Precedence:
/// 1. Runtime override via [setBaseUrl] (for tests / explicit runtime configuration)
/// 2. Persisted custom backend URL in [DeviceStorageService]
/// 3. Compile-time `--dart-define=BACKEND_BASE_URL=http://...`
/// 4. Local network production default (http://192.168.0.227:3000)
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
      final s = stored.trim();
      if (!s.contains('localhost') && !s.contains('127.0.0.1')) {
        return s;
      }
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    return 'http://192.168.0.227:3000';
  }
}
