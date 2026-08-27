import '../config/device_connection_config.dart';
import 'connection_repository.dart';

class UnavailableConnectionRepository implements ConnectionRepository {
  const UnavailableConnectionRepository();

  @override
  Future<ConnectionResult> connect({
    required DeviceConnectionConfig config,
  }) async {
    if (!config.isReady) {
      return const ConnectionResult(
        success: false,
        message: 'Hardware connection values are not configured yet.',
      );
    }
    return const ConnectionResult(
      success: false,
      message: 'Bluetooth connection service is not enabled in this build yet.',
    );
  }
}
