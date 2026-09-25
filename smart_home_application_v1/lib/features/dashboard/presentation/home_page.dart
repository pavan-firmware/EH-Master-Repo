import 'package:flutter/material.dart';

import '../../../core/models/connection_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_greeting.dart';
import '../../../core/widgets/carousel_page_indicator.dart';
import 'all_alerts_sheet.dart';
import 'control_group_editor_sheet.dart';
import 'other_spaces_devices_sheet.dart';
import 'space_management_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.dashboard,
    required this.lightOn,
    required this.lightCommandPending,
    required this.alertAcknowledged,
    required this.onLightChanged,
    this.onControlChanged,
    this.onRefresh,
    required this.onAlertTap,
    required this.onConnectHome,
    required this.onShowRooms,
    required this.onOpenRoom,
    required this.onShowRoutines,
    required this.onShowActivity,
    this.onShowNotifications,
    required this.onShowSettings,
    required this.onShowInsights,
    required this.onCustomizeControls,
    required this.onUnavailableControl,
    this.isLocalMode = false,
    this.isCloudReachable = true,
    this.activeSpaceId = 'home_default',
    this.activeSpaceName = 'My Home',
    this.spaces = const [],
    this.onSelectSpace,
    this.onCreateSpace,
    this.onUpdateSpace,
    this.onDeleteSpace,
    this.onSwitchToLanMode,
    this.userName,
    this.allSpacesAlerts = const [],
    this.devicesOnInOtherSpaces = const [],
    this.groupControls = const [],
    this.favouriteControlIds = const [],
    this.upcomingRoutines = const [],
    this.onToggleRoutine,
    this.onToggleGroup,
    this.onCreateGroup,
    this.onUpdateGroup,
    this.onDeleteGroup,
    this.onToggleFavourite,
    this.devices = const [],
    this.selectedQuickControlIds = const [],
    this.onSaveQuickControls,
  });

  final HomeDashboardData dashboard;
  final bool lightOn;
  final bool lightCommandPending;
  final bool alertAcknowledged;
  final bool isLocalMode;
  final bool isCloudReachable;
  final String activeSpaceId;
  final String activeSpaceName;
  final List<Map<String, dynamic>> spaces;
  final ValueChanged<String>? onSelectSpace;
  final ValueChanged<String>? onCreateSpace;
  final void Function(String id, String name, String icon)? onUpdateSpace;
  final ValueChanged<String>? onDeleteSpace;
  final VoidCallback? onSwitchToLanMode;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final Future<void> Function()? onRefresh;
  final VoidCallback onAlertTap;
  final VoidCallback onConnectHome;
  final VoidCallback onShowRooms;
  final ValueChanged<RoomPreview> onOpenRoom;
  final VoidCallback onShowRoutines;
  final VoidCallback onShowActivity;
  final VoidCallback? onShowNotifications;
  final VoidCallback onShowSettings;
  final VoidCallback onShowInsights;
  final VoidCallback onCustomizeControls;
  final VoidCallback onUnavailableControl;
  final String? userName;

  final List<SpaceAlertItem> allSpacesAlerts;
  final List<SpaceOnSummary> devicesOnInOtherSpaces;
  final List<GroupControlItem> groupControls;
  final List<String> favouriteControlIds;
  final List<UpcomingRoutineItem> upcomingRoutines;
  final void Function(String id, bool enabled)? onToggleRoutine;
  final void Function(GroupControlItem group, bool value)? onToggleGroup;
  final void Function(String label, QuickControlKind kind, List<String> targetIds)? onCreateGroup;
  final ValueChanged<GroupControlItem>? onUpdateGroup;
  final ValueChanged<String>? onDeleteGroup;
  final ValueChanged<String>? onToggleFavourite;
  final List<ConnectedDeviceSummary> devices;
  final List<String> selectedQuickControlIds;
  final ValueChanged<List<String>>? onSaveQuickControls;

  void _showQuickControlPlayground(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ControlGroupEditorSheet(
        spaceId: activeSpaceId,
        spaceName: activeSpaceName,
        devices: devices,
        selectedSingleControlIds: selectedQuickControlIds,
        existingGroups: groupControls,
        onSaveSingleControls: onSaveQuickControls,
        onCreateGroup: onCreateGroup,
        onUpdateGroup: onUpdateGroup,
        onDeleteGroup: onDeleteGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = dashboard.rooms.isNotEmpty;
    final tokens = context.ehColors;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        color: tokens.bluePrimary,
        backgroundColor: tokens.surfaceCard,
        displacement: 24,
        child: ListView(
          key: const PageStorageKey<String>('haven-home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          children: [
            // 1. Header: [(space ) notification (profile)]
            _HomeHeader(
              subtitle: _contextualSubtitle(dashboard),
              onActivity: onShowActivity,
              onNotifications: onShowNotifications,
              onSettings: onShowSettings,
              userName: userName,
              activeSpaceId: activeSpaceId,
              activeSpaceName: activeSpaceName,
              spaces: spaces,
              onSelectSpace: onSelectSpace,
              onCreateSpace: (name) => onCreateSpace?.call(name),
              onUpdateSpace: onUpdateSpace,
              onDeleteSpace: onDeleteSpace,
              isLocalMode: isLocalMode,
              isCloudReachable: isCloudReachable,
              onSwitchToLanMode: onSwitchToLanMode,
            ),

            // 2. Alerts from all spaces
            if (allSpacesAlerts.isNotEmpty && !alertAcknowledged) ...[
              const SizedBox(height: 14),
              _AllSpacesAlertsCard(
                alerts: allSpacesAlerts,
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => AllAlertsSheet(
                      alerts: allSpacesAlerts,
                      onSelectAlert: (alert) {
                        if (alert.spaceId != activeSpaceId) {
                          onSelectSpace?.call(alert.spaceId);
                        }
                        onAlertTap();
                      },
                    ),
                  );
                },
              ),
            ],

            // 3. Devices ON in other spaces only (not current space)
            if (devicesOnInOtherSpaces.isNotEmpty) ...[
              const SizedBox(height: 14),
              _DevicesOnInOtherSpacesStrip(
                summaries: devicesOnInOtherSpaces,
                onTapSummary: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => OtherSpacesDevicesSheet(
                      summaries: devicesOnInOtherSpaces,
                      onSwitchSpace: (spId) => onSelectSpace?.call(spId),
                    ),
                  );
                },
                onTapSpace: (spId) => onSelectSpace?.call(spId),
              ),
            ],

            // 4. Space/Place overview section (current space only)
            const SizedBox(height: 16),
            _HomeOverviewCard(
              data: dashboard,
              spaceName: activeSpaceName,
              onTap: dashboard.isSetupFlow || dashboard.state == HomeDashboardState.offline
                  ? onConnectHome
                  : onShowInsights,
            ),

            // 5. Quick Controls of all spaces + custom group controls playground
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Quick controls',
              icon: Icons.home_rounded,
              action: 'Customize',
              onAction: () => _showQuickControlPlayground(context),
            ),
            const SizedBox(height: 12),
            _QuickControlsSection(
              controls: dashboard.controls,
              groupControls: groupControls,
              lightOn: lightOn,
              lightPending: lightCommandPending,
              onLightChanged: onLightChanged,
              onControlChanged: onControlChanged,
              onToggleGroup: onToggleGroup,
              onUnavailable: onUnavailableControl,
            ),

            // 6. Favourite or daily use controllers (current space only)
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Favourite Devices',
              icon: Icons.star_rounded,
              iconColor: const Color(0xFF10B981),
              action: 'Customize',
              onAction: onCustomizeControls,
            ),
            const SizedBox(height: 12),
            _FavouriteDevicesStrip(
              controls: dashboard.controls,
              favouriteIds: favouriteControlIds,
              lightOn: lightOn,
              lightPending: lightCommandPending,
              onLightChanged: onLightChanged,
              onControlChanged: onControlChanged,
              onUnavailable: onUnavailableControl,
              onManageFavourites: onCustomizeControls,
            ),

            // 7. Rooms of the current space only (showing devices count + ON count)
            if (hasContent) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Your rooms',
                action: 'See all',
                onAction: onShowRooms,
              ),
              const SizedBox(height: 12),
              _RoomPreviewStrip(
                rooms: dashboard.rooms.take(4).toList(),
                onOpenRoom: onOpenRoom,
              ),
            ],

            // 8. Upcoming routines across all spaces
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Upcoming Routines',
              icon: Icons.access_time_rounded,
              action: upcomingRoutines.isNotEmpty ? 'View All' : null,
              onAction: onShowRoutines,
            ),
            const SizedBox(height: 12),
            if (upcomingRoutines.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: tokens.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No routines scheduled.',
                        style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              _UpcomingRoutinesStrip(
                routines: upcomingRoutines,
                onToggleRoutine: onToggleRoutine ?? (id, enabled) {},
                onTapRoutine: onShowRoutines,
              ),
          ],
        ),
      ),
    );
  }
}

String _contextualSubtitle(HomeDashboardData data) {
  return switch (data.state) {
    HomeDashboardState.ready => 'Everything looks good at home.',
    HomeDashboardState.warning => 'One device needs your attention.',
    HomeDashboardState.critical => 'Immediate attention is required.',
    HomeDashboardState.partial => 'Some home information needs attention.',
    HomeDashboardState.loading => 'Looking for your nearby home device.',
    HomeDashboardState.deviceFound => 'Your device is ready to finish setup.',
    HomeDashboardState.wifiRequired =>
      'Let’s connect your device to home Wi-Fi.',
    HomeDashboardState.offline => 'Your home device is currently unavailable.',
    HomeDashboardState.noInternet =>
      'You’re offline. Some details may be out of date.',
    HomeDashboardState.setupRequired => 'Let’s finish setting up your home.',
  };
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.subtitle,
    required this.onActivity,
    this.onNotifications,
    required this.onSettings,
    this.userName,
    this.activeSpaceId = 'home_default',
    this.activeSpaceName = 'My Home',
    this.spaces = const [],
    this.onSelectSpace,
    this.onCreateSpace,
    this.onUpdateSpace,
    this.onDeleteSpace,
    this.isLocalMode = false,
    this.isCloudReachable = true,
    this.onSwitchToLanMode,
  });

  final String subtitle;
  final VoidCallback onActivity;
  final VoidCallback? onNotifications;
  final VoidCallback onSettings;
  final String? userName;
  final String activeSpaceId;
  final String activeSpaceName;
  final List<Map<String, dynamic>> spaces;
  final ValueChanged<String>? onSelectSpace;
  final ValueChanged<String>? onCreateSpace;
  final void Function(String id, String name, String icon)? onUpdateSpace;
  final ValueChanged<String>? onDeleteSpace;
  final bool isLocalMode;
  final bool isCloudReachable;
  final VoidCallback? onSwitchToLanMode;

  void _showSpaceSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpaceManagementSheet(
        spaces: spaces,
        activeSpaceId: activeSpaceId,
        onSelectSpace: onSelectSpace ?? (_) {},
        onCreateSpace: (name, icon) => onCreateSpace?.call(name),
        onUpdateSpace: onUpdateSpace ?? (id, name, icon) {},
        onDeleteSpace: onDeleteSpace ?? (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _showSpaceSelector(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF4FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            activeSpaceName.toLowerCase().contains('office')
                                ? Icons.business_rounded
                                : activeSpaceName.toLowerCase().contains('shop')
                                    ? Icons.storefront_rounded
                                    : Icons.home_rounded,
                            color: tokens.bluePrimary,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              activeSpaceName,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: tokens.textSecondary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLocalMode
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : isCloudReachable
                              ? tokens.success.withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: isLocalMode
                              ? const Color(0xFFF59E0B)
                              : isCloudReachable
                                  ? tokens.success
                                  : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLocalMode
                              ? 'LAN'
                              : isCloudReachable
                                  ? 'CLOUD'
                                  : 'OFFLINE',
                          style: TextStyle(
                            color: isLocalMode
                                ? const Color(0xFFF59E0B)
                                : isCloudReachable
                                    ? tokens.success
                                    : const Color(0xFFEF4444),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Notifications, 2 unread',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Notifications',
                    onPressed: onNotifications ?? onActivity,
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: tokens.isDark
                          ? tokens.headerAction
                          : const Color(0xFF102142),
                      size: 27,
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF02B32),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Semantics(
              button: true,
              label: 'Open settings and profile',
              child: InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: compact ? 36 : 40,
                  height: compact ? 36 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.isDark ? tokens.surfaceElevated : null,
                    border: tokens.isDark
                        ? Border.all(color: tokens.borderSubtle)
                        : null,
                    gradient: tokens.isDark
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFE9EEF8), Color(0xFFC8D5EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: tokens.isDark
                        ? tokens.textPrimary
                        : const Color(0xFF365171),
                    size: compact ? 20 : 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: compact ? 25 : 28,
              letterSpacing: compact ? -.5 : -.75,
              fontWeight: FontWeight.w600,
              height: 1.08,
            ),
            children: [
              TextSpan(text: getTimeAwareGreeting()),
              TextSpan(
                text: (userName != null && userName!.trim().isNotEmpty)
                    ? userName!.trim()
                    : 'User',
                style: TextStyle(
                  color: tokens.bluePrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle.replaceFirst(
            'Everything',
            'Your home is ready — everything',
          ),
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: compact ? 14 : 15,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _AllSpacesAlertsCard extends StatelessWidget {
  const _AllSpacesAlertsCard({
    required this.alerts,
    required this.onTap,
  });

  final List<SpaceAlertItem> alerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final tokens = context.ehColors;
    final topAlert = alerts.first;
    final isCritical = topAlert.severity == AlertSeverity.critical;
    final alertColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final alertBg = isCritical
        ? (tokens.isDark ? const Color(0xFF2D1214) : const Color(0xFFFEF2F2))
        : (tokens.isDark ? const Color(0xFF291E09) : const Color(0xFFFFFBEB));
    final borderColor = isCritical
        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
        : const Color(0xFFF59E0B).withValues(alpha: 0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: alertBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: alertColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCritical ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                color: alertColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alertColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          topAlert.spaceName.toUpperCase(),
                          style: TextStyle(
                            color: alertColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          topAlert.title,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alerts.length > 1
                        ? '${topAlert.message} • +${alerts.length - 1} more alert${alerts.length > 2 ? 's' : ''}'
                        : topAlert.message,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: tokens.textSecondary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesOnInOtherSpacesStrip extends StatelessWidget {
  const _DevicesOnInOtherSpacesStrip({
    required this.summaries,
    required this.onTapSummary,
    required this.onTapSpace,
  });

  final List<SpaceOnSummary> summaries;
  final VoidCallback onTapSummary;
  final ValueChanged<String> onTapSpace;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();
    final tokens = context.ehColors;
    final totalOn = summaries.fold<int>(0, (sum, s) => sum + s.devicesOnCount);

    return SizedBox(
      height: 72,
      child: SingleChildScrollView(
        key: const ValueKey('devices_on_other_spaces_scroll'),
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        primary: false,
        child: Row(
          children: [
            // Left summary card
            InkWell(
              onTap: onTapSummary,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 170,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: tokens.bluePrimary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: tokens.bluePrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.power_settings_new_rounded, color: tokens.bluePrimary, size: 18),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'In other places',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                          Text(
                            '$totalOn device${totalOn == 1 ? '' : 's'} ON',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Per-space cards
            ...summaries.map((s) {
              final hasOn = s.devicesOnCount > 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onTapSpace(s.spaceId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 105),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasOn
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : tokens.borderSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.spaceName.toLowerCase().contains('office')
                                  ? Icons.business_rounded
                                  : s.spaceName.toLowerCase().contains('shop')
                                      ? Icons.storefront_rounded
                                      : Icons.home_work_rounded,
                              size: 14,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.spaceName,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 3.5,
                              backgroundColor: hasOn ? const Color(0xFF10B981) : tokens.textSecondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasOn ? '${s.devicesOnCount} on' : 'None',
                              style: TextStyle(
                                color: hasOn ? const Color(0xFF10B981) : tokens.textSecondary,
                                fontSize: 11,
                                fontWeight: hasOn ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickControlsSection extends StatelessWidget {
  const _QuickControlsSection({
    required this.controls,
    required this.groupControls,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    this.onControlChanged,
    this.onToggleGroup,
    required this.onUnavailable,
  });

  final List<QuickControlPreview> controls;
  final List<GroupControlItem> groupControls;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final void Function(GroupControlItem group, bool value)? onToggleGroup;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    if (controls.isEmpty && groupControls.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Center(
          child: Text(
            'No quick controls in this space yet. Tap Customize to add single controls or groups.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: 122,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Group controls (Small Brick)
          ...groupControls.map((group) {
            final isOn = group.isOn;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => onToggleGroup?.call(group, !isOn),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 148,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOn
                        ? (tokens.isDark ? const Color(0xFF221834) : const Color(0xFFF5F3FF))
                        : tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isOn
                          ? (tokens.isDark ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE))
                          : tokens.borderSubtle,
                      width: isOn ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isOn ? const Color(0xFF7C3AED) : tokens.borderSubtle.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.all_inclusive_rounded,
                              size: 16,
                              color: isOn ? Colors.white : tokens.textSecondary,
                            ),
                          ),
                          Switch(
                            value: isOn,
                            onChanged: (val) => onToggleGroup?.call(group, val),
                            activeTrackColor: const Color(0xFF7C3AED),
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: tokens.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.label,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${group.targetControlIds.length} target channels',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 2. Specialized Single Controls (Wide for Light & Fan, Small for Switch & Socket)
          ...controls.map((ctrl) {
            if (ctrl.kind == QuickControlKind.light) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _LightQuickBrick(
                  control: ctrl,
                  lightOn: lightOn,
                  onLightChanged: onLightChanged,
                  onControlChanged: onControlChanged,
                  onUnavailable: onUnavailable,
                ),
              );
            }

            if (ctrl.kind == QuickControlKind.fan) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _FanQuickBrick(
                  control: ctrl,
                  onControlChanged: onControlChanged,
                  onUnavailable: onUnavailable,
                ),
              );
            }

            // Standard Compact Brick for switches and sockets
            final isOn = ctrl.isOn;
            final isSocket = ctrl.kind == QuickControlKind.socket;
            final activeColor = isSocket ? const Color(0xFF059669) : const Color(0xFF2563EB);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  if (!ctrl.isAvailable) {
                    onUnavailable();
                  } else {
                    onControlChanged?.call(ctrl, !isOn);
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 148,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOn
                        ? (isSocket
                            ? (tokens.isDark ? const Color(0xFF11291E) : const Color(0xFFF0FDF4))
                            : (tokens.isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF)))
                        : tokens.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isOn
                          ? (isSocket
                              ? (tokens.isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0))
                              : (tokens.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)))
                          : tokens.borderSubtle,
                      width: isOn ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isOn ? activeColor : tokens.borderSubtle.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSocket ? Icons.power_rounded : Icons.toggle_on_rounded,
                              size: 16,
                              color: isOn ? Colors.white : tokens.textSecondary,
                            ),
                          ),
                          Switch(
                            value: isOn,
                            onChanged: ctrl.isAvailable
                                ? (val) => onControlChanged?.call(ctrl, val)
                                : null,
                            activeTrackColor: activeColor,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: tokens.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.label,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOn ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: isOn ? activeColor : tokens.textSecondary,
                              fontSize: 11,
                              fontWeight: isOn ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LightQuickBrick extends StatefulWidget {
  const _LightQuickBrick({
    required this.control,
    required this.lightOn,
    required this.onLightChanged,
    this.onControlChanged,
    required this.onUnavailable,
  });

  final QuickControlPreview control;
  final bool lightOn;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final VoidCallback onUnavailable;

  @override
  State<_LightQuickBrick> createState() => _LightQuickBrickState();
}

class _LightQuickBrickState extends State<_LightQuickBrick> {
  double _brightness = 80;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isOn = widget.control.id == 'main_light' ? widget.lightOn : widget.control.isOn;
    const accentColor = Color(0xFFD97706);

    return InkWell(
      onTap: () {
        if (!widget.control.isAvailable) {
          widget.onUnavailable();
        } else {
          final nextVal = !isOn;
          if (widget.control.id == 'main_light') {
            widget.onLightChanged(nextVal);
          } else {
            widget.onControlChanged?.call(widget.control, nextVal);
          }
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOn
              ? (tokens.isDark ? const Color(0xFF2E2413) : const Color(0xFFFFFBEB))
              : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOn
                ? (tokens.isDark ? const Color(0xFF785412) : const Color(0xFFFDE68A))
                : tokens.borderSubtle,
            width: isOn ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon + Title + Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isOn ? accentColor : tokens.borderSubtle.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: isOn ? Colors.white : tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.control.label,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isOn ? 'Brightness ${_brightness.round()}%' : 'OFF',
                        style: TextStyle(
                          color: isOn ? accentColor : tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: widget.control.isAvailable
                      ? (val) {
                          if (widget.control.id == 'main_light') {
                            widget.onLightChanged(val);
                          } else {
                            widget.onControlChanged?.call(widget.control, val);
                          }
                        }
                      : null,
                  activeTrackColor: accentColor,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: tokens.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  inactiveThumbColor: Colors.white,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),

            // Bottom Section: Sleek Brightness Slider
            Row(
              children: [
                Icon(
                  Icons.brightness_low_rounded,
                  size: 14,
                  color: isOn ? accentColor : tokens.textSecondary,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: accentColor,
                      inactiveTrackColor: tokens.borderSubtle,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _brightness,
                      min: 10,
                      max: 100,
                      onChanged: (val) {
                        setState(() => _brightness = val);
                        if (!isOn) {
                          if (widget.control.id == 'main_light') {
                            widget.onLightChanged(true);
                          } else {
                            widget.onControlChanged?.call(widget.control, true);
                          }
                        }
                      },
                    ),
                  ),
                ),
                Icon(
                  Icons.brightness_high_rounded,
                  size: 14,
                  color: isOn ? accentColor : tokens.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FanQuickBrick extends StatefulWidget {
  const _FanQuickBrick({
    required this.control,
    this.onControlChanged,
    required this.onUnavailable,
  });

  final QuickControlPreview control;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final VoidCallback onUnavailable;

  @override
  State<_FanQuickBrick> createState() => _FanQuickBrickState();
}

class _FanQuickBrickState extends State<_FanQuickBrick> {
  int _speed = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isOn = widget.control.isOn;
    const accentColor = Color(0xFF0D9488);

    return InkWell(
      onTap: () {
        if (!widget.control.isAvailable) {
          widget.onUnavailable();
        } else {
          widget.onControlChanged?.call(widget.control, !isOn);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOn
              ? (tokens.isDark ? const Color(0xFF10282C) : const Color(0xFFECFEFF))
              : tokens.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOn
                ? (tokens.isDark ? const Color(0xFF115E59) : const Color(0xFFA5F3FC))
                : tokens.borderSubtle,
            width: isOn ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon + Title + Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isOn ? accentColor : tokens.borderSubtle.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.air_rounded,
                    size: 16,
                    color: isOn ? Colors.white : tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.control.label,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isOn ? 'Speed $_speed' : 'OFF',
                        style: TextStyle(
                          color: isOn ? accentColor : tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: widget.control.isAvailable
                      ? (val) => widget.onControlChanged?.call(widget.control, val)
                      : null,
                  activeTrackColor: accentColor,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: tokens.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  inactiveThumbColor: Colors.white,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),

            // Bottom Section: Speed Step Buttons (1 to 5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [1, 2, 3, 4, 5].map((lvl) {
                final isSelected = isOn && _speed == lvl;
                return InkWell(
                  onTap: () {
                    setState(() => _speed = lvl);
                    if (!isOn) {
                      widget.onControlChanged?.call(widget.control, true);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor
                          : (tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? accentColor : tokens.borderSubtle,
                      ),
                    ),
                    child: Text(
                      '$lvl',
                      style: TextStyle(
                        color: isSelected ? Colors.white : tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteDevicesStrip extends StatelessWidget {
  const _FavouriteDevicesStrip({
    required this.controls,
    required this.favouriteIds,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    this.onControlChanged,
    required this.onUnavailable,
    required this.onManageFavourites,
  });

  final List<QuickControlPreview> controls;
  final List<String> favouriteIds;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final VoidCallback onUnavailable;
  final VoidCallback onManageFavourites;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final favList = controls.where((c) => favouriteIds.contains(c.id)).toList();

    if (favList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Center(
          child: Text(
            'No favourite devices selected yet. Tap Customize to add daily favourites.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: favList.length,
        itemBuilder: (context, index) {
          final item = favList[index];
          final isOn = item.isOn;
          final isLight = item.kind == QuickControlKind.light;
          final isFan = item.kind == QuickControlKind.fan;
          final isSocket = item.kind == QuickControlKind.socket;
          final activeColor = isLight
              ? const Color(0xFFD97706)
              : (isFan ? const Color(0xFF0D9488) : (isSocket ? const Color(0xFF059669) : const Color(0xFF2563EB)));

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                if (!item.isAvailable) {
                  onUnavailable();
                } else {
                  if (item.kind == QuickControlKind.light && item.id == 'main_light') {
                    onLightChanged(!lightOn);
                  } else {
                    onControlChanged?.call(item, !isOn);
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 148,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOn
                      ? (isLight
                          ? (tokens.isDark ? const Color(0xFF2E2413) : const Color(0xFFFFFBEB))
                          : (isFan
                              ? (tokens.isDark ? const Color(0xFF10282C) : const Color(0xFFECFEFF))
                              : (isSocket
                                  ? (tokens.isDark ? const Color(0xFF11291E) : const Color(0xFFF0FDF4))
                                  : (tokens.isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF)))))
                      : tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOn
                        ? (isLight
                            ? (tokens.isDark ? const Color(0xFF785412) : const Color(0xFFFDE68A))
                            : (isFan
                                ? (tokens.isDark ? const Color(0xFF115E59) : const Color(0xFFA5F3FC))
                                : (isSocket
                                    ? (tokens.isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0))
                                    : (tokens.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)))))
                        : tokens.borderSubtle,
                    width: isOn ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isOn ? activeColor : tokens.borderSubtle.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLight
                                ? Icons.lightbulb_outline_rounded
                                : (isFan
                                    ? Icons.air_rounded
                                    : (isSocket ? Icons.power_rounded : Icons.toggle_on_rounded)),
                            size: 19,
                            color: isOn ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                        Switch(
                          value: isOn,
                          onChanged: item.isAvailable
                              ? (val) {
                                  if (item.kind == QuickControlKind.light && item.id == 'main_light') {
                                    onLightChanged(val);
                                  } else {
                                    onControlChanged?.call(item, val);
                                  }
                                }
                              : null,
                          activeTrackColor: activeColor,
                          activeThumbColor: Colors.white,
                          inactiveTrackColor: tokens.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          inactiveThumbColor: Colors.white,
                          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.roomName ?? 'Living Room',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingRoutinesStrip extends StatelessWidget {
  const _UpcomingRoutinesStrip({
    required this.routines,
    required this.onToggleRoutine,
    required this.onTapRoutine,
  });

  final List<UpcomingRoutineItem> routines;
  final void Function(String id, bool enabled) onToggleRoutine;
  final VoidCallback onTapRoutine;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: routines.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: onTapRoutine,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.bluePrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      r.iconKey == 'sun'
                          ? Icons.wb_sunny_rounded
                          : r.iconKey == 'work'
                              ? Icons.business_rounded
                              : Icons.bedtime_rounded,
                      color: tokens.bluePrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.timeLabel,
                              style: TextStyle(
                                color: tokens.bluePrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.borderSubtle.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.spaceName,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.title,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: r.isEnabled,
                    onChanged: (val) => onToggleRoutine(r.id, val),
                    activeThumbColor: tokens.bluePrimary,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HomeOverviewCard extends StatelessWidget {
  const _HomeOverviewCard({
    required this.data,
    required this.onTap,
    this.spaceName = 'Home',
  });

  final HomeDashboardData data;
  final VoidCallback onTap;
  final String spaceName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final setup =
        data.isSetupFlow ||
        data.state == HomeDashboardState.loading ||
        data.state == HomeDashboardState.offline;
    return Semantics(
      button: true,
      label: setup
          ? (data.primaryAction ?? 'Open setup')
          : 'Open home insights',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 380 ? 14 : 20,
            MediaQuery.sizeOf(context).width < 380 ? 15 : 20,
            MediaQuery.sizeOf(context).width < 380 ? 14 : 20,
            16,
          ),
          decoration: BoxDecoration(
            color: tokens.isDark ? tokens.surfaceCard : null,
            border: tokens.isDark
                ? Border.all(color: tokens.borderSubtle)
                : null,
            gradient: tokens.isDark
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF0B2A59), Color(0xFF19477F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: tokens.isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x220C2E62),
                      blurRadius: 20,
                      offset: Offset(0, 9),
                    ),
                  ],
          ),
          child: setup
              ? _SetupOverview(data: data)
              : _ReadyOverview(data: data, spaceName: spaceName),
        ),
      ),
    );
  }
}

class _ReadyOverview extends StatelessWidget {
  const _ReadyOverview({required this.data, this.spaceName = 'Home'});
  final HomeDashboardData data;
  final String spaceName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    const heroPrimary = Colors.white;

    final compact = MediaQuery.sizeOf(context).width < 380;
    final isOffice = spaceName.toLowerCase().contains('office');
    final isShop = spaceName.toLowerCase().contains('shop');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isOffice
                  ? Icons.business_rounded
                  : isShop
                      ? Icons.storefront_rounded
                      : Icons.home_outlined,
              color: heroPrimary,
              size: 27,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${spaceName.toUpperCase()} OVERVIEW',
                style: TextStyle(
                  color: heroPrimary,
                  fontSize: compact ? 12 : 13,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _OverviewPill(
              label: 'All systems normal',
              color: tokens.isDark ? tokens.success : const Color(0xFF36D878),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            if (compact) {
              return _CompactOverviewMetrics(data: data);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _OverviewMetric(
                    icon: Icons.devices_other_rounded,
                    value: '${data.deviceCount}',
                    label: 'Devices',
                    detail: '${data.devicesOnline} online',
                    accent: tokens.isDark
                        ? tokens.success
                        : const Color(0xFF72E7A5),
                    compact: compact,
                  ),
                ),
                _MetricDivider(compact: compact),
                Expanded(
                  child: _OverviewMetric(
                    icon: Icons.grid_view_rounded,
                    value: '${data.roomCount}',
                    label: 'Rooms',
                    detail: '${data.activeRoomCount} active',
                    accent: tokens.isDark
                        ? tokens.bluePrimary
                        : const Color(0xFF8EC3FF),
                    compact: compact,
                  ),
                ),
                _MetricDivider(compact: compact),
                Expanded(
                  child: _OverviewMetric(
                    icon: Icons.wifi_rounded,
                    value: data.networkLabel,
                    label: 'Connected',
                    detail: data.networkDetail,
                    accent: tokens.isDark
                        ? tokens.iconFgWater
                        : const Color(0xFFE7A9FF),
                    compact: compact,
                  ),
                ),
                _MetricDivider(compact: compact),
                Expanded(
                  child: _OverviewMetric(
                    icon: Icons.shield_outlined,
                    value: 'Security',
                    label: 'All sensors',
                    detail: 'normal',
                    accent: tokens.isDark
                        ? tokens.success
                        : const Color(0xFF85F0DD),
                    compact: compact,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Divider(
          color: tokens.isDark ? tokens.borderSubtle : const Color(0x3DDAE9FF),
          height: 1,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              color: tokens.isDark
                  ? tokens.blueSelectedText
                  : const Color(0xFFD2E2FF),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'View detailed home insights',
                style: TextStyle(
                  color: heroPrimary,
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.isDark ? tokens.headerAction : Colors.white,
              size: 28,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactOverviewMetrics extends StatelessWidget {
  const _CompactOverviewMetrics({required this.data});
  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactMetric(
                icon: Icons.devices_other_rounded,
                value: '${data.deviceCount} devices',
                detail: '${data.devicesOnline} online',
                accent: tokens.isDark
                    ? tokens.success
                    : const Color(0xFF72E7A5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactMetric(
                icon: Icons.grid_view_rounded,
                value: '${data.roomCount} rooms',
                detail: '${data.activeRoomCount} active',
                accent: tokens.isDark
                    ? tokens.bluePrimary
                    : const Color(0xFF8EC3FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CompactMetric(
                icon: Icons.wifi_rounded,
                value: data.networkLabel,
                detail: data.networkDetail,
                accent: tokens.isDark
                    ? tokens.iconFgWater
                    : const Color(0xFFE7A9FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactMetric(
                icon: Icons.shield_outlined,
                value: 'Security',
                detail: 'All sensors normal',
                accent: tokens.isDark
                    ? tokens.success
                    : const Color(0xFF85F0DD),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    const heroPrimary = Colors.white;
    const heroSecondary = Color(0xFFD9E8FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? tokens.surfaceElevated
            : Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: heroPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: heroSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupOverview extends StatelessWidget {
  const _SetupOverview({required this.data});
  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    const heroPrimary = Colors.white;
    const heroSecondary = Color(0xFFD9E8FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.hub_outlined, color: heroPrimary, size: 27),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'DEVICE SETUP',
                style: TextStyle(
                  color: heroPrimary,
                  fontSize: 13,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _OverviewPill(
              label: data.state == HomeDashboardState.loading
                  ? 'Searching nearby…'
                  : (data.state == HomeDashboardState.wifiRequired
                        ? 'Wi-Fi required'
                        : (data.state == HomeDashboardState.offline
                              ? 'Unavailable'
                              : 'Action required')),
              color: data.state == HomeDashboardState.loading
                  ? const Color(0xFF67B7FF)
                  : (data.state == HomeDashboardState.offline
                        ? tokens.warning
                        : tokens.goldBright),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          data.primaryTitle ?? 'Set up your home',
          style: const TextStyle(
            color: heroPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.primaryMessage ?? 'Your home is ready for its first device.',
          style: const TextStyle(
            color: heroSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SetupMetric(
                icon: Icons.bluetooth_searching_rounded,
                value: data.devicesOnline == 0 ? 'Ready' : 'Connected',
                label: 'BLUETOOTH',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _SetupMetric(
                icon: Icons.meeting_room_outlined,
                value: '${data.roomCount} configured',
                label: 'ROOMS',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _SetupMetric(
                icon: Icons.wifi_rounded,
                value: data.networkDetail,
                label: 'NETWORK',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: tokens.isDark ? tokens.blueDarker : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.state == HomeDashboardState.loading
                    ? Icons.bluetooth_searching_rounded
                    : Icons.add_circle_outline_rounded,
                color: tokens.isDark
                    ? tokens.textPrimary
                    : const Color(0xFF1956A8),
              ),
              const SizedBox(width: 9),
              Text(
                data.primaryAction ?? 'Add a device',
                style: TextStyle(
                  color: tokens.isDark
                      ? tokens.textPrimary
                      : const Color(0xFF102142),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 148),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      border: Border.all(color: Colors.white.withValues(alpha: .13)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.accent,
    required this.compact,
  });
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const heroPrimary = Colors.white;
    const heroSecondary = Color(0xFFD9E8FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 31 : 38,
          height: compact ? 31 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: .16),
          ),
          child: Icon(icon, color: accent, size: compact ? 17 : 21),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: heroPrimary,
            fontSize: compact ? 17 : 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: heroPrimary, fontSize: compact ? 9 : 10),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: heroSecondary,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      width: 1,
      height: compact ? 90 : 102,
      margin: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
      color: tokens.isDark ? tokens.borderSubtle : const Color(0x33CDE0FF),
    );
  }
}

class _SetupMetric extends StatelessWidget {
  const _SetupMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    const heroPrimary = Colors.white;
    const heroSecondary = Color(0xFFD9E8FF);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? tokens.surfaceElevated
            : Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(15),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: tokens.isDark ? tokens.bluePrimary : const Color(0xFFD4E5FF),
            size: 19,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: heroPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: heroSecondary,
              fontSize: 9,
              letterSpacing: .6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.alert, required this.onTap});
  final DashboardAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final critical = alert.severity == AlertSeverity.critical;

    final color = critical
        ? (tokens.isDark ? tokens.errorText : const Color(0xFFC52A26))
        : (tokens.isDark ? tokens.warning : const Color(0xFFD6581F));

    final background = critical
        ? (tokens.isDark ? tokens.errorContainer : const Color(0xFFFFE9E8))
        : (tokens.isDark ? tokens.warningContainer : const Color(0xFFFFF3EE));

    final borderColor = critical
        ? (tokens.isDark ? const Color(0xFF5A2924) : const Color(0xFFF5A39D))
        : (tokens.isDark ? const Color(0xFF5A3E20) : const Color(0xFFFFD2C2));

    return Semantics(
      button: true,
      label: '${alert.title}. ${alert.safeDisplayMessage}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                critical
                    ? Icons.gpp_maybe_outlined
                    : Icons.warning_amber_rounded,
                color: color,
                size: 33,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.safeDisplayMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.isDark
                            ? tokens.textSecondary
                            : (critical
                                  ? const Color(0xFF913A35)
                                  : const Color(0xFF94523D)),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.onAction,
    this.icon,
    this.iconColor,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 21, color: iconColor ?? tokens.bluePrimary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
            child: Text(
              action!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _RoomPreviewStrip extends StatefulWidget {
  const _RoomPreviewStrip({required this.rooms, required this.onOpenRoom});
  final List<RoomPreview> rooms;
  final ValueChanged<RoomPreview> onOpenRoom;

  @override
  State<_RoomPreviewStrip> createState() => _RoomPreviewStripState();
}

class _RoomPreviewStripState extends State<_RoomPreviewStrip> {
  static const _viewportFraction = 0.46;

  int _page = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 206,
        child: PageView.builder(
          padEnds: false,
          controller: _controller,
          itemCount: widget.rooms.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              right: index == widget.rooms.length - 1 ? 0 : 12,
            ),
            child: _RoomPreviewCard(
              room: widget.rooms[index],
              onTap: () => widget.onOpenRoom(widget.rooms[index]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      CarouselDotIndicator(
        itemCount: widget.rooms.length,
        pageIndex: _page,
        viewportFraction: _viewportFraction,
      ),
    ],
  );
}

class _RoomPreviewCard extends StatelessWidget {
  const _RoomPreviewCard({required this.room, required this.onTap});
  final RoomPreview room;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final palette = _roomPalette(room.iconKey, tokens);
    final isOffline = room.status.toLowerCase() == 'offline';
    final statusColor = room.isAttention
        ? tokens.warning
        : (isOffline ? tokens.textSecondary : tokens.success);
    return Semantics(
      button: true,
      label: '${room.name}, ${room.deviceCount} devices, ${room.status}',
      child: SizedBox(
        width: 150,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: tokens.isDark
                  ? Border.all(color: tokens.borderSubtle)
                  : null,
              boxShadow: tokens.isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x100B2448),
                        blurRadius: 17,
                        offset: Offset(0, 7),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        palette.icon,
                        color: palette.foreground,
                        size: 23,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${room.deviceCount} ${room.deviceCount == 1 ? 'device' : 'devices'}${room.devicesOnCount > 0 ? ' • ${room.devicesOnCount} ON' : ''}',
                  style: TextStyle(
                    color: room.devicesOnCount > 0 ? const Color(0xFF10B981) : tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: room.devicesOnCount > 0 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                Divider(
                  height: 18,
                  color: tokens.isDark
                      ? tokens.borderSubtle
                      : const Color(0xFFDAE0E9),
                ),
                Text(
                  room.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: room.isAttention
                        ? tokens.warning
                        : tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      room.isAttention
                          ? Icons.error_outline_rounded
                          : (isOffline
                              ? Icons.cloud_off_rounded
                              : Icons.check_circle_outline_rounded),
                      size: 15,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        room.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _QuickControlViewMode { brick, carousel, list }

class _QuickControlStrip extends StatefulWidget {
  const _QuickControlStrip({
    required this.controls,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    // ignore: unused_element_parameter
    this.onControlChanged,
    required this.onUnavailable,
  });
  final List<QuickControlPreview> controls;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final VoidCallback onUnavailable;

  @override
  State<_QuickControlStrip> createState() => _QuickControlStripState();
}

class _QuickControlStripState extends State<_QuickControlStrip> {
  static const _viewportFraction = 0.46;

  _QuickControlViewMode _viewMode = _QuickControlViewMode.brick;
  int _page = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    if (widget.controls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'No quick controls selected. Tap Customize to choose your home controls.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Switcher Pill
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modeButton(
                    mode: _QuickControlViewMode.brick,
                    icon: Icons.dashboard_customize_rounded,
                    tooltip: 'Adaptive Brick Layout',
                    tokens: tokens,
                  ),
                  _modeButton(
                    mode: _QuickControlViewMode.carousel,
                    icon: Icons.view_carousel_rounded,
                    tooltip: 'Horizontal Carousel',
                    tokens: tokens,
                  ),
                  _modeButton(
                    mode: _QuickControlViewMode.list,
                    icon: Icons.view_agenda_rounded,
                    tooltip: 'List View',
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 1. Adaptive Brick Masonry Layout (Default)
        if (_viewMode == _QuickControlViewMode.brick)
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final halfWidth = (maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.controls.map((ctrl) {
                  final isFullWidth = ctrl.kind == QuickControlKind.fan ||
                      ctrl.kind == QuickControlKind.curtain ||
                      ctrl.title.toLowerCase().contains('dimmer') ||
                      ctrl.title.toLowerCase().contains('ac') ||
                      ctrl.title.toLowerCase().contains('climate');

                  return SizedBox(
                    width: isFullWidth ? maxWidth : halfWidth,
                    child: _AdaptiveQuickControlCard(
                      control: ctrl,
                      isFullWidth: isFullWidth,
                      lightOn: widget.lightOn,
                      lightPending: widget.lightPending,
                      onLightChanged: widget.onLightChanged,
                      onControlChanged: widget.onControlChanged,
                      onUnavailable: widget.onUnavailable,
                    ),
                  );
                }).toList(),
              );
            },
          )

        // 2. Horizontal Carousel Mode
        else if (_viewMode == _QuickControlViewMode.carousel)
          Column(
            children: [
              SizedBox(
                height: 170,
                child: PageView.builder(
                  padEnds: false,
                  controller: _controller,
                  itemCount: widget.controls.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.controls.length - 1 ? 0 : 12,
                    ),
                    child: _AdaptiveQuickControlCard(
                      control: widget.controls[index],
                      isFullWidth: false,
                      lightOn: widget.lightOn,
                      lightPending: widget.lightPending,
                      onLightChanged: widget.onLightChanged,
                      onControlChanged: widget.onControlChanged,
                      onUnavailable: widget.onUnavailable,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              CarouselDotIndicator(
                itemCount: widget.controls.length,
                pageIndex: _page,
                viewportFraction: _viewportFraction,
              ),
            ],
          )

        // 3. Vertical List View Mode
        else
          Column(
            children: widget.controls
                .map(
                  (ctrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdaptiveQuickControlCard(
                      control: ctrl,
                      isFullWidth: true,
                      lightOn: widget.lightOn,
                      lightPending: widget.lightPending,
                      onLightChanged: widget.onLightChanged,
                      onControlChanged: widget.onControlChanged,
                      onUnavailable: widget.onUnavailable,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _modeButton({
    required _QuickControlViewMode mode,
    required IconData icon,
    required String tooltip,
    required EHThemeTokens tokens,
  }) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? tokens.bluePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : tokens.textSecondary,
        ),
      ),
    );
  }
}

class _AdaptiveQuickControlCard extends StatelessWidget {
  const _AdaptiveQuickControlCard({
    required this.control,
    required this.isFullWidth,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    this.onControlChanged,
    required this.onUnavailable,
  });

  final QuickControlPreview control;
  final bool isFullWidth;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final void Function(QuickControlPreview control, bool value)? onControlChanged;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final visual = _controlVisual(control.kind, tokens);
    final unavailable =
        !control.isEnabled ||
        control.confidence == ActuatorConfidence.unavailable;
    final isOn = control.value == 'On';

    if (isFullWidth) {
      return _buildWideCard(context, tokens, visual, unavailable, isOn);
    }
    return _buildCompactCard(context, tokens, visual, unavailable, isOn);
  }

  Widget _buildCompactCard(
    BuildContext context,
    EHThemeTokens tokens,
    _ControlVisual visual,
    bool unavailable,
    bool isOn,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn && !unavailable
              ? visual.color.withValues(alpha: 0.45)
              : tokens.borderSubtle,
          width: isOn && !unavailable ? 1.5 : 1.0,
        ),
        boxShadow: isOn && !unavailable
            ? [
                BoxShadow(
                  color: visual.color.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOn && !unavailable
                      ? visual.color
                      : tokens.isDark
                          ? const Color(0xFF253347)
                          : const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  visual.icon,
                  color: isOn && !unavailable ? Colors.white : tokens.textTertiary,
                  size: 22,
                ),
              ),
              _ControlToggle(
                value: isOn && !unavailable,
                enabled: !unavailable,
                activeColor: visual.color,
                onChanged: (val) {
                  if (onControlChanged != null) {
                    onControlChanged!(control, val);
                  } else {
                    onLightChanged(val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            control.title.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unavailable
                ? 'Offline'
                : (isOn ? 'Active · ON' : 'Standby · OFF'),
            style: TextStyle(
              color: unavailable
                  ? tokens.textTertiary
                  : (isOn ? tokens.success : tokens.textTertiary),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideCard(
    BuildContext context,
    EHThemeTokens tokens,
    _ControlVisual visual,
    bool unavailable,
    bool isOn,
  ) {
    final isFan = control.kind == QuickControlKind.fan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn && !unavailable
              ? visual.color.withValues(alpha: 0.45)
              : tokens.borderSubtle,
          width: isOn && !unavailable ? 1.5 : 1.0,
        ),
        boxShadow: isOn && !unavailable
            ? [
                BoxShadow(
                  color: visual.color.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOn && !unavailable
                      ? visual.color
                      : tokens.isDark
                          ? const Color(0xFF253347)
                          : const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  visual.icon,
                  color: isOn && !unavailable ? Colors.white : tokens.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      control.title.replaceAll('\n', ' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unavailable
                          ? 'Device Offline'
                          : (isOn
                              ? (isFan ? 'Fan Speed: Active' : 'Power: Active · ON')
                              : 'Standby · OFF'),
                      style: TextStyle(
                        color: unavailable
                            ? tokens.textTertiary
                            : (isOn ? tokens.success : tokens.textTertiary),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ControlToggle(
                value: isOn && !unavailable,
                enabled: !unavailable,
                activeColor: visual.color,
                onChanged: (val) {
                  if (onControlChanged != null) {
                    onControlChanged!(control, val);
                  } else {
                    onLightChanged(val);
                  }
                },
              ),
            ],
          ),
          if (isFan && !unavailable && isOn) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _speedChip('1', true, visual.color, tokens),
                _speedChip('2', false, visual.color, tokens),
                _speedChip('3', false, visual.color, tokens),
                _speedChip('4', false, visual.color, tokens),
                _speedChip('Turbo', false, visual.color, tokens),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _speedChip(String label, bool active, Color color, EHThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color : tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color : tokens.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ControlToggle extends StatelessWidget {
  const _ControlToggle({
    required this.value,
    required this.enabled,
    required this.activeColor,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final offTrack = tokens.isDark
        ? tokens.switchTrackOff
        : const Color(0xFFE2E5EA);
    final offThumb = tokens.isDark ? tokens.switchThumbOff : Colors.white;
    final onThumb = tokens.isDark ? tokens.switchThumbOn : Colors.white;
    final onTrack = activeColor;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value && enabled ? onTrack : offTrack,
            borderRadius: BorderRadius.circular(99),
            border: value && enabled
                ? null
                : (tokens.isDark
                      ? Border.all(color: tokens.borderControl)
                      : Border.all(color: const Color(0xFFC7CCD5))),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? onThumb : offThumb,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTap});
  final RoutinePreview routine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Semantics(
      button: true,
      label:
          'Next routine: ${routine.name}, ${routine.scheduleLabel}, ${routine.actionCount} actions',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: tokens.isDark ? tokens.surfaceCard : const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: tokens.isDark
                  ? tokens.borderSubtle
                  : const Color(0xFFE5DBFF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tokens.isDark
                      ? tokens.iconBgPurple
                      : const Color(0xFFECE0FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.nightlight_round,
                  color: tokens.isDark
                      ? tokens.iconFgPurple
                      : const Color(0xFF7955E6),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next routine',
                      style: TextStyle(
                        color: tokens.isDark
                            ? tokens.iconFgPurple
                            : const Color(0xFF7653DE),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      routine.name,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${routine.scheduleLabel}  ·  ${routine.actionCount} actions',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.isDark
                    ? tokens.iconFgPurple
                    : const Color(0xFF7550DC),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SetupSupportingContent extends StatelessWidget {
  const _SetupSupportingContent({required this.data, required this.onAction});
  final HomeDashboardData data;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.devices_other_outlined,
            color: tokens.bluePrimary,
            size: 31,
          ),
          const SizedBox(height: 13),
          Text(
            data.state == HomeDashboardState.offline
                ? 'Need help reconnecting?'
                : 'Your home is ready for its first device',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nearby setup will help you identify the device, connect it securely, and finish its network setup.',
            style: TextStyle(color: tokens.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.bluePrimary,
              side: BorderSide(color: tokens.borderControl),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(data.primaryAction ?? 'Start setup'),
          ),
        ],
      ),
    );
  }
}

class _RoomPalette {
  const _RoomPalette(this.icon, this.background, this.foreground);
  final IconData icon;
  final Color background;
  final Color foreground;
}

_RoomPalette _roomPalette(String key, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (key) {
      'kitchen' => _RoomPalette(
        Icons.kitchen_outlined,
        tokens.iconBgKitchen,
        tokens.iconFgKitchen,
      ),
      'plant' => _RoomPalette(
        Icons.local_florist_outlined,
        tokens.iconBgPlant,
        tokens.iconFgPlant,
      ),
      'water' => _RoomPalette(
        Icons.water_drop_outlined,
        tokens.iconBgWater,
        tokens.iconFgWater,
      ),
      _ => _RoomPalette(
        Icons.weekend_rounded,
        tokens.iconBgBlue,
        tokens.iconFgBlue,
      ),
    };
  }
  return switch (key) {
    'kitchen' => const _RoomPalette(
      Icons.kitchen_outlined,
      Color(0xFFFFECE9),
      Color(0xFF102142),
    ),
    'plant' => const _RoomPalette(
      Icons.local_florist_outlined,
      Color(0xFFF0ECFF),
      Color(0xFF102142),
    ),
    'water' => const _RoomPalette(
      Icons.water_drop_outlined,
      Color(0xFFE7F3FF),
      Color(0xFF102142),
    ),
    _ => const _RoomPalette(
      Icons.weekend_rounded,
      Color(0xFFF8EEDB),
      Color(0xFF102142),
    ),
  };
}

class _ControlVisual {
  const _ControlVisual(this.icon, this.background, this.color, this.valueColor);
  final IconData icon;
  final Color background;
  final Color color;
  final Color valueColor;
}

_ControlVisual _controlVisual(QuickControlKind kind, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (kind) {
      QuickControlKind.socket => _ControlVisual(
        Icons.power_rounded,
        tokens.iconBgWater,
        tokens.iconFgWater,
        tokens.iconFgWater,
      ),
      QuickControlKind.switchControl => _ControlVisual(
        Icons.toggle_on_rounded,
        tokens.iconBgBlue,
        tokens.bluePrimary,
        tokens.bluePrimary,
      ),
      QuickControlKind.light => _ControlVisual(
        Icons.lightbulb_outline_rounded,
        tokens.goldContainer,
        tokens.gold,
        tokens.gold,
      ),
      QuickControlKind.fan => _ControlVisual(
        Icons.air_rounded,
        tokens.iconBgBlue,
        tokens.bluePrimary,
        tokens.bluePrimary,
      ),
      QuickControlKind.mistMaker => _ControlVisual(
        Icons.water_drop_outlined,
        tokens.iconBgWater,
        tokens.iconFgWater,
        tokens.iconFgWater,
      ),
      QuickControlKind.curtain => _ControlVisual(
        Icons.blinds_outlined,
        tokens.iconBgPurple,
        tokens.iconFgPurple,
        tokens.iconFgPurple,
      ),
    };
  }
  return switch (kind) {
    QuickControlKind.socket => const _ControlVisual(
      Icons.power_rounded,
      Color(0xFFE0F2FE),
      Color(0xFF0284C7),
      Color(0xFF0369A1),
    ),
    QuickControlKind.switchControl => const _ControlVisual(
      Icons.toggle_on_rounded,
      Color(0xFFE5F2FF),
      Color(0xFF1685CA),
      Color(0xFF1976C4),
    ),
    QuickControlKind.light => const _ControlVisual(
      Icons.lightbulb_outline_rounded,
      Color(0xFFFFF0C6),
      Color(0xFFB57B00),
      Color(0xFF09A45D),
    ),
    QuickControlKind.fan => const _ControlVisual(
      Icons.air_rounded,
      Color(0xFFE5F2FF),
      Color(0xFF1685CA),
      Color(0xFF1976C4),
    ),
    QuickControlKind.mistMaker => const _ControlVisual(
      Icons.water_drop_outlined,
      Color(0xFFE9F8EF),
      Color(0xFF1AAD67),
      Color(0xFF617089),
    ),
    QuickControlKind.curtain => const _ControlVisual(
      Icons.blinds_outlined,
      Color(0xFFF0E9FF),
      Color(0xFF7850DD),
      Color(0xFF6144B4),
    ),
  };
}
