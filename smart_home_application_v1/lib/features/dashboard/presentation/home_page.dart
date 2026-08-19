import 'package:flutter/material.dart';

import '../../../core/models/home_dashboard_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/carousel_page_indicator.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.dashboard,
    required this.lightOn,
    required this.lightCommandPending,
    required this.alertAcknowledged,
    required this.onLightChanged,
    required this.onAlertTap,
    required this.onConnectHome,
    required this.onShowRooms,
    required this.onOpenRoom,
    required this.onShowRoutines,
    required this.onShowActivity,
    required this.onShowSettings,
    required this.onShowInsights,
    required this.onCustomizeControls,
    required this.onUnavailableControl,
  });

  final HomeDashboardData dashboard;
  final bool lightOn;
  final bool lightCommandPending;
  final bool alertAcknowledged;
  final ValueChanged<bool> onLightChanged;
  final VoidCallback onAlertTap;
  final VoidCallback onConnectHome;
  final VoidCallback onShowRooms;
  final ValueChanged<RoomPreview> onOpenRoom;
  final VoidCallback onShowRoutines;
  final VoidCallback onShowActivity;
  final VoidCallback onShowSettings;
  final VoidCallback onShowInsights;
  final VoidCallback onCustomizeControls;
  final VoidCallback onUnavailableControl;

  @override
  Widget build(BuildContext context) {
    final hasContent = dashboard.rooms.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: ScrollFriendlyPage(
        child: ListView(
          key: const PageStorageKey<String>('haven-home-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          children: [
            _HomeHeader(
              subtitle: _contextualSubtitle(dashboard),
              onActivity: onShowActivity,
              onSettings: onShowSettings,
            ),
            const SizedBox(height: 18),
            _HomeOverviewCard(
              data: dashboard,
              onTap:
                  dashboard.isSetupFlow ||
                      dashboard.state == HomeDashboardState.offline
                  ? onConnectHome
                  : onShowInsights,
            ),
            if (dashboard.alert != null && !alertAcknowledged) ...[
              const SizedBox(height: 16),
              _AttentionCard(alert: dashboard.alert!, onTap: onAlertTap),
            ],
            const SizedBox(height: 28),
            if (hasContent) ...[
              _SectionHeader(
                title: 'Your rooms',
                action: 'See all',
                onAction: onShowRooms,
              ),
              const SizedBox(height: 14),
              _RoomPreviewStrip(
                rooms: dashboard.rooms.take(4).toList(),
                onOpenRoom: onOpenRoom,
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Quick controls',
                action: 'Customize',
                onAction: onCustomizeControls,
              ),
              const SizedBox(height: 14),
              _QuickControlStrip(
                controls: dashboard.controls,
                lightOn: lightOn,
                lightPending: lightCommandPending,
                onLightChanged: onLightChanged,
                onUnavailable: onUnavailableControl,
              ),
              if (dashboard.routine != null) ...[
                const SizedBox(height: 24),
                _RoutineCard(
                  routine: dashboard.routine!,
                  onTap: onShowRoutines,
                ),
              ],
            ] else ...[
              _SetupSupportingContent(data: dashboard, onAction: onConnectHome),
            ],
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
    required this.onSettings,
  });

  final String subtitle;
  final VoidCallback onActivity;
  final VoidCallback onSettings;

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
              child: Text(
                'EH HOME',
                style: TextStyle(
                  color: tokens.bluePrimary,
                  fontSize: 12,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w800,
                ),
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
                    tooltip: 'Activity',
                    onPressed: onActivity,
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
              const TextSpan(text: 'Good evening, '),
              TextSpan(
                text: 'Pavan',
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

class _HomeOverviewCard extends StatelessWidget {
  const _HomeOverviewCard({required this.data, required this.onTap});

  final HomeDashboardData data;
  final VoidCallback onTap;

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
              : _ReadyOverview(data: data),
        ),
      ),
    );
  }
}

class _ReadyOverview extends StatelessWidget {
  const _ReadyOverview({required this.data});
  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    const heroPrimary = Colors.white;

    final compact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.home_outlined, color: heroPrimary, size: 27),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'HOME OVERVIEW',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub_outlined, color: tokens.textPrimary, size: 27),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DEVICE SETUP',
                style: TextStyle(
                  color: tokens.textPrimary,
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
                        : tokens.gold),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          data.primaryTitle ?? 'Set up your home',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.primaryMessage ?? 'Your home is ready for its first device.',
          style: TextStyle(
            color: tokens.textSecondary,
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
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: tokens.textSecondary,
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
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
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
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
          child: Text(
            action,
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
    final statusColor = room.isAttention ? tokens.warning : tokens.success;
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
                  '${room.deviceCount} ${room.deviceCount == 1 ? 'device' : 'devices'}',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
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
                          : Icons.check_circle_outline_rounded,
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

class _QuickControlStrip extends StatefulWidget {
  const _QuickControlStrip({
    required this.controls,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    required this.onUnavailable,
  });
  final List<QuickControlPreview> controls;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final VoidCallback onUnavailable;

  @override
  State<_QuickControlStrip> createState() => _QuickControlStripState();
}

class _QuickControlStripState extends State<_QuickControlStrip> {
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
        height: 194,
        child: PageView.builder(
          padEnds: false,
          controller: _controller,
          itemCount: widget.controls.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              right: index == widget.controls.length - 1 ? 0 : 12,
            ),
            child: _QuickControlCard(
              control: widget.controls[index],
              lightOn: widget.lightOn,
              lightPending: widget.lightPending,
              onLightChanged: widget.onLightChanged,
              onUnavailable: widget.onUnavailable,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      CarouselDotIndicator(
        itemCount: widget.controls.length,
        pageIndex: _page,
        viewportFraction: _viewportFraction,
      ),
    ],
  );
}

class _QuickControlCard extends StatelessWidget {
  const _QuickControlCard({
    required this.control,
    required this.lightOn,
    required this.lightPending,
    required this.onLightChanged,
    required this.onUnavailable,
  });
  final QuickControlPreview control;
  final bool lightOn;
  final bool lightPending;
  final ValueChanged<bool> onLightChanged;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final visual = _controlVisual(control.kind, tokens);
    final unavailable =
        !control.isEnabled ||
        control.confidence == ActuatorConfidence.unavailable;
    return Semantics(
      button: true,
      label: '${control.title.replaceAll('\n', ' ')}, ${control.value}',
      child: SizedBox(
        width: 154,
        child: InkWell(
          onTap: unavailable ? onUnavailable : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(15),
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
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: visual.background,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 26),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 34,
                  child: Text(
                    control.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controlValue(control, lightOn, lightPending),
                  style: TextStyle(
                    color: unavailable
                        ? tokens.textTertiary
                        : visual.valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 108,
                    height: 32,
                    child: Center(
                      child: _controlAction(visual, unavailable, tokens),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _controlValue(QuickControlPreview item, bool isLightOn, bool pending) {
    if (item.kind == QuickControlKind.light && pending) return 'Updating…';
    if (item.kind == QuickControlKind.light) return isLightOn ? 'On' : 'Off';
    if (item.confidence == ActuatorConfidence.unavailable) return 'Unavailable';
    return item.value;
  }

  Widget _controlAction(
    _ControlVisual visual,
    bool unavailable,
    EHThemeTokens tokens,
  ) {
    switch (control.kind) {
      case QuickControlKind.light:
        return _ControlToggle(
          value: lightOn,
          enabled: !lightPending && !unavailable,
          activeColor: visual.color,
          onChanged: onLightChanged,
        );
      case QuickControlKind.fan:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 76,
              child: LinearProgressIndicator(
                value: .4,
                minHeight: 6,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: tokens.isDark
                    ? tokens.borderControl
                    : const Color(0xFFE4EAF2),
                valueColor: AlwaysStoppedAnimation(visual.color),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.tune_rounded, color: visual.color, size: 22),
          ],
        );
      case QuickControlKind.mistMaker:
        return _ControlToggle(
          value: false,
          enabled: false,
          activeColor: visual.color,
          onChanged: (_) {},
        );
      case QuickControlKind.curtain:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CircleIcon(icon: Icons.chevron_left_rounded, color: visual.color),
            const SizedBox(width: 7),
            _CircleIcon(
              icon: Icons.pause_rounded,
              color: visual.color,
              filled: true,
            ),
            const SizedBox(width: 7),
            _CircleIcon(icon: Icons.chevron_right_rounded, color: visual.color),
          ],
        );
    }
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.color,
    this.filled = false,
  });
  final IconData icon;
  final Color color;
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : color.withValues(alpha: .10),
    ),
    child: Icon(icon, color: filled ? Colors.white : color, size: 18),
  );
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
    final onTrack = tokens.isDark ? activeColor : activeColor;

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
