import '../models/device_models.dart';
import 'home_repository.dart';
import '../api/api_client.dart';

class CloudHomeRepository implements HomeRepository {
  final ApiClient _apiClient;

  CloudHomeRepository(this._apiClient);

  @override
  Future<List<DeviceSnapshot>> getDevices() async {
    // We fetch the first home id (assuming single home for now, as per backend defaults or we can fetch homes list first)
    final homesResponse = await _apiClient.get('/api/v1/homes');
    if (homesResponse == null || (homesResponse as List).isEmpty) {
      return [];
    }

    final homeId = homesResponse[0]['id'];

    final devicesResponse = await _apiClient.get(
      '/api/v1/homes/$homeId/devices',
    );
    if (devicesResponse == null) return [];

    final List<DeviceSnapshot> devices = [];
    for (var device in (devicesResponse as List)) {
      devices.add(
        DeviceSnapshot(
          id: device['id'],
          name: device['label'] ?? 'Unknown Device',
          roomName:
              'Home', // Could be fetched from room resolution if available
          hardwareRevision: device['product_sku'] ?? 'unknown',
          connection: _mapConnection(device['last_seen_at']),
          capabilities: const [
            DeviceCapability(id: 'status', label: 'Home status'),
            // Would map real capabilities from catalog here ideally
          ],
          reportedAt: device['last_seen_at'] != null
              ? DateTime.parse(device['last_seen_at'])
              : DateTime.now(),
          firmwareVersion: device['firmware_version'] ?? '1.0.0',
        ),
      );
    }
    return devices;
  }

  DeviceConnection _mapConnection(String? lastSeenAt) {
    if (lastSeenAt == null) return DeviceConnection.offline;
    final lastSeen = DateTime.parse(lastSeenAt);
    final diff = DateTime.now().difference(lastSeen).inSeconds;
    if (diff > 120) {
      return DeviceConnection
          .offline; // Stale logic should be driven by backend availability events ideally
    }
    return DeviceConnection.online;
  }

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/commands/send',
        body: {
          'deviceId': deviceId,
          'action': action,
          'parameters': parameters,
          'idempotencyKey': idempotencyKey,
        },
      );

      return CommandReceipt(
        commandId: response['id'] ?? idempotencyKey,
        state: CommandState.accepted,
      );
    } catch (e) {
      return CommandReceipt(
        commandId: idempotencyKey,
        state: CommandState.failed,
        message: e.toString(),
      );
    }
  }

  @override
  Future<FirmwareRelease?> getAvailableRelease() async {
    // Phase 7C doesn't focus on real OTA, mock for now
    return null;
  }

  @override
  Stream<FirmwareJob> watchFirmwareJob() async* {
    yield const FirmwareJob(state: FirmwareJobState.idle, progress: 0);
  }
}
