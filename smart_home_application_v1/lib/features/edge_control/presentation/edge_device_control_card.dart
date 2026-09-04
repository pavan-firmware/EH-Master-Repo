import 'package:flutter/material.dart';
import '../../../core/models/edge_control_models.dart';
import '../../../core/theme/app_theme.dart';

/// Interactive Device Control Card with deterministic state feedback:
/// Pending -> Confirmed -> Failed -> Offline.
/// Physical hardware state is authoritative.
class EdgeDeviceControlCard extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  final String roomName;
  final bool isOn;
  final EdgeDeviceControlStatus controlStatus;
  final ExecutionRouteMode routeMode;
  final double? lastLatencyMs;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onRetry;

  const EdgeDeviceControlCard({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.roomName = 'Living Room',
    required this.isOn,
    this.controlStatus = EdgeDeviceControlStatus.idle,
    this.routeMode = ExecutionRouteMode.local,
    this.lastLatencyMs,
    this.onToggle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final isOffline = controlStatus == EdgeDeviceControlStatus.offline;
    final isPending = controlStatus == EdgeDeviceControlStatus.pending;
    final isFailed = controlStatus == EdgeDeviceControlStatus.failed;
    final isConfirmed = controlStatus == EdgeDeviceControlStatus.confirmed;

    Color borderColor = tokens.borderSubtle;
    if (isPending) {
      borderColor = tokens.bluePrimary.withValues(alpha: 0.6);
    } else if (isConfirmed) {
      borderColor = tokens.success.withValues(alpha: 0.8);
    } else if (isFailed) {
      borderColor = tokens.error.withValues(alpha: 0.8);
    }

    return Container(
      decoration: BoxDecoration(
        color: isOffline ? tokens.surfaceCard.withValues(alpha: 0.5) : tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isConfirmed || isPending ? 1.5 : 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOn ? tokens.bluePrimary.withValues(alpha: 0.15) : tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                  color: isOn ? tokens.bluePrimary : tokens.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isOffline ? tokens.textSecondary : tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roomName,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // State Switch or Retry
              if (isFailed && onRetry != null)
                IconButton(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh_rounded, color: tokens.error),
                  tooltip: 'Retry local command',
                )
              else if (isPending)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.bluePrimary),
                  ),
                )
              else
                Switch.adaptive(
                  value: isOn,
                  onChanged: isOffline ? null : onToggle,
                  activeTrackColor: tokens.bluePrimary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(context, controlStatus, tokens),
              Row(
                children: [
                  Icon(
                    routeMode == ExecutionRouteMode.local ? Icons.wifi_rounded : Icons.cloud_done_rounded,
                    size: 12,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    routeMode == ExecutionRouteMode.local ? 'Local' : 'Cloud',
                    style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                  ),
                  if (lastLatencyMs != null && lastLatencyMs! > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ${lastLatencyMs!.toStringAsFixed(0)}ms',
                      style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    EdgeDeviceControlStatus status,
    EHThemeTokens tokens,
  ) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case EdgeDeviceControlStatus.idle:
        color = tokens.textSecondary;
        icon = Icons.check_circle_outline_rounded;
        text = 'Ready';
        break;
      case EdgeDeviceControlStatus.pending:
        color = tokens.bluePrimary;
        icon = Icons.sync_rounded;
        text = 'Verifying hardware...';
        break;
      case EdgeDeviceControlStatus.confirmed:
        color = tokens.success;
        icon = Icons.verified_rounded;
        text = 'Confirmed';
        break;
      case EdgeDeviceControlStatus.failed:
        color = tokens.error;
        icon = Icons.error_outline_rounded;
        text = 'Command Failed';
        break;
      case EdgeDeviceControlStatus.offline:
        color = tokens.warning;
        icon = Icons.signal_wifi_connected_no_internet_4_rounded;
        text = 'Device Unreachable';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
