import 'package:flutter/material.dart';

import '../../../core/models/activity_models.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/device_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/home_connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../activity/presentation/activity_page.dart';
import '../../settings/presentation/add_room_device_page.dart';
import '../../settings/presentation/help/help_support_page.dart';
import '../../settings/presentation/settings_ui.dart';
import 'forget_home_page.dart';
import 'wifi_connection_detail_page.dart';

class HomeConnectionPage extends StatefulWidget {
  const HomeConnectionPage({
    super.key,
    this.onStart,
    this.connectionState,
    this.connectionMessage,
    this.repository = const PreviewHomeConnectionRepository(),
  });

  final Future<ConnectionResult> Function()? onStart;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;
  final HomeConnectionRepository repository;

  @override
  State<HomeConnectionPage> createState() => _HomeConnectionPageState();
}

class _HomeConnectionPageState extends State<HomeConnectionPage> {
  late Future<HomeConnectionOverview> _overview;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _overview = widget.repository.getOverview(
        liveState: widget.connectionState,
      );
    });
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    await widget.repository.refresh();
    _load();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return NestedSettingsScaffold(
      title: 'Connect your home',
      subtitle: 'Connect EH Home to your devices and Wi-Fi.',
      actions: [
        settingsHelpAction(
          context,
          message:
              'Connect EH Home to your devices through secure nearby setup and home Wi-Fi.',
        ),
      ],
      child: FutureBuilder<HomeConnectionOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: tokens.bluePrimary),
            );
          }
          final overview = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              _ConnectionStatusCard(
                overview: overview,
                checking: _checking,
                onRefresh: _refresh,
              ),
              if (overview.isFullyConnected) ...[
                const SizedBox(height: 24),
                const SettingsSectionTitle('CONNECTION SETUP'),
                SettingsStepperList(steps: _mapSteps(overview.setupSteps)),
                const SizedBox(height: 24),
                const SettingsSectionTitle('CONNECTED DEVICE'),
                if (overview.primaryDevice != null)
                  _ConnectedDeviceCard(device: overview.primaryDevice!),
                const SizedBox(height: 12),
                SettingsSurface(
                  child: Column(
                    children: [
                      SettingsListItem(
                        icon: Icons.wifi_rounded,
                        title: 'Home Wi-Fi',
                        subtitle: overview.wifiSsid ?? 'Home Wi-Fi',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WifiConnectionDetailPage(
                              ssid: overview.wifiSsid ?? 'Home Wi-Fi',
                            ),
                          ),
                        ),
                        showDivider: true,
                      ),
                      SettingsListItem(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Change Wi-Fi network',
                        subtitle: 'Switch your home network',
                        iconColor: tokens.isDark
                            ? tokens.bluePrimary
                            : SettingsColors.purple,
                        iconBackground: tokens.isDark
                            ? tokens.iconBgBlue
                            : SettingsColors.palePurple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddRoomDevicePage(
                              repository: const PreviewSettingsRepository(),
                              onStartSecureSetup: widget.onStart,
                              connectionState: widget.connectionState,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                SettingsStepperList(steps: _mapSteps(overview.setupSteps)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddRoomDevicePage(
                          repository: const PreviewSettingsRepository(),
                          onStartSecureSetup: widget.onStart,
                          connectionState: widget.connectionState,
                        ),
                      ),
                    ),
                    child: const Text('Connect your home'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SettingsInfoBanner(
                title: 'Having trouble?',
                subtitle:
                    'Get help with connection issues and troubleshooting.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HelpSupportPage(initialTopic: 'connection'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SettingsDestructiveActionBanner(
                title: 'Forget this home',
                subtitle: 'Remove this home and reset connection settings.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgetHomePage()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<SettingsStepData> _mapSteps(List<SetupStep> steps) => steps
      .map(
        (s) => SettingsStepData(
          index: s.index,
          title: s.title,
          subtitle: s.subtitle,
          status: switch (s.status) {
            SetupStepStatus.completed => SettingsStepVisual.completed,
            SetupStepStatus.active => SettingsStepVisual.active,
            SetupStepStatus.failed => SettingsStepVisual.failed,
            SetupStepStatus.pending => SettingsStepVisual.pending,
          },
        ),
      )
      .toList();
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.overview,
    required this.checking,
    required this.onRefresh,
  });

  final HomeConnectionOverview overview;
  final bool checking;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final connected = overview.isFullyConnected;
    return SettingsHeroCard(
      leading: settingsHeroIcon(
        icon: connected ? Icons.home_rounded : Icons.home_outlined,
        color: connected ? tokens.success : tokens.bluePrimary,
        background: connected ? tokens.successContainer : tokens.blueSelectedBg,
      ),
      title: overview.title,
      subtitle: overview.subtitle,
      statusChip: SettingsStatusChip(
        label: overview.statusLabel,
        color: connected ? tokens.success : tokens.warning,
        background: connected
            ? tokens.successContainer
            : tokens.warningContainer,
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: connected ? tokens.success : tokens.warning,
            shape: BoxShape.circle,
          ),
        ),
      ),
      footer: connected
          ? SettingsMetricRow(
              metrics: overview.layers
                  .map(
                    (layer) => SettingsMetricItem(
                      icon: _layerIcon(layer.kind),
                      label: layer.label,
                      value: layer.statusLabel,
                      iconColor:
                          layer.status == ConnectionLayerStatus.connected ||
                              layer.status == ConnectionLayerStatus.ready
                          ? tokens.success
                          : tokens.textSecondary,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  IconData _layerIcon(ConnectionLayerKind kind) => switch (kind) {
    ConnectionLayerKind.bluetooth => Icons.bluetooth_rounded,
    ConnectionLayerKind.homeWifi => Icons.wifi_rounded,
    ConnectionLayerKind.havenService => Icons.cloud_rounded,
  };
}

class _ConnectedDeviceCard extends StatelessWidget {
  const _ConnectedDeviceCard({required this.device});
  final ConnectedDeviceSummary device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceDetailPage(
              device: ActivityDeviceSnapshot(
                id: device.id,
                name: device.name,
                room: device.roomName,
                connection: device.online
                    ? ActivityDeviceConnection.online
                    : ActivityDeviceConnection.offline,
                lastSeen: DateTime.now(),
                lastReading: 'Online',
              ),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.iconBgWater,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.water_drop_outlined,
                      color: tokens.iconFgWater,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          device.id,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SettingsStatusChip(
                    label: device.online ? 'Online' : 'Offline',
                    color: device.online ? tokens.success : tokens.warning,
                    background: device.online
                        ? tokens.successContainer
                        : tokens.warningContainer,
                    leading: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: device.online ? tokens.success : tokens.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.chevron),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: tokens.borderSubtle),
              ),
              SettingsMetricRow(
                metrics: [
                  SettingsMetricItem(
                    icon: Icons.memory_rounded,
                    label: 'Model',
                    value: device.model,
                  ),
                  SettingsMetricItem(
                    icon: Icons.system_update_alt_rounded,
                    label: 'Firmware',
                    value: device.firmware,
                  ),
                  SettingsMetricItem(
                    icon: Icons.wifi_rounded,
                    label: 'Connected via',
                    value: 'Wi-Fi',
                  ),
                  SettingsMetricItem(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: 'Signal',
                    value: device.signalLabel,
                    iconColor: tokens.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible export name.
typedef ConnectionPage = HomeConnectionPage;
