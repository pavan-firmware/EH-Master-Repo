import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/settings_ui.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';

class HubSecuritySettingsScreen extends StatefulWidget {
  const HubSecuritySettingsScreen({
    super.key,
    required this.repository,
    required this.hubState,
    required this.onMutated,
  });

  final HubRepository repository;
  final HubState hubState;
  final VoidCallback onMutated;

  @override
  State<HubSecuritySettingsScreen> createState() => _HubSecuritySettingsScreenState();
}

class _HubSecuritySettingsScreenState extends State<HubSecuritySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Hub Network & Security',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SettingsSectionTitle('Connectivity & Mesh'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.settings_ethernet_rounded,
                  title: 'Custom Hub Host / IP',
                  subtitle: LiveHubRepository.customHost != null && LiveHubRepository.customHost!.isNotEmpty
                      ? 'Active: ${LiveHubRepository.customHost}'
                      : 'Automatic mDNS (${widget.hubState.hostname})',
                  onTap: () async {
                    final ctrl = TextEditingController(text: LiveHubRepository.customHost ?? '');
                    final newHost = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Custom Hub Host / IP'),
                        content: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            labelText: 'Hub Hostname or IP',
                            hintText: '192.168.0.174 or eh-hub.local',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Auto')),
                          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (newHost != null) {
                      LiveHubRepository.customHost = newHost.isEmpty ? null : newHost;
                      widget.onMutated();
                      if (mounted) setState(() {});
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.refresh_rounded,
                  title: 'Reset Mesh Network',
                  subtitle: 'Flushes Hub device registry and re-probes LAN nodes',
                  onTap: () async {
                    final ok = await widget.repository.resetMeshNetwork(hubHostname: widget.hubState.hostname);
                    widget.onMutated();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Mesh network reset triggered.' : 'Mesh reset failed.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SettingsSectionTitle('LAN Security & Ownership'),
          SettingsSurface(
            child: Column(
              children: [
                SettingsListItem(
                  icon: Icons.vpn_key_rounded,
                  title: 'Rotate Hub LAN Access Token',
                  subtitle: 'Generates a fresh cryptographic Bearer token for port 4210 API',
                  onTap: () async {
                    final newTok = await widget.repository.rotateHubToken(hubHostname: widget.hubState.hostname);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(newTok != null ? 'Hub access token rotated & saved cleanly.' : 'Token rotation failed.')),
                      );
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.link_off_rounded,
                  title: 'Unlink Hub from this Home',
                  subtitle: 'Returns devices to direct local Wi-Fi without Hub coordination',
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unlink Smart Home Hub?'),
                        content: const Text('Standalone devices will keep working directly over LAN & Cloud.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text('Unlink Hub'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await widget.repository.unlinkHub(hubHostname: widget.hubState.hostname);
                      widget.onMutated();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SettingsListItem(
                  icon: Icons.delete_forever_rounded,
                  title: 'Factory Reset Hub',
                  subtitle: 'Erases tokens, schedules, rules, and resets Hub to defaults',
                  destructive: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Factory Reset Hub?'),
                        content: const Text('This erases all Hub data. Adopted switches remain safe.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            child: const Text('Confirm Factory Reset'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await widget.repository.factoryResetHub(hubHostname: widget.hubState.hostname);
                      widget.onMutated();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
