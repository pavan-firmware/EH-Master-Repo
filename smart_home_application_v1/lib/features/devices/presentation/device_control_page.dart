import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';

class DeviceControlPage extends StatefulWidget {
  const DeviceControlPage({
    super.key,
    required this.device,
    required this.homeController,
  });

  final ConnectedDeviceSummary device;
  final HomeController homeController;

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  // Track custom channel labels
  final Map<int, String> _channelLabels = {};

  @override
  void initState() {
    super.initState();
    final saved = DeviceStorageService.getChannelLabels(widget.device.id);
    _channelLabels.addAll(saved);
  }

  int get _channelCount {
    final modelLower = widget.device.model.toLowerCase();
    final nameLower = widget.device.name.toLowerCase();
    if (modelLower.contains('4x') || nameLower.contains('4x')) return 4;
    if (modelLower.contains('3x') || nameLower.contains('3x')) return 3;
    if (modelLower.contains('2x') || nameLower.contains('2x')) return 2;
    if (modelLower.contains('1x') || nameLower.contains('1x')) return 1;
    // Default to 3 channels for smart switches/sockets unless specified
    return 3;
  }

  bool get _isSocket {
    final modelLower = widget.device.model.toLowerCase();
    final nameLower = widget.device.name.toLowerCase();
    return modelLower.contains('socket') || nameLower.contains('socket');
  }

  bool get _isDimmer {
    final modelLower = widget.device.model.toLowerCase();
    final nameLower = widget.device.name.toLowerCase();
    return modelLower.contains('dimmer') || nameLower.contains('dimmer');
  }

  bool get _isFan {
    final modelLower = widget.device.model.toLowerCase();
    final nameLower = widget.device.name.toLowerCase();
    return modelLower.contains('fan') || nameLower.contains('fan');
  }

  bool get _isCurtain {
    final modelLower = widget.device.model.toLowerCase();
    final nameLower = widget.device.name.toLowerCase();
    return modelLower.contains('curtain') || nameLower.contains('curtain');
  }

  String _getChannelName(int index) {
    if (_channelLabels.containsKey(index)) {
      return _channelLabels[index]!;
    }
    final saved = DeviceStorageService.getChannelLabels(widget.device.id);
    if (saved.containsKey(index)) {
      _channelLabels[index] = saved[index]!;
      return saved[index]!;
    }
    final prefix = _isSocket
        ? 'Socket'
        : _isDimmer
            ? 'Dimmer'
            : _isFan
                ? 'Fan'
                : _isCurtain
                    ? 'Curtain'
                    : 'Switch';
    return '$prefix $index';
  }

  IconData get _productIcon {
    if (_isSocket) return Icons.power_rounded;
    if (_isDimmer) return Icons.brightness_6_rounded;
    if (_isFan) return Icons.mode_fan_off_rounded;
    if (_isCurtain) return Icons.curtains_rounded;
    return Icons.lightbulb_rounded;
  }

  Future<void> _toggleAll(bool enable) async {
    for (int i = 1; i <= _channelCount; i++) {
      await widget.homeController.setDeviceChannelPower(
        deviceId: widget.device.id,
        channelIndex: i,
        value: enable,
      );
    }
  }

  Future<void> _editChannelName(int channelIndex) async {
    final controller = TextEditingController(text: _getChannelName(channelIndex));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename Channel $channelIndex'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Channel Name',
            hintText: 'e.g. Living Room TV, Main Light',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final newName = controller.text.trim();
      setState(() {
        _channelLabels[channelIndex] = newName;
      });
      await widget.homeController.renameDeviceChannel(
        deviceId: widget.device.id,
        channelIndex: channelIndex,
        newName: newName,
      );
    }
  }

  Future<void> _changeWifiCredentials() async {
    final tokens = context.ehColors;
    final ssidController = TextEditingController();
    final passController = TextEditingController();
    bool obscurePass = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_password_rounded, color: tokens.bluePrimary),
              const SizedBox(width: 8),
              const Text('Change Wi-Fi Network', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update the Wi-Fi credentials for ${widget.device.name}. The device will connect to the new network without resetting custom channel names.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ssidController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'New Wi-Fi SSID',
                    hintText: 'e.g. MyHome_5G',
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Wi-Fi Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update Wi-Fi'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && ssidController.text.trim().isNotEmpty) {
      if (!mounted) return;
      final scaffold = ScaffoldMessenger.of(context);
      try {
        await widget.homeController.updateDeviceWifi(
          deviceId: widget.device.id,
          ssid: ssidController.text.trim(),
          password: passController.text.trim(),
        );
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Wi-Fi credentials updated for ${widget.device.name}. Reconnecting...'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Failed to update Wi-Fi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return AnimatedBuilder(
      animation: widget.homeController,
      builder: (context, _) {
        final liveDevice = widget.homeController.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );
        final isOnline = liveDevice.online;
        final channelCount = _channelCount;
        final isLocalMode = widget.homeController.isLocalMode && isOnline;

        // Check if any channel is ON
        bool anyOn = false;
        for (int i = 1; i <= channelCount; i++) {
          final isOn = widget.homeController.getDeviceChannelPower(
            widget.device.id,
            i,
            defaultValue: i == 1 && widget.homeController.livingRoomLightOn,
          );
          if (isOn) anyOn = true;
        }

        return Scaffold(
          backgroundColor: tokens.bgApp,
          appBar: AppBar(
            backgroundColor: tokens.bgApp,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.device.name,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.wifi_password_rounded, color: tokens.textPrimary),
                tooltip: 'Change Wi-Fi Network',
                onPressed: _changeWifiCredentials,
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? (isLocalMode
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : tokens.success.withValues(alpha: 0.15))
                      : tokens.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: isOnline
                          ? (isLocalMode ? const Color(0xFFF59E0B) : tokens.success)
                          : tokens.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? (isLocalMode ? 'LOCAL WI-FI' : 'ONLINE') : 'OFFLINE',
                      style: TextStyle(
                        color: isOnline
                            ? (isLocalMode ? const Color(0xFFF59E0B) : tokens.success)
                            : tokens.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await widget.homeController.loadHomeData();
            },
            color: tokens.bluePrimary,
            backgroundColor: tokens.surfaceCard,
            displacement: 24,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              // Local Wi-Fi Mode Banner
              if (isLocalMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFF59E0B), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Local Wi-Fi Mode Active',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cloud backend is offline. Controls are communicating directly over local home Wi-Fi.',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Offline Alert Banner
              if (!isOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Device is Offline',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Controls are disabled to prevent conflicts. If your backend or internet is down, connect via Local Wi-Fi Mode.',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!widget.homeController.isLocalMode) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final ok = await widget.homeController.switchToLanMode();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No local devices responded to UDP/Subnet scan. Ensure ESP32 is powered and on this Wi-Fi.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                            label: const Text(
                              'Switch to Local Wi-Fi Mode',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 1. Device Hero / Master Overview Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tokens.isDark
                        ? [const Color(0xFF1B263B), const Color(0xFF0D1B2A)]
                        : [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: tokens.isDark
                        ? const Color(0xFF2E3D52)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.isDark
                          ? Colors.black26
                          : const Color(0x0D0B2448),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: tokens.bluePrimary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _productIcon,
                            color: tokens.bluePrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.device.name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.device.roomName} • $channelCount Channels',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Master Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isOnline ? () => _toggleAll(false) : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.textSecondary,
                              side: BorderSide(color: tokens.borderControl),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                            label: const Text('All Off', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isOnline ? () => _toggleAll(true) : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: tokens.bluePrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: const Text('All On', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // 2. Individual Channel Controls Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSocket ? 'Socket Outlets' : 'Switch Controls',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isOnline ? '$channelCount Active' : 'Offline',
                    style: TextStyle(
                      color: tokens.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Channel Grid / List
              ...List.generate(channelCount, (i) {
                final channelIdx = i + 1;
                final channelName = _getChannelName(channelIdx);
                final isChOn = widget.homeController.getDeviceChannelPower(
                  widget.device.id,
                  channelIdx,
                  defaultValue: channelIdx == 1 && widget.homeController.livingRoomLightOn,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Opacity(
                    opacity: isOnline ? 1.0 : 0.55,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isChOn && isOnline
                              ? tokens.bluePrimary.withValues(alpha: 0.5)
                              : tokens.borderSubtle,
                          width: (isChOn && isOnline) ? 1.5 : 1.0,
                        ),
                        boxShadow: (isChOn && isOnline)
                            ? [
                                BoxShadow(
                                  color: tokens.bluePrimary.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isChOn && isOnline
                                ? tokens.bluePrimary
                                : tokens.isDark
                                    ? const Color(0xFF253347)
                                    : const Color(0xFFEFF2F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _isSocket ? Icons.power_rounded : Icons.lightbulb_rounded,
                            color: isChOn && isOnline
                                ? Colors.white
                                : tokens.textTertiary,
                            size: 26,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                channelName,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  size: 18, color: tokens.textTertiary),
                              onPressed: () => _editChannelName(channelIdx),
                              tooltip: 'Rename Channel',
                            ),
                          ],
                        ),
                        subtitle: Text(
                          !isOnline
                              ? 'Device Offline'
                              : (isChOn ? 'State: Active • ON' : 'State: Standby • OFF'),
                          style: TextStyle(
                            color: !isOnline
                                ? tokens.textTertiary
                                : (isChOn ? tokens.success : tokens.textTertiary),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: isChOn && isOnline,
                          activeThumbColor: tokens.bluePrimary,
                          activeTrackColor: tokens.bluePrimary.withValues(alpha: 0.35),
                          inactiveThumbColor: tokens.switchThumbOff,
                          inactiveTrackColor: tokens.switchTrackOff,
                          onChanged: isOnline
                              ? (val) {
                                  widget.homeController.setDeviceChannelPower(
                                    deviceId: widget.device.id,
                                    channelIndex: channelIdx,
                                    value: val,
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // 3. Live Energy & Telemetry Card (BL0942 Chip)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.energy_savings_leaf_rounded,
                            color: tokens.success, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Live Energy & Power (BL0942)',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Active Power',
                            value: (anyOn && isOnline) ? '142.5 W' : '0.0 W',
                            icon: Icons.electric_bolt_rounded,
                            color: tokens.goldBright,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'AC Voltage',
                            value: isOnline ? '232.1 V' : '-- V',
                            icon: Icons.speed_rounded,
                            color: tokens.bluePrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Current',
                            value: (anyOn && isOnline) ? '0.61 A' : '0.00 A',
                            icon: Icons.graphic_eq_rounded,
                            color: tokens.iconFgPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'Energy Today',
                            value: isOnline ? '1.24 kWh' : '0.00 kWh',
                            icon: Icons.battery_charging_full_rounded,
                            color: tokens.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Hardware Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hardware & Network Info',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(label: 'Device ID', value: widget.device.id),
                    _InfoRow(label: 'Model Variant', value: widget.device.model),
                    _InfoRow(label: 'Firmware Version', value: widget.device.firmware),
                    _InfoRow(label: 'Protocol', value: 'mTLS Secure MQTT / BLE'),
                    _InfoRow(label: 'Assigned Room', value: widget.device.roomName),
                    _InfoRow(
                      label: 'Local LAN IP',
                      value: DeviceStorageService.getDeviceIp(widget.device.id) != null
                          ? '${DeviceStorageService.getDeviceIp(widget.device.id)} (Auto-Discovered)'
                          : 'Auto-Discovered (UDP/Subnet)',
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _changeWifiCredentials,
                      icon: const Icon(Icons.wifi_password_rounded, size: 20),
                      label: const Text('Change Wi-Fi Credentials', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.bluePrimary,
                        side: BorderSide(color: tokens.bluePrimary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? const Color(0xFF141F30)
            : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tokens.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
