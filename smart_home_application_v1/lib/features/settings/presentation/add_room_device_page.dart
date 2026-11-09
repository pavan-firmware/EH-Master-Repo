import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../connection/presentation/connection_page.dart';
import 'settings_ui.dart';
import 'help/help_support_page.dart';

/// Consumer-facing entry point for commissioning.
class AddRoomDevicePage extends StatefulWidget {
  const AddRoomDevicePage({
    super.key,
    required this.repository,
    this.onStartSecureSetup,
    this.connectionState,
    this.homeController,
  });

  final SettingsRepository repository;
  final Future<ConnectionResult> Function()? onStartSecureSetup;
  final HomeConnectionState? connectionState;
  final HomeController? homeController;

  @override
  State<AddRoomDevicePage> createState() => _AddRoomDevicePageState();
}

class _AddRoomDevicePageState extends State<AddRoomDevicePage> {
  late Future<List<DiscoveredRoomDevice>> _devices;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _devices = widget.repository.getNearbyDevices();
    widget.homeController?.addListener(_onHomeStateChanged);
  }

  void _onHomeStateChanged() {
    if (mounted) _refresh();
  }

  @override
  void didUpdateWidget(covariant AddRoomDevicePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeController != widget.homeController) {
      oldWidget.homeController?.removeListener(_onHomeStateChanged);
      widget.homeController?.addListener(_onHomeStateChanged);
    }
  }

  @override
  void dispose() {
    widget.homeController?.removeListener(_onHomeStateChanged);
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _refreshing = true;
      _devices = widget.repository.getNearbyDevices().whenComplete(() {
        if (mounted) setState(() => _refreshing = false);
      });
    });
  }

  Future<void> _openSecureSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectionPage(
          onStart: widget.onStartSecureSetup,
          connectionState: widget.connectionState,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  void _selectPreviewDevice(DiscoveredRoomDevice device) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return NestedSettingsScaffold(
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
            color: tokens.isDark ? tokens.surfaceCard : const Color(0xFFF3F7FF),
            borderColor: tokens.bluePrimary.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.bluePrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bluetooth_searching_rounded, color: tokens.bluePrimary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pair a New Device',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Connect via Bluetooth Low Energy (BLE) or Wi-Fi provisioning.',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _openSecureSetup,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Start Setup & Pairing', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SettingsSurface(
            color: tokens.isDark ? tokens.surfaceCard : const Color(0xFFF3F7FF),
            borderColor: tokens.isDark ? tokens.borderControl : const Color(0xFFD9E5FF),
            padding: const EdgeInsets.all(18),
            child: Row(
            children: [
              const _ScanningRadar(),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finding nearby devices…',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Make sure your device is powered on and nearby.',
                      style: TextStyle(
                        color: tokens.textSecondary,
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
                            style: TextStyle(
                              color: tokens.bluePrimary,
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
            Expanded(
              child: Text(
                'Nearby devices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
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
        const SizedBox(height: 24),
        const SettingsSectionTitle('Need help?'),
        SettingsSurface(
          child: Column(
            children: [
              _HelpRow(
                icon: Icons.bluetooth_rounded,
                text: 'Make sure Bluetooth is on',
                divider: true,
                settingsRepository: widget.repository,
                homeController: widget.homeController,
              ),
              _HelpRow(
                icon: Icons.power_settings_new_rounded,
                text: 'Power on your device',
                divider: true,
                settingsRepository: widget.repository,
                homeController: widget.homeController,
              ),
              _HelpRow(
                icon: Icons.location_on_outlined,
                text: 'Keep your device and phone close',
                divider: true,
                settingsRepository: widget.repository,
                homeController: widget.homeController,
              ),
              _HelpRow(
                icon: Icons.info_outline_rounded,
                text: 'View troubleshooting guide',
                settingsRepository: widget.repository,
                homeController: widget.homeController,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  }

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
  Widget build(BuildContext context) => const FittedBox(
    alignment: Alignment.centerLeft,
    fit: BoxFit.scaleDown,
    child: Row(
      children: [
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
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: active ? tokens.bluePrimary : (tokens.isDark ? tokens.surfaceCard : Colors.white),
          foregroundColor: active ? Colors.white : tokens.textPrimary,
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
            color: active ? tokens.bluePrimary : tokens.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SizedBox(
      width: 28,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 21),
        child: Divider(
          color: tokens.isDark ? tokens.borderControl : const Color(0xFFD7DFEC),
          thickness: 1.5,
        ),
      ),
    );
  }
}

class _ScanningRadar extends StatelessWidget {
  const _ScanningRadar();
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.isDark
            ? tokens.bluePrimary.withValues(alpha: 0.15)
            : const Color(0xFFDDE8FF),
      ),
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.isDark
              ? tokens.bluePrimary.withValues(alpha: 0.28)
              : const Color(0xFFCBDBFF),
        ),
        child: Icon(
          Icons.radar_rounded,
          color: tokens.bluePrimary,
          size: 34,
        ),
      ),
    );
  }
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
      'switch' => Icons.toggle_on_rounded,
      'socket' || 'plug' => Icons.power_outlined,
      _ => Icons.devices_other_rounded,
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProductImageWidget(
                      imageUrl: device.model,
                      size: 40,
                      borderRadius: BorderRadius.circular(10),
                      fallbackIcon: icon,
                      placeholderColor: SettingsColors.blue.withValues(alpha: 0.1),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 14,
                          color: SettingsColors.blue,
                        ),
                      ),
                    ),
                  ],
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
                        style: const TextStyle(
                          color: SettingsColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          SettingsStatusChip(
                            label: 'New device',
                            color: SettingsColors.green,
                            background: SettingsColors.paleGreen,
                          ),
                          if (device.signalLabel.isNotEmpty)
                            Text(
                              device.signalLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SettingsColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
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
                      color: strong
                          ? SettingsColors.green
                          : SettingsColors.orange,
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
    this.settingsRepository,
    this.homeController,
  });
  final IconData icon;
  final String text;
  final bool divider;
  final SettingsRepository? settingsRepository;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        child: ListTile(
          minTileHeight: 52,
          leading: Icon(icon, color: SettingsColors.muted),
          title: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SettingsColors.muted,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelpSupportPage(
                initialTopic: 'troubleshooting',
                settingsRepository: settingsRepository,
                homeController: homeController,
              ),
            ),
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
        const SizedBox(height: 8),
        const Text(
          'Make sure Bluetooth is turned on and granted. Power on your device and put it in pairing mode. Keep your device close to your phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SettingsColors.muted, height: 1.4),
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
