import 'package:flutter/material.dart';
import '../../../app/home_controller.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/connectivity_models.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import 'transport_health_card.dart';
import 'transport_selector.dart';

extension on Iterable<ConnectedDeviceSummary> {
  ConnectedDeviceSummary? findDevice(String id) {
    for (final d in this) {
      if (d.id == id) return d;
    }
    return null;
  }
}

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
  late String _currentDeviceId;
  late String _currentDeviceName;

  @override
  void initState() {
    super.initState();
    _currentDeviceId = widget.deviceId;
    _currentDeviceName = widget.deviceName;

    if (_currentDeviceId.isEmpty) {
      final first = HomeController.instance?.devices.firstOrNull;
      if (first != null) {
        _currentDeviceId = first.id;
        _currentDeviceName = first.name;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentDevice();
    });
  }

  void _loadCurrentDevice() {
    if (_currentDeviceId.isNotEmpty) {
      widget.connectivityService.loadDeviceConnection(_currentDeviceId);
      widget.connectivityService.loadDeviceTransports(_currentDeviceId);
    }
  }

  void _onDeviceChanged(String newId, String newName) {
    setState(() {
      _currentDeviceId = newId;
      _currentDeviceName = newName;
    });
    _loadCurrentDevice();
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
    final success = await widget.connectivityService.triggerReconnect(_currentDeviceId);
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
    final success = await widget.connectivityService.selectTransport(_currentDeviceId, transport);
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
    final tokens = context.ehColors;
    final ctrl = HomeController.instance;
    final allDevices = ctrl?.devices ?? [];

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: BackButton(color: tokens.headerAction),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentDeviceName,
              style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 16),
            ),
            Text(
              'Connectivity',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tokens.headerAction),
            onPressed: _loadCurrentDevice,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.connectivityService,
        builder: (context, _) {
          final svc = widget.connectivityService;
          if (svc.loading && svc.deviceConnection == null) {
            return Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(tokens.bluePrimary)));
          }

          final conn = svc.deviceConnection;
          if (conn == null) {
            final activeDev = allDevices.findDevice(_currentDeviceId);
            final isLan = activeDev != null && activeDev.online;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (allDevices.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentDeviceId.isNotEmpty && allDevices.any((d) => d.id == _currentDeviceId)
                                ? _currentDeviceId
                                : allDevices.first.id,
                            dropdownColor: tokens.surfaceElevated,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.headerAction),
                            items: allDevices.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  '${d.name} (${d.roomName.isNotEmpty ? d.roomName : "Home"})',
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final match = allDevices.findDevice(val);
                                if (match != null) {
                                  _onDeviceChanged(match.id, match.name);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Icon(
                      isLan ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                      size: 56,
                      color: isLan ? tokens.bluePrimary : tokens.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isLan ? 'Local Direct Wi-Fi Active' : 'No Telemetry Found',
                      style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLan
                          ? '$_currentDeviceName is operating via Direct LAN Wi-Fi. Multi-protocol gateway telemetry will be synchronized when cloud broker is connected.'
                          : 'No protocol telemetry reported for $_currentDeviceName. Ensure the device is powered on and connected to your local network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadCurrentDevice,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Probe Device Protocols'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: tokens.buttonText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final stateColor = _stateColor(conn.connectionState);

          return RefreshIndicator(
            onRefresh: () async {
              await svc.loadDeviceConnection(_currentDeviceId);
              await svc.loadDeviceTransports(_currentDeviceId);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (allDevices.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentDeviceId.isNotEmpty && allDevices.any((d) => d.id == _currentDeviceId)
                            ? _currentDeviceId
                            : allDevices.first.id,
                        dropdownColor: tokens.surfaceElevated,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.headerAction),
                        items: allDevices.map((d) {
                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(
                              '${d.name} (${d.roomName.isNotEmpty ? d.roomName : "Home"})',
                              style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = allDevices.findDevice(val);
                            if (match != null) {
                              _onDeviceChanged(match.id, match.name);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Active Connection Hero ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCard,
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
                                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
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
                              icon: Icon(Icons.sync_rounded, size: 16, color: tokens.bluePrimary),
                              label: Text('Reconnect', style: TextStyle(color: tokens.bluePrimary)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: tokens.borderControl),
                              ),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select the primary transport protocol for command dispatch.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary, fontSize: 16),
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
