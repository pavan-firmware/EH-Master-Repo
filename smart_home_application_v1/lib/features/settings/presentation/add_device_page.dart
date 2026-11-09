import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/device_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../connection/presentation/device_provisioning_page.dart';
import '../../onboarding/ble/ble_commissioning_channel.dart';
import 'help/help_support_page.dart';

typedef AddRoomDevicePage = AddDevicePage;

/// "Add a device" screen — Redesigned unified device discovery and commissioning flow.
class AddDevicePage extends StatefulWidget {
  const AddDevicePage({
    super.key,
    this.repository = const PreviewSettingsRepository(),
    this.onStartSecureSetup,
    this.connectionState,
    this.homeController,
    this.initialRoomName,
    this.availableRooms,
    this.spaceId,
    this.onDeviceProvisioned,
    this.animateRadar = true,
  });

  final SettingsRepository repository;
  final Future<ConnectionResult> Function()? onStartSecureSetup;
  final HomeConnectionState? connectionState;
  final HomeController? homeController;
  final String? initialRoomName;
  final List<String>? availableRooms;
  final String? spaceId;
  final bool animateRadar;
  final void Function({
    required String deviceId,
    required String displayName,
    required String serialNumber,
    String? roomName,
    String? model,
  })? onDeviceProvisioned;

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _radarController;
  List<DiscoveredRoomDevice> _devices = [];
  bool _scanning = true;
  double _progress = 0.0;
  int _secondsLeft = 10;
  Timer? _scanTimer;
  String? _errorMessage;
  bool _openingSettings = false;
  int _scanGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animateRadar) {
      _radarController.forward();
      _radarController.addStatusListener((status) {
        if (status == AnimationStatus.completed && _scanning && mounted && widget.animateRadar) {
          _radarController.forward(from: 0.0);
        }
      });
    }

    _startScan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _errorMessage != null &&
        !_openingSettings) {
      _startScan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    _scanTimer?.cancel();
    if (widget.repository is BleDiscoverySettingsRepository) {
      unawaited((widget.repository as BleDiscoverySettingsRepository).resetDiscovery());
    }
    super.dispose();
  }

  String get _recoveryActionLabel {
    final value = (_errorMessage ?? '').toLowerCase();
    if (value.contains('location')) return 'Turn on Location';
    if (value.contains('bluetooth')) return 'Open Bluetooth settings';
    return 'Open Settings';
  }

  Future<void> _openRecoverySettings() async {
    setState(() => _openingSettings = true);
    bool opened = false;
    try {
      if (widget.repository is BleDiscoverySettingsRepository) {
        opened = await (widget.repository as BleDiscoverySettingsRepository)
            .openRecoverySettings(_errorMessage);
      }
    } catch (error) {
      debugPrint('[ADD-DEVICE] Could not open recovery settings: $error');
    }
    if (!mounted) return;
    setState(() => _openingSettings = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open system settings. Please enable the requirement manually.')),
      );
    }
  }

  Future<void> _startScan() async {
    final generation = ++_scanGeneration;
    _scanTimer?.cancel();
    if (widget.repository is BleDiscoverySettingsRepository) {
      await (widget.repository as BleDiscoverySettingsRepository).resetDiscovery();
    }
    if (!mounted || generation != _scanGeneration) return;
    setState(() {
      _scanning = true;
      _devices = [];
      _progress = 0.0;
      _secondsLeft = 10;
      _errorMessage = null;
    });
    if (widget.animateRadar) {
      _radarController.forward(from: 0.0);
    }

    const totalSeconds = 10;
    const tickIntervalMs = 200;
    const totalTicks = (totalSeconds * 1000) ~/ tickIntervalMs;
    int tickCount = 0;

    _scanTimer = Timer.periodic(const Duration(milliseconds: tickIntervalMs), (timer) {
      tickCount++;
      final p = (tickCount / totalTicks).clamp(0.0, 1.0);
      final remaining = ((totalSeconds * (1.0 - p))).ceil();

      if (mounted) {
        setState(() {
          _progress = p;
          _secondsLeft = remaining;
        });
      }

      if (tickCount >= totalTicks) {
        timer.cancel();
        // The real BLE request below owns the scan lifecycle. Do not start a
        // second scan here: flutter_reactive_ble cancels the first stream when
        // a second scan is opened, which can drop advertisements at the
        // exact moment the visual countdown completes.
      }
    });

    try {
      final list = widget.repository is BleDiscoverySettingsRepository
          ? await (widget.repository as BleDiscoverySettingsRepository).scanNearbyDevices(
              onDeviceDiscovered: (device) {
                if (!mounted || generation != _scanGeneration) return;
                setState(() {
                  final index = _devices.indexWhere((item) => item.id == device.id);
                  if (index == -1) {
                    _devices = [..._devices, device];
                  } else {
                    final updated = [..._devices];
                    updated[index] = device;
                    _devices = updated;
                  }
                });
              },
            )
          : await widget.repository.getNearbyDevices();
      if (mounted && generation == _scanGeneration) {
        setState(() {
          _devices = list;
          _scanning = false;
          _progress = 1.0;
          _secondsLeft = 0;
        });
        _scanTimer?.cancel();
        _radarController.stop();
      }
    } catch (e) {
      if (mounted && generation == _scanGeneration) {
        setState(() {
          _errorMessage = e.toString();
          _scanning = false;
          _progress = 1.0;
          _secondsLeft = 0;
        });
        _scanTimer?.cancel();
        _radarController.stop();
      }
    }
  }

  Future<void> _connectToDevice(DiscoveredRoomDevice device) async {
    // Release the discovery stream before commissioning. Keeping a scan open
    // while connecting can leave the BLE adapter busy after the setup route
    // is popped, making the next Refresh appear to find nothing.
    ++_scanGeneration;
    _scanTimer?.cancel();
    if (widget.repository is BleDiscoverySettingsRepository) {
      await (widget.repository as BleDiscoverySettingsRepository).resetDiscovery();
    }
    if (mounted) {
      setState(() => _scanning = false);
      _radarController.stop();
    }

    // If onStartSecureSetup is provided, run preflight / secure initiation
    BleCommissioningChannel? channel;
    if (widget.onStartSecureSetup != null) {
      try {
        final res = await widget.onStartSecureSetup!();
        if (res.channel is BleCommissioningChannel) {
          channel = res.channel as BleCommissioningChannel;
        }
      } catch (e) {
        debugPrint('[ADD-DEVICE] onStartSecureSetup note: $e');
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceSetupPage(
          deviceName: device.name,
          deviceId: device.id,
          model: device.productVariantId ?? device.model,
          imageUrl: device.resolvedImageUrl,
          channel: channel,
          initialRoomName: widget.initialRoomName,
          availableRooms: widget.availableRooms ?? widget.homeController?.rooms.map((r) => r.name).toList(),
          spaceId: widget.spaceId ?? widget.homeController?.activeSpaceId,
          onDeviceProvisioned: ({
            required String deviceId,
            required String displayName,
            required String serialNumber,
            String? roomName,
            String? model,
          }) {
            widget.onDeviceProvisioned?.call(
              deviceId: deviceId,
              displayName: displayName,
              serialNumber: serialNumber,
              roomName: roomName,
              model: model,
            );
            widget.homeController?.markDeviceProvisioned(
              deviceId: deviceId,
              displayName: displayName,
              serialNumber: serialNumber,
              roomName: roomName,
              model: model,
            );
          },
        ),
      ),
    );

    // DeviceSetupPage can be left from any step. It does not own the
    // connection lifecycle, so release the exact commissioning channel here
    // before the user presses Refresh on this page.
    if (channel != null) {
      try {
        await channel.disconnect();
      } catch (error) {
        debugPrint('[ADD-DEVICE] Failed to release setup BLE channel: $error');
      }
    }

    // Returning from setup does not start another radio scan. The user can
    // explicitly press Refresh; this avoids reconnect/scan races and keeps
    // the page responsive after cancelling or completing setup.
  }

  void _showHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        centerTitle: false,
        leading: BackButton(
          color: tokens.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add a device',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Setup help',
            onPressed: _showHelp,
            icon: Icon(Icons.help_outline_rounded, color: tokens.headerAction),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Scanning card with 0 -> 100% progress loader and radar animation
            _buildScanningCard(tokens),
            const SizedBox(height: 24),

            // Nearby devices Header + Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Nearby devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: _startScan,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.bluePrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: tokens.bluePrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Discovered device list, Error state, or Empty state
            if (_errorMessage != null)
              _buildErrorState(tokens)
            else if (_devices.isNotEmpty)
              ..._devices.map((device) => _buildDeviceRow(device, tokens))
            else if (!_scanning)
              _buildEmptyState(tokens),

            const SizedBox(height: 32),

            // "NEED HELP?" Section at bottom
            _buildNeedHelpSection(tokens),
          ],
        ),
      ),
    );
  }

  /// Scanning Card with Radar animation, percentage, progress bar, and countdown
  Widget _buildScanningCard(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Radar Animation Icon
              _buildRadarAnimation(tokens),
              const SizedBox(width: 16),

              // Title and percentage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _scanning ? 'Finding nearby devices' : 'Scan finished',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_scanning)
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Loader
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        // The scan is event-driven. Keep the bar animated
                        // while listening and steady only after timeout.
                        value: _scanning ? null : 1.0,
                        minHeight: 6,
                        backgroundColor: tokens.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _scanning
                          ? 'About $_secondsLeft sec left'
                          : '${_devices.length} devices found',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Animated Radar Pulse Icon
  Widget _buildRadarAnimation(EHThemeTokens tokens) {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        final scale = 1.0 + (_radarController.value * 0.15);
        final opacity = (1.0 - _radarController.value).clamp(0.2, 0.8);

        return Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.bluePrimary.withValues(
              alpha: _scanning ? (0.15 * opacity) : 0.15,
            ),
          ),
          child: Transform.scale(
            scale: _scanning ? scale : 1.0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.bluePrimary.withValues(alpha: 0.25),
              ),
              child: Icon(
                _scanning ? Icons.radar_rounded : Icons.check_circle_rounded,
                color: tokens.bluePrimary,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Discovered Device Card with Product Image, Name, Signal, and Connect Button
  Widget _buildDeviceRow(DiscoveredRoomDevice device, EHThemeTokens tokens) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          // Dynamic Product Image
          ProductImageWidget(
            imageUrl: device.resolvedImageUrl,
            size: 54,
            borderRadius: BorderRadius.circular(12),
            placeholderColor: tokens.isDark ? Colors.black26 : const Color(0xFFE8EEF8),
          ),
          const SizedBox(width: 14),

          // Name & Signal Indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _signalIcon(device.signalLabel),
                      size: 15,
                      color: _signalColor(device.signalLabel),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        device.signalLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: _signalColor(device.signalLabel),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Connect Button
          FilledButton(
            onPressed: () => _connectToDevice(device),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Connect',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _signalIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('weak')) return Icons.signal_cellular_alt_1_bar_rounded;
    if (value.contains('good')) return Icons.signal_cellular_alt_2_bar_rounded;
    return Icons.signal_cellular_4_bar_rounded;
  }

  Color _signalColor(String label) {
    return label.toLowerCase().contains('weak')
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
  }

  /// Error State with alert icon, error message, and Try again button
  Widget _buildErrorState(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.error.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: tokens.error,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scanning issue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unable to complete Bluetooth discovery.',
            style: TextStyle(
              fontSize: 14,
              color: tokens.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openingSettings ? null : _openRecoverySettings,
              icon: _openingSettings
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.settings_rounded, size: 18),
              label: Text(_openingSettings ? 'Opening Settings…' : _recoveryActionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openingSettings ? null : _startScan,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty State with Bluetooth icon, helper text, and Rescan button
  Widget _buildEmptyState(EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              color: tokens.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No nearby devices found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure Bluetooth is on, your device is powered and in pairing mode, and close to your phone.',
            style: TextStyle(
              fontSize: 14,
              color: tokens.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Rescan', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// "NEED HELP?" Section
  Widget _buildNeedHelpSection(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEED HELP?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            children: [
              _buildHelpRow(
                icon: Icons.bluetooth_rounded,
                text: 'Make sure Bluetooth is on',
                tokens: tokens,
                showDivider: true,
              ),
              _buildHelpRow(
                icon: Icons.power_rounded,
                text: 'Power on your device',
                tokens: tokens,
                showDivider: true,
              ),
              _buildHelpRow(
                icon: Icons.help_outline_rounded,
                text: 'View troubleshooting guide',
                tokens: tokens,
                showDivider: false,
                onTap: _showHelp,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpRow({
    required IconData icon,
    required String text,
    required EHThemeTokens tokens,
    required bool showDivider,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tokens.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: tokens.textSecondary,
                  ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: tokens.borderSubtle,
            ),
        ],
      ),
    );
  }
}
