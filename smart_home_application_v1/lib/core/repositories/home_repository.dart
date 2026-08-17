import '../models/device_models.dart';

abstract interface class HomeRepository {
  Future<List<DeviceSnapshot>> getDevices();

  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  });

  Future<FirmwareRelease?> getAvailableRelease();

  Stream<FirmwareJob> watchFirmwareJob();
}
