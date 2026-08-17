import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class NearbySetupPage extends StatefulWidget {
  const NearbySetupPage({super.key});
  @override
  State<NearbySetupPage> createState() => _NearbySetupPageState();
}

class _NearbySetupPageState extends State<NearbySetupPage> {
  int step = 0;
  final steps = const [
    (
      'Let’s set up your device',
      'Keep your phone close to the home device. You will need its setup QR code.',
      Icons.qr_code_scanner_rounded,
    ),
    (
      'Allow nearby access',
      'This lets your phone find and securely connect to your home device. You can change this later in phone settings.',
      Icons.near_me_outlined,
    ),
    (
      'Connect your home',
      'Choose your Wi-Fi, then we will check that your room device is ready.',
      Icons.wifi_rounded,
    ),
    (
      'You’re all set',
      'Your device is connected and ready to use.',
      Icons.check_circle_outline_rounded,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final current = steps[step];
    final last = step == steps.length - 1;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: tokens.headerAction),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (step + 1) / steps.length,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: tokens.isDark ? tokens.borderControl : null,
                valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
              ),
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: tokens.iconBgBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  current.$3,
                  size: 40,
                  color: tokens.bluePrimary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                current.$1,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                current.$2,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      Navigator.pop(context);
                    } else {
                      setState(() => step++);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.blueDarker,
                    foregroundColor: tokens.textPrimary,
                  ),
                  child: Text(
                    last
                        ? 'Finish setup'
                        : step == 1
                        ? 'Allow and continue'
                        : 'Continue',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!last)
                Center(
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
                    child: const Text('Need help?'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
