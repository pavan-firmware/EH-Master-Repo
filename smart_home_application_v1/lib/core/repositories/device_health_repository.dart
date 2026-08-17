import '../models/health_models.dart';

abstract interface class DeviceHealthRepository {
  Future<HomeHealthSummary> getSummary();
  Future<HomeHealthSummary> runFullCheck();
}

class PreviewDeviceHealthRepository implements DeviceHealthRepository {
  const PreviewDeviceHealthRepository();

  static final _lastChecked = DateTime(2026, 8, 15, 9, 40);

  static const _devices = [
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
    DeviceHealthEntry(
      deviceId: 'water-pump',
      name: 'Water Pump',
      roomId: 'water-tank',
      roomName: 'Water Tank',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.good,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'water',
    ),
    DeviceHealthEntry(
      deviceId: 'plant-moisture',
      name: 'Plant Moisture Sensor',
      roomId: 'plant-corner',
      roomName: 'Plant Corner',
      state: DeviceHealthState.attention,
      signal: SignalStrength.weak,
      lastSeen: null,
      statusLine: 'Attention · Weak signal',
      iconKey: 'plant',
    ),
    DeviceHealthEntry(
      deviceId: 'SH-8EF248',
      name: 'Smart Mist Maker',
      roomId: 'plant-corner',
      roomName: 'Plant Corner',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.strong,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'mist',
    ),
    DeviceHealthEntry(
      deviceId: 'gas-sensor',
      name: 'Kitchen Air Sensor',
      roomId: 'kitchen',
      roomName: 'Kitchen',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.good,
      lastSeen: null,
      statusLine: 'Online · Updated 1 min ago',
      iconKey: 'air',
    ),
    DeviceHealthEntry(
      deviceId: 'tank-level',
      name: 'Water Level Sensor',
      roomId: 'water-tank',
      roomName: 'Water Tank',
      state: DeviceHealthState.healthy,
      signal: SignalStrength.strong,
      lastSeen: null,
      statusLine: 'Online · Updated just now',
      iconKey: 'level',
    ),
  ];

  static const _rooms = [
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
      deviceCount: 2,
      issueCount: 1,
      iconKey: 'kitchen',
    ),
    RoomHealthSummary(
      roomId: 'plant-corner',
      roomName: 'Plant Corner',
      deviceCount: 2,
      issueCount: 0,
      iconKey: 'plant',
    ),
    RoomHealthSummary(
      roomId: 'water-tank',
      roomName: 'Water Tank',
      deviceCount: 2,
      issueCount: 0,
      iconKey: 'water',
    ),
  ];

  @override
  Future<HomeHealthSummary> getSummary() async {
    const attention = 1;
    const online = 8;
    return HomeHealthSummary(
      overall: HomeHealthOverall.healthy,
      title: 'All good!',
      subtitle: 'All devices are online and working properly.',
      statusLabel: 'Healthy',
      totalDevices: 8,
      onlineCount: online,
      attentionCount: attention,
      offlineCount: 0,
      lastChecked: _lastChecked,
      devices: _devices,
      rooms: _rooms,
    );
  }

  @override
  Future<HomeHealthSummary> runFullCheck() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return getSummary();
  }
}
