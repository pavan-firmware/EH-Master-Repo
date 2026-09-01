import 'package:flutter/material.dart';
import '../../../core/models/sync_models.dart';
import '../../../core/services/sync_service.dart';
import 'sync_center_page.dart';

/// Compact Sync Status Badge Widget for Home and Settings app bars
class SyncStatusWidget extends StatelessWidget {
  final SyncService syncService;
  final VoidCallback? onTap;

  const SyncStatusWidget({
    super.key,
    required this.syncService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: syncService,
      builder: (context, _) {
        final status = syncService.status;
        final pendingCount = syncService.pendingMutations.length;

        IconData icon;
        Color color;
        String label;

        switch (status) {
          case SyncStatus.synced:
            icon = Icons.cloud_done_rounded;
            color = const Color(0xFF10B981); // Emerald Green
            label = 'Synced';
            break;
          case SyncStatus.syncing:
            icon = Icons.sync_rounded;
            color = const Color(0xFF3B82F6); // Blue
            label = 'Syncing...';
            break;
          case SyncStatus.pendingChanges:
            icon = Icons.cloud_upload_rounded;
            color = const Color(0xFFF59E0B); // Amber
            label = '$pendingCount Pending';
            break;
          case SyncStatus.offline:
            icon = Icons.cloud_off_rounded;
            color = const Color(0xFF6B7280); // Slate Grey
            label = 'Offline';
            break;
          case SyncStatus.conflict:
            icon = Icons.warning_amber_rounded;
            color = const Color(0xFFEF4444); // Red
            label = 'Conflict';
            break;
          case SyncStatus.error:
            icon = Icons.error_outline_rounded;
            color = const Color(0xFFEF4444);
            label = 'Error';
            break;
        }

        return InkWell(
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SyncCenterPage(syncService: syncService),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == SyncStatus.syncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
