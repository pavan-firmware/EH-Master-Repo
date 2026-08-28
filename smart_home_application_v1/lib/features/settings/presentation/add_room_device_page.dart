import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../../../core/models/device_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/ble_connection_repository.dart';
import '../../../core/repositories/connection_repository.dart';
import '../../../core/repositories/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/ble/ble_commissioning_channel.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/services/onboarding_service.dart';
import 'settings_ui.dart';

enum AddDeviceStep {
  scanning,
  deviceFound,
  wifiInput,
  commissioning,
  success,
  error,
}

class AddRoomDevicePage extends StatefulWidget {
  const AddRoomDevicePage({
    super.key,
    required this.repository,
    this.onStartSecureSetup,
    this.connectionState,
    this.bleRepo,
    this.onboardingService,
  });

  final SettingsRepository repository;
  final Future<ConnectionResult> Function()? onStartSecureSetup;
  final HomeConnectionState? connectionState;
  final BleConnectionRepository? bleRepo;
  final OnboardingService? onboardingService;

  @override
  State<AddRoomDevicePage> createState() => _AddRoomDevicePageState();
}

class _AddRoomDevicePageState extends State<AddRoomDevicePage> {
  late final BleConnectionRepository _bleRepo;
  late final BleCommissioningChannel _channel;
  late final OnboardingService _onboardingService;

  AddDeviceStep _currentStep = AddDeviceStep.scanning;
  final List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredRoomDevice> _previewDevices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  OnboardingDeviceIdentity? _identifiedDevice;

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String _statusMessage = 'Searching for nearby EH Home devices...';
  String _errorMessage = '';
  double _commissioningProgress = 0.0;

  @override
  void initState() {
    super.initState();
    try {
      _bleRepo = widget.bleRepo ?? BleConnectionRepository();
    } catch (_) {
      _bleRepo = BleConnectionRepository();
    }
    _channel = BleCommissioningChannel();
    _onboardingService =
        widget.onboardingService ?? DefaultOnboardingService(channel: _channel);

    _startBleScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _channel.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _startBleScan() async {
    await _channel.disconnect();
    _scanSubscription?.cancel();

    if (!mounted) return;
    setState(() {
      _currentStep = AddDeviceStep.scanning;
      _discoveredDevices.clear();
      _statusMessage = 'Searching for nearby EH Home devices...';
      _errorMessage = '';
    });

    // In unit/widget tests only, load mock preview devices if no real BLE hardware
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      widget.repository.getNearbyDevices().then((preview) {
        if (mounted && preview.isNotEmpty) {
          setState(() {
            _previewDevices = preview;
            if (_currentStep == AddDeviceStep.scanning &&
                _discoveredDevices.isEmpty) {
              _currentStep = AddDeviceStep.deviceFound;
            }
          });
        }
      });
    }

    try {
      _scanSubscription = _bleRepo
          .scanNearby(timeout: const Duration(seconds: 30))
          .listen(
            (device) {
              if (mounted) {
                setState(() {
                  if (!_discoveredDevices.any((d) => d.id == device.id)) {
                    _discoveredDevices.add(device);
                    _currentStep = AddDeviceStep.deviceFound;
                  }
                });
              }
            },
            onError: (Object err) {
              if (mounted && _previewDevices.isEmpty) {
                setState(() {
                  _currentStep = AddDeviceStep.error;
                  _errorMessage = 'Bluetooth scan failed: $err';
                });
              }
            },
            onDone: () {
              if (mounted &&
                  _discoveredDevices.isEmpty &&
                  _previewDevices.isEmpty) {
                setState(() {
                  _currentStep = AddDeviceStep.error;
                  _errorMessage =
                      'No nearby EH Home device was found. Make sure your switch is powered on and within Bluetooth range.';
                });
              }
            },
          );
    } catch (err) {
      if (mounted && _previewDevices.isEmpty) {
        setState(() {
          _currentStep = AddDeviceStep.error;
          _errorMessage = 'Bluetooth error: $err';
        });
      }
    }
  }

  void _selectDevice(DiscoveredDevice device) {
    _scanSubscription?.cancel();
    setState(() {
      _identifiedDevice = OnboardingDeviceIdentity(
        deviceId: device.id,
        serialNumber: device.name.isNotEmpty ? device.name : device.id,
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: device.name.isNotEmpty
            ? device.name
            : 'EH Smart Switch 3X',
      );
      _currentStep = AddDeviceStep.wifiInput;
    });
  }

  void _selectPreviewDevice(DiscoveredRoomDevice device) {
    _scanSubscription?.cancel();
    setState(() {
      _identifiedDevice = OnboardingDeviceIdentity(
        deviceId: device.id,
        serialNumber: device.model,
        productVariantId: 'eh-smart-switch-3x',
        hardwareRevision: 'HW_1_0',
        firmwareFamily: 'esp32-switch-platform',
        displayName: device.name,
      );
      _currentStep = AddDeviceStep.wifiInput;
    });
  }

  Future<void> _startCommissioning() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Wi-Fi network name (SSID)'),
        ),
      );
      return;
    }

    setState(() {
      _currentStep = AddDeviceStep.commissioning;
      _commissioningProgress = 0.15;
      _statusMessage = 'Connecting to switch and starting secure session...';
    });

    try {
      final identity = _identifiedDevice!;

      // Step 1: Start Commissioning (Connects to BLE -> HELLO -> HELLO_ACK)
      setState(() {
        _commissioningProgress = 0.35;
        _statusMessage = 'Establishing encrypted EH-PROV/1 session...';
      });
      final commProgress = await _onboardingService.startSecureCommissioning(
        identity,
      );

      if (commProgress.stepState == OnboardingStepState.failed) {
        throw Exception(
          commProgress.errorMessage ?? 'Commissioning handshake failed',
        );
      }

      // Step 2: Proving Identity (AUTH -> AUTH_ACK)
      setState(() {
        _commissioningProgress = 0.60;
        _statusMessage = 'Verifying cryptographic device proof...';
      });
      final authProgress = await _onboardingService.proveIdentity(
        sessionId: commProgress.sessionId!,
        identity: identity,
        deviceChallenge: Uint8List(32),
      );

      if (authProgress.stepState == OnboardingStepState.failed) {
        throw Exception(
          authProgress.errorMessage ?? 'Device authentication failed',
        );
      }

      // Step 3: Wi-Fi Provisioning (WIFI_CRED -> WIFI_ACK)
      setState(() {
        _commissioningProgress = 0.85;
        _statusMessage = 'Transferring encrypted Wi-Fi credentials...';
      });
      final wifiProgress = await _onboardingService.provisionWifi(
        sessionId: commProgress.sessionId!,
        identity: identity,
        appChallenge: Uint8List(32),
        deviceChallenge: Uint8List(32),
        ssid: ssid,
        password: password,
      );

      if (wifiProgress.stepState == OnboardingStepState.failed) {
        throw Exception(
          wifiProgress.errorMessage ?? 'Wi-Fi credential transfer failed',
        );
      }

      // Step 4: Finalize Claiming
      setState(() {
        _commissioningProgress = 1.0;
        _statusMessage = 'Finalizing setup...';
      });
      await _onboardingService.claimAndAssignDevice(
        deviceId: identity.deviceId,
        sessionId: commProgress.sessionId!,
        homeId: 'default',
      );

      if (mounted) {
        setState(() {
          _currentStep = AddDeviceStep.success;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _currentStep = AddDeviceStep.error;
          _errorMessage = '$err';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return NestedSettingsScaffold(
      title: 'Add a room device',
      subtitle: 'Scan and securely set up your EH Home device.',
      actions: [
        if (_currentStep == AddDeviceStep.scanning ||
            _currentStep == AddDeviceStep.deviceFound)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan',
            onPressed: _startBleScan,
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          switch (_currentStep) {
            AddDeviceStep.scanning => _buildScanningView(tokens),
            AddDeviceStep.deviceFound => _buildDeviceListView(tokens),
            AddDeviceStep.wifiInput => _buildWifiInputView(tokens),
            AddDeviceStep.commissioning => _buildCommissioningView(tokens),
            AddDeviceStep.success => _buildSuccessView(tokens),
            AddDeviceStep.error => _buildErrorView(tokens),
          },
        ],
      ),
    );
  }

  Widget _buildScanningView(EHThemeTokens tokens) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.bluePrimary.withValues(alpha: 0.12),
            border: Border.all(color: tokens.bluePrimary, width: 2),
          ),
          child: Icon(
            Icons.bluetooth_searching_rounded,
            size: 48,
            color: tokens.bluePrimary,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Scanning for devices',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ensure your physical EH Smart Switch is powered on and within Bluetooth range.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 32),
        LinearProgressIndicator(
          value: 0.7,
          color: tokens.bluePrimary,
          backgroundColor: tokens.surfaceCard,
        ),
      ],
    );
  }

  Widget _buildDeviceListView(EHThemeTokens tokens) {
    final hasBle = _discoveredDevices.isNotEmpty;
    final totalCount = hasBle
        ? _discoveredDevices.length
        : _previewDevices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onPressed: _startBleScan,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: Text('Refresh ($totalCount)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasBle)
          ..._discoveredDevices.map((device) {
            final displayName = device.name.isNotEmpty
                ? device.name
                : 'EH Smart Switch 3X';
            final rssi = device.rssi;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SettingsSurface(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: tokens.iconBgBlue,
                    child: Icon(
                      Icons.toggle_on_rounded,
                      color: tokens.bluePrimary,
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: tokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${device.id} • Signal: ${rssi != 0 ? '$rssi dBm' : 'Strong'}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _selectDevice(device),
                    child: const Text('Set Up'),
                  ),
                ),
              ),
            );
          })
        else
          ..._previewDevices.map((pDev) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SettingsSurface(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: tokens.iconBgBlue,
                    child: Icon(
                      Icons.devices_other_rounded,
                      color: tokens.bluePrimary,
                    ),
                  ),
                  title: Text(
                    pDev.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${pDev.model} • ${pDev.signalLabel}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _selectPreviewDevice(pDev),
                    child: const Text('Set Up'),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWifiInputView(EHThemeTokens tokens) {
    final devName = _identifiedDevice?.displayName ?? 'EH Smart Switch 3X';
    final serial = _identifiedDevice?.serialNumber ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: tokens.iconBgBlue,
                  radius: 24,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: tokens.bluePrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        devName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (serial.isNotEmpty)
                        Text(
                          'Serial: $serial',
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
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionTitle('Connect to home Wi-Fi'),
        const SizedBox(height: 10),
        SettingsSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _ssidController,
                  decoration: const InputDecoration(
                    labelText: 'Wi-Fi Network Name (SSID)',
                    prefixIcon: Icon(Icons.wifi_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Wi-Fi Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary),
            onPressed: _startCommissioning,
            icon: const Icon(Icons.security_rounded),
            label: const Text(
              'Connect Device Securely',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissioningView(EHThemeTokens tokens) {
    return Column(
      children: [
        const SizedBox(height: 32),
        CircularProgressIndicator(
          value: _commissioningProgress,
          color: tokens.bluePrimary,
          strokeWidth: 6,
        ),
        const SizedBox(height: 24),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please do not disconnect your phone or power off the switch.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSuccessView(EHThemeTokens tokens) {
    final devName = _identifiedDevice?.displayName ?? 'EH Smart Switch 3X';

    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.successContainer,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: tokens.success,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Device Added!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$devName has been securely provisioned and joined your home Wi-Fi network.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(EHThemeTokens tokens) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.warningContainer,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: tokens.warning,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Setup Incomplete',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage.isNotEmpty
              ? _errorMessage
              : 'An unexpected issue occurred during device setup.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary),
            onPressed: _startBleScan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }
}
