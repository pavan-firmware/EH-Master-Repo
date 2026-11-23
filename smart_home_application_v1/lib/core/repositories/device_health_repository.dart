import '../../app/home_controller.dart';
import '../models/health_models.dart';

abstract interface class DeviceHealthRepository {
  Future<HomeHealthSummary> getSummary();
  Future<HomeHealthSummary> runFullCheck();
}

class PreviewDeviceHealthRepository implements DeviceHealthRepository {
  const PreviewDeviceHealthRepository();

  @override
  Future<HomeHealthSummary> getSummary() async {
    final ctrl = HomeController.instance;
    if (ctrl != null && ctrl.devices.isNotEmpty) {
      final devices = ctrl.devices;
      final onlineList = devices.where((d) => d.online).toList();
      final offlineList = devices.where((d) => !d.online).toList();

      final deviceEntries = devices.map((d) {
        return DeviceHealthEntry(
          deviceId: d.id,
          name: d.name,
          roomId: d.roomName.toLowerCase().replaceAll(' ', '-'),
          roomName: d.roomName.isNotEmpty ? d.roomName : 'Main Space',
          state: d.online ? DeviceHealthState.healthy : DeviceHealthState.offline,
          signal: d.online ? SignalStrength.strong : SignalStrength.unknown,
          lastSeen: null,
          statusLine: d.online ? 'Online · Connected' : 'Offline · Disconnected',
          iconKey: 'switch',
          reading: d.model,
        );
      }).toList();

      final rooms = ctrl.rooms.map((r) {
        return RoomHealthSummary(
          roomId: r.id,
          roomName: r.name,
          deviceCount: r.deviceCount,
          issueCount: r.isOffline ? 1 : 0,
          iconKey: r.iconKey,
        );
      }).toList();

      return HomeHealthSummary(
        overall: offlineList.isEmpty ? HomeHealthOverall.healthy : HomeHealthOverall.attention,
        title: offlineList.isEmpty ? 'All systems operational' : '${offlineList.length} device(s) offline',
        subtitle: offlineList.isEmpty ? 'All devices connected.' : 'Check power or Wi-Fi connection.',
        statusLabel: offlineList.isEmpty ? 'Healthy' : 'Attention needed',
        totalDevices: devices.length,
        onlineCount: onlineList.length,
        attentionCount: 0,
        offlineCount: offlineList.length,
        lastChecked: DateTime.now(),
        devices: deviceEntries,
        rooms: rooms,
      );
    }

    return HomeHealthSummary(
      overall: HomeHealthOverall.healthy,
      title: 'No devices found',
      subtitle: 'Add devices to your home to view health status.',
      statusLabel: 'Standby',
      totalDevices: 0,
      onlineCount: 0,
      attentionCount: 0,
      offlineCount: 0,
      lastChecked: DateTime.now(),
      devices: const [],
      rooms: const [],
    );
  }

  @override
  Future<HomeHealthSummary> runFullCheck() async {
    final ctrl = HomeController.instance;
    if (ctrl != null) {
      await ctrl.probeLanAndPromote();
    }
    return getSummary();
  }
}
