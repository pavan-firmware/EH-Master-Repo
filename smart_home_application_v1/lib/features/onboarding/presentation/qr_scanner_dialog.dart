import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';

enum QrScannerMode {
  all,
  deviceVerification,
  wifiCredentials,
}

/// Parsed standard Wi-Fi QR code (`WIFI:T:...;S:...;P:...;;`).
class WifiQrPayload {
  final String ssid;
  final String password;
  final String security;
  final bool hidden;

  const WifiQrPayload({
    required this.ssid,
    required this.password,
    this.security = 'WPA',
    this.hidden = false,
  });

  static WifiQrPayload? tryParse(String raw) {
    final text = raw.trim();
    if (!text.toUpperCase().startsWith('WIFI:')) return null;

    String ssid = '';
    String password = '';
    String security = 'WPA';
    bool hidden = false;

    final content = text.substring(5);
    final buffer = StringBuffer();
    String? currentKey;
    bool escaped = false;

    for (int i = 0; i < content.length; i++) {
      final ch = content[i];
      if (escaped) {
        buffer.write(ch);
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (ch == ':' && currentKey == null) {
        currentKey = buffer.toString().toUpperCase();
        buffer.clear();
      } else if (ch == ';') {
        if (currentKey != null) {
          final val = buffer.toString();
          switch (currentKey) {
            case 'S':
              ssid = val;
              break;
            case 'P':
              password = val;
              break;
            case 'T':
              security = val;
              break;
            case 'H':
              hidden = val.toLowerCase() == 'true';
              break;
          }
          currentKey = null;
          buffer.clear();
        }
      } else {
        buffer.write(ch);
      }
    }

    if (ssid.isEmpty) return null;
    return WifiQrPayload(
      ssid: ssid,
      password: password,
      security: security,
      hidden: hidden,
    );
  }
}

/// Full-screen camera QR scanner dialog with permission checks, lifecycle recovery, and error guidance.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({
    super.key,
    this.mode = QrScannerMode.all,
  });

  final QrScannerMode mode;

  static Future<String?> show(
    BuildContext context, {
    QrScannerMode mode = QrScannerMode.all,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (context) => QrScannerDialog(mode: mode),
    );
  }

  static Future<WifiQrPayload?> showWifiScanner(BuildContext context) async {
    final raw = await show(context, mode: QrScannerMode.wifiCredentials);
    if (raw == null || raw.isEmpty) return null;
    return WifiQrPayload.tryParse(raw);
  }

  static Future<String?> showDeviceScanner(BuildContext context) {
    return show(context, mode: QrScannerMode.deviceVerification);
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> with WidgetsBindingObserver {
  MobileScannerController? _controller;

  bool _isChecking = true;
  bool _hasScanned = false;
  bool _permissionGranted = false;
  bool _permanentlyDenied = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_permissionGranted) {
      _checkAndRequestPermission();
    }
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() => _isChecking = true);
    final currentStatus = await Permission.camera.status;
    if (!mounted) return;

    if (currentStatus.isGranted) {
      _startScanner();
      return;
    }

    final requestedStatus = await Permission.camera.request();
    if (!mounted) return;

    if (requestedStatus.isGranted) {
      _startScanner();
    } else if (requestedStatus.isPermanentlyDenied) {
      setState(() {
        _permissionGranted = false;
        _permanentlyDenied = true;
        _isChecking = false;
      });
    } else {
      setState(() {
        _permissionGranted = false;
        _permanentlyDenied = false;
        _isChecking = false;
      });
    }
  }

  void _startScanner() {
    _controller ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    try {
      _controller?.start();
    } catch (_) {}
    setState(() {
      _permissionGranted = true;
      _permanentlyDenied = false;
      _isChecking = false;
    });
    debugPrint('[QR] SCAN_STARTED mode=${widget.mode}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final code = rawValue.trim();
        final isWifi = code.toUpperCase().startsWith('WIFI:');

        if (widget.mode == QrScannerMode.wifiCredentials) {
          if (!isWifi) {
            setState(() {
              _scanError = 'Invalid Wi-Fi QR code. Please scan a standard Wi-Fi network QR code.';
            });
            return;
          }
        }

        if (widget.mode == QrScannerMode.deviceVerification) {
          if (isWifi) {
            setState(() {
              _scanError = 'This is a Wi-Fi QR code. Please scan the device setup QR code.';
            });
            return;
          }
        }

        _hasScanned = true;
        debugPrint('[QR] SCAN_DETECTED: $code');
        Navigator.of(context).pop(code);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final title = widget.mode == QrScannerMode.wifiCredentials
        ? 'Scan Wi-Fi QR Code'
        : (widget.mode == QrScannerMode.deviceVerification
            ? 'Scan Device QR Code'
            : 'Scan QR Code');

    final subtitle = widget.mode == QrScannerMode.wifiCredentials
        ? 'Align your Wi-Fi network QR code within the frame'
        : 'Align the QR code on your EH Home device within the frame';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isChecking)
            Center(
              child: CircularProgressIndicator(color: tokens.bluePrimary),
            )
          else if (_permissionGranted && _controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.amber,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Camera initialization error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.errorDetails?.message ?? 'Please restart the app or retry.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            _controller?.start();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.bluePrimary,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _permanentlyDenied
                          ? Icons.no_photography_rounded
                          : Icons.camera_alt_outlined,
                      size: 64,
                      color: tokens.bluePrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _permanentlyDenied
                          ? 'Camera Permission Blocked'
                          : 'Camera Access Needed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _permanentlyDenied
                          ? 'Camera permission is permanently denied. Please grant permission in device settings to scan QR codes.'
                          : 'To scan QR codes for quick device provisioning, please allow camera access.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_permanentlyDenied)
                      FilledButton(
                        onPressed: openAppSettings,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.bluePrimary,
                        ),
                        child: const Text('Open App Settings'),
                      )
                    else
                      FilledButton(
                        onPressed: _checkAndRequestPermission,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.bluePrimary,
                        ),
                        child: const Text('Grant Permission'),
                      ),
                  ],
                ),
              ),
            ),

          // Top Header & Close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance close button
                ],
              ),
            ),
          ),

          // Center Viewfinder target box
          if (_permissionGranted && !_isChecking)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _scanError != null ? Colors.redAccent : tokens.bluePrimary,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),

          // In-scanner Error notice if wrong QR mode scanned
          if (_scanError != null)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 70, left: 24, right: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _scanError!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom instruction text
          if (_permissionGranted && !_isChecking)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
