import 'package:flutter/material.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';

class AllAlertsSheet extends StatelessWidget {
  const AllAlertsSheet({
    super.key,
    required this.alerts,
    required this.onSelectAlert,
  });

  final List<SpaceAlertItem> alerts;
  final ValueChanged<SpaceAlertItem> onSelectAlert;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                width: 36,
                height: 36,
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
            ],
          ),
          const SizedBox(height: 18),
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

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectAlert(item);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? (tokens.isDark ? const Color(0xFF2A1215) : const Color(0xFFFFECEB))
                                : tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCritical ? Colors.redAccent : tokens.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCritical ? Icons.error_rounded : Icons.warning_amber_rounded,
                                color: isCritical ? Colors.redAccent : Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
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
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: tokens.textSecondary, size: 22),
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
