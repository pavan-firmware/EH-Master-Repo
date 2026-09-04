import 'package:flutter/material.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/theme/app_theme.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onAction,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final ValueChanged<NotificationItem>? onAction;

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.deviceOffline:
        return Icons.cloud_off_rounded;
      case NotificationType.deviceRecovered:
        return Icons.cloud_done_rounded;
      case NotificationType.commandFailed:
        return Icons.error_outline_rounded;
      case NotificationType.automationExecuted:
      case NotificationType.automationFailed:
      case NotificationType.sceneFailed:
      case NotificationType.scheduleFailed:
        return Icons.smart_toy_outlined;
      case NotificationType.otaAvailable:
      case NotificationType.otaStarted:
      case NotificationType.otaSuccess:
      case NotificationType.otaFailed:
      case NotificationType.otaRolledBack:
        return Icons.system_update_rounded;
      case NotificationType.energyHigh:
      case NotificationType.energyThresholdExceeded:
      case NotificationType.unusualEnergyUsage:
        return Icons.bolt_rounded;
      case NotificationType.matterConnected:
      case NotificationType.matterDisconnected:
      case NotificationType.matterCommissioningFailed:
        return Icons.hub_rounded;
      case NotificationType.securityAlert:
      case NotificationType.securityEvent:
        return Icons.security_rounded;
      case NotificationType.accountEvent:
      case NotificationType.homeMemberAdded:
        return Icons.person_outline_rounded;
      case NotificationType.deviceStateChanged:
      case NotificationType.physicalSwitchChanged:
      case NotificationType.systemEvent:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForSeverity(NotificationSeverity severity, BuildContext context) {
    final tokens = context.ehColors;
    switch (severity) {
      case NotificationSeverity.critical:
        return Colors.redAccent.shade700;
      case NotificationSeverity.error:
        return Colors.red.shade600;
      case NotificationSeverity.warning:
        return Colors.orange.shade800;
      case NotificationSeverity.notice:
        return tokens.bluePrimary;
      case NotificationSeverity.info:
        return tokens.textSecondary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _actionButtonLabel(String? actionType) {
    switch (actionType?.toUpperCase()) {
      case 'RECONNECT_DEVICE':
        return 'Reconnect Device';
      case 'ACK_ALERT':
        return 'Acknowledge';
      case 'DISMISS_ALERT':
        return 'Dismiss';
      case 'MUTE_ALERTS':
        return 'Mute Alerts';
      case 'VIEW_DEVICE':
        return 'View Device';
      case 'REVIEW_UPDATE':
        return 'Review Update';
      case 'VIEW_ENERGY':
        return 'Check Energy';
      case 'VIEW_AUTOMATION':
        return 'View Routine';
      case 'VIEW_INTEGRATIONS':
        return 'Integrations';
      case 'VIEW_SECURITY':
        return 'Review Security';
      default:
        return 'View Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final color = _getColorForSeverity(item.severity, context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? Colors.transparent : tokens.bluePrimary.withAlpha(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForType(item.type),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Aggregated count chip
                      if (item.isAggregated && item.aggregatedCount > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.aggregatedCount}x',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),

                  // Critical Alert Badge
                  if (item.isCritical) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CRITICAL SAFETY ALERT',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],

                  // Action Button
                  if (item.hasAction && onAction != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: BorderSide(color: tokens.bluePrimary.withAlpha(120)),
                      ),
                      onPressed: () => onAction!(item),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text(
                        _actionButtonLabel(item.actionType),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Unread Blue Dot
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.bluePrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
