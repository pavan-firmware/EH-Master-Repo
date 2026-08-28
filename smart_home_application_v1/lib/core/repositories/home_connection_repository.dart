import '../models/connection_models.dart';
import '../models/device_models.dart';

abstract interface class HomeConnectionRepository {
  Future<HomeConnectionOverview> getOverview({HomeConnectionState? liveState});
  Future<void> refresh();
}

class PreviewHomeConnectionRepository implements HomeConnectionRepository {
  const PreviewHomeConnectionRepository();

  static const _device = ConnectedDeviceSummary(
    id: 'EH-SW3X-2026W12-00001',
    name: 'EH Smart Switch 3X',
    model: 'EH-SW3X-V1',
    firmware: '1.0.0',
    connectedVia: 'Wi-Fi (2.4 GHz)',
    signalLabel: 'Strong',
    roomName: 'Living Room',
    online: true,
  );

  static const _connectedSteps = [
    SetupStep(
      index: 1,
      title: 'Find your device',
      subtitle: 'Searching for nearby EH Home devices',
      status: SetupStepStatus.completed,
    ),
    SetupStep(
      index: 2,
      title: 'Connect securely',
      subtitle: 'Establishing a trusted connection',
      status: SetupStepStatus.completed,
    ),
    SetupStep(
      index: 3,
      title: 'Connect to home Wi-Fi',
      subtitle: 'Joining your home network',
      status: SetupStepStatus.completed,
    ),
    SetupStep(
      index: 4,
      title: 'Verify connection',
      subtitle: 'Confirming device is online',
      status: SetupStepStatus.completed,
    ),
    SetupStep(
      index: 5,
      title: 'Finish setup',
      subtitle: 'Your home is ready to use',
      status: SetupStepStatus.completed,
    ),
  ];

  @override
  Future<HomeConnectionOverview> getOverview({
    HomeConnectionState? liveState,
  }) async {
    final state = liveState ?? HomeConnectionState.connected;
    if (state == HomeConnectionState.connected) {
      return HomeConnectionOverview(
        overall: HomeConnectionState.connected,
        title: 'Your home is connected',
        subtitle: 'All systems are working normally.',
        statusLabel: 'Connected',
        layers: const [
          ConnectionLayer(
            kind: ConnectionLayerKind.bluetooth,
            label: 'Bluetooth',
            description: 'Used for nearby device setup',
            status: ConnectionLayerStatus.ready,
          ),
          ConnectionLayer(
            kind: ConnectionLayerKind.homeWifi,
            label: 'Home Wi-Fi',
            description: 'Used for normal device communication',
            status: ConnectionLayerStatus.connected,
          ),
        ],
        setupSteps: _connectedSteps,
        primaryDevice: _device,
        wifiSsid: 'Home Wi-Fi',
        lastChecked: DateTime(2026, 8, 15, 9, 40),
      );
    }
    return HomeConnectionOverview(
      overall: state,
      title: 'Your home isn\'t connected yet',
      subtitle: 'Connect your devices to get started.',
      statusLabel: 'Not connected',
      layers: const [
        ConnectionLayer(
          kind: ConnectionLayerKind.bluetooth,
          label: 'Bluetooth',
          description: 'Used for nearby device setup',
          status: ConnectionLayerStatus.notConfigured,
        ),
        ConnectionLayer(
          kind: ConnectionLayerKind.homeWifi,
          label: 'Home Wi-Fi',
          description: 'Used for normal device communication',
          status: ConnectionLayerStatus.notConfigured,
        ),
      ],
      setupSteps: const [
        SetupStep(
          index: 1,
          title: 'Find your device',
          subtitle: 'Searching for nearby EH Home devices',
          status: SetupStepStatus.active,
        ),
        SetupStep(
          index: 2,
          title: 'Connect securely',
          subtitle: 'Establishing a trusted connection',
          status: SetupStepStatus.pending,
        ),
        SetupStep(
          index: 3,
          title: 'Connect to home Wi-Fi',
          subtitle: 'Joining your home network',
          status: SetupStepStatus.pending,
        ),
        SetupStep(
          index: 4,
          title: 'Verify connection',
          subtitle: 'Confirming device is online',
          status: SetupStepStatus.pending,
        ),
        SetupStep(
          index: 5,
          title: 'Finish setup',
          subtitle: 'Your home is ready to use',
          status: SetupStepStatus.pending,
        ),
      ],
    );
  }

  @override
  Future<void> refresh() async {}
}
