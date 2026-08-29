import 'package:flutter/material.dart';

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
import '../features/settings/presentation/settings_page.dart';
import 'home_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.homeController});

  final HomeController? homeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final HomeController _homeController;

  @override
  void initState() {
    super.initState();
    _homeController = widget.homeController ?? HomeController();
  }

  @override
  void dispose() {
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

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  void _openConnection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionPage(
          onStart: _homeController.startConnectionSetup,
          connectionState: _homeController.connectionState,
          connectionMessage: _homeController.connectionMessage,
          repository: RealHomeConnectionRepository(
            primaryDevice: _homeController.connectedDeviceSummary,
            onRefresh: _homeController.startConnectionSetup,
          ),
          onDeviceProvisioned: _homeController.markDeviceProvisioned,
        ),
      ),
    );
  }

  void _openInsights() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeInsightsPage(data: _homeController.dashboard),
      ),
    );
  }

  void _openRoomContext(RoomPreview room) {
    final typedRoom = RoomCatalog.preview.firstWhere(
      (candidate) => candidate.id == room.id,
      orElse: () => RoomCatalog.preview.first,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RoomContextPage(room: typedRoom)));
  }

  void _showControlCustomization() {
    final tokens = context.ehColors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick controls',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose up to four confirmed, secure device controls. This will be available after device commissioning.',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return AnimatedBuilder(
      animation: _homeController,
      builder: (context, _) {
        final pages = <Widget>[
          HomePage(
            dashboard: _homeController.dashboard,
            lightOn: _homeController.livingRoomLightOn,
            alertAcknowledged: _homeController.alertAcknowledged,
            lightCommandPending: _homeController.lightCommandPending,
            onLightChanged: (value) async {
              await _homeController.setLivingRoomLight(value);
              _showMessage(
                _homeController.lightConfidence.name == 'confirmed'
                    ? (value
                          ? 'Living room light confirmed on.'
                          : 'Living room light confirmed off.')
                    : 'The light did not confirm the command. Try again.',
              );
            },
            onAlertTap: () async {
              final acknowledged = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SafetyAlertPage()),
              );
              if (acknowledged == true) {
                _homeController.acknowledgeAlert();
                _showMessage(
                  'Alert acknowledged. Safety monitoring remains active.',
                );
              }
            },
            onConnectHome: _openConnection,
            onShowRooms: () => _selectTab(1),
            onOpenRoom: _openRoomContext,
            onShowRoutines: () => _selectTab(2),
            onShowActivity: () => _selectTab(3),
            onShowSettings: () => _selectTab(4),
            onShowInsights: _openInsights,
            onCustomizeControls: _showControlCustomization,
            onUnavailableControl: () => _showMessage(
              'This control stays unavailable until secure device acknowledgement is implemented.',
            ),
          ),
          RoomsPage(homeController: _homeController),
          AutomationsPage(onConnectHome: _openConnection),
          const ActivityPage(),
          SettingsPage(
            onConnectHome: _homeController.startConnectionSetup,
            connectionState: _homeController.connectionState,
            connectionMessage: _homeController.connectionMessage,
            connectionRepository: RealHomeConnectionRepository(
              primaryDevice: _homeController.connectedDeviceSummary,
              onRefresh: _homeController.startConnectionSetup,
            ),
          ),
        ];
        return Scaffold(
          extendBody: false,
          backgroundColor: tokens.bgApp,
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: _HavenFloatingNavigation(
            selectedIndex: _selectedIndex,
            onSelected: _selectTab,
          ),
        );
      },
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
