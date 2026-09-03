import 'package:flutter/material.dart';
import '../../../core/models/connectivity_models.dart';
import '../../../core/services/connectivity_service.dart';
import 'transport_health_card.dart';
import 'transport_selector.dart';

/// Phase 26 — Device Connectivity Dashboard
///
/// Shows active transport status, connection state, latency/rssi,
/// manual reconnect button, and transport selector with fallback order.
class DeviceConnectivityPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final ConnectivityService connectivityService;

  const DeviceConnectivityPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.connectivityService,
  });

  @override
  State<DeviceConnectivityPage> createState() => _DeviceConnectivityPageState();
}

class _DeviceConnectivityPageState extends State<DeviceConnectivityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.connectivityService.loadDeviceConnection(widget.deviceId);
      widget.connectivityService.loadDeviceTransports(widget.deviceId);
    });
  }

  Color _stateColor(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.connected => const Color(0xFF22C55E),
    DeviceConnectionState.connecting || DeviceConnectionState.reconnecting => const Color(0xFF3B82F6),
    DeviceConnectionState.degraded => const Color(0xFFF59E0B),
    DeviceConnectionState.disconnected || DeviceConnectionState.failed => const Color(0xFFEF4444),
    _ => const Color(0xFF9CA3AF),
  };

  IconData _stateIcon(DeviceConnectionState state) => switch (state) {
    DeviceConnectionState.connected => Icons.link_rounded,
    DeviceConnectionState.connecting || DeviceConnectionState.reconnecting => Icons.sync_rounded,
    DeviceConnectionState.degraded => Icons.link_off_rounded,
    DeviceConnectionState.disconnected || DeviceConnectionState.failed => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };

  Future<void> _handleReconnect() async {
    final success = await widget.connectivityService.triggerReconnect(widget.deviceId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Reconnect signal sent' : 'Reconnect failed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSelectTransport(DeviceTransportType transport) async {
    final success = await widget.connectivityService.selectTransport(widget.deviceId, transport);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Active transport switched to ${transport.toDisplayLabel()}' : 'Transport switch failed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deviceName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Connectivity',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => widget.connectivityService.loadDeviceConnection(widget.deviceId),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.connectivityService,
        builder: (context, _) {
          final svc = widget.connectivityService;
          if (svc.loading && svc.deviceConnection == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final conn = svc.deviceConnection;
          if (conn == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No connection data found', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => svc.loadDeviceConnection(widget.deviceId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final stateColor = _stateColor(conn.connectionState);

          return RefreshIndicator(
            onRefresh: () async {
              await svc.loadDeviceConnection(widget.deviceId);
              await svc.loadDeviceTransports(widget.deviceId);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Active Connection Hero ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: stateColor.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_stateIcon(conn.connectionState), color: stateColor, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conn.connectionState.toDisplayLabel(),
                                  style: TextStyle(color: stateColor, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Active Transport: ${conn.activeTransport.toDisplayLabel()}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleReconnect,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Reconnect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Switch Active Transport ───────────────────────────
                Text(
                  'Active Transport Selection',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select the primary transport protocol for command dispatch.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TransportSelector(
                  availableTransports: conn.supportedTransports,
                  selectedTransport: conn.activeTransport,
                  onTransportSelected: _handleSelectTransport,
                ),
                const SizedBox(height: 24),

                // ── Transport Health Snapshots ────────────────────────
                Text(
                  'Protocol Health Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...conn.transportHealth.values.map(
                  (health) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TransportHealthCard(
                      health: health,
                      isActive: health.transportType == conn.activeTransport,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
