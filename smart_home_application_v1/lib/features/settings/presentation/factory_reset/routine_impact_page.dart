import 'package:flutter/material.dart';

import '../settings_ui.dart';

class RoutineImpactPage extends StatelessWidget {
  const RoutineImpactPage({super.key, required this.routineNames});

  final List<String> routineNames;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Affected routines',
    subtitle: 'These routines may become unavailable after reset.',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsSurface(
          child: Column(
            children: [
              for (var i = 0; i < routineNames.length; i++)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const SettingsIconBadge(
                      icon: Icons.hub_outlined,
                      color: SettingsColors.purple,
                      background: SettingsColors.palePurple,
                      size: 40,
                    ),
                    title: Text(
                      routineNames[i],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Will become unavailable until device is set up again.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
