import 'package:flutter/material.dart';

import '../../settings/presentation/settings_ui.dart';

class WifiConnectionDetailPage extends StatelessWidget {
  const WifiConnectionDetailPage({super.key, required this.ssid});

  final String ssid;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Home Wi-Fi',
    subtitle: 'Your current home network connection.',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsSurface(
          child: Column(
            children: [
              _Line(label: 'Network', value: ssid),
              const Divider(height: 1, color: SettingsColors.line),
              const _Line(label: 'Band', value: '2.4 GHz'),
              const Divider(height: 1, color: SettingsColors.line),
              const _Line(label: 'Signal', value: 'Strong'),
              const Divider(height: 1, color: SettingsColors.line),
              const _Line(label: 'Status', value: 'Connected'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: SettingsColors.muted))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
