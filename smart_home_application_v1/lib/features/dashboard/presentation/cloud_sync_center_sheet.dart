import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/home_controller.dart';
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
      animation: widget.homeController,
      builder: (context, _) {
        final hasPending = widget.homeController.hasPendingCloudUpload;
        final lastSync = widget.homeController.lastCloudSyncTime;
        final devices = widget.homeController.devices;
        final rooms = widget.homeController.rooms;
        final favouritesCount = widget.homeController.favouriteControlIds.length;
        final quickControlsCount = widget.homeController.selectedQuickControlIds.length;

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
                                        'Inspect rooms, devices, and labels to be uploaded',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildChangeRow(
                                  icon: Icons.meeting_room_outlined,
                                  title: 'Spaces & Rooms',
                                  detail: rooms.isEmpty
                                      ? 'Default space'
                                      : '${rooms.length} space(s) defined (${rooms.map((r) => r.name).take(3).join(', ')})',
                                  tokens: tokens,
                                ),
                                const SizedBox(height: 12),
                                _buildChangeRow(
                                  icon: Icons.memory_rounded,
                                  title: 'Connected Hardware Nodes',
                                  detail: '${devices.length} commissioned devices (${devices.map((d) => d.name).take(3).join(', ')})',
                                  tokens: tokens,
                                ),
                                const SizedBox(height: 12),
                                _buildChangeRow(
                                  icon: Icons.star_border_rounded,
                                  title: 'Dashboard Favourites & Tiles',
                                  detail: '$favouritesCount favourite items, $quickControlsCount quick actions',
                                  tokens: tokens,
                                ),
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
                          activeThumbColor: tokens.bluePrimary,
                          onChanged: _setStartupReminderPref,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Primary Upload Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _handleUpload,
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
                      onPressed: _isDownloading ? null : _handleDownload,
                      icon: _isDownloading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary),
                            )
                          : Icon(Icons.cloud_download_rounded, color: tokens.textPrimary),
                      label: Text(
                        _isDownloading ? 'Restoring from Cloud...' : 'Restore Setup from Cloud',
                        style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.borderSubtle),
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

  Widget _buildChangeRow({
    required IconData icon,
    required String title,
    required String detail,
    required EHThemeTokens tokens,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tokens.bluePrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.textPrimary),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                style: TextStyle(fontSize: 11, color: tokens.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
