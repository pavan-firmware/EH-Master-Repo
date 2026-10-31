import 'package:flutter/material.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';

class AllAlertsSheet extends StatelessWidget {
  const AllAlertsSheet({
    super.key,
    required this.alerts,
    required this.onSelectAlert,
    this.onClearAll,
    this.onDismissAlert,
  });

  final List<SpaceAlertItem> alerts;
  final ValueChanged<SpaceAlertItem> onSelectAlert;
  final VoidCallback? onClearAll;
  final ValueChanged<SpaceAlertItem>? onDismissAlert;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: tokens.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Alerts',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${alerts.length} alert${alerts.length == 1 ? '' : 's'} across all spaces',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (alerts.isNotEmpty && onClearAll != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onClearAll?.call();
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 18, color: Colors.redAccent),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: tokens.success, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'All Spaces Normal',
                          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No active alerts or sensor warnings across your spaces.',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = alerts[index];
                      final isCritical = item.severity == AlertSeverity.critical;
                      final isWarning = item.severity == AlertSeverity.warning;
                      final accentColor = isCritical
                          ? Colors.redAccent
                          : (isWarning ? Colors.amber.shade700 : tokens.bluePrimary);

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectAlert(item);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? (tokens.isDark ? const Color(0xFF2A1215) : const Color(0xFFFFECEB))
                                : tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCritical ? Colors.redAccent.withValues(alpha: 0.7) : tokens.borderSubtle,
                              width: isCritical ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCritical
                                      ? Icons.crisis_alert_rounded
                                      : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tokens.surfaceElevated,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.spaceName,
                                            style: TextStyle(
                                              color: tokens.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(item.timestamp),
                                          style: TextStyle(
                                            color: tokens.textSecondary.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.message,
                                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (onDismissAlert != null)
                                IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: tokens.textSecondary),
                                  onPressed: () => onDismissAlert?.call(item),
                                  tooltip: 'Dismiss alert',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Icon(Icons.chevron_right_rounded, color: tokens.textSecondary, size: 20),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
