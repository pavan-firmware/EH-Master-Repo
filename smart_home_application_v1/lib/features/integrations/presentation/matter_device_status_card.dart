import 'package:flutter/material.dart';
import '../../../core/models/matter_models.dart';
import '../../../core/theme/app_theme.dart';

/// Card presenting a Matter-capable device's Matter interoperability status,
/// connected fabrics, and option to share / commission into additional ecosystems.
class MatterDeviceStatusCard extends StatelessWidget {
  final MatterDeviceSummary device;
  final VoidCallback? onShareDevice;
  final VoidCallback? onManageFabrics;

  const MatterDeviceStatusCard({
    super.key,
    required this.device,
    this.onShareDevice,
    this.onManageFabrics,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.bluePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.hub_outlined,
                  color: tokens.bluePrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Matter Node: ${device.nodeId}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (device.isCommissioned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: tokens.success),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: tokens.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Ready to Link',
                    style: TextStyle(
                      color: tokens.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Fabrics info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connected Ecosystems',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${device.activeFabricsCount} / ${device.maxFabricsSupported} Fabrics',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: device.maxFabricsSupported > 0
                  ? device.activeFabricsCount / device.maxFabricsSupported
                  : 0.0,
              backgroundColor: tokens.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.bluePrimary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              if (onShareDevice != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareDevice,
                    icon: const Icon(Icons.qr_code_2, size: 16),
                    label: const Text('Share / Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.bluePrimary,
                      side: BorderSide(color: tokens.bluePrimary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (onShareDevice != null && onManageFabrics != null)
                const SizedBox(width: 8),
              if (onManageFabrics != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManageFabrics,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Fabrics'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
