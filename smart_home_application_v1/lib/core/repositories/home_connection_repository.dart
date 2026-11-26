import '../models/connection_models.dart';
import '../models/device_models.dart';
import '../../app/home_controller.dart';
import '../services/device_storage_service.dart';

abstract interface class HomeConnectionRepository {
  Future<HomeConnectionOverview> getOverview({HomeConnectionState? liveState});
  Future<void> refresh();
}

class RealHomeConnectionRepository implements HomeConnectionRepository {
  const RealHomeConnectionRepository({
    this.primaryDevice,
    this.wifiSsid,
    this.onRefresh,
    this.forceCommissioningMode = false,
  });

  final ConnectedDeviceSummary? primaryDevice;
  final String? wifiSsid;
  final Future<void> Function()? onRefresh;
  final bool forceCommissioningMode;

  @override
  Future<HomeConnectionOverview> getOverview({
    HomeConnectionState? liveState,
  }) async {
    final effectiveDevice = forceCommissioningMode
        ? null
        : (primaryDevice ?? HomeController.instance?.connectedDeviceSummary ?? DeviceStorageService.primaryDevice);
    final ctrl = HomeController.instance;
    final bool isOnline;
    if (ctrl != null) {
      isOnline = ctrl.authoritativeConnectionState.isOnline;
    } else {
      isOnline = !forceCommissioningMode &&
          (effectiveDevice?.online ?? false);
    }
    final state = liveState ?? ((effectiveDevice != null && isOnline)
        ? HomeConnectionState.connected
        : (effectiveDevice != null ? HomeConnectionState.offline : HomeConnectionState.notConfigured));

    if (state == HomeConnectionState.connected && effectiveDevice != null) {
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
        setupSteps: const [
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
        ],
        primaryDevice: primaryDevice,
        wifiSsid: wifiSsid ?? 'Home Wi-Fi',
        lastChecked: DateTime.now(),
      );
    }

    final isConnecting = state == HomeConnectionState.connecting;
    return HomeConnectionOverview(
      overall: state,
      title: isConnecting
          ? 'Finding your device'
          : 'Your home isn\'t connected yet',
      subtitle: isConnecting
          ? 'Keep your phone close to your EH Home device.'
          : 'Connect your devices to get started.',
      statusLabel: isConnecting ? 'Connecting…' : 'Not connected',
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
      setupSteps: [
        SetupStep(
          index: 1,
          title: 'Find your device',
          subtitle: 'Searching for nearby EH Home devices',
          status: isConnecting
              ? SetupStepStatus.active
              : SetupStepStatus.pending,
        ),
        const SetupStep(
          index: 2,
          title: 'Connect securely',
          subtitle: 'Establishing a trusted connection',
          status: SetupStepStatus.pending,
        ),
        const SetupStep(
          index: 3,
          title: 'Connect to home Wi-Fi',
          subtitle: 'Joining your home network',
          status: SetupStepStatus.pending,
        ),
        const SetupStep(
          index: 4,
          title: 'Verify connection',
          subtitle: 'Confirming device is online',
          status: SetupStepStatus.pending,
        ),
        const SetupStep(
          index: 5,
          title: 'Finish setup',
          subtitle: 'Your home is ready to use',
          status: SetupStepStatus.pending,
        ),
      ],
    );
  }

  @override
  Future<void> refresh() async {
    if (onRefresh != null) {
      await onRefresh!();
    }
  }
}

class PreviewHomeConnectionRepository implements HomeConnectionRepository {
  const PreviewHomeConnectionRepository();

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
    final ctrl = HomeController.instance;
    final realDevice = ctrl?.connectedDeviceSummary ??
        (ctrl?.devices.isNotEmpty == true ? ctrl!.devices.first : null);
    final state = liveState ??
        (realDevice != null
            ? (realDevice.online
                ? HomeConnectionState.connected
                : HomeConnectionState.offline)
            : HomeConnectionState.offline);

    if (state == HomeConnectionState.connected && realDevice != null) {
      return HomeConnectionOverview(
        overall: HomeConnectionState.connected,
        title: '${realDevice.name} is connected',
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
        primaryDevice: realDevice,
        wifiSsid: realDevice.connectedVia.isNotEmpty
            ? realDevice.connectedVia
            : 'Home Wi-Fi',
        lastChecked: DateTime.now(),
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
