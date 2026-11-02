import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../settings_ui.dart';

class PrivacyLegalPage extends StatelessWidget {
  const PrivacyLegalPage({super.key, required this.title, required this.kind});

  final String title;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return NestedSettingsScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            _body(kind),
            style: TextStyle(height: 1.5, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }

  String _body(String kind) => switch (kind) {
    'security' =>
      'EH Home employs hardware-backed cryptographic identity verification (fact_v2), secure mTLS-encrypted transport on MQTT port 8883, and end-to-end tokenized authentication for all cloud and local operations. Device credentials and cryptographic secrets are protected within isolated hardware partitions, and all firmware images are cryptographically signed with anti-rollback verification.',
    'privacy' =>
      'Your privacy is fundamental to EH Home. Personal information, device telemetry, and occupancy states are stored securely and never sold or shared with third parties. Telemetry data from energy sensors (BL0942) and switch relays is processed strictly to deliver real-time monitoring and automation schedules for your home.',
    'terms' =>
      'By using EH Home services and hardware, you agree to operate connected electrical devices in accordance with rated electrical specifications and safety guidelines. EH Home provides local-first reliability, ensuring essential switch operations continue even when internet connectivity is interrupted. Users are responsible for maintaining secure Wi-Fi networks and authorized access to their home credentials.',
    _ =>
      'EH Home collects only the telemetry and configuration data necessary to provide reliable smart home automation. All communication adheres to least-privilege access models and industry-standard security protocols.',
  };
}
