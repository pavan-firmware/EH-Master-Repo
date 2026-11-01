import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';

/// Full-screen camera QR scanner dialog with permission checks, lifecycle recovery, and error guidance.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (context) => const QrScannerDialog(),
    );
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
    debugPrint('[QR] SCAN_STARTED');
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
        _hasScanned = true;
        debugPrint('[QR] SCAN_DETECTED: ${rawValue.trim()}');
        Navigator.of(context).pop(rawValue.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

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
                        const SizedBox(height: 16),
                        Text(
                          'Camera Error: ${error.errorCode.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            _controller?.start();
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Camera'),
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.bluePrimary,
                          ),
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
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white70,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Camera Permission Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _permanentlyDenied
                          ? 'Camera access is disabled. Please enable camera permission in App Settings to scan the device QR code.'
                          : 'Please grant camera permission to scan your EH Home device QR code.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
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
                  const Expanded(
                    child: Text(
                      'Scan Device QR Code',
                      style: TextStyle(
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
                  border: Border.all(color: tokens.bluePrimary, width: 2.5),
                  borderRadius: BorderRadius.circular(24),
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
                    child: const Text(
                      'Align the QR code on your EH Home device within the frame',
                      style: TextStyle(
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
