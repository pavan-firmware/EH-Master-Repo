import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/capabilities/models/capability_models.dart';
import '../../../core/capabilities/repositories/product_catalog_repository.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/services/product_asset_resolver.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../automations/presentation/active_routine_guard.dart';

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
  ProductVariantDefinition? _variant;
  String? _loadedModel;

  @override
  void initState() {
    super.initState();
    final saved = DeviceStorageService.getChannelLabels(widget.device.id);
    _channelLabels.addAll(saved);
    _loadVariantMetadata(widget.device.model);
  }

  void _checkAndRefreshVariant(String model) {
    if (_loadedModel != model) {
      _loadedModel = model;
      _loadVariantMetadata(model);
    }
  }

  Future<void> _loadVariantMetadata(String model) async {
    final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
      variantId: model,
      deviceName: widget.device.name,
    );
    final v = await ProductCatalogRepository.instance.getProductVariant(canonical);
    if (v != null && mounted) {
      setState(() {
        _variant = v;
      });
    }
  }

  int _channelCountFor(ConnectedDeviceSummary liveDevice) {
    final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
      variantId: liveDevice.model,
      deviceName: liveDevice.name,
    );
    if (_variant != null && _variant!.productVariantId == canonical) {
      return _variant!.channelCount;
    }
    final nameLower = liveDevice.name.toLowerCase();
    if (nameLower.contains('4x') || canonical.contains('4x')) return 4;
    if (nameLower.contains('3x') || canonical.contains('3x')) return 3;
    if (nameLower.contains('2x') || canonical.contains('2x')) return 2;
    if (nameLower.contains('1x') || canonical.contains('1x')) return 1;
    if (_isSocketFor(liveDevice)) return 2;
    return 3;
  }

  bool _isSocketFor(ConnectedDeviceSummary liveDevice) {
    final canonical = MockProductCatalogRepository.resolveCanonicalProductVariant(
      variantId: liveDevice.model,
      deviceName: liveDevice.name,
    );
    if (canonical.contains('socket') || canonical.contains('plug') || canonical.contains('sk')) {
      return true;
    }
    if (_variant != null && _variant!.productVariantId == canonical) {
      return _variant!.productFamily == 'smart_socket' || _variant!.capabilities.contains('socket');
    }
    final norm = MockProductCatalogRepository.normalizeVariantId(
      liveDevice.model.isNotEmpty ? liveDevice.model : liveDevice.name,
    );
    if (norm.contains('socket')) return true;
    final modelLower = liveDevice.model.toLowerCase();
    final nameLower = liveDevice.name.toLowerCase();
    return modelLower.contains('socket') ||
        nameLower.contains('socket') ||
        modelLower.contains('sk') ||
        nameLower.contains('sk');
  }

  bool _isDimmerFor(ConnectedDeviceSummary liveDevice) {
    if (_variant != null && _variant!.productVariantId == liveDevice.model) {
      return _variant!.capabilities.contains('brightness') || _variant!.capabilities.contains('dimmer');
    }
    final modelLower = liveDevice.model.toLowerCase();
    final nameLower = liveDevice.name.toLowerCase();
    return modelLower.contains('dimmer') || nameLower.contains('dimmer');
  }

  bool _isFanFor(ConnectedDeviceSummary liveDevice) {
    if (_variant != null && _variant!.productVariantId == liveDevice.model) {
      return _variant!.productFamily == 'smart_fan' || _variant!.capabilities.contains('fan_speed');
    }
    final modelLower = liveDevice.model.toLowerCase();
    final nameLower = liveDevice.name.toLowerCase();
    return modelLower.contains('fan') || nameLower.contains('fan');
  }

  bool _isCurtainFor(ConnectedDeviceSummary liveDevice) {
    if (_variant != null && _variant!.productVariantId == liveDevice.model) {
      return _variant!.capabilities.contains('curtain');
    }
    final modelLower = liveDevice.model.toLowerCase();
    final nameLower = liveDevice.name.toLowerCase();
    return modelLower.contains('curtain') || nameLower.contains('curtain');
  }

  bool _hasEnergyMonitoringFor(ConnectedDeviceSummary liveDevice) {
    if (_variant != null && _variant!.productVariantId == liveDevice.model) {
      return _variant!.hasEnergyMetering;
    }
    final modelLower = liveDevice.model.toLowerCase();
    final nameLower = liveDevice.name.toLowerCase();
    if (modelLower.contains('-em') || nameLower.contains('energy') || modelLower.contains('energy')) {
      return true;
    }
    return false;
  }

  String _getChannelName(int index, ConnectedDeviceSummary liveDevice) {
    if (liveDevice.id.isNotEmpty) {
      final savedLive = DeviceStorageService.getChannelLabels(liveDevice.id);
      if (savedLive.containsKey(index) && savedLive[index]!.trim().isNotEmpty) {
        _channelLabels[index] = savedLive[index]!;
        return savedLive[index]!;
      }
    }
    if (widget.device.id.isNotEmpty) {
      final savedWidget = DeviceStorageService.getChannelLabels(widget.device.id);
      if (savedWidget.containsKey(index) && savedWidget[index]!.trim().isNotEmpty) {
        _channelLabels[index] = savedWidget[index]!;
        return savedWidget[index]!;
      }
    }
    if (_channelLabels.containsKey(index) && _channelLabels[index]!.trim().isNotEmpty) {
      return _channelLabels[index]!;
    }
    final prefix = _isSocketFor(liveDevice)
        ? 'Socket'
        : _isDimmerFor(liveDevice)
            ? 'Dimmer'
            : _isFanFor(liveDevice)
                ? 'Fan'
                : _isCurtainFor(liveDevice)
                    ? 'Curtain'
                    : 'Switch';

    if (_variant != null && _variant!.channels.length >= index) {
      final vLabel = _variant!.channels[index - 1].defaultLabel.trim();
      if (vLabel.isNotEmpty && !vLabel.startsWith('Channel ')) {
        return vLabel;
      }
    }
    return '$prefix $index';
  }

  IconData _productIconFor(ConnectedDeviceSummary liveDevice) {
    if (_isSocketFor(liveDevice)) return Icons.power_rounded;
    if (_isDimmerFor(liveDevice)) return Icons.brightness_6_rounded;
    if (_isFanFor(liveDevice)) return Icons.mode_fan_off_rounded;
    if (_isCurtainFor(liveDevice)) return Icons.curtains_rounded;
    return Icons.lightbulb_rounded;
  }

  Future<void> _toggleAll(bool enable, int channelCount) async {
    for (int i = 1; i <= channelCount; i++) {
      await widget.homeController.setDeviceChannelPower(
        deviceId: widget.device.id,
        channelIndex: i,
        value: enable,
      );
    }
  }

  Future<void> _editChannelName(int channelIndex, ConnectedDeviceSummary liveDevice) async {
    final tokens = context.ehColors;
    final targetDevId = (liveDevice.id.isNotEmpty ? liveDevice.id : widget.device.id).trim();
    final nameController = TextEditingController(text: _getChannelName(channelIndex, liveDevice));
    var currentAlertConfig = widget.homeController.getChannelAlertConfig(targetDevId, channelIndex);
    final candidates = [
      targetDevId,
      liveDevice.id,
      widget.device.id,
      liveDevice.name,
      widget.device.name,
      'esp32_device',
    ];
    for (final cand in candidates) {
      if (cand.isNotEmpty) {
        final cfg = widget.homeController.getChannelAlertConfig(cand, channelIndex);
        if (cfg.enabled || (currentAlertConfig.customMessage.isEmpty && cfg.customMessage.isNotEmpty)) {
          currentAlertConfig = cfg;
          if (cfg.enabled) break;
        }
      }
    }
    
    bool alertEnabled = currentAlertConfig.enabled;
    bool alertOnOn = currentAlertConfig.alertOnTurnOn;
    bool alertOnOff = currentAlertConfig.alertOnTurnOff;
    if (alertEnabled && !alertOnOn && !alertOnOff) {
      alertOnOn = true;
      alertOnOff = true;
    }
    final messageController = TextEditingController(text: currentAlertConfig.customMessage);

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: tokens.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.bluePrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.tune_rounded, color: tokens.bluePrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control $channelIndex Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            liveDevice.name,
                            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Control Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  autofocus: false,
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Living Room TV, Main AC, Geyser',
                    prefixIcon: Icon(Icons.edit_outlined, size: 20, color: tokens.bluePrimary),
                    filled: true,
                    fillColor: tokens.isDark ? const Color(0xFF141F30) : const Color(0xFFF4F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Activity Alert Notification Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.isDark
                        ? const Color(0xFF141F30)
                        : const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: alertEnabled
                          ? tokens.bluePrimary.withValues(alpha: 0.4)
                          : tokens.borderSubtle,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: alertEnabled
                                        ? tokens.bluePrimary.withValues(alpha: 0.18)
                                        : tokens.textTertiary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: alertEnabled ? tokens.bluePrimary : tokens.textTertiary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Activity Notifications',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: alertEnabled,
                            onChanged: (val) {
                              setSheetState(() {
                                alertEnabled = val;
                                if (val && !alertOnOn && !alertOnOff) {
                                  alertOnOn = true;
                                  alertOnOff = true;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get notified when this specific control changes state.',
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      ),
                      if (alertEnabled) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Notify When',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTriggerButton(
                                label: 'ON Only',
                                isSelected: alertOnOn && !alertOnOff,
                                icon: Icons.power_rounded,
                                tokens: tokens,
                                onTap: () {
                                  setSheetState(() {
                                    alertOnOn = true;
                                    alertOnOff = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTriggerButton(
                                label: 'OFF Only',
                                isSelected: !alertOnOn && alertOnOff,
                                icon: Icons.power_off_rounded,
                                tokens: tokens,
                                onTap: () {
                                  setSheetState(() {
                                    alertOnOn = false;
                                    alertOnOff = true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTriggerButton(
                                label: 'Both ON/OFF',
                                isSelected: alertOnOn && alertOnOff,
                                icon: Icons.sync_alt_rounded,
                                tokens: tokens,
                                onTap: () {
                                  setSheetState(() {
                                    alertOnOn = true;
                                    alertOnOff = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Custom Alert Message (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: messageController,
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Geyser is running! Remember to turn off.',
                            prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: tokens.bluePrimary),
                            filled: true,
                            fillColor: tokens.surfaceCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: tokens.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: tokens.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: tokens.bluePrimary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: tokens.borderSubtle),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.bluePrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      ),
    );

    if (saved == true && mounted) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty) {
        _channelLabels[channelIndex] = newName;
      }

      final newConfig = ChannelAlertConfig(
        enabled: alertEnabled,
        alertOnTurnOn: alertOnOn,
        alertOnTurnOff: alertOnOff,
        customMessage: messageController.text.trim(),
      );

      final devIds = <String>{
        if (targetDevId.isNotEmpty) targetDevId,
        if (liveDevice.id.isNotEmpty) liveDevice.id,
        if (widget.device.id.isNotEmpty) widget.device.id,
        if (liveDevice.name.isNotEmpty) liveDevice.name,
        if (widget.device.name.isNotEmpty) widget.device.name,
        'esp32_device',
      };

      for (final dId in devIds) {
        if (newName.isNotEmpty) {
          await widget.homeController.renameDeviceChannel(
            deviceId: dId,
            channelIndex: channelIndex,
            newName: newName,
          );
        }
        await widget.homeController.setChannelAlertConfig(
          dId,
          channelIndex,
          newConfig,
        );
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Settings saved for ${newName.isNotEmpty ? newName : "Channel $channelIndex"}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildTriggerButton({
    required String label,
    required bool isSelected,
    required IconData icon,
    required dynamic tokens,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.bluePrimary.withValues(alpha: 0.18)
              : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? tokens.bluePrimary
                : tokens.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tokens.bluePrimary : tokens.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? tokens.bluePrimary : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureDeviceIp(ConnectedDeviceSummary liveDevice) async {
    final tokens = context.ehColors;
    final currentIp = LocalLanDeviceService.instance.getDeviceIp(liveDevice.id) ?? '192.168.0.106';
    final ipController = TextEditingController(text: currentIp);
    String? pingStatus;
    bool isPinging = false;
    bool pingSuccess = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.router_rounded, color: tokens.bluePrimary),
              const SizedBox(width: 8),
              const Text('Device Local IP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure direct LAN IP for "${liveDevice.name}". When in LAN or Auto mode, controls communicate directly to this IP.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Device IP Address',
                  hintText: 'e.g. 192.168.0.106',
                  prefixIcon: const Icon(Icons.lan_rounded),
                  suffixIcon: IconButton(
                    icon: isPinging
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_ping_rounded),
                    tooltip: 'Test Ping',
                    onPressed: isPinging
                        ? null
                        : () async {
                            setDialogState(() {
                              isPinging = true;
                              pingStatus = null;
                            });
                            final testIp = ipController.text.trim();
                            final ok = await LocalLanDeviceService.instance.pingDevice(
                              deviceId: liveDevice.id,
                              explicitIp: testIp,
                            );
                            setDialogState(() {
                              isPinging = false;
                              pingSuccess = ok;
                              pingStatus = ok ? 'Connected! Responding directly (<10ms).' : 'No response from $testIp';
                            });
                          },
                  ),
                ),
              ),
              if (pingStatus != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      pingSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: pingSuccess ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pingStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pingSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newIp = ipController.text.trim();
                if (newIp.isNotEmpty) {
                  LocalLanDeviceService.instance.registerDeviceIp(liveDevice.id, newIp);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved LAN IP $newIp for ${liveDevice.name}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save IP'),
            ),
          ],
        ),
      ),
    );
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


  Future<void> _changeRoom(ConnectedDeviceSummary liveDevice) async {
    final tokens = context.ehColors;
    final Set<String> roomSet = {};
    for (final r in widget.homeController.rooms) {
      if (r.name.trim().isNotEmpty && r.name.toLowerCase() != 'unassigned') {
        roomSet.add(r.name.trim());
      }
    }
    final stored = await DeviceStorageService().loadRooms();
    roomSet.addAll(stored.where((r) => r.trim().isNotEmpty && r.toLowerCase() != 'unassigned'));
    for (final def in ['Living Room', 'Bedroom', 'Kitchen', 'Office', 'Dining Room', 'Balcony', 'Bathroom']) {
      roomSet.add(def);
    }
    final allRooms = roomSet.toList();
    if (liveDevice.roomName.isNotEmpty && liveDevice.roomName.toLowerCase() != 'unassigned' && !allRooms.contains(liveDevice.roomName)) {
      allRooms.insert(0, liveDevice.roomName);
    }

    String? selectedRoom = (liveDevice.roomName.toLowerCase() == 'unassigned')
        ? (allRooms.isNotEmpty ? allRooms.first : 'Living Room')
        : liveDevice.roomName;
    final newRoomController = TextEditingController();

    if (!mounted) return;
    final confirmed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: tokens.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.meeting_room_rounded, color: tokens.bluePrimary, size: 24),
                  const SizedBox(width: 10),
                  const Text('Change Device Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reassign "${liveDevice.name}" to another room (e.g. moved from Bedroom to Kitchen):',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allRooms.length,
                  itemBuilder: (ctx, idx) {
                    final r = allRooms[idx];
                    final isSel = selectedRoom == r;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSel ? tokens.bluePrimary : tokens.textTertiary,
                      ),
                      title: Text(r, style: TextStyle(fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: tokens.textPrimary)),
                      onTap: () => setSheetState(() => selectedRoom = r),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newRoomController,
                decoration: InputDecoration(
                  labelText: '+ Or create custom room',
                  hintText: 'e.g. Kids Room, Guest Bedroom',
                  prefixIcon: const Icon(Icons.add_home_work_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    setSheetState(() => selectedRoom = val.trim());
                  }
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final target = newRoomController.text.trim().isNotEmpty
                        ? newRoomController.text.trim()
                        : selectedRoom;
                    Navigator.pop(ctx, target);
                  },
                  style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Save Room Location', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty && confirmed != liveDevice.roomName && mounted) {
      await widget.homeController.moveDeviceToRoom(liveDevice.id, confirmed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${liveDevice.name} moved to $confirmed.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _transferToSpace(ConnectedDeviceSummary liveDevice) async {
    final tokens = context.ehColors;
    final spaces = widget.homeController.spaces;
    final curSpaceId = widget.homeController.activeSpaceId;
    final targetSpaces = spaces.where((s) => s['id'] != curSpaceId).toList();

    if (targetSpaces.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other spaces found. Create an Office or secondary space in Settings first!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String selectedSpaceId = targetSpaces.first['id'] as String;
    String selectedSpaceName = targetSpaces.first['name'] as String;

    if (!mounted) return;
    final confirmed = await showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: tokens.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: tokens.bluePrimary, size: 26),
                  const SizedBox(width: 10),
                  const Text('Transfer to Another Space', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Move "${liveDevice.name}" from "${widget.homeController.activeSpaceName}" to another space (e.g. taking home device to use in Office):',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              ...targetSpaces.map((sp) {
                final spId = sp['id'] as String;
                final spName = sp['name'] as String;
                final isSel = selectedSpaceId == spId;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSel ? tokens.bluePrimary : tokens.textTertiary,
                  ),
                  title: Text(spName, style: TextStyle(fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: tokens.textPrimary)),
                  onTap: () => setSheetState(() {
                    selectedSpaceId = spId;
                    selectedSpaceName = spName;
                  }),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, (id: selectedSpaceId, name: selectedSpaceName)),
                  style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text('Transfer to $selectedSpaceName', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != null && mounted) {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await widget.homeController.transferDeviceToSpace(liveDevice.id, confirmed.id);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${liveDevice.name} transferred to ${confirmed.name}.'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Switch Space',
            textColor: Colors.white,
            onPressed: () => widget.homeController.selectSpace(confirmed.id),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmForgetDevice(ConnectedDeviceSummary liveDevice) async {
    final tokens = context.ehColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Forget & Reset Device?',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444), fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will perform a full factory reset on "${liveDevice.name}":',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Erases saved Wi-Fi credentials from physical board', style: TextStyle(fontSize: 13, height: 1.4)),
                    Text('• Puts the device back into BLE Pairing Mode (like holding BOOT button 10s)', style: TextStyle(fontSize: 13, height: 1.4)),
                    Text('• Clears all custom channel names & telemetry', style: TextStyle(fontSize: 13, height: 1.4)),
                    Text('• Removes device completely from your app', style: TextStyle(fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'To use this device again, you can re-commission it freshly via Add Device / BLE.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Forget & Reset Device', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final resetSent = await widget.homeController.forgetDevice(liveDevice.id);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resetSent
                ? '${liveDevice.name} reset to Pairing Mode. You can now re-setup freshly.'
                : '${liveDevice.name} forgotten and removed from app.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetChannelNames(ConnectedDeviceSummary liveDevice) async {
    final channelCount = _channelCountFor(liveDevice);
    final isSocket = _isSocketFor(liveDevice);
    final prefix = isSocket ? 'Socket' : 'Switch';
    final freshLabels = <int, String>{
      for (int i = 1; i <= channelCount; i++) i: '$prefix $i',
    };
    await DeviceStorageService.setChannelLabelsForDevice(liveDevice.id, freshLabels);
    if (mounted) {
      setState(() {
        _channelLabels.clear();
        _channelLabels.addAll(freshLabels);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Channel names reset to default.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        _checkAndRefreshVariant(liveDevice.model);
        final isOnline = liveDevice.online;
        final channelCount = _channelCountFor(liveDevice);
        final isSocket = _isSocketFor(liveDevice);
        final hasEnergyMonitoring = _hasEnergyMonitoringFor(liveDevice);
        final isLocalMode = widget.homeController.isLocalMode && isOnline;

        // Check if any channel is ON
        final isLivingRoom = liveDevice.roomName.toLowerCase().contains('living');
        bool anyOn = false;
        for (int i = 1; i <= channelCount; i++) {
          final isOn = widget.homeController.getDeviceChannelPower(
            liveDevice.id,
            i,
            defaultValue: i == 1 && isLivingRoom && widget.homeController.livingRoomLightOn,
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
              liveDevice.name,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: tokens.textPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: tokens.surfaceCard,
                onSelected: (val) {
                  if (val == 'configure_ip') _configureDeviceIp(liveDevice);
                  if (val == 'room') _changeRoom(liveDevice);
                  if (val == 'space') _transferToSpace(liveDevice);
                  if (val == 'wifi') _changeWifiCredentials();
                  if (val == 'reset_labels') _resetChannelNames(liveDevice);
                  if (val == 'forget') _confirmForgetDevice(liveDevice);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'configure_ip',
                    child: Row(
                      children: [
                        Icon(Icons.router_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Configure Local IP Address'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset_labels',
                    child: Row(
                      children: [
                        Icon(Icons.label_off_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Reset Channel Names to Default'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'room',
                    child: Row(
                      children: [
                        Icon(Icons.meeting_room_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Change Room / Location'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'space',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Move to Another Space'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'wifi',
                    child: Row(
                      children: [
                        Icon(Icons.wifi_password_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Change Wi-Fi Network'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'forget',
                    child: Row(
                      children: [
                        Icon(Icons.restart_alt_rounded, size: 20, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text('Forget Device (Reset)', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
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
                                      'No local devices found on this Wi-Fi network. Ensure your smart devices are powered on and nearby.',
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
                        ProductImageWidget(
                          // Bundled catalog artwork is the source of truth for
                          // the installed app. The repository can still be
                          // using its offline/mock metadata, whose imageUrl
                          // may be a generic placeholder, so resolve the
                          // exact variant before falling back to repository
                          // metadata.
                          imageUrl: resolveBundledProductAsset(
                                MockProductCatalogRepository
                                    .resolveCanonicalProductVariant(
                                  variantId: liveDevice.model,
                                  deviceName: liveDevice.name,
                                ),
                              ) ??
                              _variant?.imageUrl,
                          size: 56,
                          borderRadius: BorderRadius.circular(18),
                          fallbackIcon: _productIconFor(liveDevice),
                          placeholderColor: tokens.bluePrimary.withValues(alpha: 0.18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                liveDevice.name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${liveDevice.roomName} • $channelCount Channels',
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
                            onPressed: isOnline ? () => _toggleAll(false, channelCount) : null,
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
                            onPressed: isOnline ? () => _toggleAll(true, channelCount) : null,
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

              const SizedBox(height: 14),

              // Room Location Tile with instant assignment / change action
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: liveDevice.roomName.toLowerCase() == 'unassigned'
                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                        : tokens.borderSubtle,
                    width: liveDevice.roomName.toLowerCase() == 'unassigned' ? 1.5 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _changeRoom(liveDevice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: liveDevice.roomName.toLowerCase() == 'unassigned'
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                  : tokens.bluePrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.meeting_room_rounded,
                              color: liveDevice.roomName.toLowerCase() == 'unassigned'
                                  ? const Color(0xFFEF4444)
                                  : tokens.bluePrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ROOM LOCATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.textTertiary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  liveDevice.roomName.toLowerCase() == 'unassigned'
                                      ? 'Unassigned (Tap to choose room)'
                                      : liveDevice.roomName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: liveDevice.roomName.toLowerCase() == 'unassigned'
                                        ? const Color(0xFFEF4444)
                                        : tokens.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: liveDevice.roomName.toLowerCase() == 'unassigned'
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                  : tokens.bluePrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              liveDevice.roomName.toLowerCase() == 'unassigned' ? 'Assign' : 'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: liveDevice.roomName.toLowerCase() == 'unassigned'
                                    ? const Color(0xFFEF4444)
                                    : tokens.bluePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Individual Channel Controls Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isSocket ? 'Socket Outlets' : 'Switch Controls',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
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
                final channelName = _getChannelName(channelIdx, liveDevice);
                final isChOn = widget.homeController.getDeviceChannelPower(
                  liveDevice.id,
                  channelIdx,
                );

                final activeRoutine = widget.homeController.getActiveRoutineForChannel(
                  liveDevice.id.isNotEmpty ? liveDevice.id : widget.device.id,
                  channelIdx,
                );
                if (activeRoutine != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RoutineControlWarningOverlay(
                      routine: activeRoutine,
                      controlTitle: channelName,
                      isFullWidth: true,
                    ),
                  );
                }

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
                            isSocket ? Icons.power_rounded : Icons.lightbulb_rounded,
                            color: isChOn && isOnline ? Colors.white : tokens.textTertiary,
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
                              onPressed: () => _editChannelName(channelIdx, liveDevice),
                              tooltip: 'Rename Channel',
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
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
                            Builder(
                              builder: (context) {
                                final alertCfg = widget.homeController.getChannelAlertConfig(
                                  liveDevice.id.isNotEmpty ? liveDevice.id : widget.device.id,
                                  channelIdx,
                                );
                                if (!alertCfg.enabled) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tokens.bluePrimary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: tokens.bluePrimary.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_active_rounded,
                                          size: 13,
                                          color: tokens.bluePrimary,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Alert: ${alertCfg.alertOnTurnOn && alertCfg.alertOnTurnOff ? "ON & OFF" : (alertCfg.alertOnTurnOn ? "ON only" : "OFF only")}'
                                            '${alertCfg.customMessage.isNotEmpty ? ' • "${alertCfg.customMessage}"' : ''}',
                                            style: TextStyle(
                                              color: tokens.bluePrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final activeRoutine = widget.homeController.getActiveRoutineForChannel(
                                  liveDevice.id.isNotEmpty ? liveDevice.id : widget.device.id,
                                  channelIdx,
                                );
                                if (activeRoutine == null) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: ActiveRoutineBadge(routine: activeRoutine, showRoutineName: true),
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: Builder(
                          builder: (context) {
                            final activeRoutine = widget.homeController.getActiveRoutineForChannel(
                              liveDevice.id.isNotEmpty ? liveDevice.id : widget.device.id,
                              channelIdx,
                            );
                            return Switch.adaptive(
                              value: isChOn && isOnline,
                              activeThumbColor: tokens.bluePrimary,
                              activeTrackColor: tokens.bluePrimary.withValues(alpha: 0.35),
                              inactiveThumbColor: tokens.switchThumbOff,
                              inactiveTrackColor: tokens.switchTrackOff,
                              onChanged: isOnline
                                  ? (val) async {
                                      if (activeRoutine != null) {
                                        final proceed = await confirmRoutineInterruption(context, activeRoutine);
                                        if (!proceed) return;
                                      }
                                      widget.homeController.setDeviceChannelPower(
                                        deviceId: liveDevice.id,
                                        channelIndex: channelIdx,
                                        value: val,
                                      );
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }),

              if (hasEnergyMonitoring) ...[
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
              ],

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
                    _InfoRow(label: 'Device ID', value: liveDevice.id),
                    _InfoRow(label: 'Model Variant', value: MockProductCatalogRepository.resolveCanonicalProductVariant(variantId: liveDevice.model, deviceName: liveDevice.name)),
                    _InfoRow(label: 'Firmware Version', value: liveDevice.firmware),
                    _InfoRow(label: 'Protocol', value: 'mTLS Secure MQTT / BLE'),
                    _InfoRow(label: 'Assigned Room', value: liveDevice.roomName),
                    _InfoRow(
                      label: 'Local LAN IP',
                      value: DeviceStorageService.getDeviceIp(liveDevice.id) != null
                          ? '${DeviceStorageService.getDeviceIp(liveDevice.id)} (Auto-Discovered)'
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

              const SizedBox(height: 20),

              // 5. Device Management & Danger Zone Card
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
                      'Device Management',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage device association or trigger a remote factory reset.',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _confirmForgetDevice(liveDevice),
                      icon: const Icon(Icons.restart_alt_rounded, size: 20, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Forget & Factory Reset Device',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
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
