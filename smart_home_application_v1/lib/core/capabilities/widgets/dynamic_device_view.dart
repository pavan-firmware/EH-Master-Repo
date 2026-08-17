import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/capability_models.dart';
import 'dynamic_channel_card.dart';
import 'energy_card.dart';

/// Full Dynamic Device Screen/View rendered purely from resolved capabilities.
/// Automatically handles channel counts (1X, 2X, 3X, etc.), global capabilities
/// (Energy), connection badges, and micro-interactions.
class DynamicDeviceView extends StatefulWidget {
  const DynamicDeviceView({
    super.key,
    required this.device,
    this.onChannelUpdated,
  });

  final ResolvedDevice device;
  final void Function(ResolvedDeviceChannel channel)? onChannelUpdated;

  @override
  State<DynamicDeviceView> createState() => _DynamicDeviceViewState();
}

class _DynamicDeviceViewState extends State<DynamicDeviceView> {
  late ResolvedDevice _currentDevice;

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device;
  }

  @override
  void didUpdateWidget(covariant DynamicDeviceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device != oldWidget.device) {
      _currentDevice = widget.device;
    }
  }

  void _handleChannelUpdated(ResolvedDeviceChannel updated) {
    setState(() {
      final updatedChannels = _currentDevice.channels.map((ch) {
        return ch.channelIndex == updated.channelIndex ? updated : ch;
      }).toList();

      _currentDevice = ResolvedDevice(
        deviceId: _currentDevice.deviceId,
        productVariantId: _currentDevice.productVariantId,
        displayName: _currentDevice.displayName,
        connectionState: _currentDevice.connectionState,
        channels: updatedChannels,
        capabilities: _currentDevice.capabilities,
        energyTelemetry: _currentDevice.energyTelemetry,
        heroImageUrl: _currentDevice.heroImageUrl,
      );
    });

    widget.onChannelUpdated?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final device = _currentDevice;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.surfaceNav,
        elevation: 0,
        title: Text(
          device.displayName,
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: device.isOnline
                  ? (tokens.isDark ? tokens.iconBgGreen : const Color(0xFFE9F7EE))
                  : (tokens.isDark ? tokens.borderControl : const Color(0xFFE0E4EC)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: device.isOnline ? tokens.success : tokens.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  device.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: device.isOnline ? tokens.success : tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Dynamic Channels Section
          Row(
            children: [
              Text(
                'Channels (${device.channels.length})',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                device.productVariantId,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...device.channels.map((channel) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DynamicChannelCard(
                channel: channel,
                onChannelUpdated: _handleChannelUpdated,
              ),
            );
          }),

          // Global Energy Capability Section (only if capability exists & telemetry is available)
          if (device.hasEnergy && device.energyTelemetry != null) ...[
            const SizedBox(height: 10),
            EnergyCard(telemetry: device.energyTelemetry!),
          ],
        ],
      ),
    );
  }
}
