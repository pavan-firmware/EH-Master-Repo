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

  // One navigator key per tab so each tab keeps its own back-stack.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

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
      repository: RealHomeConnectionRepository(
        primaryDevice: _homeController.connectedDeviceSummary,
        onRefresh: _homeController.startConnectionSetup,
      ),
      onDeviceProvisioned: _homeController.markDeviceProvisioned,
    ));
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
              deviceCount: 1,
              connectivity: ConnectivityCause.online,
              telemetryFreshness: TelemetryFreshness.current,
              summary: 'Online',
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
        RoomContextPage(room: typedRoom, onAddDevice: _openConnection));
  }

  void _showControlCustomization() {
    final tokens = context.ehColors;
    final devices = _homeController.devices;

    // Build all candidate controls across commissioned devices
    final candidateControls = <({String id, String label, String room})>[];
    for (final d in devices) {
      final room = d.roomName.trim().isEmpty ? 'Living Room' : d.roomName;
      candidateControls.add((
        id: '${d.id}_ch1',
        label: '${d.name} Switch 1',
        room: room,
      ));
      candidateControls.add((
        id: '${d.id}_ch2',
        label: '${d.name} Switch 2',
        room: room,
      ));
      candidateControls.add((
        id: '${d.id}_ch3',
        label: '${d.name} Switch 3',
        room: room,
      ));
    }

    final selected = List<String>.from(_homeController.selectedQuickControlIds);
    if (selected.isEmpty && candidateControls.isNotEmpty) {
      selected.addAll(candidateControls.take(4).map((c) => c.id));
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
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
                  candidateControls.isEmpty
                      ? 'No confirmed devices found. Add a device to customize quick controls.'
                      : 'Choose up to four confirmed device controls for your home dashboard.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (candidateControls.isNotEmpty)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidateControls.length,
                      itemBuilder: (context, index) {
                        final item = candidateControls[index];
                        final isChecked = selected.contains(item.id);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: tokens.bluePrimary,
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            item.room,
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                          value: isChecked,
                          onChanged: (bool? val) {
                            setModalState(() {
                              if (val == true) {
                                if (selected.length < 4) {
                                  selected.add(item.id);
                                }
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
                            await _homeController.saveQuickControlSelection(selected);
                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop();
                            }
                            _showMessage('Quick controls saved.');
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.blueDarker,
                    ),
                    child: const Text('Save quick controls'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                // Tab 0 — Home
                Navigator(
                  key: _navigatorKeys[0],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => HomePage(
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
                        final acknowledged = await _navigatorKeys[0]
                            .currentState
                            ?.push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const SafetyAlertPage()),
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
                  ),
                ),

                // Tab 1 — Rooms
                Navigator(
                  key: _navigatorKeys[1],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => RoomsPage(
                      homeController: _homeController,
                      onAddDevice: _openConnection,
                    ),
                  ),
                ),

                // Tab 2 — Routines
                Navigator(
                  key: _navigatorKeys[2],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) =>
                        AutomationsPage(onConnectHome: _openConnection),
                  ),
                ),

                // Tab 3 — Activity
                Navigator(
                  key: _navigatorKeys[3],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => const ActivityPage(),
                  ),
                ),

                // Tab 4 — Settings
                Navigator(
                  key: _navigatorKeys[4],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      onConnectHome: _homeController.startConnectionSetup,
                      connectionState: _homeController.connectionState,
                      connectionMessage: _homeController.connectionMessage,
                      connectionRepository: RealHomeConnectionRepository(
                        primaryDevice: _homeController.connectedDeviceSummary,
                        onRefresh: _homeController.startConnectionSetup,
                      ),
                    ),
                  ),
                ),
              ],
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
