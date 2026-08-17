import 'package:flutter/material.dart';

import '../../../connection/presentation/home_connection_page.dart';
import '../settings_ui.dart';
import '../add_room_device_page.dart';
import '../../../../core/repositories/settings_repository.dart';
class FactoryResetResultPage extends StatelessWidget {
  const FactoryResetResultPage({
    super.key,
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: success ? 'Reset complete' : 'Reset failed',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsHeroCard(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: success ? SettingsColors.paleGreen : SettingsColors.paleOrange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.error_outline_rounded,
              color: success ? SettingsColors.green : SettingsColors.orange,
              size: 28,
            ),
          ),
          title: success ? 'Device reset verified' : 'Reset could not be verified',
          subtitle: message,
        ),
        const SizedBox(height: 20),
        if (success) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => AddRoomDevicePage(repository: const PreviewSettingsRepository()),
                ),
                (route) => route.isFirst,
              ),
              child: const Text('Set up device again'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeConnectionPage()),
                (route) => route.isFirst,
              ),
              child: const Text('Connect your home'),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try again'),
            ),
          ),
      ],
    ),
  );
}
