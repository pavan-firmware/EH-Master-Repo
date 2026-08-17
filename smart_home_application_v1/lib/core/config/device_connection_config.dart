/// Hardware values supplied by the firmware/hardware team.
///
/// Keep secrets out of this file. Provisioning credentials must come from the
/// device QR bootstrap flow and be stored in platform secure storage.
class DeviceConnectionConfig {
  const DeviceConnectionConfig({
    required this.bleServiceUuid,
    required this.telemetryCharacteristicUuid,
    required this.statusCharacteristicUuid,
    required this.productInfoCharacteristicUuid,
    required this.deviceNamePrefix,
    required this.protocolVersion,
  });

  final String bleServiceUuid;
  final String telemetryCharacteristicUuid;
  final String statusCharacteristicUuid;
  final String productInfoCharacteristicUuid;
  final String deviceNamePrefix;
  final String protocolVersion;

  bool get isReady => true;
}

/// Current development-node BLE contract. Sensitive provisioning and command
/// characteristics will be added only after authenticated commissioning exists.
const deviceConnectionConfig = DeviceConnectionConfig(
  bleServiceUuid: 'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101',
  telemetryCharacteristicUuid: 'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6103',
  statusCharacteristicUuid: 'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6104',
  productInfoCharacteristicUuid: 'a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6105',
  deviceNamePrefix: 'SH-',
  protocolVersion: '1',
);
