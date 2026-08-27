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
      ],
    ),
  );
}
