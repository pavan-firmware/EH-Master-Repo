import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../onboarding/ble/ble_commissioning_channel.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/services/onboarding_service.dart';

enum ProvisioningUiStage {
  inputCredentials,
  commissioningHandshake,
  sendingWifi,
  awaitingDeviceAck,
  roomAssignment,
  success,
  failed,
}

class DeviceProvisioningPage extends StatefulWidget {
  const DeviceProvisioningPage({
    super.key,
    required this.deviceName,
    this.deviceId,
    this.serialNumber,
    this.channel,
    this.onboardingService,
    this.onDeviceProvisioned,
  });

  final String deviceName;
  final String? deviceId;
  final String? serialNumber;
  final BleCommissioningChannel? channel;
  final OnboardingService? onboardingService;
  final void Function({
    required String deviceId,
    required String displayName,
    required String serialNumber,
    String? roomName,
  })?
  onDeviceProvisioned;

  @override
  State<DeviceProvisioningPage> createState() => _DeviceProvisioningPageState();
}

class _DeviceProvisioningPageState extends State<DeviceProvisioningPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  ProvisioningUiStage _stage = ProvisioningUiStage.inputCredentials;
  String? _errorMessage;
  String _statusDetail =
      'Enter your 2.4 GHz Wi-Fi details to connect this device.';
  late final OnboardingService _service;
  EhProv1Session? _session;

  @override
  void initState() {
    super.initState();
    _service =
        widget.onboardingService ??
        DefaultOnboardingService(channel: widget.channel);
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('gatt_err_unlikely') ||
        lower.contains('writecharacteristicfailure') ||
        lower.contains('status 14')) {
      return "Couldn't send secure setup data. Keep device nearby and retry.";
    }
    if (lower.contains('rejected') ||
        lower.contains('could not accept') ||
        lower.contains('could not connect') ||
        lower.contains('ssid')) {
      return "The device could not connect to this Wi-Fi network. Check the network name and password.";
    }
    if (lower.contains('disconnected') || lower.contains('timeout')) {
      return "The device disconnected or took too long to respond. Keep it nearby and try again.";
    }
    return error
        .replaceFirst('Exception: ', '')
        .replaceFirst('BLE Wi-Fi provisioning exchange failed: ', '');
  }

  Future<void> _startProvisioning() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      setState(() {
        _errorMessage = 'Wi-Fi network name (SSID) is required';
      });
      return;
    }

    try {
      final identity =
          widget.channel?.deviceIdentity ??
          (widget.deviceId != null && widget.serialNumber != null
              ? OnboardingDeviceIdentity(
                  deviceId: widget.deviceId!,
                  serialNumber: widget.serialNumber!,
                  productVariantId: 'eh-smart-switch-3x',
                  hardwareRevision: 'HW_1_0',
                  firmwareFamily: 'esp32-switch-platform',
                  displayName: widget.deviceName,
                )
              : null);

      if (identity == null) {
        throw Exception(
          'Device identity could not be verified from hardware (6105). Please reconnect.',
        );
      }

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

        // Step 2: Prove Identity (AUTH -> AUTH_ACK)
        setState(() {
          _statusDetail = 'Verifying cryptographic device identity...';
        });

        final authResult = await _service.proveIdentity(
          sessionId: _session!.sessionId,
          identity: identity,
          deviceChallenge: Uint8List.fromList(_session!.deviceChallenge ?? []),
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
        timeout: const Duration(seconds: 20),
      );
      if (connectionConfirm.hasFailed) {
        throw Exception(
          connectionConfirm.errorMessage ??
              'The device could not connect to this Wi-Fi network. Check the password and try again.',
        );
      }

      // Step 5: Complete & Update Home State
      if (widget.onDeviceProvisioned != null) {
        widget.onDeviceProvisioned!(
          deviceId: identity.deviceId,
          displayName: identity.displayName,
          serialNumber: identity.serialNumber,
          roomName: 'Living Room',
        );
      }

      setState(() {
        _stage = ProvisioningUiStage.success;
        _statusDetail =
            'Device connected to Wi-Fi and successfully commissioned!';
      });
    } catch (e) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        title: Text(
          'Set up device',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            widget.deviceName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusDetail,
            style: TextStyle(color: tokens.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 24),

          if (_stage == ProvisioningUiStage.inputCredentials) ...[
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                labelText: 'Wi-Fi Network (SSID)',
                prefixIcon: const Icon(Icons.wifi_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: tokens.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _startProvisioning,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.blueDarker,
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Connect & Provision'),
              ),
            ),
          ] else if (_stage == ProvisioningUiStage.commissioningHandshake ||
              _stage == ProvisioningUiStage.sendingWifi ||
              _stage == ProvisioningUiStage.awaitingDeviceAck) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: tokens.bluePrimary),
                    const SizedBox(height: 24),
                    Text(
                      _stage == ProvisioningUiStage.commissioningHandshake
                          ? 'Establishing Secure Session…'
                          : 'Sending Wi-Fi Credentials…',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Do not close the app or power off your device.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_stage == ProvisioningUiStage.success) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tokens.successContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.success,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup Complete!',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your device is securely commissioned and connected.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.blueDarker,
                ),
                child: const Text('Back to Home'),
              ),
            ),
          ] else if (_stage == ProvisioningUiStage.failed) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.warningContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: tokens.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup Failed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage ?? 'Unknown error occurred.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () => setState(() {
                  _stage = ProvisioningUiStage.inputCredentials;
                  _errorMessage = null;
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.blueDarker,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
