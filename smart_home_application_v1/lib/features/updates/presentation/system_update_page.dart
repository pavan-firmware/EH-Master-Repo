import 'package:flutter/material.dart';

import '../../../core/models/update_models.dart';
import '../../../core/repositories/update_repository.dart';
import '../../settings/presentation/settings_ui.dart';
import 'update_history_page.dart';
import 'update_preferences_page.dart';
import 'update_target_detail_page.dart';

class SystemUpdatePage extends StatefulWidget {
  const SystemUpdatePage({super.key, this.repository = const PreviewUpdateRepository()});

  final UpdateRepository repository;

  @override
  State<SystemUpdatePage> createState() => _SystemUpdatePageState();
}

class _SystemUpdatePageState extends State<SystemUpdatePage> {
  late Future<UpdateSummary> _summary;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _summary = widget.repository.getSummary();
    });
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    final result = await widget.repository.checkForUpdates();
    if (mounted) {
      setState(() {
        _summary = Future.value(result);
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'System update',
    subtitle: 'Keep EH Home and your devices up to date.',
    actions: [
      settingsHelpAction(
        context,
        message: 'Updates improve performance, add features, and keep your home secure.',
      ),
    ],
    child: FutureBuilder<UpdateSummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            _UpdateStatusCard(summary: data, checking: _checking, onCheck: _checkUpdates),
            const SizedBox(height: 24),
            const Text('Update targets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.targets.length; i++)
                    _UpdateTargetRow(
                      target: data.targets[i],
                      showDivider: i < data.targets.length - 1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UpdateTargetDetailPage(target: data.targets[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('Update history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                SettingsSectionLink(
                  label: 'View all',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdateHistoryPage(history: data.history),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SettingsSurface(
              child: Column(
                children: [
                  for (var i = 0; i < data.history.take(2).length; i++)
                    _HistoryRow(
                      entry: data.history[i],
                      showDivider: i < data.history.take(2).length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Update preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SettingsSurface(
              child: SettingsListItem(
                icon: Icons.settings_rounded,
                title: 'Update preferences',
                subtitle: 'Choose how and when updates are installed',
                iconColor: SettingsColors.purple,
                iconBackground: SettingsColors.palePurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpdatePreferencesPage()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SettingsInfoBanner(
              title: 'Stay secure',
              subtitle: 'Updates improve performance, add new features and keep your home secure.',
              icon: Icons.info_outline_rounded,
            ),
          ],
        );
      },
    ),
  );
}

class _UpdateStatusCard extends StatelessWidget {
  const _UpdateStatusCard({
    required this.summary,
    required this.checking,
    required this.onCheck,
  });

  final UpdateSummary summary;
  final bool checking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) => SettingsHeroCard(
    leading: settingsHeroIcon(
      icon: Icons.verified_user_rounded,
      color: SettingsColors.green,
      background: SettingsColors.paleGreen,
    ),
    title: summary.title,
    subtitle: summary.subtitle,
    statusChip: SettingsStatusChip(
      label: summary.statusLabel,
      color: SettingsColors.green,
      background: SettingsColors.paleGreen,
      leading: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: SettingsColors.green, shape: BoxShape.circle),
      ),
    ),
    footer: SettingsHeroActionFooter(
      lastCheckedLabel: 'Last checked: Today, 9:40 AM',
      actionLabel: 'Check for updates',
      onAction: onCheck,
      checking: checking,
    ),
  );
}

class _UpdateTargetRow extends StatelessWidget {
  const _UpdateTargetRow({
    required this.target,
    required this.onTap,
    this.showDivider = false,
  });

  final UpdateTarget target;
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
                SettingsIconBadge(icon: _icon(target.kind), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(target.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(target.currentVersion, style: const TextStyle(color: SettingsColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: SettingsColors.green, size: 18),
                const SizedBox(width: 4),
                Text(
                  target.statusLabel,
                  style: const TextStyle(color: SettingsColors.green, fontWeight: FontWeight.w700, fontSize: 12),
                ),
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

  IconData _icon(UpdateTargetKind kind) => switch (kind) {
        UpdateTargetKind.app => Icons.smartphone_rounded,
        UpdateTargetKind.hub => Icons.router_rounded,
        UpdateTargetKind.device => Icons.memory_rounded,
      };
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, this.showDivider = false});
  final UpdateHistoryEntry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final month = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][entry.installedAt.month - 1];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsIconBadge(
                icon: Icons.download_rounded,
                color: SettingsColors.green,
                background: SettingsColors.paleGreen,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${entry.deviceName} · ${entry.result}', style: const TextStyle(color: SettingsColors.muted, fontSize: 13)),
                    Text(
                      '$month ${entry.installedAt.day}, ${entry.installedAt.year} · ${_time(entry.installedAt)}',
                      style: const TextStyle(color: SettingsColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SettingsColors.muted),
            ],
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

  String _time(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : value.hour;
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final min = value.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}
