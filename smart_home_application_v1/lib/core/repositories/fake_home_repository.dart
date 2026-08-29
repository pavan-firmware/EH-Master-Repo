import '../models/device_models.dart';
import 'home_repository.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository()
    : _release = FirmwareRelease(
        version: '1.1.0',
        title: 'A smoother, safer home',
        summary:
            'Improved connection recovery, safety checks, and update reliability.',
        tags: const ['Reliability', 'Security', 'Improved care'],
        publishedAt: DateTime(2026, 8, 12),
      );

  final FirmwareRelease _release;
  final List<DeviceSnapshot> _mockDevices = [];
  final List<Map<String, dynamic>> _mockRooms = [];

  @override
  Future<List<DeviceSnapshot>> getDevices() async {
    if (_mockDevices.isNotEmpty) return List.unmodifiable(_mockDevices);
    return [
      DeviceSnapshot(
        id: 'home-main',
        name: 'Home device',
        roomName: 'Home',
        hardwareRevision: 'prototype',
        connection: DeviceConnection.online,
        capabilities: const [
          DeviceCapability(id: 'status', label: 'Home status'),
          DeviceCapability(id: 'system_update', label: 'System updates'),
        ],
        reportedAt: DateTime.now(),
      ),
    ];
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
    _mockDevices.add(
      DeviceSnapshot(
        id: deviceId,
        name: 'Smart Device',
        roomName: 'Living Room',
        hardwareRevision: hardwareRevision,
        connection: DeviceConnection.online,
        capabilities: const [
          DeviceCapability(id: 'status', label: 'Status'),
        ],
        reportedAt: DateTime.now(),
        firmwareVersion: firmwareVersion,
      ),
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
    final idx = _mockDevices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      final existing = _mockDevices[idx];
      _mockDevices[idx] = DeviceSnapshot(
        id: existing.id,
        name: customName ?? existing.name,
        roomName: existing.roomName,
        hardwareRevision: existing.hardwareRevision,
        connection: existing.connection,
        capabilities: existing.capabilities,
        reportedAt: DateTime.now(),
        firmwareVersion: existing.firmwareVersion,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRooms({String? homeId}) async {
    return List.unmodifiable(_mockRooms);
  }

  @override
  Future<Map<String, dynamic>> createRoom({
    required String name,
    String? homeId,
    String? iconKey,
  }) async {
    final room = {
      'id': 'room_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'iconKey': iconKey ?? 'living',
    };
    _mockRooms.add(room);
    return room;
  }

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return CommandReceipt(
      commandId: idempotencyKey,
      state: CommandState.succeeded,
    );
  }

  @override
  Future<FirmwareRelease?> getAvailableRelease() async => _release;

  @override
  Stream<FirmwareJob> watchFirmwareJob() async* {
    yield FirmwareJob(
      state: FirmwareJobState.idle,
      progress: 0,
      release: _release,
    );
  }
}
