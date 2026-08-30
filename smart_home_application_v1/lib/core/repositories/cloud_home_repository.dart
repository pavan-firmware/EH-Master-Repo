import '../models/device_models.dart';
import 'home_repository.dart';
import '../api/api_client.dart';

class CloudHomeRepository implements HomeRepository {
  final ApiClient _apiClient;
  String? _activeHomeId;

  CloudHomeRepository(this._apiClient, {String? activeHomeId}) {
    _activeHomeId = activeHomeId;
  }

  String? get activeHomeId => _activeHomeId;
  void setActiveHomeId(String homeId) => _activeHomeId = homeId;

  @override
  Future<List<DeviceSnapshot>> getDevices({String? homeId}) async {
    String resolvedHomeId = homeId ?? _activeHomeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse == null || (homesResponse as List).isEmpty) {
        return [];
      }
      resolvedHomeId = homesResponse[0]['id'] as String;
      _activeHomeId = resolvedHomeId;
    }

    final devicesResponse = await _apiClient.get(
      '/api/v1/homes/$resolvedHomeId/devices',
    );
    if (devicesResponse == null) return [];

    final List<DeviceSnapshot> devices = [];
    for (var device in (devicesResponse as List)) {
      devices.add(
        DeviceSnapshot(
          id: device['deviceId'] ?? device['id'],
          name: device['displayName'] ?? device['label'] ?? 'Unknown Device',
          roomName: device['roomName'] ?? 'Home',
          hardwareRevision:
              device['hardwareRevision'] ?? device['product_sku'] ?? 'unknown',
          connection: _mapConnection(
            device['connectionState'] ?? device['last_seen_at'],
          ),
          capabilities: const [
            DeviceCapability(id: 'status', label: 'Home status'),
          ],
          reportedAt: device['last_seen_at'] != null
              ? DateTime.parse(device['last_seen_at'])
              : DateTime.now(),
          firmwareVersion:
              device['firmwareVersion'] ??
              device['firmware_version'] ??
              '1.0.0',
        ),
      );
    }
    return devices;
  }

  DeviceConnection _mapConnection(dynamic connectionOrLastSeen) {
    if (connectionOrLastSeen == null) return DeviceConnection.offline;
    if (connectionOrLastSeen == 'ONLINE') return DeviceConnection.online;
    if (connectionOrLastSeen == 'STALE') return DeviceConnection.stale;
    if (connectionOrLastSeen == 'OFFLINE') return DeviceConnection.offline;

    try {
      final lastSeen = DateTime.parse(connectionOrLastSeen.toString());
      final diff = DateTime.now().difference(lastSeen).inSeconds;
      if (diff > 120) {
        return DeviceConnection.offline;
      }
      return DeviceConnection.online;
    } catch (_) {
      return DeviceConnection.offline;
    }
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String serialNumber,
    required String productVariantId,
    required String hardwareRevision,
    required String firmwareFamily,
    String firmwareVersion = '1.0.0',
  }) async {
    await _apiClient.post(
      '/api/v1/devices/register',
      body: {
        'deviceId': deviceId,
        'serialNumber': serialNumber,
        'productVariantId': productVariantId,
        'hardwareRevision': hardwareRevision,
        'firmwareFamily': firmwareFamily,
        'firmwareVersion': firmwareVersion,
      },
    );
  }

  @override
  Future<void> claimDevice({
    required String deviceId,
    required String homeId,
    String? roomId,
    String? customName,
    Map<String, String>? channelLabels,
  }) async {
    final body = <String, dynamic>{'homeId': homeId};
    if (roomId != null) body['roomId'] = roomId;
    if (customName != null) body['customName'] = customName;
    if (channelLabels != null) body['channelLabels'] = channelLabels;

    await _apiClient.post('/api/v1/devices/$deviceId/claim', body: body);
  }

  @override
  Future<List<Map<String, dynamic>>> getRooms({String? homeId}) async {
    String resolvedHomeId = homeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse != null && (homesResponse as List).isNotEmpty) {
        resolvedHomeId = homesResponse[0]['id'] as String;
      }
    }
    if (resolvedHomeId.isEmpty) return [];

    final response = await _apiClient.get(
      '/api/v1/homes/$resolvedHomeId/rooms',
    );
    if (response is List) {
      return response.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> createRoom({
    required String name,
    String? homeId,
    String? iconKey,
  }) async {
    String resolvedHomeId = homeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse != null && (homesResponse as List).isNotEmpty) {
        resolvedHomeId = homesResponse[0]['id'] as String;
      }
    }

    final response = await _apiClient.post(
      '/api/v1/homes/$resolvedHomeId/rooms',
      body: {'name': name, 'iconKey': iconKey ?? 'living'},
    );
    return Map<String, dynamic>.from(response as Map);
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
    return null;
  }

  @override
  Stream<FirmwareJob> watchFirmwareJob() async* {
    yield const FirmwareJob(state: FirmwareJobState.idle, progress: 0);
  }
}
