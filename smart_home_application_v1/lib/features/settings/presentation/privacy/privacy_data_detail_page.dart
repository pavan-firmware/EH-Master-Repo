import 'package:flutter/material.dart';

import '../../../../core/models/privacy_models.dart';
import '../settings_ui.dart';

class PrivacyDataDetailPage extends StatelessWidget {
  const PrivacyDataDetailPage({super.key, required this.category});

  final PrivacyDataCategory category;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: category.title,
    subtitle: category.subtitle,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(category.summary, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 20),
        const Text(
          'WHAT WE STORE',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: SettingsColors.muted,
          ),
        ),
        const SizedBox(height: 10),
        SettingsCheckList(items: category.details),
        const SizedBox(height: 20),
        const Text(
          'WHY WE USE IT',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: SettingsColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(category.whyWeUseIt, style: const TextStyle(height: 1.4)),
        if (category.storageLabel != null) ...[
          const SizedBox(height: 16),
          SettingsSurface(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('Storage'),
                subtitle: Text(category.storageLabel!),
              ),
            ),
          ),
        ],
        if (category.retentionLabel != null) ...[
          const SizedBox(height: 12),
          SettingsSurface(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('Retention'),
                subtitle: Text(category.retentionLabel!),
              ),
            ),
          ),
        ],
        if (category.kind == PrivacyDataCategoryKind.activityHistory) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
            label: const Text('Clear Local Activity Cache', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Local Activity Cache?'),
                  content: const Text(
                    'This will remove cached operational timeline events from this device. '
                    'Central platform audit logs will remain intact according to retention policies.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear Cache'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local activity cache cleared.')),
                );
              }
            },
          ),
        ],
      ],
    ),
  );
}
