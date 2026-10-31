import 'package:flutter/material.dart';

import '../../../core/models/update_models.dart';
import '../../../core/repositories/cloud_update_repository.dart';
import '../../../core/repositories/update_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.target;
  }

  Future<void> _handleInitiateUpdate() async {
    final repo = widget.updateRepository;
    final deviceId = _currentTarget.deviceId;
    final releaseId = _currentTarget.releaseId;
    final homeId = (_currentTarget.homeId != null && _currentTarget.homeId!.isNotEmpty)
        ? _currentTarget.homeId!
        : 'home_local_primary';

    if (repo is! CloudUpdateRepository || deviceId == null || releaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot initiate update: Missing release metadata')),
      );
      return;
    }

    setState(() => _isInitiating = true);

    final success = await repo.initiateUpdate(
      deviceId: deviceId,
      releaseId: releaseId,
      homeId: homeId,
    );

    if (!mounted) return;
    setState(() => _isInitiating = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTA update dispatched to ${_currentTarget.name}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _currentTarget = UpdateTarget(
          kind: _currentTarget.kind,
          name: _currentTarget.name,
          currentVersion: _currentTarget.currentVersion,
          status: UpdateTargetStatus.updating,
          availableVersion: _currentTarget.availableVersion,
          releaseNotes: _currentTarget.releaseNotes,
          releaseId: _currentTarget.releaseId,
          downloadUrl: _currentTarget.downloadUrl,
          deviceId: _currentTarget.deviceId,
          homeId: _currentTarget.homeId,
          iconKey: _currentTarget.iconKey,
        );
      });
      widget.onUpdateInitiated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to trigger update. Check device network connection.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isAvailable = _currentTarget.status == UpdateTargetStatus.updateAvailable;
    final isUpdating = _currentTarget.status == UpdateTargetStatus.updating;

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
                onPressed: _isInitiating ? null : _handleInitiateUpdate,
                icon: _isInitiating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.system_update_rounded),
                label: Text(
                  _isInitiating ? 'Initiating Safe OTA...' : 'Install Firmware Update',
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
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Downloading & Writing Partition',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Device is streaming the image from your PC over LAN. It will reboot automatically upon checksum verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.4),
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
