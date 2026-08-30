import '../api/api_client.dart';
import '../models/device_management_models.dart';

abstract class DeviceManagementRepository {
  Future<DeviceDetailsModel> getDeviceDetails(String homeId, String deviceId);
  Future<DeviceHealthMetricsModel> getDeviceHealth(
    String homeId,
    String deviceId,
  );
  Future<List<DeviceActivityLogItemModel>> getDeviceActivity(
    String homeId,
    String deviceId, {
    int limit = 50,
  });
  Future<void> renameDevice(String homeId, String deviceId, String newName);
  Future<void> moveDevice(String homeId, String deviceId, String? newRoomId);
  Future<void> removeDevice(String homeId, String deviceId);
}

class CloudDeviceManagementRepository implements DeviceManagementRepository {
  const CloudDeviceManagementRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DeviceDetailsModel> getDeviceDetails(
    String homeId,
    String deviceId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/homes/$homeId/devices/$deviceId/details',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return DeviceDetailsModel.fromJson(data);
  }

  @override
  Future<DeviceHealthMetricsModel> getDeviceHealth(
    String homeId,
    String deviceId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/homes/$homeId/devices/$deviceId/health',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return DeviceHealthMetricsModel.fromJson(data);
  }

  @override
  Future<List<DeviceActivityLogItemModel>> getDeviceActivity(
    String homeId,
    String deviceId, {
    int limit = 50,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/homes/$homeId/devices/$deviceId/activity?limit=$limit',
    );
    final list = response['data'] as List<dynamic>? ?? const [];
    return list
        .map(
          (e) => DeviceActivityLogItemModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> renameDevice(
    String homeId,
    String deviceId,
    String newName,
  ) async {
    await _apiClient.patch(
      '/api/v1/homes/$homeId/devices/$deviceId/rename',
      body: {'name': newName},
    );
  }

  @override
  Future<void> moveDevice(
    String homeId,
    String deviceId,
    String? newRoomId,
  ) async {
    await _apiClient.patch(
      '/api/v1/homes/$homeId/devices/$deviceId/move',
      body: {'roomId': newRoomId},
    );
  }

  @override
  Future<void> removeDevice(String homeId, String deviceId) async {
    await _apiClient.delete('/api/v1/homes/$homeId/devices/$deviceId');
  }
}
