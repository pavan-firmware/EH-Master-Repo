import 'package:flutter/material.dart';

import '../../../core/models/device_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../connection/presentation/connection_page.dart';
import 'settings_ui.dart';

/// Consumer-facing entry point for commissioning. It uses preview discovery
/// information only for layout validation; actual connection is always handed
/// to [ConnectionPage], which performs the authenticated nearby flow.
class AddRoomDevicePage extends StatefulWidget {
  const AddRoomDevicePage({
    super.key,
    required this.repository,
    this.onStartSecureSetup,
    this.connectionState,
  });

  final SettingsRepository repository;
  final Future<ConnectionResult> Function()? onStartSecureSetup;
  final HomeConnectionState? connectionState;

  @override
  State<AddRoomDevicePage> createState() => _AddRoomDevicePageState();
}

class _AddRoomDevicePageState extends State<AddRoomDevicePage> {
  late Future<List<DiscoveredRoomDevice>> _devices = widget.repository
      .getNearbyDevices();
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      setState(() {
        _devices = widget.repository.getNearbyDevices();
        _refreshing = false;
      });
    }
  }

  void _openSecureSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectionPage(
          onStart: widget.onStartSecureSetup,
          connectionState: widget.connectionState,
        ),
      ),
    );
  }

  void _selectPreviewDevice(DiscoveredRoomDevice device) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                device.model,
                style: const TextStyle(color: SettingsColors.muted),
              ),
              const SizedBox(height: 14),
              const Text(
                'To protect your home, EH Home verifies the real nearby device before setup continues.',
                style: TextStyle(color: SettingsColors.muted, height: 1.35),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openSecureSetup();
                  },
                  icon: const Icon(Icons.bluetooth_searching_rounded),
                  label: const Text('Verify nearby device'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Add a room device',
    subtitle: 'Set up a nearby EH Home device.',
    actions: [
      IconButton(
        tooltip: 'Setup help',
        onPressed: () => _showHelp(context),
        icon: const Icon(Icons.help_outline_rounded),
      ),
    ],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        const _SetupStepper(),
        const SizedBox(height: 22),
        SettingsSurface(
          color: const Color(0xFFF3F7FF),
          borderColor: const Color(0xFFD9E5FF),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const _ScanningRadar(),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finding nearby devices…',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Make sure your device is powered on and nearby.',
                      style: TextStyle(
                        color: SettingsColors.muted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_refreshing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_refreshing) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _refreshing
                                ? 'Refreshing nearby devices'
                                : 'Ready to scan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SettingsColors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nearby devices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Refresh'),
            ),
          ],
        ),
        FutureBuilder<List<DiscoveredRoomDevice>>(
          future: _devices,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SettingsSurface(child: SizedBox(height: 192));
            }
            final devices = snapshot.data ?? const <DiscoveredRoomDevice>[];
            if (devices.isEmpty) {
              return _NoDevices(onFindDevices: _openSecureSetup);
            }
            return SettingsSurface(
              child: Column(
                children: [
                  for (var index = 0; index < devices.length; index++)
                    _NearbyDeviceRow(
                      device: devices[index],
                      showDivider: index != devices.length - 1,
                      onTap: () => _selectPreviewDevice(devices[index]),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SettingsSurface(
          color: const Color(0xFFF3F7FF),
          borderColor: const Color(0xFFD9E5FF),
          child: SettingsListItem(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Other ways to add',
            subtitle: 'Scan a QR code or enter a setup code',
            onTap: () => showSettingsUnavailable(
              context,
              message:
                  'QR setup will be available with the secure device identity service.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionTitle('Need help?'),
        SettingsSurface(
          child: const Column(
            children: [
              _HelpRow(
                icon: Icons.bluetooth_rounded,
                text: 'Make sure Bluetooth is on',
                divider: true,
              ),
              _HelpRow(
                icon: Icons.power_settings_new_rounded,
                text: 'Power on your device',
                divider: true,
              ),
              _HelpRow(
                icon: Icons.location_on_outlined,
                text: 'Keep your device and phone close',
                divider: true,
              ),
              _HelpRow(
                icon: Icons.info_outline_rounded,
                text: 'View troubleshooting guide',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nearby setup help',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'Turn on your device, enable Bluetooth, and keep your phone nearby. EH Home will verify the device before requesting any Wi-Fi or home-access details.',
              style: TextStyle(color: SettingsColors.muted, height: 1.35),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SetupStepper extends StatelessWidget {
  const _SetupStepper();
  @override
  Widget build(BuildContext context) => FittedBox(
    alignment: Alignment.centerLeft,
    fit: BoxFit.scaleDown,
    child: Row(
      children: const [
        _Step(number: '1', label: 'Discover', active: true),
        _StepLine(),
        _Step(number: '2', label: 'Connect'),
        _StepLine(),
        _Step(number: '3', label: 'Configure'),
        _StepLine(),
        _Step(number: '4', label: 'Complete'),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label, this.active = false});
  final String number;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: active ? SettingsColors.blue : Colors.white,
        foregroundColor: active ? Colors.white : SettingsColors.ink,
        child: Text(
          number,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: active ? SettingsColors.blue : SettingsColors.muted,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}

class _StepLine extends StatelessWidget {
  const _StepLine();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28,
    child: Padding(
      padding: EdgeInsets.only(bottom: 21),
      child: Divider(color: Color(0xFFD7DFEC), thickness: 1.5),
    ),
  );
}

class _ScanningRadar extends StatelessWidget {
  const _ScanningRadar();
  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: 92,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFDDE8FF),
    ),
    child: Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFCBDBFF),
      ),
      child: const Icon(
        Icons.radar_rounded,
        color: SettingsColors.blue,
        size: 34,
      ),
    ),
  );
}

class _NearbyDeviceRow extends StatelessWidget {
  const _NearbyDeviceRow({
    required this.device,
    required this.showDivider,
    required this.onTap,
  });
  final DiscoveredRoomDevice device;
  final bool showDivider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final icon = switch (device.icon) {
      'mist' => Icons.water_drop_outlined,
      'light' => Icons.lightbulb_outline_rounded,
      _ => Icons.power_outlined,
    };
    final strong = device.signal == DeviceConnection.online;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  color: strong ? SettingsColors.green : SettingsColors.orange,
                  size: 13,
                ),
                const SizedBox(width: 10),
                SettingsIconBadge(
                  icon: icon,
                  size: 40,
                  color: SettingsColors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        device.model,
                        style: const TextStyle(color: SettingsColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SettingsStatusChip(
                          label: 'New device',
                          color: SettingsColors.green,
                          background: SettingsColors.paleGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_rounded,
                      color: strong ? SettingsColors.green : SettingsColors.orange,
                      size: 18,
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SettingsColors.muted,
                    ),
                  ],
                ),
              ],
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
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.icon,
    required this.text,
    this.divider = false,
  });
  final IconData icon;
  final String text;
  final bool divider;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        child: ListTile(
          minTileHeight: 52,
          leading: Icon(icon, color: SettingsColors.muted),
          title: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SettingsColors.muted,
          ),
          onTap: () => showSettingsUnavailable(
            context,
            message:
                'Troubleshooting guidance will be available with secure setup support.',
          ),
        ),
      ),
      if (divider)
        const Padding(
          padding: EdgeInsets.only(left: 68),
          child: Divider(height: 1, color: SettingsColors.line),
        ),
    ],
  );
}

class _NoDevices extends StatelessWidget {
  const _NoDevices({required this.onFindDevices});
  final VoidCallback onFindDevices;
  @override
  Widget build(BuildContext context) => SettingsSurface(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(
          Icons.bluetooth_disabled_rounded,
          size: 42,
          color: SettingsColors.muted,
        ),
        const SizedBox(height: 12),
        const Text(
          'No nearby devices found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Make sure your device is powered on and nearby.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SettingsColors.muted),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onFindDevices,
          child: const Text('Find devices'),
        ),
      ],
    ),
  );
}
