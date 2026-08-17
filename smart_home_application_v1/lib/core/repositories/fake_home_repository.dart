import '../models/device_models.dart';
import 'home_repository.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository()
      : _release = FirmwareRelease(
          version: '1.1.0',
          title: 'A smoother, safer home',
          summary: 'Improved connection recovery, safety checks, and update reliability.',
          tags: const ['Reliability', 'Security', 'Improved care'],
          publishedAt: DateTime(2026, 8, 12),
        );

  final FirmwareRelease _release;

  @override
  Future<List<DeviceSnapshot>> getDevices() async => [
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

  @override
  Future<CommandReceipt> sendCommand({
    required String deviceId,
    required String action,
    required Map<String, Object?> parameters,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return CommandReceipt(
      commandId: idempotencyKey,
      state: CommandState.succeeded,
    );
  }

  @override
  Future<FirmwareRelease?> getAvailableRelease() async => _release;

  @override
  Stream<FirmwareJob> watchFirmwareJob() async* {
    yield FirmwareJob(state: FirmwareJobState.idle, progress: 0, release: _release);
  }
}
