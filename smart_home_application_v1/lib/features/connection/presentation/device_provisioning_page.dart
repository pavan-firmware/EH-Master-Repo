import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../core/models/connection_models.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/product_asset_resolver.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../onboarding/ble/ble_commissioning_channel.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/presentation/qr_scanner_dialog.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../settings/presentation/help/help_support_page.dart';

enum ProvisioningUiStage {
  readyPreview,
  inputCredentials,
  verifyDevice,
  commissioningHandshake,
  sendingWifi,
  awaitingDeviceAck,
  roomAssignment,
  success,
  failed,
}

typedef DeviceSetupPage = DeviceProvisioningPage;

class DeviceProvisioningPage extends StatefulWidget {
  const DeviceProvisioningPage({
    super.key,
    required this.deviceName,
    this.deviceId,
    this.serialNumber,
    this.model,
    this.imageUrl,
    this.channel,
    this.onboardingService,
    this.storageService,
    this.onDeviceProvisioned,
    this.initialRoomName,
    this.availableRooms,
    this.spaceId,
    this.initialShowWifiForm = false,
  });

  final String deviceName;
  final String? deviceId;
  final String? serialNumber;
  final String? model;
  final String? imageUrl;
  final BleCommissioningChannel? channel;
  final OnboardingService? onboardingService;
  final DeviceStorageService? storageService;
  final String? initialRoomName;
  final List<String>? availableRooms;
  final String? spaceId;
  final bool initialShowWifiForm;
  final void Function({
    required String deviceId,
    required String displayName,
    required String serialNumber,
    String? roomName,
    String? model,
  })?
  onDeviceProvisioned;

  @override
  State<DeviceProvisioningPage> createState() => _DeviceProvisioningPageState();
}

class _DeviceProvisioningPageState extends State<DeviceProvisioningPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _qrController = TextEditingController();
  final _customRoomController = TextEditingController();
  bool _obscurePassword = true;
  bool _showManualQrInput = false;

  late ProvisioningUiStage _stage;
  String? _errorMessage;
  String _statusDetail = 'Enter your 2.4 GHz Wi-Fi details to connect this device.';
  late final OnboardingService _service;
  late final DeviceStorageService _storageService;
  EhProv1Session? _session;
  OnboardingDeviceIdentity? _activeIdentity;

  String _selectedRoom = 'Living Room';
  List<String> _availableRooms = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Office',
    'Dining Room',
    'Balcony',
  ];

  bool _isProvisioned = false;
  bool _isProvisioningInProgress = false;

  String get _resolvedImageUrl {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return widget.imageUrl!;
    }
    final modelOrName = widget.model ?? widget.deviceName;
    final resolved = resolveBundledProductAsset(modelOrName);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final modelLower = modelOrName.toLowerCase();
    if (modelLower.contains('socket') || modelLower.contains('plug') || modelLower.contains('sk')) {
      return 'assets/products/catalog/eh-smart-socket-2x/hero.webp';
    } else if (modelLower.contains('fan')) {
      return 'assets/products/catalog/eh-smart-fan-1x/hero.webp';
    }
    final match = RegExp(r'(1|2|3|4|5)x').firstMatch(modelLower);
    final variant = match?.group(1) ?? '3';
    return 'assets/products/catalog/eh-smart-switch-${variant}x/hero.webp';
  }

  @override
  void initState() {
    super.initState();
    _stage = widget.initialShowWifiForm
        ? ProvisioningUiStage.inputCredentials
        : ProvisioningUiStage.readyPreview;
    _service =
        widget.onboardingService ??
        DefaultOnboardingService(channel: widget.channel);
    _storageService = widget.storageService ?? DeviceStorageService();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final Set<String> roomSet = {};

    if (widget.availableRooms != null && widget.availableRooms!.isNotEmpty) {
      roomSet.addAll(widget.availableRooms!.where((r) => r.trim().isNotEmpty && r.trim().toLowerCase() != 'unassigned'));
    }

    final loaded = await _storageService.loadRooms();
    roomSet.addAll(loaded.where((r) => r.trim().isNotEmpty && r.trim().toLowerCase() != 'unassigned'));

    if (widget.spaceId != null && widget.spaceId!.isNotEmpty) {
      final spaceRooms = await _storageService.loadRoomsForSpace(widget.spaceId!);
      roomSet.addAll(spaceRooms.where((r) => r.trim().isNotEmpty && r.trim().toLowerCase() != 'unassigned'));
    }

    for (final def in [
      'Living Room',
      'Bedroom',
      'Kitchen',
      'Office',
      'Dining Room',
      'Balcony',
      'Bathroom',
    ]) {
      roomSet.add(def);
    }

    if (mounted) {
      setState(() {
        _availableRooms = roomSet.toList();
        if (widget.initialRoomName != null && widget.initialRoomName!.isNotEmpty) {
          _selectedRoom = widget.initialRoomName!;
          if (!_availableRooms.contains(_selectedRoom)) {
            _availableRooms.insert(0, _selectedRoom);
          }
        } else if (!_availableRooms.contains(_selectedRoom)) {
          _selectedRoom = _availableRooms.first;
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_isProvisioned) {
      widget.channel?.disconnect();
    }
    _ssidController.dispose();
    _passwordController.dispose();
    _qrController.dispose();
    _customRoomController.dispose();
    super.dispose();
  }

  String _mapErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('gatt_err_unlikely') ||
        lower.contains('writecharacteristicfailure') ||
        lower.contains('status 14')) {
      return "Couldn't send secure setup data. Keep device nearby and retry.";
    }
    if (lower.contains('mismatch') ||
        lower.contains('identity proof') ||
        lower.contains('authentication proof')) {
      return "Device authentication failed. The commissioning secret does not match this device.";
    }
    if (lower.contains('still connecting')) {
      return "Device is still connecting to Wi-Fi. Keep device nearby or check your network router.";
    }
    if (lower.contains('rejected') ||
        lower.contains('could not accept') ||
        lower.contains('could not connect') ||
        lower.contains('ssid')) {
      return "The device could not connect to this Wi-Fi network. Check the network name and password.";
    }
    if (lower.contains('devicechallenge') ||
        lower.contains('challenge') ||
        lower.contains('argumenterror')) {
      return "The device connection timed out before verification. Tap Try again to re-verify.";
    }
    if (lower.contains('disconnected') || lower.contains('timeout')) {
      return "The device disconnected or took too long to respond. Keep it nearby and try again.";
    }
    return error
        .replaceFirst('Exception: ', '')
        .replaceFirst('BLE Wi-Fi provisioning exchange failed: ', '');
  }

  /// Wi-Fi QR Scanner: Scans ONLY standard Wi-Fi QR codes (`WIFI:T:...;S:...;P:...;;`)
  /// Fills SSID and Password. NEVER triggers device verification.
  Future<void> _scanWifiQr() async {
    final raw = await QrScannerDialog.show(context, mode: QrScannerMode.wifiCredentials);
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    final wifiData = WifiQrPayload.tryParse(raw);
    if (wifiData == null) {
      setState(() {
        _errorMessage = 'Invalid Wi-Fi QR code. Please scan a standard Wi-Fi network QR code.';
      });
      return;
    }

    setState(() {
      _ssidController.text = wifiData.ssid;
      _passwordController.text = wifiData.password;
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wi-Fi credentials filled for "${wifiData.ssid}"'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Device QR Scanner: Dedicated scanner for device ownership and commissioning verification.
  Future<void> _openDeviceQrScanner() async {
    final scannedPayload = await QrScannerDialog.showDeviceScanner(context);
    if (scannedPayload != null && scannedPayload.isNotEmpty) {
      _qrController.text = scannedPayload;
      await _verifyDeviceQr(scannedPayload);
    }
  }

  Future<void> _verifyDeviceQr([String? explicitPayload]) async {
    if (_isProvisioned || _isProvisioningInProgress) return;

    final qrText = explicitPayload ?? _qrController.text.trim();
    if (qrText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or scan the device QR code payload.';
      });
      return;
    }

    final result = await _service.verifyQrCode(qrText);
    if (result.hasFailed || result.identity == null) {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Invalid device QR code.';
      });
      return;
    }

    final currentDeviceId =
        widget.channel?.deviceIdentity?.deviceId ?? widget.deviceId;
    if (currentDeviceId != null &&
        currentDeviceId.trim().isNotEmpty &&
        result.identity!.deviceId.trim().toLowerCase() !=
            currentDeviceId.trim().toLowerCase()) {
      setState(() {
        _errorMessage = 'The QR code belongs to a different device.';
      });
      return;
    }

    debugPrint('[QR] PAYLOAD_PARSED');
    debugPrint('[QR] DEVICE_ID_MATCH id=${result.identity!.deviceId}');
    debugPrint('[QR] DEVICE_VERIFIED');

    setState(() {
      _activeIdentity = (widget.channel?.deviceIdentity ?? result.identity!)
          .copyWith(commissioningSecret: result.identity!.commissioningSecret);
      _errorMessage = null;
      _statusDetail = 'Device verified';
    });

    _startProvisioning();
  }

  Future<void> _startProvisioning() async {
    if (_isProvisioned || _isProvisioningInProgress) return;
    _isProvisioningInProgress = true;

    try {
      final ssid = _ssidController.text.trim();
      final password = _passwordController.text;

      if (ssid.isEmpty) {
        setState(() {
          _errorMessage = 'Wi-Fi network name (SSID) is required';
        });
        return;
      }

      final baseIdentity =
          _activeIdentity ??
          widget.channel?.deviceIdentity ??
          (widget.deviceId != null && widget.serialNumber != null
              ? OnboardingDeviceIdentity(
                  deviceId: widget.deviceId!,
                  serialNumber: widget.serialNumber!,
                  productVariantId: widget.model ?? 'eh-smart-switch-3x',
                  hardwareRevision: 'HW_1_0',
                  firmwareFamily: 'esp32-switch-platform',
                  displayName: widget.deviceName,
                )
              : null);

      if (baseIdentity == null) {
        setState(() {
          _stage = ProvisioningUiStage.failed;
          _errorMessage =
              'Device identity could not be verified from hardware. Please reconnect.';
        });
        return;
      }

      // Pre-check: if device is ALREADY active on Wi-Fi, move directly to room assignment
      if (widget.channel != null && widget.channel!.isConnected) {
        try {
          final curStatus = await widget.channel!.readStatus();
          final curState = (curStatus['state'] as String?)?.toUpperCase();
          final curWifi = curStatus['wifi'] == true;
          if (curState == 'ACTIVE' || curWifi) {
            debugPrint(
              '[PROV] DEVICE_ACTIVE (already confirmed on Wi-Fi). Moving to room assignment.',
            );
            setState(() {
              _stage = ProvisioningUiStage.roomAssignment;
              _statusDetail =
                  'Choose a room for your ${baseIdentity.displayName}.';
            });
            return;
          }
        } catch (e) {
          debugPrint('[PROV] Pre-check status warning: $e');
        }
      }

      // If commissioningSecret is missing, prompt user to scan device QR code
      if (baseIdentity.commissioningSecret == null ||
          baseIdentity.commissioningSecret!.trim().isEmpty) {
        setState(() {
          _stage = ProvisioningUiStage.verifyDevice;
          _errorMessage = null;
          _statusDetail =
              'Scan the QR code on your device to securely verify ownership.';
        });
        return;
      }

      final identity = baseIdentity;

      final bool isSessionAuthenticated =
          _session?.sessionKey != null &&
          _session?.sessionId != null &&
          (widget.channel?.isConnected ?? false);

      if (!isSessionAuthenticated) {
        // Step 1: Start Commissioning (HELLO -> HELLO_ACK)
        setState(() {
          _stage = ProvisioningUiStage.commissioningHandshake;
          _errorMessage = null;
          _statusDetail =
              'Starting secure commissioning handshake with device...';
        });

        final helloResult = await _service.startSecureCommissioning(identity);
        if (helloResult.hasFailed || helloResult.session == null) {
          throw Exception(
            helloResult.errorMessage ?? 'BLE HELLO exchange failed',
          );
        }
        _session = helloResult.session;

        final rawDevChallenge = _session?.deviceChallenge;
        if (rawDevChallenge == null || rawDevChallenge.length != 32) {
          throw Exception(
            'The device took too long to complete verification handshake. Please keep it nearby and try again.',
          );
        }

        // Step 2: Prove Identity (AUTH -> AUTH_ACK)
        setState(() {
          _statusDetail = 'Verifying cryptographic device identity...';
        });

        final authResult = await _service.proveIdentity(
          sessionId: _session!.sessionId,
          identity: identity,
          deviceChallenge: Uint8List.fromList(rawDevChallenge),
          session: _session,
        );
        if (authResult.hasFailed || authResult.session == null) {
          throw Exception(
            authResult.errorMessage ?? 'Identity proof verification failed',
          );
        }
        _session = authResult.session;
      }

      // Step 3: Wi-Fi Provisioning (WIFI_CRED -> WIFI_ACK)
      setState(() {
        _stage = ProvisioningUiStage.sendingWifi;
        _statusDetail = 'Encrypting and transmitting Wi-Fi credentials...';
      });

      final wifiResult = await _service.provisionWifi(
        sessionId: _session!.sessionId,
        identity: identity,
        appChallenge: Uint8List.fromList(_session!.appChallenge),
        deviceChallenge: Uint8List.fromList(_session!.deviceChallenge ?? []),
        ssid: ssid,
        password: password,
        session: _session,
      );
      if (wifiResult.hasFailed) {
        throw Exception(
          wifiResult.errorMessage ?? 'Device rejected Wi-Fi configuration',
        );
      }
      if (wifiResult.session != null) {
        _session = wifiResult.session;
      }

      // Step 4: Wi-Fi Connecting & Confirmation
      setState(() {
        _stage = ProvisioningUiStage.awaitingDeviceAck;
        _statusDetail = 'Connecting device to "$ssid" Wi-Fi network...';
      });

      final connectionConfirm = await _service.waitForWifiConnection(
        deviceId: identity.deviceId,
        session: _session,
        timeout: const Duration(seconds: 25),
      );
      if (connectionConfirm.hasFailed) {
        throw Exception(
          connectionConfirm.errorMessage ??
              'The device could not connect to this Wi-Fi network. Check the password and try again.',
        );
      }

      debugPrint('[PROV] DEVICE_ACTIVE');

      // Step 5: Room Assignment
      setState(() {
        _stage = ProvisioningUiStage.roomAssignment;
        _statusDetail = 'Choose a room for your ${identity.displayName}.';
      });
    } catch (e) {
      debugPrint('[PROV] Provisioning caught error: $e. Checking LAN fallback...');
      final targetDevId = _activeIdentity?.deviceId ?? widget.deviceId ?? '';
      bool verifiedOnLan = false;
      if (targetDevId.isNotEmpty) {
        try {
          final lan = await LocalLanDeviceService.instance.fetchLocalDeviceState(deviceId: targetDevId);
          if (lan != null && lan.channels.isNotEmpty) {
            verifiedOnLan = true;
          } else {
            final disc = await LocalLanDeviceService.instance.autoDiscoverDevices(
              expectedDeviceIds: [targetDevId],
              timeout: const Duration(seconds: 2),
            );
            if (disc.containsKey(targetDevId)) {
              verifiedOnLan = true;
            }
          }
        } catch (_) {}
      }

      if (verifiedOnLan && mounted) {
        debugPrint('[PROV] Device verified active on local Wi-Fi despite BLE drop. Transitioning to room assignment.');
        final dName = _activeIdentity?.displayName ?? widget.deviceName;
        setState(() {
          _stage = ProvisioningUiStage.roomAssignment;
          _statusDetail = 'Choose a room for your $dName.';
          _errorMessage = null;
        });
        return;
      }

      final isBleLost = widget.channel != null && !widget.channel!.isConnected;
      if (isBleLost) {
        _session = null;
      }
      setState(() {
        _stage = ProvisioningUiStage.failed;
        _errorMessage = _mapErrorMessage(e.toString());
        _statusDetail = isBleLost
            ? 'The device disconnected. Keep it nearby and try again.'
            : 'Wi-Fi setup incomplete. Verify your Wi-Fi details and try again.';
      });
    } finally {
      _isProvisioningInProgress = false;
    }
  }

  Future<void> _completeRoomAssignment() async {
    final finalRoom = _customRoomController.text.trim().isNotEmpty
        ? _customRoomController.text.trim()
        : _selectedRoom;

    final targetIdentity =
        _activeIdentity ??
        widget.channel?.deviceIdentity ??
        OnboardingDeviceIdentity(
          deviceId: widget.deviceId ?? 'device-001',
          serialNumber: widget.serialNumber ?? 'SN-001',
          productVariantId: widget.model ?? 'eh-smart-switch-3x',
          hardwareRevision: 'HW_1_0',
          firmwareFamily: 'esp32-switch-platform',
          displayName: widget.deviceName,
        );

    final devSummary = ConnectedDeviceSummary(
      id: targetIdentity.deviceId,
      name: targetIdentity.displayName,
      model: targetIdentity.productVariantId,
      firmware: '1.0.0',
      connectedVia: 'Wi-Fi (2.4 GHz)',
      signalLabel: 'Strong',
      roomName: finalRoom,
      online: true,
    );

    if (widget.spaceId != null && widget.spaceId!.isNotEmpty) {
      await _storageService.saveDeviceForSpace(widget.spaceId!, devSummary);
    } else {
      await _storageService.saveDevice(devSummary);
    }

    _isProvisioned = true;

    widget.onDeviceProvisioned?.call(
      deviceId: targetIdentity.deviceId,
      displayName: targetIdentity.displayName,
      serialNumber: targetIdentity.serialNumber,
      roomName: finalRoom,
      model: targetIdentity.productVariantId,
    );

    if (mounted) {
      setState(() {
        _stage = ProvisioningUiStage.success;
        _statusDetail = 'Setup complete! Your device is ready to use.';
      });
    }
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
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
        ),
        title: Text(
          'Set up device',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _buildStageContent(tokens),
        ),
      ),
    );
  }

  Widget _buildStageContent(EHThemeTokens tokens) {
    switch (_stage) {
      case ProvisioningUiStage.readyPreview:
        return _buildReadyPreview(tokens);
      case ProvisioningUiStage.inputCredentials:
        return _buildWifiForm(tokens);
      case ProvisioningUiStage.verifyDevice:
        return _buildVerifyDevice(tokens);
      case ProvisioningUiStage.commissioningHandshake:
      case ProvisioningUiStage.sendingWifi:
      case ProvisioningUiStage.awaitingDeviceAck:
        return _buildProgressState(tokens);
      case ProvisioningUiStage.roomAssignment:
        return _buildRoomAssignment(tokens);
      case ProvisioningUiStage.success:
        return _buildSuccess(tokens);
      case ProvisioningUiStage.failed:
        return _buildFailure(tokens);
    }
  }

  /// Page 3 Design: Product ready preview with Proceed button.
  Widget _buildReadyPreview(EHThemeTokens tokens) {
    return Padding(
      key: const ValueKey('stage_ready_preview'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Spacer(),
          Center(
            child: ProductImageWidget(
              imageUrl: _resolvedImageUrl,
              size: 220,
              borderRadius: BorderRadius.circular(24),
              placeholderColor: tokens.surfaceCard,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.deviceName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Powered on and ready. Tap Proceed to connect it to your Wi-Fi.',
              style: TextStyle(
                fontSize: 15,
                color: tokens.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                setState(() {
                  _stage = ProvisioningUiStage.inputCredentials;
                });
              },
              child: const Text(
                'Proceed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Page 4 Design: Wi-Fi Form with collapsed instructions, QR button, SSID/Password, and Connect & Provision button.
  Widget _buildWifiForm(EHThemeTokens tokens) {
    return SingleChildScrollView(
      key: const ValueKey('stage_wifi_form'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Product thumbnail + Name + Connected over Bluetooth
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                ProductImageWidget(
                  imageUrl: _resolvedImageUrl,
                  size: 46,
                  borderRadius: BorderRadius.circular(10),
                  placeholderColor: tokens.surfaceCard,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deviceName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Connected over Bluetooth',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w500,
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
          const SizedBox(height: 16),

          // Setup Instructions Dropdown (Collapsed by default)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.info_outline_rounded, color: tokens.bluePrimary, size: 22),
                title: Text(
                  'Setup instructions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    '1. Ensure your Wi-Fi router is operating at 2.4 GHz.\n'
                    '2. Type the network SSID exactly as configured or tap "Scan QR" to auto-fill.\n'
                    '3. Keep your phone near the device while credentials are securely provisioned.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          const SizedBox(height: 20),

          // Wi-Fi Details Header & Scan QR button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wi-Fi details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '2.4 GHz networks only',
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _scanWifiQr,
                icon: Icon(Icons.qr_code_scanner_rounded, size: 18, color: tokens.bluePrimary),
                label: Text(
                  'Scan QR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.bluePrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.bluePrimary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Error Banner if present
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // SSID Field
          TextFormField(
            controller: _ssidController,
            style: TextStyle(color: tokens.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Wi-Fi Network (SSID)',
              labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 14),
              prefixIcon: Icon(Icons.wifi_rounded, color: tokens.bluePrimary),
              filled: true,
              fillColor: tokens.surfaceCard,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: tokens.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 14),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.bluePrimary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: tokens.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: tokens.surfaceCard,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Connect & Provision Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isProvisioningInProgress ? null : _startProvisioning,
              icon: _isProvisioningInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isProvisioningInProgress ? 'Provisioning...' : 'Connect & Provision',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Footer note
          Center(
            child: Text(
              'Keep your phone close to the device during setup.',
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Device Verification Step (Cryptographic Ownership Proof)
  Widget _buildVerifyDevice(EHThemeTokens tokens) {
    return Padding(
      key: const ValueKey('stage_verify_device'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify device ownership',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To secure your smart home network, scan the QR code printed on the device or its packaging.',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _openDeviceQrScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan device QR code'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _showManualQrInput = !_showManualQrInput);
              },
              child: Text(
                _showManualQrInput ? 'Hide manual entry' : 'Enter setup code manually',
                style: TextStyle(color: tokens.bluePrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (_showManualQrInput) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _qrController,
              decoration: InputDecoration(
                labelText: 'Setup code / QR payload',
                filled: true,
                fillColor: tokens.surfaceCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _verifyDeviceQr(),
                child: const Text('Submit setup code'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// In-flight Provisioning Progress Animation
  Widget _buildProgressState(EHThemeTokens tokens) {
    return Center(
      key: const ValueKey('stage_progress'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Connecting device',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusDetail,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Room Assignment Step
  Widget _buildRoomAssignment(EHThemeTokens tokens) {
    return Padding(
      key: const ValueKey('stage_room_assignment'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign a room',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Where is this ${widget.deviceName} located?',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _availableRooms.map((room) {
              final isSelected = _selectedRoom == room && _customRoomController.text.trim().isEmpty;
              return ChoiceChip(
                label: Text(room),
                selected: isSelected,
                selectedColor: tokens.bluePrimary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : tokens.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: tokens.surfaceCard,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedRoom = room;
                      _customRoomController.clear();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _customRoomController,
            decoration: InputDecoration(
              labelText: 'Or enter a custom room name',
              filled: true,
              fillColor: tokens.surfaceCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              if (val.trim().isNotEmpty) {
                setState(() {});
              }
            },
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _completeRoomAssignment,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Complete setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Success View
  Widget _buildSuccess(EHThemeTokens tokens) {
    return Center(
      key: const ValueKey('stage_success'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10B981),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Device connected!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.deviceName} is ready to control in $_selectedRoom.',
              style: TextStyle(
                fontSize: 15,
                color: tokens.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.bluePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Failure View with Retry
  Widget _buildFailure(EHThemeTokens tokens) {
    return Padding(
      key: const ValueKey('stage_failed'),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade900.withValues(alpha: 0.3),
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
          ),
          const SizedBox(height: 22),
          Text(
            'Setup encountered an issue',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? _statusDetail,
            style: TextStyle(
              fontSize: 14,
              color: tokens.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _session = null;
                  _activeIdentity = null;
                  _errorMessage = null;
                  _isProvisioningInProgress = false;
                  final hasCreds = _ssidController.text.trim().isNotEmpty;
                  _stage = hasCreds
                      ? ProvisioningUiStage.verifyDevice
                      : ProvisioningUiStage.inputCredentials;
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: tokens.bluePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Try again', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
