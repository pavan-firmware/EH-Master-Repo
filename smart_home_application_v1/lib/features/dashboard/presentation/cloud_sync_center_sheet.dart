import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/home_controller.dart';
import '../../../core/services/change_tracking_service.dart';
import '../../../core/theme/app_theme.dart';

class CloudSyncCenterSheet extends StatefulWidget {
  const CloudSyncCenterSheet({
    super.key,
    required this.homeController,
  });

  final HomeController homeController;

  @override
  State<CloudSyncCenterSheet> createState() => _CloudSyncCenterSheetState();
}

class _CloudSyncCenterSheetState extends State<CloudSyncCenterSheet> {
  bool _isUploading = false;
  bool _isDownloading = false;
  bool _promptAtStartup = true;
  bool _showChangesDetails = false;

  @override
  void initState() {
    super.initState();
    _loadStartupReminderPref();
  }

  Future<void> _loadStartupReminderPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontRemind = prefs.getBool('eh_unsaved_dont_remind') ?? false;
      if (mounted) {
        setState(() => _promptAtStartup = !dontRemind);
      }
    } catch (_) {}
  }

  Future<void> _setStartupReminderPref(bool enabled) async {
    setState(() => _promptAtStartup = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eh_unsaved_dont_remind', !enabled);
      if (enabled) {
        await prefs.remove('eh_unsaved_remind_after');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Startup review reminder re-enabled. You will be prompted at app launch when changes exist.'
                  : 'Startup review reminder disabled.',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleUpload() async {
    setState(() => _isUploading = true);
    final success = await widget.homeController.uploadLocalChangesToCloud();
    if (!mounted) return;
    setState(() => _isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Local configuration successfully backed up and synced to your cloud account.'
              : 'Failed to sync with cloud. Check server connection.',
        ),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download & Restore from Cloud?'),
        content: const Text(
          'This will retrieve your saved rooms, devices, and layouts from your cloud account. Any unsaved local modifications will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download & Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDownloading = true);
      final success = await widget.homeController.downloadCloudChanges();
      if (!mounted) return;
      setState(() => _isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Cloud configuration downloaded and applied.'
                : 'Failed to download cloud setup.',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return AnimatedBuilder(
      animation: Listenable.merge([widget.homeController, ChangeTrackingService.instance]),
      builder: (context, _) {
        final pendingChanges = ChangeTrackingService.instance.pendingChanges;
        final changesByArea = ChangeTrackingService.instance.changesByArea;
        final hasPending = widget.homeController.hasPendingCloudUpload || pendingChanges.isNotEmpty;
        final lastSync = widget.homeController.lastCloudSyncTime;

        return Container(
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: tokens.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.bluePrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.cloud_sync_rounded, color: tokens.bluePrimary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Sync & Backup Center',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Preserve rooms, hardware setups, and custom labels',
                              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 1. Ambient Sync Status Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: hasPending
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (hasPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasPending ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                            color: hasPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasPending ? 'Pending Offline Changes' : 'Cloud Setup In Sync',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasPending
                                    ? 'Local modifications have not been backed up to your account yet.'
                                    : (lastSync != null
                                        ? 'Last sync: ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')} today'
                                        : 'All rooms, device names, and favourites are secured.'),
                                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. "Review Changes Before Upload" Expandable Tile
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.isDark ? const Color(0xFF141F30) : const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setState(() => _showChangesDetails = !_showChangesDetails),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: tokens.bluePrimary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.rule_folder_rounded, color: tokens.bluePrimary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Review Changes Before Upload',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pendingChanges.isNotEmpty
                                            ? '${pendingChanges.length} pending change(s) across ${changesByArea.keys.length} categories'
                                            : 'Inspect pending changes or verify cloud sync status',
                                        style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showChangesDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  color: tokens.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showChangesDetails) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: changesByArea.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, color: tokens.success, size: 28),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No pending offline changes',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'All spaces, devices, controls, and routines are in sync with your cloud backup.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final entry in changesByArea.entries) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                                          child: Row(
                                            children: [
                                              Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: tokens.bluePrimary,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: tokens.bluePrimary.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${entry.value.length}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: tokens.bluePrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...entry.value.map((c) => _buildTrackedChangeItem(c, tokens)),
                                        const SizedBox(height: 8),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Startup Dialog Preference Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.isDark ? const Color(0xFF141F30) : const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prompt on App Launch',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ask to review & upload offline changes at startup',
                                style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _promptAtStartup,
                          activeThumbColor: Colors.white,
                          activeTrackColor: tokens.bluePrimary,
                          inactiveThumbColor: tokens.isDark ? tokens.textSecondary : const Color(0xFF757575),
                          inactiveTrackColor: tokens.isDark ? tokens.bgSecondary : const Color(0xFFE0E0E0),
                          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.transparent;
                            }
                            return tokens.borderSubtle;
                          }),
                          onChanged: _setStartupReminderPref,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (!widget.homeController.isCloudReachable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: tokens.isDark ? const Color(0xFF261D15) : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tokens.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 18, color: tokens.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Cloud is offline. Connect to internet to sync or restore.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 4. Primary Upload Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_isUploading || !widget.homeController.isCloudReachable) ? null : _handleUpload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(_isUploading ? 'Uploading Configuration...' : 'Upload Local Changes to Cloud'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        disabledForegroundColor: tokens.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Secondary Download & Restore Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: (_isDownloading || !widget.homeController.isCloudReachable) ? null : _handleDownload,
                      icon: _isDownloading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary),
                            )
                          : Icon(
                              Icons.cloud_download_rounded,
                              color: widget.homeController.isCloudReachable
                                  ? tokens.textPrimary
                                  : (tokens.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                      label: Text(
                        _isDownloading ? 'Restoring from Cloud...' : 'Restore Setup from Cloud',
                        style: TextStyle(
                          color: widget.homeController.isCloudReachable
                              ? tokens.textPrimary
                              : (tokens.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: widget.homeController.isCloudReachable
                              ? tokens.borderSubtle
                              : (tokens.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackedChangeItem(TrackedChange change, EHThemeTokens tokens) {
    final Color badgeBg;
    final Color badgeFg;
    switch (change.changeType) {
      case ChangeType.created:
        badgeBg = tokens.successContainer;
        badgeFg = tokens.success;
        break;
      case ChangeType.modified:
        badgeBg = tokens.warningContainer;
        badgeFg = tokens.warning;
        break;
      case ChangeType.deleted:
        badgeBg = tokens.errorContainer;
        badgeFg = tokens.error;
        break;
    }

    final IconData icon = switch (change.entityType.toLowerCase()) {
      'room' => Icons.meeting_room_outlined,
      'device' => Icons.memory_rounded,
      'control' || 'channel' || 'channel_alert' => Icons.toggle_on_outlined,
      'quick_controls' || 'favourites' => Icons.star_border_rounded,
      'routine' || 'automation' => Icons.auto_awesome_rounded,
      'home' || 'space' => Icons.home_work_outlined,
      'notification_preference' => Icons.notifications_none_rounded,
      _ => Icons.tune_rounded,
    };

    final timeStr = '${change.timestamp.hour.toString().padLeft(2, '0')}:${change.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.bluePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tokens.bluePrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.displaySummary,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${change.entityType.toUpperCase()} · $timeStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              change.changeType.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
