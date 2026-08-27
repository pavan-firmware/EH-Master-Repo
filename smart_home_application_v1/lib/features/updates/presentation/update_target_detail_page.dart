import 'package:flutter/material.dart';

import '../../../core/models/update_models.dart';
import '../../settings/presentation/settings_ui.dart';

class UpdateTargetDetailPage extends StatelessWidget {
  const UpdateTargetDetailPage({super.key, required this.target});

  final UpdateTarget target;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: target.name,
    subtitle: target.currentVersion,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsHeroCard(
          leading: const SettingsIconBadge(
            icon: Icons.system_update_alt_rounded,
            size: 44,
          ),
          title: target.statusLabel,
          subtitle:
              target.statusDetail ??
              'This component is running the latest available version.',
          statusChip: SettingsStatusChip(
            label: target.statusLabel,
            color: SettingsColors.green,
            background: SettingsColors.paleGreen,
          ),
        ),
        const SizedBox(height: 16),
        const SettingsInfoBanner(
          title: 'Preview build',
          subtitle:
              'Device firmware updates become available after your home is securely connected.',
        ),
      ],
    ),
  );
}
