import 'package:flutter/material.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';

class OtherSpacesDevicesSheet extends StatelessWidget {
  const OtherSpacesDevicesSheet({
    super.key,
    required this.summaries,
    required this.onSwitchSpace,
  });

  final List<SpaceOnSummary> summaries;
  final ValueChanged<String> onSwitchSpace;

  IconData _resolveIcon(String key) {
    return switch (key) {
      'business' => Icons.business_rounded,
      'storefront' => Icons.storefront_rounded,
      'cottage' => Icons.cottage_rounded,
      'warehouse' => Icons.warehouse_rounded,
      'apartment' => Icons.apartment_rounded,
      _ => Icons.home_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final totalOn = summaries.fold<int>(0, (sum, s) => sum + s.devicesOnCount);

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
                  color: tokens.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: tokens.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Devices ON in Other Spaces',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$totalOn devices active across other places',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: summaries.isEmpty
                ? Center(
                    child: Text(
                      'No other spaces created yet.\nAdd an Office or Shop from the space menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: summaries.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = summaries[index];
                      final hasOn = s.devicesOnCount > 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasOn
                                ? Colors.amber.withValues(alpha: 0.4)
                                : tokens.borderSubtle,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _resolveIcon(s.icon),
                                    color: tokens.bluePrimary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.spaceName,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasOn
                                            ? '${s.devicesOnCount} device${s.devicesOnCount == 1 ? '' : 's'} running'
                                            : 'All devices standby / off',
                                        style: TextStyle(
                                          color: hasOn ? Colors.amber : tokens.textSecondary,
                                          fontSize: 12,
                                          fontWeight: hasOn ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    onSwitchSpace(s.spaceId);
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Go to Space', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            if (s.onDeviceNames.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Divider(color: tokens.borderSubtle, height: 1),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: s.onDeviceNames.map((name) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.greenAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
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
