import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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

  String _generateUuid() {
    final rnd = math.Random();
    String hex(int len) =>
        List.generate(len, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  Future<List<Map<String, dynamic>>> getHomes() async {
    final response = await _apiClient.get('/api/v1/homes');
    if (response is List) {
      return response.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createHome(String name) async {
    final response = await _apiClient.post(
      '/api/v1/homes',
      body: {'name': name.trim()},
    );
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return response;
    }
    return <String, dynamic>{'name': name};
  }

  Future<void> updateHome(String homeId, String name) async {
    try {
      await _apiClient.patch('/api/v1/homes/$homeId', body: {'name': name.trim()});
    } catch (_) {}
  }

  Future<void> deleteHome(String homeId) async {
    try {
      await _apiClient.delete('/api/v1/homes/$homeId');
    } catch (_) {}
  }


  @override
  Future<List<DeviceSnapshot>> getDevices({String? homeId}) async {
    String resolvedHomeId = homeId ?? _activeHomeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse == null) return [];
      final homesList = homesResponse is List
          ? homesResponse
          : (homesResponse is Map && homesResponse['data'] is List
              ? homesResponse['data'] as List
              : []);
      if (homesList.isEmpty) return [];
      resolvedHomeId = homesList[0]['id'] as String;
      _activeHomeId = resolvedHomeId;
    }

    dynamic devicesResponse;
    try {
      devicesResponse = await _apiClient.get(
        '/api/v1/homes/$resolvedHomeId/devices',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        return [];
      }
      rethrow;
    }
    if (devicesResponse == null) return [];

    final rawList = devicesResponse is List
        ? devicesResponse
        : (devicesResponse is Map && devicesResponse['data'] is List
            ? devicesResponse['data'] as List
            : []);

    final List<DeviceSnapshot> devices = [];
    for (var device in rawList) {
      final devMap = Map<String, dynamic>.from(device as Map);
      final rawCaps = devMap['capabilities'];
      List<DeviceCapability> capabilities = [];
      if (rawCaps is List) {
        capabilities = rawCaps
            .map((c) => DeviceCapability(
                  id: c.toString(),
                  label: c.toString(),
                ))
            .toList();
      }

      final rawChannels = devMap['channels'];
      List<Map<String, dynamic>> channels = [];
      if (rawChannels is List) {
        channels = rawChannels
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
      }

      devices.add(
        DeviceSnapshot(
          id: devMap['deviceId'] ?? devMap['id'] ?? '',
          name: devMap['displayName'] ?? devMap['label'] ?? 'Unknown Device',
          roomName: devMap['roomName'] ?? 'Home',
          hardwareRevision: devMap['hardwareRevision'] ??
              devMap['product_sku'] ??
              'HW_1_0',
          connection: _mapConnection(
            devMap['connectionState'] ?? devMap['last_seen_at'],
          ),
          capabilities: capabilities,
          reportedAt: devMap['last_seen_at'] != null
              ? DateTime.tryParse(devMap['last_seen_at'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
          firmwareVersion: devMap['firmwareVersion'] ??
              devMap['firmware_version'] ??
              '1.0.0',
          channels: channels,
          productVariantId: devMap['productVariantId'] ??
              devMap['product_variant_id']?.toString(),
          serialNumber:
              devMap['serialNumber'] ?? devMap['serial_number']?.toString(),
        ),
      );
    }
    return devices;
  }

  DeviceConnection _mapConnection(dynamic connectionOrLastSeen) {
    if (connectionOrLastSeen == null) return DeviceConnection.offline;
    final str = connectionOrLastSeen.toString().toUpperCase();
    if (str == 'ONLINE') return DeviceConnection.online;
    if (str == 'STALE') return DeviceConnection.stale;
    if (str == 'OFFLINE') return DeviceConnection.offline;

    try {
      final lastSeen = DateTime.parse(connectionOrLastSeen.toString());
      final diff = DateTime.now().difference(lastSeen).inSeconds;
      if (diff > 45) {
        return DeviceConnection.offline;
      }
      return DeviceConnection.online;
    } catch (_) {
      return DeviceConnection.offline;
    }
  }

  Future<void> renameChannel({
    required String deviceId,
    required int channelIndex,
    required String newName,
  }) async {
    try {
      await _apiClient.patch(
        '/api/v1/devices/$deviceId/channels/$channelIndex',
        body: {'name': newName},
      );
    } catch (_) {
      final homeId = _activeHomeId ?? 'home_01';
      await claimDevice(
        deviceId: deviceId,
        homeId: homeId,
        channelLabels: {channelIndex.toString(): newName},
      );
    }
  }

  Future<void> renameRoom({
    required String roomId,
    required String newName,
  }) async {
    try {
      await _apiClient.patch(
        '/api/v1/rooms/$roomId',
        body: {'name': newName.trim()},
      );
    } catch (e) {
      // Fallback to home-scoped room route if needed
      if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
        try {
          await _apiClient.patch(
            '/api/v1/homes/$_activeHomeId/rooms/$roomId',
            body: {'name': newName.trim()},
          );
        } catch (innerErr) {
          debugPrint('[CloudHomeRepo] renameRoom error: $innerErr');
        }
      } else {
        debugPrint('[CloudHomeRepo] renameRoom error: $e');
      }
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _apiClient.delete('/api/v1/rooms/$roomId');
    } catch (e) {
      // Fallback to home-scoped room route if needed
      if (_activeHomeId != null && _activeHomeId!.isNotEmpty) {
        try {
          await _apiClient.delete('/api/v1/homes/$_activeHomeId/rooms/$roomId');
        } catch (innerErr) {
          debugPrint('[CloudHomeRepo] deleteRoom error: $innerErr');
        }
      } else {
        debugPrint('[CloudHomeRepo] deleteRoom error: $e');
      }
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
    String resolvedHomeId = homeId ?? _activeHomeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse != null) {
        final homesList = homesResponse is List
            ? homesResponse
            : (homesResponse is Map && homesResponse['data'] is List
                ? homesResponse['data'] as List
                : []);
        if (homesList.isNotEmpty) {
          resolvedHomeId = homesList[0]['id'] as String;
          _activeHomeId = resolvedHomeId;
        }
      }
    }
    if (resolvedHomeId.isEmpty) return [];

    dynamic response;
    try {
      response = await _apiClient.get(
        '/api/v1/homes/$resolvedHomeId/rooms',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        return [];
      }
      rethrow;
    }
    if (response is List) {
      return response.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> createRoom({
    required String name,
    String? homeId,
    String? iconKey,
  }) async {
    if (name.trim().isEmpty) {
      throw ApiException(statusCode: 400, message: 'Room name cannot be empty');
    }

    String resolvedHomeId = homeId ?? _activeHomeId ?? '';
    if (resolvedHomeId.isEmpty) {
      final homesResponse = await _apiClient.get('/api/v1/homes');
      if (homesResponse != null) {
        final homesList = homesResponse is List
            ? homesResponse
            : (homesResponse is Map && homesResponse['data'] is List
                ? homesResponse['data'] as List
                : []);
        if (homesList.isNotEmpty) {
          resolvedHomeId = homesList[0]['id'] as String;
          _activeHomeId = resolvedHomeId;
        }
      }
    }

    if (resolvedHomeId.isEmpty) {
      throw ApiException(statusCode: 400, message: 'Please create or select an active home first');
    }

    final response = await _apiClient.post(
      '/api/v1/homes/$resolvedHomeId/rooms',
      body: {'name': name.trim(), 'iconKey': iconKey ?? 'living'},
    );
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return response;
    }
    return <String, dynamic>{'name': name};
  }

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async {
    try {
      final channelIndex = parameters['channel'] as int? ??
          parameters['channelIndex'] as int? ??
          1;

      String actionName = action;
      if (action == 'set_power' || action == 'toggle_power') {
        actionName = 'setPower';
      }

      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validCommandId =
          uuidRegex.hasMatch(idempotencyKey) ? idempotencyKey : _generateUuid();
      final validDeviceId =
          uuidRegex.hasMatch(deviceId) ? deviceId : _generateUuid();

      final response = await _apiClient.post(
        '/api/v1/commands/send',
        body: {
          'commandId': validCommandId,
          'deviceId': validDeviceId,
          'channelIndex': channelIndex,
          'action': actionName,
          'params': parameters,
          'idempotencyKey': idempotencyKey,
          'source': 'APP',
        },
      );

      final respMap = response is Map<String, dynamic> ? response : {};
      return CommandReceipt(
        commandId: respMap['commandId'] ?? respMap['id'] ?? idempotencyKey,
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
    try {
      final response = await _apiClient.get('/api/v1/ota/check');
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] is Map<String, dynamic>
            ? response['data'] as Map<String, dynamic>
            : response;
        if (data.containsKey('version')) {
          return FirmwareRelease(
            version: data['version'] ?? '1.0.0',
            title: data['title'] ?? 'Release',
            summary: data['summary'] ?? '',
            tags: (data['tags'] as List?)?.cast<String>() ?? const [],
            publishedAt: data['publishedAt'] != null
                ? DateTime.parse(data['publishedAt'])
                : DateTime.now(),
            required: data['required'] ?? false,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Stream<FirmwareJob> watchFirmwareJob() async* {
    // Return empty stream when no OTA job is in progress
  }
}
