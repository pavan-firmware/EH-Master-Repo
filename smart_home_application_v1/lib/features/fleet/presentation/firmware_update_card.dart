import 'package:flutter/material.dart';
import '../../../core/models/fleet_models.dart';
import '../../../core/services/fleet_management_service.dart';

/// Card component showing firmware state and OTA update actions for a single device
class FirmwareUpdateCard extends StatefulWidget {
  final String deviceId;
  final String homeId;
  final String currentVersion;
  final String productVariantId;
  final String? hardwareRevision;
  final Map<String, dynamic>? availableUpdate;
  final OtaOperationStatus? otaStatus;
  final int? progressPercent;
  final FleetManagementService fleetService;
  final VoidCallback? onUpdateTriggered;

  const FirmwareUpdateCard({
    super.key,
    required this.deviceId,
    required this.homeId,
    required this.currentVersion,
    required this.productVariantId,
    this.hardwareRevision,
    this.availableUpdate,
    this.otaStatus,
    this.progressPercent,
    required this.fleetService,
    this.onUpdateTriggered,
  });

  @override
  State<FirmwareUpdateCard> createState() => _FirmwareUpdateCardState();
}

class _FirmwareUpdateCardState extends State<FirmwareUpdateCard> {
  bool _isTriggering = false;
  String? _errorMessage;

  Future<void> _handleInitiateUpdate(String releaseId) async {
    setState(() {
      _isTriggering = true;
      _errorMessage = null;
    });

    try {
      await widget.fleetService.initiateOtaUpdate(
        deviceId: widget.deviceId,
        releaseId: releaseId,
        homeId: widget.homeId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firmware update started successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onUpdateTriggered?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTriggering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = widget.availableUpdate != null;
    final targetVersion = widget.availableUpdate?['version'] as String? ?? '';
    final releaseNotes = widget.availableUpdate?['releaseNotes'] as String?;
    final releaseId = widget.availableUpdate?['releaseId'] as String? ?? '';

    final isUpdating = widget.otaStatus != null &&
        [
          OtaOperationStatus.queued,
          OtaOperationStatus.downloading,
          OtaOperationStatus.verifying,
          OtaOperationStatus.installing,
          OtaOperationStatus.rebooting,
          OtaOperationStatus.confirming
        ].contains(widget.otaStatus);

    final isFailed = widget.otaStatus == OtaOperationStatus.failed ||
        widget.otaStatus == OtaOperationStatus.rolledBack;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Current Version
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Device Firmware',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Chip(
                  label: Text('v${widget.currentVersion}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.grey.withAlpha(30),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Updating Progress State
            if (isUpdating) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Updating to v$targetVersion (${widget.otaStatus?.name.toUpperCase()})...',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue),
                        ),
                        Text(
                          '${widget.progressPercent ?? 50}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (widget.progressPercent ?? 50) / 100.0,
                      backgroundColor: Colors.blue.withAlpha(40),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ]
            // Update Available State
            else if (hasUpdate) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.new_releases_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Update Available: v$targetVersion',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        releaseNotes,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTriggering ? null : () => _handleInitiateUpdate(releaseId),
                        icon: _isTriggering
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.file_download_rounded, size: 18),
                        label: const Text('Install Update Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Latest / Up-to-Date State
            else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Firmware is up to date',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            // Error / Rollback Notice
            if (isFailed || _errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage ?? (widget.otaStatus == OtaOperationStatus.rolledBack ? 'Rollback detected to previous partition' : 'Update failed'),
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
