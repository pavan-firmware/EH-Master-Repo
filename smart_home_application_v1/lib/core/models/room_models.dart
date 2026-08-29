import 'home_dashboard_models.dart';

/// Room domain data is transport-independent. BLE, local Wi-Fi and cloud
/// repositories will eventually map authenticated device data into this model.
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.deviceCount,
    required this.connectivity,
    required this.telemetryFreshness,
    required this.summary,
    required this.status,
    required this.capabilities,
    required this.devices,
    required this.insights,
    this.lastUpdated,
  });

  final String id;
  final String name;
  final String iconKey;
  final int deviceCount;
  final ConnectivityCause connectivity;
  final TelemetryFreshness telemetryFreshness;
  final String summary;
  final RoomStatus status;
  final List<RoomCapability> capabilities;
  final List<RoomDevice> devices;
  final RoomInsights insights;
  final DateTime? lastUpdated;

  bool get isOnline => connectivity == ConnectivityCause.online;
  bool get needsAttention => status == RoomStatus.attention;
  bool get isOffline =>
      !isOnline || telemetryFreshness == TelemetryFreshness.unknown;

  String get connectivityLabel {
    if (isOffline) return 'Device state unavailable';
    if (needsAttention) return '1 issue detected';
    if (telemetryFreshness == TelemetryFreshness.stale) {
      return 'Telemetry stale';
    }
    return 'All devices online';
  }
}

enum RoomStatus { normal, attention, unavailable }

class RoomCapability {
  const RoomCapability({
    required this.id,
    required this.label,
    required this.value,
    required this.kind,
    this.isWarning = false,
    this.safetyCritical = false,
  });

  final String id;
  final String label;
  final String value;
  final RoomCapabilityKind kind;
  final bool isWarning;
  final bool safetyCritical;
}

enum RoomCapabilityKind {
  light,
  temperature,
  gasSensor,
  soilMoisture,
  mistCare,
  waterLevel,
  lowLevelAlert,
  fan,
  curtain,
  lamp,
  outlet,
  socket,
  switchControl,
  energy,
}

class RoomDevice {
  const RoomDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.kind,
    required this.confidence,
  });

  final String id;
  final String name;
  final String type;
  final String value;
  final RoomCapabilityKind kind;
  final ActuatorConfidence confidence;
}

class RoomInsights {
  const RoomInsights({
    required this.energyKwh,
    required this.energyChange,
    required this.activeWindow,
    required this.averageTemperature,
    required this.averageHumidity,
  });

  final String energyKwh;
  final String energyChange;
  final String activeWindow;
  final String averageTemperature;
  final String averageHumidity;
}

class RoomCatalog {
  const RoomCatalog._();

  static const preview = <Room>[
    Room(
      id: 'living',
      name: 'Living Room',
      iconKey: 'living',
      deviceCount: 3,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '24°C · Comfortable',
      status: RoomStatus.normal,
      capabilities: [
        RoomCapability(
          id: 'light',
          label: 'Main light',
          value: 'On',
          kind: RoomCapabilityKind.light,
        ),
        RoomCapability(
          id: 'temperature',
          label: 'Temperature',
          value: '24°C',
          kind: RoomCapabilityKind.temperature,
        ),
      ],
      devices: [
        RoomDevice(
          id: 'living-light',
          name: 'Main light',
          type: 'Smart bulb · Living Room',
          value: 'On',
          kind: RoomCapabilityKind.light,
          confidence: ActuatorConfidence.unavailable,
        ),
        RoomDevice(
          id: 'living-fan',
          name: 'Ceiling fan',
          type: 'Smart fan · Living Room',
          value: 'Speed 2',
          kind: RoomCapabilityKind.fan,
          confidence: ActuatorConfidence.unavailable,
        ),
        RoomDevice(
          id: 'living-temp',
          name: 'Temperature sensor',
          type: 'Sensor · Living Room',
          value: '24.0°C',
          kind: RoomCapabilityKind.temperature,
          confidence: ActuatorConfidence.confirmed,
        ),
      ],
      insights: RoomInsights(
        energyKwh: '2.35 kWh',
        energyChange: '+12% vs yesterday',
        activeWindow: '6:00 PM – 10:00 PM',
        averageTemperature: '24.2°C',
        averageHumidity: '51%',
      ),
    ),
    Room(
      id: 'kitchen',
      name: 'Kitchen',
      iconKey: 'kitchen',
      deviceCount: 2,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '2 devices · Attention needed',
      status: RoomStatus.attention,
      capabilities: [
        RoomCapability(
          id: 'gas',
          label: 'Gas sensor',
          value: 'Check required',
          kind: RoomCapabilityKind.gasSensor,
          isWarning: true,
          safetyCritical: true,
        ),
        RoomCapability(
          id: 'temperature',
          label: 'Temperature',
          value: '26°C',
          kind: RoomCapabilityKind.temperature,
        ),
      ],
      devices: [
        RoomDevice(
          id: 'gas',
          name: 'Gas sensor',
          type: 'Safety sensor · Kitchen',
          value: 'Check required',
          kind: RoomCapabilityKind.gasSensor,
          confidence: ActuatorConfidence.confirmed,
        ),
        RoomDevice(
          id: 'kitchen-temp',
          name: 'Temperature sensor',
          type: 'Sensor · Kitchen',
          value: '26.0°C',
          kind: RoomCapabilityKind.temperature,
          confidence: ActuatorConfidence.confirmed,
        ),
      ],
      insights: RoomInsights(
        energyKwh: '1.14 kWh',
        energyChange: 'No change today',
        activeWindow: '7:00 AM – 9:00 AM',
        averageTemperature: '25.6°C',
        averageHumidity: '54%',
      ),
    ),
    Room(
      id: 'plant',
      name: 'Plant Corner',
      iconKey: 'plant',
      deviceCount: 2,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '2 devices · Soil moisture good',
      status: RoomStatus.normal,
      capabilities: [
        RoomCapability(
          id: 'soil',
          label: 'Soil moisture',
          value: '42%',
          kind: RoomCapabilityKind.soilMoisture,
        ),
        RoomCapability(
          id: 'mist',
          label: 'Mist care',
          value: 'Scheduled',
          kind: RoomCapabilityKind.mistCare,
        ),
      ],
      devices: [
        RoomDevice(
          id: 'soil',
          name: 'Soil sensor',
          type: 'Sensor · Plant Corner',
          value: '42%',
          kind: RoomCapabilityKind.soilMoisture,
          confidence: ActuatorConfidence.confirmed,
        ),
        RoomDevice(
          id: 'mist',
          name: 'Mist maker',
          type: 'Actuator · Plant Corner',
          value: 'Scheduled',
          kind: RoomCapabilityKind.mistCare,
          confidence: ActuatorConfidence.unavailable,
        ),
      ],
      insights: RoomInsights(
        energyKwh: '0.42 kWh',
        energyChange: '-4% vs yesterday',
        activeWindow: '8:00 AM – 8:15 AM',
        averageTemperature: '25.0°C',
        averageHumidity: '62%',
      ),
    ),
    Room(
      id: 'water',
      name: 'Water Tank',
      iconKey: 'water',
      deviceCount: 1,
      connectivity: ConnectivityCause.online,
      telemetryFreshness: TelemetryFreshness.current,
      summary: '1 device · 72% full',
      status: RoomStatus.normal,
      capabilities: [
        RoomCapability(
          id: 'level',
          label: 'Water level',
          value: '72%',
          kind: RoomCapabilityKind.waterLevel,
        ),
        RoomCapability(
          id: 'low-level',
          label: 'Low-level alert',
          value: 'Enabled',
          kind: RoomCapabilityKind.lowLevelAlert,
        ),
      ],
      devices: [
        RoomDevice(
          id: 'tank',
          name: 'Water level sensor',
          type: 'Sensor · Water Tank',
          value: '72%',
          kind: RoomCapabilityKind.waterLevel,
          confidence: ActuatorConfidence.confirmed,
        ),
      ],
      insights: RoomInsights(
        energyKwh: '0.08 kWh',
        energyChange: 'No change today',
        activeWindow: '6:00 AM – 6:05 AM',
        averageTemperature: '24.8°C',
        averageHumidity: '58%',
      ),
    ),
  ];
}
