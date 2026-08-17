import 'package:flutter/material.dart';

import '../../settings/presentation/settings_ui.dart';

class ForgetHomePage extends StatelessWidget {
  const ForgetHomePage({super.key});

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Forget this home',
    subtitle: 'Remove this home from this phone.',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        const SettingsDestructiveBanner(
          title: 'This removes local home access',
          body: 'Your EH account and other devices are not deleted. You can set up this home again later.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SettingsColors.red),
            onPressed: () {
              Navigator.pop(context);
              showSettingsUnavailable(
                context,
                message: 'Forget home requires owner confirmation in a connected build.',
              );
            },
            child: const Text('Forget this home'),
          ),
        ),
      ],
    ),
  );
}
