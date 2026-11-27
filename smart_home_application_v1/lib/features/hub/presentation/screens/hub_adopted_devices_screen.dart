import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/settings_ui.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';
import 'hub_ui_helpers.dart';

class HubAdoptedDevicesScreen extends StatefulWidget {
  const HubAdoptedDevicesScreen({
    super.key,
    required this.repository,
    required this.initialState,
    required this.onScanAndAdopt,
  });

  final HubRepository repository;
  final HubState initialState;
  final Future<List<HubDeviceInfo>> Function() onScanAndAdopt;

  @override
  State<HubAdoptedDevicesScreen> createState() => _HubAdoptedDevicesScreenState();
}

class _HubAdoptedDevicesScreenState extends State<HubAdoptedDevicesScreen> {
  late HubState _state;
  HubDeviceCategory? _selectedCategory;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  Future<void> _refresh() async {
    final fresh = await widget.repository.getHubState();
    if (!mounted) return;
    if (fresh.status == HubConnectionStatus.connected) {
      setState(() => _state = fresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final allDevices = _state.connectedDevices;
    final filtered = _selectedCategory == null
        ? allDevices
        : allDevices.where((d) => d.category == _selectedCategory).toList();

    final categoryCounts = <HubDeviceCategory, int>{};
    for (final d in allDevices) {
      categoryCounts[d.category] = (categoryCounts[d.category] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Adopted Devices (${allDevices.length})',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _isBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.sync_rounded, color: tokens.headerAction),
            tooltip: 'Scan & Adopt Devices',
            onPressed: _isBusy
                ? null
                : () async {
                    setState(() => _isBusy = true);
                    await widget.onScanAndAdopt();
                    await _refresh();
                    if (mounted) setState(() => _isBusy = false);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Multi-Category Filter Bar (All / Switches / Sockets / Fans / Sensors / Others)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                FilterChip(
                  label: Text('All (${allDevices.length})'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                for (final cat in HubDeviceCategory.values)
                  if (categoryCounts[cat] != null ||
                      cat == HubDeviceCategory.switches ||
                      cat == HubDeviceCategory.sockets ||
                      cat == HubDeviceCategory.fans ||
                      cat == HubDeviceCategory.sensors) ...[
                    FilterChip(
                      avatar: Icon(HubUiHelpers.categoryIcon(cat), size: 15),
                      label: Text('${cat.displayLabel} (${categoryCounts[cat] ?? 0})'),
                      selected: _selectedCategory == cat,
                      onSelected: (_) => setState(() => _selectedCategory = _selectedCategory == cat ? null : cat),
                    ),
                    const SizedBox(width: 8),
                  ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices_other_rounded, size: 42, color: tokens.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            _selectedCategory == null
                                ? 'No devices adopted yet'
                                : 'No ${_selectedCategory!.displayLabel} adopted',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap Sync above to adopt Wi-Fi switches, sockets, fans, sensors, and other EH Home nodes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildDeviceCard(tokens, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(EHThemeTokens tokens, HubDeviceInfo device) {
    final fullName = HubUiHelpers.resolveFullDeviceName(device);
    final isOffline = !device.online;

    return Opacity(
      opacity: isOffline ? 0.72 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOffline ? tokens.borderSubtle : tokens.bluePrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    HubUiHelpers.categoryIcon(device.category),
                    color: isOffline ? tokens.textTertiary : tokens.bluePrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: tokens.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.roomName} • ${device.category.displayLabel}${device.model != null ? " • ${device.model}" : ""}',
                        style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            device.ipAddress.isNotEmpty
                                ? '${device.ipAddress} • ${isOffline ? "Unreachable" : "${device.latencyMs}ms"}'
                                : 'No LAN IP',
                            style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          HubUiHelpers.buildSignalPill(tokens, device.rssiDbm, device.online),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (choice) async {
                    if (choice == 'edit') {
                      final updated = await HubUiHelpers.showEditDeviceDialog(
                        context,
                        repo: widget.repository,
                        hubHostname: _state.hostname,
                        device: device,
                      );
                      if (updated) await _refresh();
                    } else if (choice == 'hw') {
                      if (!mounted) return;
                      await HubUiHelpers.showDeviceHardwareSettingsSheet(
                        context,
                        tokens: tokens,
                        repo: widget.repository,
                        device: device,
                      );
                    } else if (choice == 'remove') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Remove Device from Hub?'),
                          content: Text('Unadopt "$fullName" from Hub coordination?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.repository.removeHubDevice(hubHostname: _state.hostname, deviceId: device.id);
                        await _refresh();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit Name / Room / Type')),
                    PopupMenuItem(value: 'hw', child: Text('Hardware Settings')),
                    PopupMenuItem(value: 'remove', child: Text('Remove from Hub')),
                  ],
                ),
              ],
            ),
            if (isOffline) ...[
              const SizedBox(height: 10),
              SettingsStatusChip(
                label: 'Device Offline — Controls Locked',
                color: tokens.textTertiary,
                background: tokens.surfaceElevated,
                leading: Icon(Icons.cloud_off_rounded, size: 13, color: tokens.textTertiary),
              ),
            ],
            const SizedBox(height: 10),
            if (device.category == HubDeviceCategory.sensors)
              _buildSensorTelemetryRow(tokens, device)
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (int ch = 1; ch <= device.channelCount; ch++)
                    _buildChannelChip(tokens, device, ch),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTelemetryRow(EHThemeTokens tokens, HubDeviceInfo device) {
    final tel = device.telemetry;
    if (tel.isEmpty) {
      return Text(
        device.online ? 'Sensor online — awaiting telemetry sample' : 'Sensor offline — no live reading',
        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final e in tel.entries)
          Chip(
            label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildChannelChip(EHThemeTokens tokens, HubDeviceInfo device, int channelIndex) {
    final isPowered = device.channels[channelIndex] == true;
    final isOffline = !device.online;
    final prefix = device.category == HubDeviceCategory.fans && channelIndex == 1
        ? 'Fan'
        : 'CH$channelIndex';

    return ActionChip(
      avatar: Icon(
        isOffline ? Icons.lock_outline_rounded : Icons.power_settings_new_rounded,
        size: 14,
        color: isOffline
            ? tokens.textTertiary
            : (isPowered ? tokens.success : tokens.textTertiary),
      ),
      label: Text(
        '$prefix: ${isOffline ? "Offline" : (isPowered ? "ON" : "OFF")}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isOffline
              ? tokens.textTertiary
              : (isPowered ? tokens.success : tokens.textSecondary),
        ),
      ),
      backgroundColor: isOffline
          ? tokens.bgApp
          : (isPowered ? tokens.successContainer : tokens.surfaceElevated),
      side: BorderSide(
        color: isOffline
            ? tokens.borderSubtle
            : (isPowered ? tokens.success.withValues(alpha: 0.5) : tokens.borderSubtle),
      ),
      onPressed: isOffline
          ? null
          : () async {
              final newPower = !isPowered;
              final updatedDevices = _state.connectedDevices.map((d) {
                if (d.id != device.id) return d;
                final newCh = Map<int, bool>.from(d.channels);
                newCh[channelIndex] = newPower;
                return d.copyWith(channels: newCh);
              }).toList();
              setState(() => _state = _state.copyWith(connectedDevices: updatedDevices));
              final ok = await widget.repository.sendDeviceControl(
                hubHostname: _state.hostname,
                deviceId: device.id,
                channel: channelIndex,
                power: newPower,
              );
              if (!ok && mounted) {
                await _refresh();
              }
            },
    );
  }
}
