import 'package:flutter/material.dart';

import '../../../../core/models/privacy_models.dart';import '../../../../core/repositories/privacy_repository.dart';import '../settings_ui.dart';
import 'privacy_data_detail_page.dart';
import 'privacy_legal_page.dart';
import 'privacy_permission_detail_page.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, this.repository});

  final PrivacyRepository? repository;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late PrivacyRepository _repository;
  late Future<PrivacySummary> _summary;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PreviewPrivacyRepository();
    _load();
  }

  void _load() {
    setState(() {
      _summary = _repository.getSummary();
    });
  }

  Future<void> _toggleDiagnostic(bool value) async {
    final ok = await _repository.setDiagnosticSharing(value);
    if (!mounted) return;
    if (!ok && value) {
      showSettingsUnavailable(
        context,
        message: 'Diagnostic sharing is not available in this preview build.',
      );
    }
    _load();
  }

  Future<void> _toggleAnalytics(bool value) async {
    final ok = await _repository.setUsageAnalytics(value);
    if (!mounted) return;
    if (!ok && value) {
      showSettingsUnavailable(
        context,
        message: 'Usage analytics is not available in this preview build.',
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Privacy',
    subtitle: 'Manage your data and privacy preferences.',
    actions: [settingsHelpAction(context)],
    child: FutureBuilder<PrivacySummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            SettingsHeroCard(
              leading: settingsHeroIcon(
                icon: Icons.shield_rounded,
                color: SettingsColors.green,
                background: SettingsColors.paleGreen,
              ),
              title: data.title,
              subtitle: data.subtitle,
              statusChip: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, color: SettingsColors.green, size: 16),
                  const SizedBox(width: 6),
                  SettingsStatusChip(
                    label: data.statusLabel,
                    color: SettingsColors.green,
                    background: SettingsColors.paleGreen,
                    leading: const Icon(Icons.check_rounded, color: SettingsColors.green, size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('YOUR DATA'),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.dataCategories.length; i++)
                    SettingsListItem(
                      icon: _dataIcon(data.dataCategories[i].kind),
                      title: data.dataCategories[i].title,
                      subtitle: data.dataCategories[i].subtitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyDataDetailPage(category: data.dataCategories[i]),
                        ),
                      ),
                      showDivider: i < data.dataCategories.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('PERMISSIONS'),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.permissions.length; i++)
                    _PermissionRow(
                      permission: data.permissions[i],
                      showDivider: i < data.permissions.length - 1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivacyPermissionDetailPage(permission: data.permissions[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('PRIVACY PREFERENCES'),
            SettingsSurface(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Diagnostic data sharing', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Help us improve by sharing device diagnostics.'),
                    value: data.diagnosticSharing,
                    onChanged: data.diagnosticSupported ? _toggleDiagnostic : (_) => _toggleDiagnostic(true),
                  ),
                  const Divider(height: 1, color: SettingsColors.line),
                  SwitchListTile(
                    title: const Text('Usage analytics', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Help us improve the app experience.'),
                    value: data.usageAnalytics,
                    onChanged: data.analyticsSupported ? _toggleAnalytics : (_) => _toggleAnalytics(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('DATA MANAGEMENT'),
            SettingsSurface(
              child: Column(
                children: [
                  SettingsListItem(
                    icon: Icons.cloud_download_outlined,
                    title: 'Download your data',
                    subtitle: 'Get a copy of your data',
                    iconColor: SettingsColors.purple,
                    iconBackground: SettingsColors.palePurple,
                    onTap: () => showSettingsUnavailable(
                      context,
                      message: 'Data export will be available when account services are connected.',
                    ),
                    showDivider: true,
                  ),
                  SettingsListItem(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete activity history',
                    subtitle: 'Remove your activity records',
                    iconColor: SettingsColors.red,
                    iconBackground: const Color(0xFFFFEEEE),
                    onTap: () => showSettingsUnavailable(
                      context,
                      message: 'Activity deletion will be wired to the activity repository when supported.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('LEGAL & SECURITY'),
            SettingsSurface(
              child: Column(
                children: [
                  SettingsListItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Security',
                    subtitle: 'Learn how we keep your data secure',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyLegalPage(title: 'Security', kind: 'security'),
                      ),
                    ),
                    showDivider: true,
                  ),
                  SettingsListItem(
                    icon: Icons.description_outlined,
                    title: 'Privacy policy',
                    subtitle: 'Read our privacy policy',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyLegalPage(title: 'Privacy policy', kind: 'privacy'),
                      ),
                    ),
                    showDivider: true,
                  ),
                  SettingsListItem(
                    icon: Icons.article_outlined,
                    title: 'Terms of service',
                    subtitle: 'Read our terms of service',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyLegalPage(title: 'Terms of service', kind: 'terms'),
                      ),
                    ),
                    showDivider: true,
                  ),
                  SettingsListItem(
                    icon: Icons.info_outline_rounded,
                    title: 'Data practices',
                    subtitle: 'How we collect, use and protect your data',
                    iconColor: SettingsColors.purple,
                    iconBackground: SettingsColors.palePurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyLegalPage(title: 'Data practices', kind: 'practices'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  IconData _dataIcon(PrivacyDataCategoryKind kind) => switch (kind) {
        PrivacyDataCategoryKind.homeDevice => Icons.home_outlined,
        PrivacyDataCategoryKind.activityHistory => Icons.history_rounded,
        PrivacyDataCategoryKind.routineData => Icons.hub_outlined,
        PrivacyDataCategoryKind.accountInfo => Icons.person_outline_rounded,
      };
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.onTap,
    this.showDivider = false,
  });

  final PrivacyPermission permission;
  final VoidCallback onTap;
  final bool showDivider;

  Color get _statusColor => switch (permission.status) {
        PrivacyPermissionStatus.allowed => SettingsColors.green,
        PrivacyPermissionStatus.denied => SettingsColors.red,
        _ => SettingsColors.muted,
      };

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
                SettingsIconBadge(icon: _icon(permission.id), size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(permission.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(permission.description, style: const TextStyle(color: SettingsColors.muted, fontSize: 14)),
                    ],
                  ),
                ),
                Text(
                  permission.statusLabel,
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Icon(Icons.chevron_right_rounded, color: SettingsColors.muted),
              ],
            ),
          ),
        ),
      ),
      if (showDivider)
        const Padding(
          padding: EdgeInsets.only(left: 76),
          child: Divider(height: 1, color: SettingsColors.line),
        ),
    ],
  );

  IconData _icon(String id) => switch (id) {
        'bluetooth' => Icons.bluetooth_rounded,
        'notifications' => Icons.notifications_outlined,
        'location' => Icons.location_on_outlined,
        _ => Icons.security_rounded,
      };
}
