import 'package:flutter/material.dart';
import '../../../../app/home_controller.dart';
import '../../../../core/services/device_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/hub_repository.dart';
import '../../domain/models/hub_models.dart';

/// Shared UI helpers across Hub overview and nested Hub management screens.
class HubUiHelpers {
  HubUiHelpers._();

  static String resolveFullDeviceName(HubDeviceInfo device) {
    String? appCustomName;
    String? appModelVariant;

    final ctrlDevices = HomeController.instance?.devices ?? const [];
    for (final d in [...ctrlDevices, ...DeviceStorageService.cachedDevices]) {
      if (d.id.toLowerCase() == device.id.toLowerCase()) {
        if (!HubDeviceInfo.isGenericAutoName(d.name)) {
          appCustomName = d.name;
        }
        if (d.model.isNotEmpty) {
          appModelVariant = d.model;
        }
        break;
      }
    }

    return device.resolveCanonicalName(
      appCustomName: appCustomName,
      appModelVariant: appModelVariant,
    );
  }

  static IconData categoryIcon(HubDeviceCategory category) {
    switch (category) {
      case HubDeviceCategory.switches:
        return Icons.toggle_on_rounded;
      case HubDeviceCategory.sockets:
        return Icons.power_rounded;
      case HubDeviceCategory.fans:
        return Icons.mode_fan_off_rounded;
      case HubDeviceCategory.lighting:
        return Icons.lightbulb_outline_rounded;
      case HubDeviceCategory.controllers:
        return Icons.settings_remote_rounded;
      case HubDeviceCategory.sensors:
        return Icons.sensors_rounded;
      case HubDeviceCategory.others:
        return Icons.devices_other_rounded;
    }
  }

  static Widget buildSignalPill(EHThemeTokens tokens, int? rssiDbm, bool online) {
    final String label;
    final Color color;
    final int bars;
    if (!online) {
      label = 'Offline';
      color = tokens.textTertiary;
      bars = 0;
    } else if (rssiDbm == null) {
      label = 'Connected';
      color = tokens.success;
      bars = 3;
    } else if (rssiDbm >= -60) {
      label = 'High ($rssiDbm dBm)';
      color = tokens.success;
      bars = 3;
    } else if (rssiDbm >= -74) {
      label = 'Med ($rssiDbm dBm)';
      color = const Color(0xFFF59E0B);
      bars = 2;
    } else {
      label = 'Low ($rssiDbm dBm)';
      color = const Color(0xFFEF4444);
      bars = 1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int b = 1; b <= 3; b++)
            Container(
              width: 2.5,
              height: 3.0 + b * 2.5,
              margin: const EdgeInsets.only(right: 1.5),
              decoration: BoxDecoration(
                color: b <= bars ? color : tokens.borderSubtle,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  static Widget buildMetricTile(
    EHThemeTokens tokens,
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: tokens.textSecondary),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: tokens.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> showEditDeviceDialog(
    BuildContext context, {
    required HubRepository repo,
    required String hubHostname,
    required HubDeviceInfo device,
  }) async {
    final nameCtrl = TextEditingController(text: resolveFullDeviceName(device));
    final roomCtrl = TextEditingController(text: device.roomName);
    var selectedCategory = device.category;
    bool saved = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Edit Adopted Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device Display Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<HubDeviceCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Device Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: HubDeviceCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.displayLabel)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedCategory = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final ok = await repo.updateHubDevice(
                  hubHostname: hubHostname,
                  deviceId: device.id,
                  name: nameCtrl.text.trim(),
                  roomName: roomCtrl.text.trim().isEmpty ? 'Unassigned' : roomCtrl.text.trim(),
                  category: selectedCategory,
                );
                saved = ok;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
    return saved;
  }

  static Future<void> showDeviceHardwareSettingsSheet(
    BuildContext context, {
    required EHThemeTokens tokens,
    required HubRepository repo,
    required HubDeviceInfo device,
  }) async {
    int powerOnMode = 2;
    bool childLock = false;
    bool loading = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          if (loading) {
            repo.getDeviceSettings(deviceIp: device.ipAddress).then((settings) {
              if (!modalCtx.mounted) return;
              setModalState(() {
                if (settings != null) {
                  powerOnMode = (settings['powerOnMode'] as num?)?.toInt() ?? 2;
                  childLock = settings['childLock'] == true;
                }
                loading = false;
              });
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hardware Device Settings',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(modalCtx)),
                  ],
                ),
                Text(
                  '${resolveFullDeviceName(device)} • ${device.ipAddress}',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                if (loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else ...[
                  Text('Power-On Behavior (After Outage)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: RadioGroup<int>(
                      groupValue: powerOnMode,
                      onChanged: (v) => setModalState(() => powerOnMode = v ?? 2),
                      child: const Column(
                        children: [
                          RadioListTile<int>(title: Text('Restore Last State'), value: 2),
                          Divider(height: 1),
                          RadioListTile<int>(title: Text('Always OFF (Safe Mode)'), value: 0),
                          Divider(height: 1),
                          RadioListTile<int>(title: Text('Always ON'), value: 1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text('Child Lock (Physical Touch)'),
                    subtitle: const Text('Locks wall touch while Hub/App remain active'),
                    value: childLock,
                    activeThumbColor: tokens.bluePrimary,
                    onChanged: (v) => setModalState(() => childLock = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(modalCtx);
                        await repo.setDevicePowerOnMode(deviceIp: device.ipAddress, mode: powerOnMode);
                        await repo.setDeviceChildLock(deviceIp: device.ipAddress, enabled: childLock);
                      },
                      child: const Text('Save Hardware Settings'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
