import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/privacy_models.dart';
import '../settings_ui.dart';

class PrivacyPermissionDetailPage extends StatelessWidget {
  const PrivacyPermissionDetailPage({super.key, required this.permission});

  final PrivacyPermission permission;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: permission.title,
    subtitle: permission.description,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsSurface(
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: const Text('Current status'),
              trailing: Text(
                permission.statusLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: permission.status == PrivacyPermissionStatus.allowed
                      ? SettingsColors.green
                      : SettingsColors.muted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: openAppSettings,
            child: const Text('Open system settings'),
          ),
        ),
      ],
    ),
  );
}
