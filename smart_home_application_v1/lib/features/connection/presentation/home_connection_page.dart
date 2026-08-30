import 'package:flutter/material.dart';

import '../../../core/models/connection_models.dart';
import '../../../core/models/device_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/home_connection_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/ble/ble_commissioning_channel.dart';
import '../../settings/presentation/help/help_support_page.dart';
import '../../settings/presentation/settings_ui.dart';
import 'device_provisioning_page.dart';
import 'forget_home_page.dart';
import 'wifi_connection_detail_page.dart';

class HomeConnectionPage extends StatefulWidget {
  const HomeConnectionPage({
    super.key,
    this.onStart,
    this.connectionState,
    this.connectionMessage,
    this.repository = const RealHomeConnectionRepository(),
    this.onDeviceProvisioned,
  });

  final Future<ConnectionResult> Function()? onStart;
  final HomeConnectionState? connectionState;
  final String? connectionMessage;
  final HomeConnectionRepository repository;
  final void Function({
    required String deviceId,
    required String displayName,
    required String serialNumber,
    String? roomName,
  })?
  onDeviceProvisioned;

  @override
  State<HomeConnectionPage> createState() => _HomeConnectionPageState();
}

class _HomeConnectionPageState extends State<HomeConnectionPage> {
  late Future<HomeConnectionOverview> _overview;
  bool _checking = false;
  bool _inProgress = false;
  String? _activeStatus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeConnectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connectionState != oldWidget.connectionState ||
        widget.connectionMessage != oldWidget.connectionMessage) {
      _load();
    }
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

  String _mapErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('gatt_err_unlikely') ||
        lower.contains('writecharacteristicfailure') ||
        lower.contains('status 14')) {
      return "Couldn't send secure setup data. Make sure the device is close and powered on.";
    }
    if (lower.contains('no nearby') ||
        lower.contains('not found') ||
        lower.contains('scantimedout')) {
      return "No nearby Smart Home device was found. Make sure it is powered on and close to your phone.";
    }
    if (lower.contains('disconnected') || lower.contains('timeout')) {
      return "The device disconnected or took too long to connect. Keep it nearby and try again.";
    }
    if (lower.contains('permission')) {
      return "Bluetooth and Location permissions are required to discover nearby devices.";
    }
    return error
        .replaceFirst('Exception: ', '')
        .replaceFirst('Connection failed: ', '')
        .replaceFirst('Nearby connection failed: ', '');
  }

  Future<void> _handleConnect() async {
    if (widget.onStart == null || _inProgress) return;

    setState(() {
      _inProgress = true;
      _errorMessage = null;
      _activeStatus = 'Searching for nearby EH Home devices...';
    });

    final navigator = Navigator.of(context);
    try {
      final result = await widget.onStart!();
      if (!mounted) return;

      if (result.success) {
        setState(() {
          _inProgress = false;
          _activeStatus = null;
        });
        navigator.push(
          MaterialPageRoute(
            builder: (_) => DeviceProvisioningPage(
              deviceName:
                  result.displayName ??
                  (result.message.contains('Connected to ')
                      ? result.message
                            .replaceFirst('Connected to ', '')
                            .split(' (')
                            .first
                      : 'EH Smart Switch 3X'),
              deviceId: result.deviceId,
              serialNumber: result.serialNumber,
              channel: result.channel is BleCommissioningChannel
                  ? result.channel as BleCommissioningChannel
                  : null,
              onDeviceProvisioned:
                  ({
                    required String deviceId,
                    required String displayName,
                    required String serialNumber,
                    String? roomName,
                  }) {
                    widget.onDeviceProvisioned?.call(
                      deviceId: deviceId,
                      displayName: displayName,
                      serialNumber: serialNumber,
                      roomName: roomName,
                    );
                    if (mounted) {
                      _load();
                    }
                  },
            ),
          ),
        );
      } else {
        setState(() {
          _inProgress = false;
          _activeStatus = null;
          _errorMessage = _mapErrorMessage(result.message);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inProgress = false;
        _activeStatus = null;
        _errorMessage = _mapErrorMessage(e.toString());
      });
    }
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
              if (_inProgress) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokens.bluePrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: tokens.bluePrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _activeStatus ?? 'Connecting to nearby device...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.isDark
                        ? const Color(0xFF331A1A)
                        : const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokens.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: tokens.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connection Incomplete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tokens.isDark
                                  ? Colors.white
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: tokens.isDark
                              ? const Color(0xFFFCA5A5)
                              : tokens.errorText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                            builder: (_) => DeviceProvisioningPage(
                              deviceName:
                                  overview.primaryDevice?.name ??
                                  'EH Smart Switch 3X',
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
                      backgroundColor: tokens.blueDarker,
                    ),
                    onPressed: _inProgress ? null : _handleConnect,
                    child: Text(
                      _inProgress
                          ? 'Connecting...'
                          : (_errorMessage != null
                                ? 'Try Again'
                                : 'Connect your home'),
                    ),
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

  static List<SettingsStepData> _mapSteps(List<SetupStep> steps) => steps
      .map(
        (step) => SettingsStepData(
          index: step.index,
          title: step.title,
          subtitle: step.subtitle,
          status: _toUiStatus(step.status),
        ),
      )
      .toList();

  static SettingsStepVisual _toUiStatus(SetupStepStatus status) {
    switch (status) {
      case SetupStepStatus.completed:
        return SettingsStepVisual.completed;
      case SetupStepStatus.active:
        return SettingsStepVisual.active;
      case SetupStepStatus.pending:
        return SettingsStepVisual.pending;
      case SetupStepStatus.failed:
        return SettingsStepVisual.failed;
    }
  }
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
    final isConnected = overview.isFullyConnected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isConnected
                      ? (tokens.isDark
                            ? tokens.iconBgGreen
                            : SettingsColors.paleGreen)
                      : (tokens.isDark
                            ? tokens.iconBgBlue
                            : const Color(0xFFE0E7FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected
                      ? Icons.check_circle_rounded
                      : Icons.bluetooth_searching_rounded,
                  color: isConnected ? tokens.success : tokens.bluePrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overview.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.isDark
                            ? tokens.textSecondary
                            : SettingsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: ${overview.statusLabel}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isConnected ? tokens.success : tokens.textPrimary,
                ),
              ),
              IconButton(
                onPressed: checking ? null : onRefresh,
                icon: checking
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.bluePrimary,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: tokens.bluePrimary,
                        size: 20,
                      ),
                tooltip: 'Refresh status',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  const _ConnectedDeviceCard({required this.device});

  final ConnectedDeviceSummary device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.isDark
                    ? tokens.iconBgBlue
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.toggle_on_rounded,
                color: tokens.bluePrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.roomName} • ${device.connectedVia}',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.isDark
                          ? tokens.textSecondary
                          : SettingsColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.isDark
                    ? tokens.iconBgGreen
                    : SettingsColors.paleGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Online',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
