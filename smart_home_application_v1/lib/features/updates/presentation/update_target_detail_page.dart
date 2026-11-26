import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/update_models.dart';
import '../../../core/repositories/cloud_update_repository.dart';
import '../../../core/repositories/update_repository.dart';
import '../../../core/services/local_lan_device_service.dart';
import '../../../core/theme/app_theme.dart';

class UpdateTargetDetailPage extends StatefulWidget {
  const UpdateTargetDetailPage({
    super.key,
    required this.target,
    this.updateRepository,
    this.onUpdateInitiated,
  });

  final UpdateTarget target;
  final UpdateRepository? updateRepository;
  final VoidCallback? onUpdateInitiated;

  @override
  State<UpdateTargetDetailPage> createState() => _UpdateTargetDetailPageState();
}

class _UpdateTargetDetailPageState extends State<UpdateTargetDetailPage> {
  bool _isInitiating = false;
  late UpdateTarget _currentTarget;
  Timer? _progressTimer;
  int? _liveProgressPct;
  String _otaStatusDetail = 'Dispatching firmware update to device...';

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.target;
    if (_currentTarget.status == UpdateTargetStatus.updating) {
      _startHardwareStatusPolling();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startHardwareStatusPolling() {
    final devId = _currentTarget.deviceId;
    if (devId == null || devId.isEmpty) return;

    int polls = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      polls++;
      final statusMap = await LocalLanDeviceService.instance.fetchLocalOtaStatus(deviceId: devId);
      if (!mounted) return;

      if (statusMap != null) {
        final hwState = (statusMap['state'] ?? 'IDLE').toString().toUpperCase();
        final pct = (statusMap['progressPercent'] as num?)?.toInt();
        final reportedVer = statusMap['firmwareVersion']?.toString().trim() ?? '';
        final targetVer = (_currentTarget.availableVersion ?? '').replaceAll('Version ', '').trim();
        final lastErr = statusMap['lastError']?.toString() ?? '';

        if (targetVer.isNotEmpty && reportedVer == targetVer) {
          timer.cancel();
          setState(() {
            _liveProgressPct = 100;
            _currentTarget = UpdateTarget(
              kind: _currentTarget.kind,
              name: _currentTarget.name,
              currentVersion: 'Firmware $reportedVer',
              status: UpdateTargetStatus.upToDate,
              availableVersion: null,
              releaseNotes: _currentTarget.releaseNotes,
              releaseId: _currentTarget.releaseId,
              deviceId: _currentTarget.deviceId,
              homeId: _currentTarget.homeId,
              iconKey: _currentTarget.iconKey,
            );
          });
          HomeController.instance?.updateDeviceFirmwareVersion(devId, reportedVer);
          widget.onUpdateInitiated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hardware verified Firmware $reportedVer running on ${_currentTarget.name}!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        if (hwState == 'FAILED' || hwState == 'ROLLED_BACK') {
          timer.cancel();
          setState(() {
            _liveProgressPct = null;
            _currentTarget = UpdateTarget(
              kind: _currentTarget.kind,
              name: _currentTarget.name,
              currentVersion: _currentTarget.currentVersion,
              status: UpdateTargetStatus.updateAvailable,
              availableVersion: _currentTarget.availableVersion,
              releaseNotes: _currentTarget.releaseNotes,
              releaseId: _currentTarget.releaseId,
              downloadUrl: _currentTarget.downloadUrl,
              sha256: _currentTarget.sha256,
              binarySizeBytes: _currentTarget.binarySizeBytes,
              deviceId: _currentTarget.deviceId,
              homeId: _currentTarget.homeId,
              iconKey: _currentTarget.iconKey,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hardware OTA failed${lastErr.isNotEmpty ? ": $lastErr" : ""}'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        setState(() {
          if (pct != null && pct > 0) _liveProgressPct = pct;
          switch (hwState) {
            case 'DOWNLOADING':
              _otaStatusDetail = 'Board downloading firmware binary...';
              break;
            case 'INSTALLING':
              _otaStatusDetail = 'Writing OTA flash partition (LED rapid blink)...';
              break;
            case 'VERIFYING':
              _otaStatusDetail = 'Verifying SHA-256 checksum on chip...';
              break;
            case 'REBOOTING':
              _otaStatusDetail = 'Rebooting hardware into new firmware...';
              break;
            default:
              if (polls > 4 && (pct == null || pct == 0)) {
                _otaStatusDetail = 'Waiting for hardware to start OTA download...';
              }
              break;
          }
        });
      } else {
        setState(() {
          _otaStatusDetail = 'Device rebooting or applying OTA flash...';
        });
      }

      if (polls >= 80) {
        timer.cancel();
      }
    });
  }

  Future<void> _handleInitiateUpdate() async {
    final repo = widget.updateRepository;
    final deviceId = _currentTarget.deviceId;
    final releaseId = _currentTarget.releaseId;
    final homeId = (_currentTarget.homeId != null && _currentTarget.homeId!.isNotEmpty)
        ? _currentTarget.homeId!
        : 'home_local_primary';

    // 1. Hardware Reachability Pre-Check
    // Validate if the physical device is reachable on local LAN or registered as online
    final ctrl = HomeController.instance;
    final isReachableOnLan = deviceId != null &&
        (LocalLanDeviceService.instance.isDeviceReachableOnLan(deviceId) ||
            (ctrl != null && ctrl.devices.any((d) => (d.id == deviceId || d.id.toLowerCase() == deviceId.toLowerCase()) && d.online)));

    if (!isReachableOnLan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Device "${_currentTarget.name}" is offline on local Wi-Fi. Ensure power is ON and switch is connected before installing firmware.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (repo is! CloudUpdateRepository || releaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot initiate update: Missing release metadata')),
      );
      return;
    }

    final targetDevId = deviceId;

    setState(() {
      _isInitiating = true;
      _otaStatusDetail = 'Handshaking with target switch over LAN...';
    });

    final success = await repo.initiateUpdate(
      deviceId: targetDevId,
      releaseId: releaseId,
      homeId: homeId,
      downloadUrl: _currentTarget.downloadUrl,
      version: _currentTarget.availableVersion?.replaceAll('Version ', ''),
      sha256: _currentTarget.sha256,
      binarySizeBytes: _currentTarget.binarySizeBytes,
    );

    if (!mounted) return;
    setState(() => _isInitiating = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTA directive sent to ${_currentTarget.name}. Polling live hardware status...'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _liveProgressPct = null;
        _currentTarget = UpdateTarget(
          kind: _currentTarget.kind,
          name: _currentTarget.name,
          currentVersion: _currentTarget.currentVersion,
          status: UpdateTargetStatus.updating,
          availableVersion: _currentTarget.availableVersion,
          releaseNotes: _currentTarget.releaseNotes,
          releaseId: _currentTarget.releaseId,
          downloadUrl: _currentTarget.downloadUrl,
          sha256: _currentTarget.sha256,
          binarySizeBytes: _currentTarget.binarySizeBytes,
          deviceId: _currentTarget.deviceId,
          homeId: _currentTarget.homeId,
          iconKey: _currentTarget.iconKey,
        );
        _otaStatusDetail = 'Waiting for hardware to begin download...';
      });
      _startHardwareStatusPolling();
      widget.onUpdateInitiated?.call();
    } else {
      final errDetail = CloudUpdateRepository.lastInitiateError ?? 'Check device & server connection.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTA failed to start: $errDetail'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isAvailable = _currentTarget.status == UpdateTargetStatus.updateAvailable;
    final isUpdating = _currentTarget.status == UpdateTargetStatus.updating;
    final ctrl = HomeController.instance;
    final devId = _currentTarget.deviceId;
    final isDeviceOnline = devId == null ||
        LocalLanDeviceService.instance.isDeviceReachableOnLan(devId) ||
        (ctrl != null && ctrl.devices.any((d) => (d.id == devId || d.id.toLowerCase() == devId.toLowerCase()) && d.online)) ||
        (devId == 'dev_switch_3x' && (LocalLanDeviceService.instance.isAnyDeviceReachableOnLan() || (ctrl != null && ctrl.devices.any((d) => d.online))));

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentTarget.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Hero Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isAvailable ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : tokens.borderSubtle,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAvailable
                    ? [const Color(0xFFF59E0B).withValues(alpha: 0.15), Colors.transparent]
                    : (isUpdating
                        ? [const Color(0xFF3B82F6).withValues(alpha: 0.15), Colors.transparent]
                        : [const Color(0xFF10B981).withValues(alpha: 0.12), Colors.transparent]),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                        : (isUpdating
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : const Color(0xFF10B981).withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isAvailable
                        ? Icons.system_update_rounded
                        : (isUpdating ? Icons.sync_rounded : Icons.verified_rounded),
                    color: isAvailable
                        ? const Color(0xFFF59E0B)
                        : (isUpdating ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAvailable
                            ? (_currentTarget.availableVersion ?? 'New Firmware Ready')
                            : (isUpdating ? 'Installing OTA Update...' : 'Firmware Up to Date'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Installed: ${_currentTarget.currentVersion}',
                        style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDeviceOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDeviceOnline ? 'Online (Local Wi-Fi)' : 'Offline (Power ON device)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDeviceOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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

          const SizedBox(height: 20),

          // 2. Release & Integrity Details
          if (isAvailable) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_rounded, size: 18, color: tokens.bluePrimary),
                      const SizedBox(width: 8),
                      Text(
                        'CRYPTOGRAPHIC INTEGRITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tokens.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailRow('Target Version', _currentTarget.availableVersion ?? 'Latest', tokens),
                  if (_currentTarget.formattedSize.isNotEmpty) ...[
                    const Divider(height: 18),
                    _detailRow('Binary Size', _currentTarget.formattedSize, tokens),
                  ],
                  if (_currentTarget.component != null) ...[
                    const Divider(height: 18),
                    _detailRow('Affected Target', _currentTarget.component!, tokens),
                  ],
                  const Divider(height: 18),
                  _detailRow(
                    'Upgrade Path',
                    _currentTarget.isDirectUpgrade
                        ? 'Direct Jump (${_currentTarget.currentVersion.replaceAll(RegExp(r'[^0-9.]'), '')} \u2192 ${_currentTarget.availableVersion?.replaceAll('Version ', 'v')})'
                        : 'Direct Upgrade',
                    tokens,
                  ),
                  const Divider(height: 18),
                  _detailRow('Verification', 'SHA-256 + Ed25519 Signed', tokens),
                  if (_currentTarget.sha256 != null) ...[
                    const Divider(height: 18),
                    _detailRow(
                      'SHA-256 Digest',
                      '${_currentTarget.sha256!.substring(0, 16)}...',
                      tokens,
                    ),
                  ],
                  const Divider(height: 18),
                  _detailRow(
                    'Package Host',
                    _currentTarget.downloadUrl != null && _currentTarget.downloadUrl!.startsWith('http://192.168.')
                        ? 'Local PC Backend'
                        : 'Secure Distribution Server',
                    tokens,
                  ),
                  const Divider(height: 18),
                  _detailRow('Rollback Protection', 'Automatic Rollback Safeguard', tokens),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 3. Why Update Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        'WHY YOU SHOULD UPDATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tokens.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentTarget.effectiveWhyUpdate,
                    style: TextStyle(fontSize: 14, height: 1.45, color: tokens.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. Changelog / Release Notes
            if (_currentTarget.releaseNotes != null && _currentTarget.releaseNotes!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Text(
                          'WHAT\'S IN THIS RELEASE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tokens.textTertiary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentTarget.releaseNotes!,
                      style: TextStyle(fontSize: 14, height: 1.45, color: tokens.textPrimary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // 4. Update Now Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isInitiating || !isDeviceOnline) ? null : _handleInitiateUpdate,
                icon: _isInitiating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(!isDeviceOnline ? Icons.wifi_off_rounded : Icons.system_update_rounded),
                label: Text(
                  _isInitiating
                      ? 'Initiating Safe OTA...'
                      : (!isDeviceOnline ? 'Device Offline (Power ON Switch)' : 'Install Firmware Update'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ] else if (isUpdating) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: tokens.bluePrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _otaStatusDetail,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _liveProgressPct != null ? (_liveProgressPct! / 100.0).clamp(0.0, 1.0) : null,
                      backgroundColor: tokens.borderControl,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.bluePrimary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _liveProgressPct != null
                        ? '$_liveProgressPct% · Hardware OTA Active'
                        : 'OTA Flashing in Progress · Safe Bootloader Active',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.bluePrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The switch is verifying SHA-256 and flashing the alternate partition. Live firmware version will update automatically once device restarts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  _detailRow('Target Type', _currentTarget.kind.name.toUpperCase(), tokens),
                  const Divider(height: 18),
                  _detailRow('Firmware Version', _currentTarget.currentVersion, tokens),
                  const Divider(height: 18),
                  _detailRow('Status', 'Active & Operating Deterministically', tokens),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, EHThemeTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary),
        ),
      ],
    );
  }
}
