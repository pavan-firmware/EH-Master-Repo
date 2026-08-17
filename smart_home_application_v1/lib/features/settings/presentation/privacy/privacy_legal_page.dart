import 'package:flutter/material.dart';

import '../settings_ui.dart';

class PrivacyLegalPage extends StatelessWidget {
  const PrivacyLegalPage({super.key, required this.title, required this.kind});

  final String title;
  final String kind;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: title,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(
          _body(kind),
          style: const TextStyle(height: 1.5, color: SettingsColors.ink),
        ),
      ],
    ),
  );

  String _body(String kind) => switch (kind) {
        'security' =>
          'EH Home uses secure nearby setup, authenticated device communication, and protected local storage. Full security documentation will be published before production release.',
        'privacy' =>
          'This preview build stores home and device data locally. A full privacy policy will be available before cloud services launch.',
        'terms' =>
          'Terms of service for EH Home will be published before public release. This preview is for development and testing only.',
        _ =>
          'EH Home collects only the data needed to run your home. Diagnostic and analytics sharing remain off unless you enable them when supported.',
      };
}
