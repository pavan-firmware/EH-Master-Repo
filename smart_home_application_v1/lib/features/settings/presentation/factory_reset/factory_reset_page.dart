import 'package:flutter/material.dart';

import '../../../../core/models/factory_reset_models.dart';
import '../../../../core/repositories/factory_reset_repository.dart';
import '../../../activity/presentation/activity_page.dart';
import '../../../rooms/presentation/room_context_page.dart';
import '../../../../core/models/room_models.dart';
import '../settings_ui.dart';import 'factory_reset_confirm_page.dart';
import 'routine_impact_page.dart';

class FactoryResetPage extends StatefulWidget {
  const FactoryResetPage({
    super.key,
    this.repository = const PreviewFactoryResetRepository(),
  });

  final FactoryResetRepository repository;

  @override
  State<FactoryResetPage> createState() => _FactoryResetPageState();
}

class _FactoryResetPageState extends State<FactoryResetPage> {
  late Future<FactoryResetImpact> _impact;

  @override
  void initState() {
    super.initState();
    _impact = widget.repository.getImpact();
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Factory reset',
    subtitle: 'Reset your device to its factory state.',
    actions: [settingsHelpAction(context)],
    child: FutureBuilder<FactoryResetImpact>(
      future: _impact,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final impact = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const SettingsDestructiveBanner(
              title: 'This action cannot be undone',
              body: 'The device will be removed from your home and all settings will be erased.',
            ),
            const SizedBox(height: 20),
            const SettingsSectionTitle('DEVICE TO RESET'),
            _DeviceCard(impact: impact),
            const SizedBox(height: 20),
            const SettingsSectionTitle('WHAT WILL HAPPEN'),
            SettingsCheckList(items: impact.willHappen),
            const SizedBox(height: 20),
            const SettingsSectionTitle('WHAT WILL NOT HAPPEN'),
            SettingsCheckList(items: impact.willNotHappen, positive: false),
            const SizedBox(height: 20),
            const SettingsSectionTitle('IMPACT'),
            SettingsSurface(
              child: Column(
                children: [
                  _ImpactRow(
                    icon: Icons.hub_outlined,
                    title: 'Routines that use this device',
                    subtitle: 'They will become unavailable',
                    value: '${impact.routineCount} routines',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutineImpactPage(routineNames: impact.routineNames),
                      ),
                    ),
                    showDivider: true,
                  ),
                  _ImpactRow(
                    icon: Icons.weekend_outlined,
                    title: 'Room',
                    subtitle: 'This device is in a room',
                    value: impact.roomName,
                    onTap: () {
                      final room = RoomCatalog.preview.firstWhere(
                        (r) => r.name == impact.roomName,
                        orElse: () => RoomCatalog.preview.first,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RoomContextPage(room: room)),
                      );
                    },
                    showDivider: true,
                  ),
                  _ImpactRow(
                    icon: Icons.history_rounded,
                    title: 'Activity history',
                    subtitle: 'Will be preserved',
                    value: 'Preserved',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivityPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SettingsInfoBanner(
              title: 'Before you continue',
              subtitle: 'Make sure the device is powered on and nearby.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: SettingsColors.red),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FactoryResetConfirmPage(repository: widget.repository),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.impact});
  final FactoryResetImpact impact;

  @override
  Widget build(BuildContext context) => SettingsSurface(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SettingsColors.paleBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop_outlined, color: SettingsColors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      impact.deviceName,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      impact.deviceModel,
                      style: const TextStyle(color: SettingsColors.muted),
                    ),
                    const SizedBox(height: 6),
                    SettingsStatusChip(
                      label: impact.online ? 'Online' : 'Offline',
                      color: SettingsColors.green,
                      background: SettingsColors.paleGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SettingsStatusChip(
              label: impact.roomName,
              color: SettingsColors.muted,
              background: const Color(0xFFF0F3F7),
              leading: const Icon(Icons.place_outlined, size: 14, color: SettingsColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                SettingsIconBadge(icon: icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(subtitle, style: const TextStyle(color: SettingsColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, color: SettingsColors.muted),
              ],
            ),
          ),
        ),
      ),
      if (showDivider)
        const Padding(
          padding: EdgeInsets.only(left: 72),
          child: Divider(height: 1, color: SettingsColors.line),
        ),
    ],
  );
}
