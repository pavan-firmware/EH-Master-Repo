import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The device is already identified through BLE before this page is shown.
/// Wi-Fi credentials, ownership authentication, and completion are deliberately
/// blocked until firmware implements an authenticated provisioning channel.
class DeviceProvisioningPage extends StatelessWidget {
  const DeviceProvisioningPage({super.key, required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        title: Text(
          'Set up device',
          style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Almost there',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: tokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '$deviceName is identified nearby. Finish the secure setup steps below.',
            style: TextStyle(color: tokens.textSecondary),
          ),
          const SizedBox(height: 24),
          const _ProvisioningStep(
            number: '1',
            icon: Icons.wifi_rounded,
            title: 'Connect to home Wi-Fi',
            detail:
                'Secure Wi-Fi provisioning is not yet exposed by this ESP32 firmware.',
            current: true,
          ),
          const _ProvisioningStep(
            number: '2',
            icon: Icons.edit_outlined,
            title: 'Name your device',
            detail: 'Choose a friendly name after it joins your network.',
          ),
          const _ProvisioningStep(
            number: '3',
            icon: Icons.meeting_room_outlined,
            title: 'Choose a room',
            detail: 'Assign the device to a room after secure commissioning.',
          ),
          const _ProvisioningStep(
            number: '4',
            icon: Icons.verified_outlined,
            title: 'Finish setup',
            detail: 'The device must confirm ownership and online status.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.warningContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.isDark ? const Color(0xFF5A3E20) : const Color(0xFFFFD8BB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: tokens.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For your safety, BLE proximity alone never gives control or Wi-Fi access. This screen will unlock only after the firmware supports authenticated commissioning.',
                    style: TextStyle(color: tokens.isDark ? tokens.textSecondary : const Color(0xFF7A421F), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.blueDarker,
                foregroundColor: tokens.textPrimary,
              ),
              child: const Text('Back to home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisioningStep extends StatelessWidget {
  const _ProvisioningStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    this.current = false,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final tileColor = current
        ? tokens.blueSelectedBg
        : tokens.surfaceCard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: tokens.isDark ? BorderSide(color: current ? tokens.bluePrimary : tokens.borderSubtle) : BorderSide.none,
        ),
        tileColor: tileColor,
        leading: CircleAvatar(
          backgroundColor: current
              ? tokens.bluePrimary
              : tokens.surfaceElevated,
          foregroundColor: current ? Colors.white : tokens.textSecondary,
          child: Text(number),
        ),
        title: Row(
          children: [
            Icon(icon, size: 19, color: current ? tokens.bluePrimary : tokens.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(detail, style: TextStyle(color: tokens.textSecondary)),
        ),
      ),
    );
  }
}
