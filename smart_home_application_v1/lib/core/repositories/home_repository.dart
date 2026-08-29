import '../models/device_models.dart';

abstract interface class HomeRepository {
  Future<List<DeviceSnapshot>> getDevices({String? homeId});

  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  });

  Future<void> claimDevice({
    required String deviceId,
    required String homeId,
    String? roomId,
    String? customName,
    Map<String, String>? channelLabels,
  });

  Future<void> registerDevice({
    required String deviceId,
    required String serialNumber,
    required String productVariantId,
    required String hardwareRevision,
    required String firmwareFamily,
    String firmwareVersion = '1.0.0',
  });

  Future<List<Map<String, dynamic>>> getRooms({String? homeId});

  Future<Map<String, dynamic>> createRoom({
    required String name,
    String? homeId,
    String? iconKey,
  });

  Future<FirmwareRelease?> getAvailableRelease();

  Stream<FirmwareJob> watchFirmwareJob();
}
