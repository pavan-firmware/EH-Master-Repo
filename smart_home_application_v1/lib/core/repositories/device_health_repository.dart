import '../../app/home_controller.dart';
import '../models/health_models.dart';

abstract interface class DeviceHealthRepository {
  Future<HomeHealthSummary> getSummary();
  Future<HomeHealthSummary> runFullCheck();
}

class PreviewDeviceHealthRepository implements DeviceHealthRepository {
  const PreviewDeviceHealthRepository();

  static final _lastChecked = DateTime(2026, 8, 15, 9, 40);

  static const _previewDevices = [
    DeviceHealthEntry(
      deviceId: 'living-light',
      name: 'Living Room Light',
      roomId: 'living-room',
      roomName: 'Living Room',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.strong,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'light',
    ),
    DeviceHealthEntry(
      deviceId: 'temp-sensor',
      name: 'Temperature Sensor',
      roomId: 'living-room',
      roomName: 'Living Room',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.good,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'temperature',
      reading: '24°',
    ),
    DeviceHealthEntry(
      deviceId: 'kitchen-plug',
      name: 'Smart Plug',
      roomId: 'kitchen',
      roomName: 'Kitchen',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.strong,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'plug',
    ),
  ];

  static const _previewRooms = [
    RoomHealthSummary(
      roomId: 'living-room',
      roomName: 'Living Room',
      deviceCount: 2,
      issueCount: 0,
      iconKey: 'sofa',
    ),
    RoomHealthSummary(
      roomId: 'kitchen',
      roomName: 'Kitchen',
      deviceCount: 1,
      issueCount: 0,
      iconKey: 'kitchen',
    ),
  ];

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
        title: offlineList.isEmpty ? 'All good!' : '${offlineList.length} device(s) offline',
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
      title: 'All good!',
      subtitle: 'All devices are online and working properly.',
      statusLabel: 'Healthy',
      totalDevices: _previewDevices.length,
      onlineCount: _previewDevices.length,
      attentionCount: 0,
      offlineCount: 0,
      lastChecked: _lastChecked,
      devices: _previewDevices,
      rooms: _previewRooms,
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
