import 'package:flutter/material.dart';

import '../../settings/presentation/settings_ui.dart';

class UpdatePreferencesPage extends StatelessWidget {
  const UpdatePreferencesPage({super.key});

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Update preferences',
    subtitle: 'Choose how and when updates are installed.',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsInfoBanner(
          title: 'Automatic updates unavailable',
          subtitle:
              'Automatic OTA requires secure update verification and will be enabled when supported.',
        ),
        SizedBox(height: 16),
        SettingsSurface(
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(
                'Automatic updates',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Install updates automatically when your home is idle.',
              ),
              trailing: Switch(value: false, onChanged: null),
            ),
          ),
        ),
      ],
    ),
  );
}
