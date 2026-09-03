import 'package:flutter/material.dart';
import '../../../core/models/connectivity_models.dart';

/// Phase 26 — Transport Health Card
///
/// Reusable card displaying transport availability badge, latency metrics,
/// error rate, reconnect count, and signal strength.
class TransportHealthCard extends StatelessWidget {
  final TransportHealth health;
  final bool isActive;

  const TransportHealthCard({
    super.key,
    required this.health,
    this.isActive = false,
  });

  Color _availabilityColor(TransportAvailability a) => switch (a) {
    TransportAvailability.online => const Color(0xFF22C55E),
    TransportAvailability.degraded => const Color(0xFFF59E0B),
    TransportAvailability.unreachable => const Color(0xFFEF4444),
    TransportAvailability.unconfigured => const Color(0xFF9CA3AF),
  };

  IconData _transportIcon(DeviceTransportType t) => switch (t) {
    DeviceTransportType.wifiMqtt => Icons.wifi_rounded,
    DeviceTransportType.ble => Icons.bluetooth_rounded,
    DeviceTransportType.thread => Icons.hub_rounded,
    DeviceTransportType.matter => Icons.all_inclusive_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final availColor = _availabilityColor(health.availability);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? colorScheme.primary : availColor.withValues(alpha: 0.25),
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_transportIcon(health.transportType), size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  health.transportType.toDisplayLabel(),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(color: colorScheme.primary, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: availColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  health.availability.toDisplayLabel(),
                  style: TextStyle(color: availColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricItem(label: 'Latency', value: '${health.latencyMs.toStringAsFixed(0)} ms'),
              _MetricItem(label: 'Error Rate', value: '${(health.errorRate * 100).toStringAsFixed(1)}%'),
              _MetricItem(label: 'Reconnects', value: '${health.reconnectCount}'),
              if (health.signalRssi != null)
                _MetricItem(label: 'RSSI', value: '${health.signalRssi!.toStringAsFixed(0)} dBm'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
