import 'device_models.dart';

enum ConnectionLayerKind { bluetooth, homeWifi, havenService }

enum ConnectionLayerStatus {
  ready,
  connected,
  notConfigured,
  unavailable,
  failed,
}

enum SetupStepStatus { pending, active, completed, failed }

class ConnectionLayer {
  const ConnectionLayer({
    required this.kind,
    required this.label,
    required this.description,
    required this.status,
  });

  final ConnectionLayerKind kind;
  final String label;
  final String description;
  final ConnectionLayerStatus status;

  String get statusLabel => switch (status) {
        ConnectionLayerStatus.ready => 'Ready',
        ConnectionLayerStatus.connected => 'Connected',
        ConnectionLayerStatus.notConfigured => 'Not configured',
        ConnectionLayerStatus.unavailable => 'Unavailable',
        ConnectionLayerStatus.failed => 'Failed',
      };
}

class SetupStep {
  const SetupStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final int index;
  final String title;
  final String subtitle;
  final SetupStepStatus status;
}

class ConnectedDeviceSummary {
  const ConnectedDeviceSummary({
    required this.id,
    required this.name,
    required this.model,
    required this.firmware,
    required this.connectedVia,
    required this.signalLabel,
    required this.roomName,
    required this.online,
  });

  final String id;
  final String name;
  final String model;
  final String firmware;
  final String connectedVia;
  final String signalLabel;
  final String roomName;
  final bool online;
}

class HomeConnectionOverview {
  const HomeConnectionOverview({
    required this.overall,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.layers,
    required this.setupSteps,
    this.primaryDevice,
    this.wifiSsid,
    this.lastChecked,
  });

  final HomeConnectionState overall;
  final String title;
  final String subtitle;
  final String statusLabel;
  final List<ConnectionLayer> layers;
  final List<SetupStep> setupSteps;
  final ConnectedDeviceSummary? primaryDevice;
  final String? wifiSsid;
  final DateTime? lastChecked;

  bool get isFullyConnected => overall == HomeConnectionState.connected;
}
