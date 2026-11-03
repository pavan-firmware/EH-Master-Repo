import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/device_models.dart';
import '../core/models/home_dashboard_models.dart';
import '../core/models/room_models.dart';
import '../core/repositories/home_connection_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/activity/presentation/activity_page.dart';
import '../features/alerts/presentation/safety_alert_page.dart';
import '../features/automations/presentation/automations_page.dart';
import '../features/connection/presentation/connection_page.dart';
import '../features/dashboard/presentation/home_insights_page.dart';
import '../features/dashboard/presentation/home_page.dart';
import '../features/rooms/presentation/rooms_page.dart';
import '../features/rooms/presentation/room_context_page.dart';
import '../core/api/api_client.dart';
import '../core/models/routine_models.dart';
import '../core/models/activity_models.dart';
import '../core/repositories/settings_repository.dart';
import '../core/repositories/cloud_routine_repository.dart';
import '../core/repositories/cloud_activity_repository.dart';
import '../core/repositories/cloud_settings_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/notifications/presentation/notification_center_page.dart';
import '../features/search/presentation/global_app_search_sheet.dart';
import '../core/repositories/cloud_notification_repository.dart';
import '../core/repositories/local_notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/dashboard/presentation/cloud_sync_center_sheet.dart';
import '../core/config/app_config.dart';
import '../core/repositories/cloud_update_repository.dart';
import '../core/services/device_storage_service.dart';
import 'home_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.homeController,
    this.authController,
    this.apiClient,
    this.homeId,
  });

  final HomeController? homeController;
  final AuthController? authController;
  final ApiClient? apiClient;
  final String? homeId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final HomeController _homeController;

  // One navigator key per tab so each tab keeps its own back-stack.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  StreamSubscription<SpaceAlertItem>? _alertSub;
  Timer? _entranceDialogTimer;

  @override
  void initState() {
    super.initState();
    _homeController = widget.homeController ?? HomeController();
    _alertSub = _homeController.channelAlertStream.listen((alert) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 4),
          elevation: 6,
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            textColor: const Color(0xFF38BDF8),
            onPressed: () => _openAlertDetail(alert),
          ),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceDialogTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _checkUnsavedChangesEntranceDialog();
        }
      });
    });
  }

  Future<void> _checkUnsavedChangesEntranceDialog() async {
    if (!mounted) return;
    if (!_homeController.hasPendingCloudUpload) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final dontRemind = prefs.getBool('eh_unsaved_dont_remind') ?? false;
      if (dontRemind) return;

      final remindAfterMs = prefs.getInt('eh_unsaved_remind_after') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < remindAfterMs) return;

      if (!mounted) return;
      _showUnsavedChangesEntranceDialog();
    } catch (e) {
      debugPrint('[HOME_SHELL] Error checking unsaved reminder preferences: $e');
    }
  }

  Future<void> _showUnsavedChangesEntranceDialog() async {
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unsaved Changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'You have local offline changes that have not been backed up to the cloud. Would you like to review and upload them now?',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('close'),
              child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop('view'),
              icon: const Icon(Icons.cloud_sync_rounded, size: 18),
              label: const Text('View'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (action == 'view') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CloudSyncCenterSheet(homeController: _homeController),
      );
    } else if (action == 'close') {
      _showReminderPreferencesDialog();
    }
  }

  Future<void> _showReminderPreferencesDialog() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: const Text(
              'Reminder Preferences',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'When should we remind you again to upload your unsaved changes?',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 12),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8), size: 22),
                  title: const Text('Remind in 6 hours', style: TextStyle(fontSize: 14)),
                  onTap: () async {
                    final target = DateTime.now().add(const Duration(hours: 6)).millisecondsSinceEpoch;
                    await prefs.setInt('eh_unsaved_remind_after', target);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.today_rounded, color: Color(0xFF38BDF8), size: 22),
                  title: const Text('Remind in 1 day', style: TextStyle(fontSize: 14)),
                  onTap: () async {
                    final target = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
                    await prefs.setInt('eh_unsaved_remind_after', target);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_rounded, color: Color(0xFF38BDF8), size: 22),
                  title: const Text('Remind in 3 days', style: TextStyle(fontSize: 14)),
                  onTap: () async {
                    final target = DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;
                    await prefs.setInt('eh_unsaved_remind_after', target);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.do_not_disturb_on_rounded, color: Color(0xFFEF4444), size: 22),
                  title: const Text(
                    "Don't remind again",
                    style: TextStyle(fontSize: 14, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    await prefs.setBool('eh_unsaved_dont_remind', true);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('[HOME_SHELL] Error displaying reminder dialog: $e');
    }
  }

  void _openAlertDetail(SpaceAlertItem alert) {
    _navigatorKeys[_selectedIndex].currentState?.push(
      MaterialPageRoute(
        builder: (_) => SafetyAlertPage(
          title: alert.title,
          description: alert.message,
          spaceName: alert.spaceName,
          roomName: alert.spaceName,
          deviceId: alert.deviceId,
          timestamp: alert.timestamp,
          severity: alert.severity.name,
          onDismiss: () {
            _homeController.dismissAlert(alert.id);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _entranceDialogTimer?.cancel();
    _alertSub?.cancel();
    if (widget.homeController == null) _homeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _selectTab(int index) {
    if (index == 0) {
      // Always return directly to root parent home screen when Home tab is clicked
      _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
    }
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  /// Push a route inside the currently active tab's navigator.
  void _pushInCurrentTab(Widget page) {
    _navigatorKeys[_selectedIndex].currentState?.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _openConnection() {
    _pushInCurrentTab(ConnectionPage(
      onStart: _homeController.startConnectionSetup,
      connectionState: _homeController.connectionState,
      connectionMessage: _homeController.connectionMessage,
      availableRooms: _homeController.rooms.map((r) => r.name).toList(),
      spaceId: _homeController.activeSpaceId,
      repository: RealHomeConnectionRepository(
        primaryDevice: _homeController.connectedDeviceSummary,
        onRefresh: _homeController.startConnectionSetup,
      ),
      onDeviceProvisioned: _homeController.markDeviceProvisioned,
    ));
  }

  void _openAddDevice({String? targetRoomName}) {
    _pushInCurrentTab(
      HomeConnectionPage(
        connectionState: HomeConnectionState.notConfigured,
        onStart: _homeController.startConnectionSetup,
        initialRoomName: targetRoomName,
        availableRooms: _homeController.rooms.map((r) => r.name).toList(),
        spaceId: _homeController.activeSpaceId,
        repository: RealHomeConnectionRepository(
          forceCommissioningMode: true,
          primaryDevice: null,
          onRefresh: _homeController.startConnectionSetup,
        ),
        onDeviceProvisioned: ({
          required String deviceId,
          required String displayName,
          required String serialNumber,
          String? roomName,
          String? model,
        }) {
          _homeController.markDeviceProvisioned(
            deviceId: deviceId,
            displayName: displayName,
            serialNumber: serialNumber,
            roomName: roomName ?? targetRoomName,
            model: model,
          );
        },
      ),
    );
  }

  void _openInsights() {
    _pushInCurrentTab(HomeInsightsPage(data: _homeController.dashboard));
  }

  void _openRoomContext(RoomPreview room) {
    final availableRooms = _homeController.rooms;
    final typedRoom = availableRooms.firstWhere(
      (candidate) => candidate.id == room.id || candidate.name == room.name,
      orElse: () => availableRooms.isNotEmpty
          ? availableRooms.first
          : Room(
              id: room.id,
              name: room.name,
              iconKey: 'living',
              deviceCount: 0,
              connectivity: ConnectivityCause.deviceOffline,
              telemetryFreshness: TelemetryFreshness.unknown,
              summary: 'Empty room',
              status: RoomStatus.normal,
              capabilities: const [],
              devices: const [],
              insights: const RoomInsights(
                energyKwh: '0.0 kWh',
                energyChange: '0.0 kWh',
                activeWindow: 'Today',
                averageTemperature: '24°C',
                averageHumidity: '55%',
              ),
            ),
    );
    _pushInCurrentTab(
      RoomContextPage(
        room: typedRoom,
        homeController: _homeController,
        onAddDevice: () => _openAddDevice(targetRoomName: typedRoom.name),
      ),
    );
  }

  void _showFavouritesCustomization() {
    final tokens = context.ehColors;
    final devices = _homeController.devices;

    // Build all candidate controls across commissioned devices using their real renamed labels
    final candidateControls = <({String id, String label, String room})>[];
    for (final d in devices) {
      final room = d.roomName.trim().isEmpty ? 'Living Room' : d.roomName;
      final rawName = d.name.startsWith('EH ') ? d.name.substring(3).trim() : d.name;
      final modelStr = d.model.toLowerCase();
      final nameStr = rawName.toLowerCase();
      final isSocket = nameStr.contains('socket') || modelStr.contains('socket');
      final is4X = nameStr.contains('4x') || modelStr.contains('4x');
      final is3X = nameStr.contains('3x') || modelStr.contains('3x');
      final is2X = nameStr.contains('2x') || modelStr.contains('2x');
      final channelCount = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : 1));

      final customLabels = DeviceStorageService.getChannelLabels(d.id);
      for (int ch = 1; ch <= channelCount; ch++) {
        final chPrefix = isSocket ? 'Socket' : 'Switch';
        final chLabel = customLabels[ch] ?? '$chPrefix $ch';
        final displayLabel = '$rawName • $chLabel';
        candidateControls.add((
          id: '${d.id}_ch$ch',
          label: displayLabel,
          room: room,
        ));
      }
    }

    // Do NOT auto-populate all devices if user unselected everything
    final selected = List<String>.from(_homeController.favouriteControlIds);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Favourite Devices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.bluePrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${selected.length} Selected',
                          style: TextStyle(
                            color: tokens.bluePrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    candidateControls.isEmpty
                        ? 'No devices found in ${_homeController.activeSpaceName}. Add devices to select favourites.'
                        : 'Choose daily favourite controls in ${_homeController.activeSpaceName} for one-tap access.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (candidateControls.isNotEmpty)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidateControls.length,
                        separatorBuilder: (_, _) => Divider(
                          color: tokens.borderSubtle,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = candidateControls[index];
                          final isChecked = selected.contains(item.id);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: tokens.bluePrimary,
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              item.room,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            value: isChecked,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  selected.add(item.id);
                                } else {
                                  selected.remove(item.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: candidateControls.isEmpty
                          ? () => Navigator.of(sheetCtx).pop()
                          : () async {
                              await _homeController.saveFavouritesForSpace(_homeController.activeSpaceId, selected);
                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              _showMessage('Favourite devices updated.');
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Favourites',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openNotificationCenter() {
    final client = widget.apiClient;
    final repo = (client != null && _homeController.isCloudReachable)
        ? CloudNotificationRepository(client)
        : LocalNotificationRepository();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterPage(
          homeId: _homeController.activeSpaceId,
          repository: repo,
        ),
      ),
    );
  }

  void _openGlobalSearch() {
    GlobalAppSearchSheet.show(
      context,
      homeController: _homeController,
      onOpenRoom: _openRoomContext,
      onOpenSettings: () => _selectTab(4),
      onOpenActivity: () => _selectTab(3),
      onOpenNotifications: _openNotificationCenter,
      onOpenInsights: _openInsights,
      onOpenAddDevice: () => _openAddDevice(),
      onOpenRoutines: () => _selectTab(2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return PopScope(
      // Never let the system handle the back gesture itself — we decide.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // 1. If the active tab's navigator can go back — do it.
        final navState = _navigatorKeys[_selectedIndex].currentState;
        if (navState != null && navState.canPop()) {
          navState.pop();
          return;
        }

        // 2. If we're on a non-home tab at its root — jump to Home tab.
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }

        // 3. We're on the Home tab at its root — allow the app to exit.
        // Use the system navigator to actually pop/exit.
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AnimatedBuilder(
        animation: _homeController,
        builder: (context, _) {
          return Scaffold(
            extendBody: false,
            backgroundColor: tokens.bgApp,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Global Sticky Alert Banner when Cloud/Internet is down & not in LAN mode
                  if (!_homeController.isCloudReachable &&
                      !_homeController.isLocalMode &&
                      !_homeController.isLoading &&
                      _homeController.isCurrentSpaceOnLocalLan)
                    _GlobalOfflineAlertBar(
                      onSwitchToLan: () async {
                        final ok = await _homeController.switchToLanMode();
                        if (!ok && context.mounted) {
                          _showMessage(
                            'No local devices found on this Wi-Fi network. Ensure your smart devices are powered on and nearby.',
                          );
                        }
                      },
                    ),

                  // Global Status Bar when Local LAN Mode is actively running
                  if (_homeController.isLocalMode)
                    _GlobalLanActiveBar(
                      onRetryCloud: () async {
                        await _homeController.loadHomeData();
                      },
                    ),

                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        // Tab 0 — Home
                        Navigator(
                          key: _navigatorKeys[0],
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => AnimatedBuilder(
                              animation: Listenable.merge([
                                _homeController,
                                if (widget.authController != null) widget.authController!,
                              ]),
                              builder: (context, _) => HomePage(
                                homeController: _homeController,
                                userName: widget.authController?.currentUser?.displayName ??
                                    DeviceStorageService.cachedUserName,
                                dashboard: _homeController.dashboard,
                                lightOn: _homeController.livingRoomLightOn,
                                alertAcknowledged: _homeController.alertAcknowledged,
                                lightCommandPending: _homeController.lightCommandPending,
                                isLocalMode: _homeController.isLocalMode,
                                isCloudReachable: _homeController.isCloudReachable,
                                isLoading: _homeController.isLoading,
                                activeSpaceId: _homeController.activeSpaceId,
                                activeSpaceName: _homeController.activeSpaceName,
                                spaces: _homeController.spaces,
                                onSelectSpace: _homeController.selectSpace,
                                onCreateSpace: _homeController.createSpace,
                                onUpdateSpace: (id, name, icon) => _homeController.updateSpace(id, name, icon: icon),
                                onDeleteSpace: _homeController.deleteSpace,
                                allSpacesAlerts: _homeController.allSpacesAlerts,
                                devicesOnInOtherSpaces: _homeController.devicesOnInOtherSpaces,
                                groupControls: _homeController.groupControls,
                                favouriteControlIds: _homeController.favouriteControlIds,
                                upcomingRoutines: _homeController.upcomingRoutinesAcrossSpaces,
                                onToggleRoutine: _homeController.toggleRoutine,
                                onToggleGroup: _homeController.toggleControlGroup,
                                onCreateGroup: (label, kind, targets) => _homeController.createControlGroup(
                                  label: label,
                                  kind: kind,
                                  targetControlIds: targets,
                                ),
                                onUpdateGroup: _homeController.updateControlGroup,
                                onDeleteGroup: _homeController.deleteControlGroup,
                                onToggleFavourite: _homeController.toggleFavourite,
                                devices: _homeController.devices,
                                selectedQuickControlIds: _homeController.selectedQuickControlIds,
                                onSaveQuickControls: (ids) => _homeController.saveQuickControlsForSpace(ids),
                                onShowNotifications: _openNotificationCenter,
                                onShowSearch: _openGlobalSearch,
                                onRefresh: () async {
                                  await _homeController.loadHomeData();
                                  await _homeController.probeLanAndPromote();
                                  await _homeController.refreshUpcomingRoutines();
                                },
                                onSwitchToLanMode: () async {
                                  final ok = await _homeController.switchToLanMode();
                                  if (!ok && context.mounted) {
                                    _showMessage('No local devices found on this Wi-Fi network. Ensure your smart devices are powered on and nearby.');
                                  }
                                },
                                onLightChanged: (value) async {
                                  await _homeController.setLivingRoomLight(value);
                                },
                                onControlChanged: (control, value) async {
                                  if (control.id.contains('_ch')) {
                                    final parts = control.id.split('_ch');
                                    final devId = parts[0];
                                    final chIdx = int.tryParse(parts[1]) ?? 1;
                                    await _homeController.setDeviceChannelPower(
                                      deviceId: devId,
                                      channelIndex: chIdx,
                                      value: value,
                                    );
                                  } else {
                                    final matchedDev = _homeController.devices.where((d) => d.id == control.id).firstOrNull;
                                    if (matchedDev != null) {
                                      await _homeController.setDeviceChannelPower(
                                        deviceId: matchedDev.id,
                                        channelIndex: 1,
                                        value: value,
                                      );
                                    } else {
                                      await _homeController.setLivingRoomLight(value);
                                    }
                                  }
                                },
                                onClearAllAlerts: () {
                                  _homeController.clearAllAlerts();
                                  _showMessage('All alerts cleared.');
                                },
                                onDismissAlert: (alert) {
                                  _homeController.dismissAlert(alert.id);
                                  _showMessage('Alert dismissed.');
                                },
                                onAlertTap: ([selectedAlert]) async {
                                  final activeAlert = selectedAlert ?? _homeController.allSpacesAlerts.firstOrNull;
                                  final acknowledged = await _navigatorKeys[0]
                                      .currentState
                                      ?.push<bool>(
                                    MaterialPageRoute(
                                        builder: (_) {
                                          return SafetyAlertPage(
                                            title: activeAlert?.title ?? 'Device safety alert',
                                            description: activeAlert?.message ?? 'Please check connected device states and power supply.',
                                            spaceName: activeAlert?.spaceName ?? _homeController.activeSpaceName,
                                            roomName: activeAlert?.spaceName ?? _homeController.activeSpaceName,
                                            deviceId: activeAlert?.deviceId,
                                            timestamp: activeAlert?.timestamp,
                                            severity: activeAlert?.severity.name ?? 'warning',
                                            onDismiss: () {
                                              if (activeAlert != null) {
                                                _homeController.dismissAlert(activeAlert.id);
                                              } else {
                                                _homeController.acknowledgeAlert();
                                              }
                                            },
                                          );
                                        }),
                                  );
                                  if (acknowledged == true) {
                                    if (activeAlert != null) {
                                      _homeController.dismissAlert(activeAlert.id);
                                    } else {
                                      _homeController.acknowledgeAlert();
                                    }
                                    _showMessage(
                                      'Alert dismissed. Safety monitoring remains active.',
                                    );
                                  }
                                },
                                onConnectHome: _openAddDevice,
                                onShowRooms: () => _selectTab(1),
                                onOpenRoom: _openRoomContext,
                                onShowRoutines: () => _selectTab(2),
                                onShowActivity: () => _selectTab(3),
                                onShowSettings: () => _selectTab(4),
                                onShowInsights: _openInsights,
                                onCustomizeControls: _showFavouritesCustomization,
                                onUnavailableControl: () => _showMessage(
                                  'Device is offline or unreachable. Please check device power and network connection.',
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Tab 1 — Rooms
                        Navigator(
                          key: _navigatorKeys[1],
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => AnimatedBuilder(
                              animation: _homeController,
                              builder: (context, _) => RoomsPage(
                                homeController: _homeController,
                                onAddDevice: _openAddDevice,
                              ),
                            ),
                          ),
                        ),

                        // Tab 2 — Routines
                        Navigator(
                          key: _navigatorKeys[2],
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => AutomationsPage(
                              repository: widget.apiClient != null
                                  ? CloudRoutineRepository(
                                      widget.apiClient!,
                                      activeHomeId: _homeController.activeHomeId ?? widget.homeId,
                                    )
                                  : const PreviewRoutineRepository(),
                              onConnectHome: _openConnection,
                            ),
                          ),
                        ),

                        // Tab 3 — Activity
                        Navigator(
                          key: _navigatorKeys[3],
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => ActivityPage(
                              repository: widget.apiClient != null
                                  ? CloudActivityRepository(
                                      widget.apiClient!,
                                      activeHomeId: _homeController.activeHomeId ?? widget.homeId,
                                    )
                                  : const PreviewActivityRepository(),
                              routineRepository: widget.apiClient != null
                                  ? CloudRoutineRepository(
                                      widget.apiClient!,
                                      activeHomeId: _homeController.activeHomeId ?? widget.homeId,
                                    )
                                  : const PreviewRoutineRepository(),
                            ),
                          ),
                        ),

                        // Tab 4 — Settings
                        Navigator(
                          key: _navigatorKeys[4],
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => AnimatedBuilder(
                              animation: _homeController,
                              builder: (context, _) => SettingsPage(
                                homeController: _homeController,
                                repository: widget.apiClient != null
                                    ? CloudSettingsRepository(
                                        widget.apiClient!,
                                        activeHomeId: _homeController.activeHomeId ?? widget.homeId,
                                      )
                                    : const PreviewSettingsRepository(),
                                onConnectHome: _homeController.startConnectionSetup,
                                connectionState: _homeController.connectionState,
                                connectionMessage: _homeController.connectionMessage,
                                connectionRepository: RealHomeConnectionRepository(
                                  primaryDevice: _homeController.connectedDeviceSummary,
                                  onRefresh: _homeController.startConnectionSetup,
                                ),
                                updateRepository: CloudUpdateRepository(
                                  apiClient: widget.apiClient ?? ApiClient(baseUrl: AppConfig.backendBaseUrl),
                                  getActiveHomeId: () => _homeController.activeHomeId ?? widget.homeId,
                                  getLocalDevices: () {
                                    final devs = _homeController.devices;
                                    if (devs.isEmpty && _homeController.connectedDeviceSummary != null) {
                                      return [_homeController.connectedDeviceSummary!];
                                    }
                                    return devs;
                                  },
                                ),
                                apiClient: widget.apiClient,
                                authController: widget.authController,
                                homeId: _homeController.activeHomeId ?? widget.homeId,
                                isAdmin: (widget.authController?.currentUser?.isAdmin ?? false) ||
                                    _homeController.isHomeAdmin,
                                onLogout: widget.authController != null
                                    ? () => widget.authController!.logout()
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _HavenFloatingNavigation(
              selectedIndex: _selectedIndex,
              onSelected: _selectTab,
            ),
          );
        },
      ),
    );
  }
}

/// Global Top Alert Bar displayed across all screens when cloud/internet is offline.
class _GlobalOfflineAlertBar extends StatefulWidget {
  const _GlobalOfflineAlertBar({required this.onSwitchToLan});

  final Future<void> Function() onSwitchToLan;

  @override
  State<_GlobalOfflineAlertBar> createState() => _GlobalOfflineAlertBarState();
}

class _GlobalOfflineAlertBarState extends State<_GlobalOfflineAlertBar> {
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF991B1B), Color(0xFFD97706)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF991B1B).withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Cloud Offline / No Internet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Switch to LAN mode to control devices directly via Wi-Fi.',
                  style: TextStyle(
                    color: Color(0xFFFEF3C7),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isConnecting
                ? null
                : () async {
                    setState(() => _isConnecting = true);
                    try {
                      await widget.onSwitchToLan();
                    } finally {
                      if (mounted) setState(() => _isConnecting = false);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF991B1B),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _isConnecting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF991B1B)),
                    ),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 15),
            label: Text(
              _isConnecting ? 'Scanning...' : 'Switch LAN',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Global Active Bar indicating local LAN Wi-Fi mode is active.
class _GlobalLanActiveBar extends StatelessWidget {
  const _GlobalLanActiveBar({required this.onRetryCloud});

  final Future<void> Function() onRetryCloud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_tethering_rounded,
            color: Color(0xFFD97706),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Local Wi-Fi Mode Active • Direct Device Control',
              style: TextStyle(
                color: Color(0xFFD97706),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onRetryCloud,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text(
                    'Retry Cloud',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _HavenFloatingNavigation extends StatelessWidget {
  const _HavenFloatingNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, IconData outlined, IconData filled})>[
    (label: 'Home', outlined: Icons.home_outlined, filled: Icons.home_rounded),
    (
      label: 'Rooms',
      outlined: Icons.meeting_room_outlined,
      filled: Icons.meeting_room_rounded,
    ),
    (
      label: 'Routines',
      outlined: Icons.auto_awesome_outlined,
      filled: Icons.auto_awesome_rounded,
    ),
    (
      label: 'Activity',
      outlined: Icons.history_outlined,
      filled: Icons.history_rounded,
    ),
    (
      label: 'Settings',
      outlined: Icons.settings_outlined,
      filled: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: 76,
        decoration: BoxDecoration(
          color: tokens.surfaceNav,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: tokens.isDark
              ? Border(top: BorderSide(color: tokens.borderSubtle, width: 1))
              : null,
          boxShadow: [
            BoxShadow(
              color: tokens.isDark
                  ? const Color(0x30000000)
                  : const Color(0x16102142),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? tokens.blueSelectedBg
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          selected ? item.filled : item.outlined,
                          color: selected
                              ? tokens.navSelectedIcon
                              : tokens.navInactiveIcon,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? tokens.navSelectedLabel
                              : tokens.navInactiveLabel,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
