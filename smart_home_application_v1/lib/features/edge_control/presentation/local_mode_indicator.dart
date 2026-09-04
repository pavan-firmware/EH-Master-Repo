import 'package:flutter/material.dart';
import '../../../core/models/edge_control_models.dart';
import '../../../core/theme/app_theme.dart';

/// Subtle consumer-friendly connectivity status badge.
/// Displays 'Local', 'Cloud', or 'Offline' with clean indicators.
class LocalModeIndicator extends StatelessWidget {
  final ExecutionRouteMode routeMode;
  final bool isLocalNetworkActive;
  final double? avgLatencyMs;
  final VoidCallback? onTap;

  const LocalModeIndicator({
    super.key,
    required this.routeMode,
    this.isLocalNetworkActive = true,
    this.avgLatencyMs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final Color badgeColor;
    final Color badgeBg;
    final IconData badgeIcon;
    final String labelText;

    switch (routeMode) {
      case ExecutionRouteMode.local:
        badgeColor = tokens.success;
        badgeBg = tokens.successContainer;
        badgeIcon = Icons.wifi_rounded;
        labelText = 'Local Fast';
        break;
      case ExecutionRouteMode.cloud:
        badgeColor = tokens.bluePrimary;
        badgeBg = tokens.surfaceElevated;
        badgeIcon = Icons.cloud_done_rounded;
        labelText = 'Cloud Sync';
        break;
      case ExecutionRouteMode.deferred:
        badgeColor = tokens.warning;
        badgeBg = tokens.warningContainer;
        badgeIcon = Icons.schedule_send_rounded;
        labelText = 'Queued';
        break;
      case ExecutionRouteMode.unavailable:
        badgeColor = tokens.error;
        badgeBg = tokens.errorContainer;
        badgeIcon = Icons.cloud_off_rounded;
        labelText = 'Offline';
        break;
    }

    return InkWell(
      onTap: onTap ?? () => _showConnectivitySheet(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(badgeIcon, size: 13, color: badgeColor),
            const SizedBox(width: 4),
            Text(
              labelText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
                letterSpacing: 0.2,
              ),
            ),
            if (avgLatencyMs != null && avgLatencyMs! > 0 && routeMode == ExecutionRouteMode.local) ...[
              const SizedBox(width: 4),
              Text(
                '${avgLatencyMs!.toStringAsFixed(0)}ms',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showConnectivitySheet(BuildContext context) {
    final tokens = context.ehColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_rounded, color: tokens.bluePrimary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Home Network Execution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              routeMode == ExecutionRouteMode.local
                  ? 'Your devices are responding directly over your secure local network. In-home control continues seamlessly even if Internet access drops.'
                  : 'Your commands are securely synchronized via the EH Cloud for remote access.',
              style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricPill(
                  context,
                  label: 'Routing Mode',
                  value: routeMode.toDisplayLabel(),
                  color: tokens.success,
                ),
                _buildMetricPill(
                  context,
                  label: 'Local Latency',
                  value: avgLatencyMs != null ? '${avgLatencyMs!.toStringAsFixed(1)} ms' : '< 20 ms',
                  color: tokens.bluePrimary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final tokens = context.ehColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
