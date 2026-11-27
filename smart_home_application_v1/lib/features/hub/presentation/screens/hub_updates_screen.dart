import 'package:flutter/material.dart';
import '../../../../core/services/local_lan_device_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/settings_ui.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';

class HubUpdatesScreen extends StatefulWidget {
  const HubUpdatesScreen({
    super.key,
    required this.repository,
    required this.hubState,
  });

  final HubRepository repository;
  final HubState hubState;

  @override
  State<HubUpdatesScreen> createState() => _HubUpdatesScreenState();
}

class _HubUpdatesScreenState extends State<HubUpdatesScreen> {
  Map<String, dynamic>? _updates;
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.repository.getHubUpdates(hubHostname: widget.hubState.hostname);
    if (!mounted) return;
    setState(() {
      _updates = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final hubInfo = _updates?['hub'] as Map<String, dynamic>? ?? {};
    final otaCache = _updates?['deviceOtaCache'] as Map<String, dynamic>? ?? {};
    final cachedList = otaCache['cachedFirmwares'] as List<dynamic>? ?? [];
    final isUnreachable = _updates?['status'] == 'unreachable';
    final updateAvailable = hubInfo['updateAvailable'] == true;
    final currentVer = hubInfo['currentVersion']?.toString() ?? widget.hubState.firmwareVersion;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Firmware & Local OTA Cache',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.system_update_alt_rounded, color: tokens.headerAction),
            onPressed: _checking
                ? null
                : () async {
                    setState(() => _checking = true);
                    final ok = await widget.repository.checkForUpdates(hubHostname: widget.hubState.hostname);
                    await _load();
                    if (context.mounted) {
                      setState(() => _checking = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Hub update & staged cache refreshed.' : 'Could not reach Hub update service.'),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSurface(
                  child: Column(
                    children: [
                      SettingsListItem(
                        icon: Icons.memory_rounded,
                        title: currentVer.isNotEmpty ? 'Hub Core v$currentVer' : 'Hub Daemon',
                        subtitle: 'Platform: ${hubInfo['platform'] ?? widget.hubState.model} • Storage: ${widget.hubState.storageEngine}',
                        trailing: SettingsStatusChip(
                          label: isUnreachable
                              ? 'Unreachable'
                              : (updateAvailable ? 'Update Ready' : 'Up to Date'),
                          color: isUnreachable
                              ? tokens.textTertiary
                              : (updateAvailable ? tokens.bluePrimary : tokens.success),
                          background: isUnreachable
                              ? tokens.surfaceElevated
                              : (updateAvailable ? tokens.iconBgBlue : tokens.successContainer),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SettingsSectionTitle('Staged LAN OTA Images (${cachedList.length})'),
                if (cachedList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cached_rounded, size: 32, color: tokens.textTertiary),
                        const SizedBox(height: 8),
                        Text('No Staged Firmware Binaries', style: TextStyle(fontWeight: FontWeight.w800, color: tokens.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'When releases are staged to the Hub OTA directory or synced from the Cloud, they appear here for offline LAN flashing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  SettingsSurface(
                    child: Column(
                      children: [
                        for (int i = 0; i < cachedList.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _buildStagedRow(tokens, Map<String, dynamic>.from(cachedList[i] as Map)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStagedRow(EHThemeTokens tokens, Map<String, dynamic> entry) {
    final filename = entry['filename']?.toString() ?? '';
    final model = entry['model']?.toString() ?? 'Unknown Target';
    final ver = entry['version']?.toString() ?? '—';
    final sizeBytes = (entry['sizeBytes'] as num?)?.toInt() ?? 0;
    final fullUrl = entry['fullUrl']?.toString() ?? '';
    final kb = sizeBytes > 0 ? '${(sizeBytes / 1024).round()} KB' : 'Ready';

    return ListTile(
      leading: Icon(Icons.developer_board_rounded, color: tokens.bluePrimary),
      title: Text('$model • v$ver', style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary)),
      subtitle: Text('$filename ($kb)', style: TextStyle(fontSize: 11.5, color: tokens.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fullUrl.isNotEmpty)
            IconButton(
              icon: Icon(Icons.install_mobile_rounded, color: tokens.bluePrimary),
              tooltip: 'Push LAN Update to Matching Devices',
              onPressed: () => _pushStagedUpdateToDevices(
                model: model,
                version: ver,
                fullUrl: fullUrl,
                sizeBytes: sizeBytes,
              ),
            ),
          if (filename.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Remove Staged Binary',
              onPressed: () async {
                await widget.repository.deleteStagedOtaBinary(
                  hubHostname: widget.hubState.hostname,
                  filename: filename,
                );
                await _load();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pushStagedUpdateToDevices({
    required String model,
    required String version,
    required String fullUrl,
    required int sizeBytes,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final normTarget = model.toLowerCase().trim();
    final matching = widget.hubState.connectedDevices.where((d) {
      if (!d.online) return false;
      final dm = (d.model ?? '').toLowerCase();
      if (dm == normTarget) return true;
      if (normTarget.contains('socket-2x') && d.category == HubDeviceCategory.sockets && d.channelCount == 2) {
        return true;
      }
      if (normTarget.contains('switch-3x') && d.category == HubDeviceCategory.switches && d.channelCount == 3) {
        return true;
      }
      if (normTarget.contains('switch-4x') && d.category == HubDeviceCategory.switches && d.channelCount == 4) {
        return true;
      }
      return false;
    }).toList();

    if (matching.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('No online adopted devices matched $model.')),
      );
      return;
    }

    int started = 0;
    for (final dev in matching) {
      final res = await LocalLanDeviceService.instance.startLocalOtaUpdate(
        deviceId: dev.id,
        downloadUrl: fullUrl,
        version: version,
        binarySizeBytes: sizeBytes > 0 ? sizeBytes : null,
      );
      if (res.ok) started++;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          started > 0
              ? 'Started offline Hub LAN OTA v$version on $started/${matching.length} device(s).'
              : 'Device rejected OTA start — verify device is reachable on LAN.',
        ),
      ),
    );
  }
}
