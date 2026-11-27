import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/settings_ui.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';

class HubIntegrationsBackupsScreen extends StatefulWidget {
  const HubIntegrationsBackupsScreen({
    super.key,
    required this.repository,
    required this.hubState,
    required this.onMutated,
  });

  final HubRepository repository;
  final HubState hubState;
  final VoidCallback onMutated;

  @override
  State<HubIntegrationsBackupsScreen> createState() => _HubIntegrationsBackupsScreenState();
}

class _HubIntegrationsBackupsScreenState extends State<HubIntegrationsBackupsScreen> {
  Map<String, dynamic>? _haStatus;
  List<HubBackupSummary> _backups = [];
  List<HubWebhookRule> _webhooks = [];
  bool _loading = true;
  bool _syncingHa = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final host = widget.hubState.hostname;
    final res = await Future.wait([
      widget.repository.getHomeAssistantStatus(hubHostname: host),
      widget.repository.listSavedBackups(hubHostname: host),
      widget.repository.getWebhooks(hubHostname: host),
    ]);
    if (!mounted) return;
    setState(() {
      _haStatus = res[0] as Map<String, dynamic>?;
      _backups = res[1] as List<HubBackupSummary>;
      _webhooks = res[2] as List<HubWebhookRule>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final mqtt = _haStatus?['mqtt'] as Map<String, dynamic>? ?? {};
    final mqttConfigured = mqtt['configured'] == true;
    final mqttConnected = mqtt['connected'] == true;
    final entitiesCount = (_haStatus?['entitiesCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Backups, HA & Webhooks',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh_rounded, color: tokens.headerAction), onPressed: _loadAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              children: [
                // 1. Home Assistant Live MQTT / REST Bridge
                SettingsSectionTitle(
                  'Home Assistant Bridge',
                  trailing: TextButton(
                    onPressed: _openHaConfigDialog,
                    child: Text(mqttConfigured ? 'Edit MQTT' : 'Configure MQTT'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Local MQTT & REST Bridge', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                          ),
                          SettingsStatusChip(
                            label: mqttConnected
                                ? 'MQTT Connected'
                                : (mqttConfigured ? 'MQTT Saved' : 'REST Ready (No MQTT)'),
                            color: mqttConnected ? tokens.success : tokens.bluePrimary,
                            background: mqttConnected ? tokens.successContainer : tokens.iconBgBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mqttConfigured
                            ? 'Broker: ${mqtt['host']}:${mqtt['port']} • Prefix: ${mqtt['discoveryPrefix'] ?? "homeassistant"} • $entitiesCount entities'
                            : 'REST endpoints active ($entitiesCount entities across adopted devices). Configure an MQTT broker for live push discovery.',
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _syncingHa
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    setState(() => _syncingHa = true);
                                    final r = await widget.repository.syncHomeAssistant(hubHostname: widget.hubState.hostname);
                                    await _loadAll();
                                    if (mounted) {
                                      setState(() => _syncingHa = false);
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(r?['message']?.toString() ?? 'Home Assistant sync finished.')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.sync_alt_rounded, size: 16),
                            label: Text(_syncingHa ? 'Syncing...' : 'Sync Entities'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 2. Saved Backups (Create / Restore / Delete / Diagnostics)
                SettingsSectionTitle(
                  'Configuration Backups (${_backups.length})',
                  trailing: TextButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Save Snapshot'),
                  ),
                ),
                SettingsSurface(
                  child: Column(
                    children: [
                      if (_backups.isEmpty)
                        ListTile(
                          leading: Icon(Icons.backup_outlined, color: tokens.textTertiary),
                          title: const Text('No saved snapshots on Hub yet'),
                          subtitle: const Text('Tap "Save Snapshot" to store an instant restore point.'),
                        )
                      else
                        for (int i = 0; i < _backups.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(_backups[i].label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${_backups[i].devicesCount} devices • ${_backups[i].routinesCount} routines • ${_backups[i].rulesCount} rules'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await widget.repository.restoreSavedBackupById(
                                      hubHostname: widget.hubState.hostname,
                                      backupId: _backups[i].id,
                                    );
                                    widget.onMutated();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(ok ? 'Backup restored cleanly.' : 'Restore failed.')),
                                      );
                                    }
                                  },
                                  child: const Text('Restore'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  onPressed: () async {
                                    await widget.repository.deleteSavedBackup(
                                      hubHostname: widget.hubState.hostname,
                                      backupId: _backups[i].id,
                                    );
                                    await _loadAll();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      const Divider(height: 1),
                      SettingsListItem(
                        icon: Icons.upload_file_rounded,
                        title: 'Restore from JSON Snapshot',
                        subtitle: 'Paste an exported Hub backup JSON payload to restore state',
                        onTap: _openJsonRestoreDialog,
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsListItem(
                        icon: Icons.medical_services_rounded,
                        title: 'One-Click Diagnostics Export',
                        subtitle: 'Inspect storage engine, uptime, OverlayFS, NTP & device counts',
                        onTap: _showDiagnosticsDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Local Offline Webhooks Full CRUD
                SettingsSectionTitle(
                  'Local Webhooks (${_webhooks.length})',
                  trailing: TextButton.icon(
                    onPressed: () => _openWebhookEditor(null),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Webhook'),
                  ),
                ),
                SettingsSurface(
                  child: _webhooks.isEmpty
                      ? ListTile(
                          leading: Icon(Icons.webhook_rounded, color: tokens.textTertiary),
                          title: const Text('No local webhooks created'),
                          subtitle: const Text('Create offline HTTP webhook triggers for voice/assistant bridges.'),
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < _webhooks.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              ListTile(
                                title: Text(_webhooks[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('Event: ${_webhooks[i].event} • CH${_webhooks[i].channel}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.play_arrow_rounded, color: tokens.bluePrimary),
                                      onPressed: () async {
                                        await widget.repository.testWebhook(
                                          hubHostname: widget.hubState.hostname,
                                          webhookId: _webhooks[i].id,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _openWebhookEditor(_webhooks[i]),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      onPressed: () async {
                                        await widget.repository.deleteWebhook(
                                          hubHostname: widget.hubState.hostname,
                                          webhookId: _webhooks[i].id,
                                        );
                                        await _loadAll();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _createBackup() async {
    final labelCtrl = TextEditingController(text: 'Backup ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}');
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Hub Backup'),
        content: TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Backup Label', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, labelCtrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (label != null && label.isNotEmpty) {
      await widget.repository.createSavedBackup(hubHostname: widget.hubState.hostname, label: label);
      await _loadAll();
    }
  }

  Future<void> _openJsonRestoreDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Hub from JSON'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(hintText: '{"devices": [...], "routines": [...]}', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final decoded = Map<String, dynamic>.from(jsonDecode(ctrl.text.trim()) as Map);
                final ok = await widget.repository.restoreHubBackup(hubHostname: widget.hubState.hostname, backup: decoded);
                widget.onMutated();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Hub restored from JSON snapshot.' : 'Restore failed.')),
                  );
                }
                await _loadAll();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid JSON snapshot payload.')));
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDiagnosticsDialog() async {
    final diag = await widget.repository.exportDiagnostics(hubHostname: widget.hubState.hostname);
    if (!mounted) return;
    if (diag == null || diag['status'] != 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load Hub diagnostics.')));
      return;
    }
    final hub = diag['hub'] as Map<String, dynamic>? ?? {};
    final summary = diag['summary'] as Map<String, dynamic>? ?? {};
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hub Diagnostics Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Engine: ${hub['storageEngine'] ?? summary['databaseEngine'] ?? "sqlite"}'),
            Text('Version: ${hub['version'] ?? "—"}'),
            Text('Devices: ${(diag['devices'] as List?)?.length ?? summary['totalDevices'] ?? 0}'),
            Text('Routines: ${diag['routinesCount'] ?? 0} • Rules: ${diag['rulesCount'] ?? 0}'),
            Text('OverlayFS: ${(hub['overlayFs'] ?? summary['overlayFsActive']) == true ? "ACTIVE" : "OFF"}'),
            Text('NTP Synced: ${(hub['ntpSynced'] ?? summary['ntpSynced']) == true ? "YES" : "NO"}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _openHaConfigDialog() async {
    final mqtt = _haStatus?['mqtt'] as Map<String, dynamic>? ?? {};
    final hostCtrl = TextEditingController(text: mqtt['host']?.toString() ?? '');
    final portCtrl = TextEditingController(text: (mqtt['port'] ?? 1883).toString());
    final userCtrl = TextEditingController(text: mqtt['username']?.toString() ?? '');
    final passCtrl = TextEditingController();
    final prefixCtrl = TextEditingController(text: mqtt['discoveryPrefix']?.toString() ?? 'homeassistant');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Home Assistant MQTT Broker'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Broker IP / Host', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port (1883)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username (optional)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password (optional)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: prefixCtrl, decoration: const InputDecoration(labelText: 'Discovery Prefix', border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await widget.repository.saveHomeAssistantConfig(
                hubHostname: widget.hubState.hostname,
                host: hostCtrl.text.trim(),
                port: int.tryParse(portCtrl.text.trim()) ?? 1883,
                username: userCtrl.text.trim(),
                password: passCtrl.text,
                discoveryPrefix: prefixCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadAll();
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebhookEditor(HubWebhookRule? existing) async {
    final devices = widget.hubState.connectedDevices;
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Local Webhook');
    final eventCtrl = TextEditingController(text: existing?.event ?? 'voice.command.toggle');
    String devId = existing?.deviceId ?? (devices.isNotEmpty ? devices.first.id : '');
    int ch = existing?.channel ?? 1;
    bool state = existing?.state ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Create Webhook Trigger' : 'Edit Webhook Trigger'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: eventCtrl, decoration: const InputDecoration(labelText: 'Event Key', border: OutlineInputBorder(), isDense: true)),
                if (devices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: devices.any((d) => d.id == devId) ? devId : devices.first.id,
                    decoration: const InputDecoration(labelText: 'Target Device', border: OutlineInputBorder(), isDense: true),
                    items: devices.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (v) { if (v != null) setDlg(() => devId = v); },
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: ch,
                        decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder(), isDense: true),
                        items: [1, 2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('CH$c'))).toList(),
                        onChanged: (v) { if (v != null) setDlg(() => ch = v); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('ON'),
                        value: state,
                        onChanged: (v) => setDlg(() => state = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.repository.saveWebhook(
                  hubHostname: widget.hubState.hostname,
                  webhook: HubWebhookRule(
                    id: existing?.id ?? '',
                    name: nameCtrl.text.trim(),
                    event: eventCtrl.text.trim(),
                    deviceId: devId.isEmpty ? null : devId,
                    channel: ch,
                    state: state,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
