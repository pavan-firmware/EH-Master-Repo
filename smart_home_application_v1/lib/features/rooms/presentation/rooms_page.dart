import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/room_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/carousel_page_indicator.dart';
import '../../onboarding/presentation/nearby_setup_page.dart';
import 'room_context_page.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, this.homeController});

  final HomeController? homeController;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

enum _RoomFilter { all, attention, online, offline }

enum _RoomSort { nameAscending, nameDescending, deviceCount, attentionFirst }

class _RoomsPageState extends State<RoomsPage> {
  static const _filterViewportFraction = 0.43;
  static const _filterCount = 4;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  _RoomFilter _filter = _RoomFilter.all;
  _RoomSort _sort = _RoomSort.nameAscending;
  int _filterPage = 0;
  final _filterController = PageController(
    viewportFraction: _filterViewportFraction,
  );

  void _dismissSearch() {
    _searchFocus.unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _filterController.dispose();
    super.dispose();
  }

  List<Room> get _visibleRooms {
    final query = _search.text.trim().toLowerCase();
    final sourceRooms = widget.homeController?.rooms ?? RoomCatalog.preview;
    final rooms =
        sourceRooms.where((room) {
          final matchesQuery =
              query.isEmpty || room.name.toLowerCase().contains(query);
          final matchesFilter = switch (_filter) {
            _RoomFilter.all => true,
            _RoomFilter.attention => room.needsAttention,
            _RoomFilter.online => room.isOnline && !room.needsAttention,
            _RoomFilter.offline => room.isOffline,
          };
          return matchesQuery && matchesFilter;
        }).toList()..sort(
          (a, b) => switch (_sort) {
            _RoomSort.nameAscending => a.name.compareTo(b.name),
            _RoomSort.nameDescending => b.name.compareTo(a.name),
            _RoomSort.deviceCount => b.deviceCount.compareTo(a.deviceCount),
            _RoomSort.attentionFirst => (b.needsAttention ? 1 : 0).compareTo(
              a.needsAttention ? 1 : 0,
            ),
          },
        );
    return rooms;
  }

  void _openRoom(Room room) {
    _dismissSearch();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoomContextPage(room: room)))
        .then((_) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _dismissSearch();
            });
          }
        });
  }

  Future<void> _openSortMenu(BuildContext buttonContext) async {
    _dismissSearch();
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final selected = await showMenu<_RoomSort>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height,
        MediaQuery.sizeOf(context).width - origin.dx - box.size.width,
        0,
      ),
      items: const [
        PopupMenuItem(value: _RoomSort.nameAscending, child: Text('Name: A-Z')),
        PopupMenuItem(
          value: _RoomSort.nameDescending,
          child: Text('Name: Z-A'),
        ),
        PopupMenuItem(
          value: _RoomSort.deviceCount,
          child: Text('Most devices'),
        ),
        PopupMenuItem(
          value: _RoomSort.attentionFirst,
          child: Text('Needs attention first'),
        ),
      ],
    );
    if (selected != null && mounted) {
      _dismissSearch();
      setState(() => _sort = selected);
    }
  }

  void _addRoom() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const NearbySetupPage()));

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final rooms = _visibleRooms;
    final sourceRooms = widget.homeController?.rooms ?? RoomCatalog.preview;
    final totalDevices = sourceRooms.fold<int>(
      0,
      (sum, room) => sum + room.deviceCount,
    );
    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: tokens.bgApp,
        body: ScrollFriendlyPage(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissSearch,
            child: ListView(
              key: const PageStorageKey<String>('rooms-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 106),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rooms',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'View and control every space in your home.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    _RoundAction(
                      icon: Icons.add_rounded,
                      tooltip: 'Add room',
                      onTap: _addRoom,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  style: TextStyle(color: tokens.textPrimary),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) => _dismissSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search rooms',
                    hintStyle: TextStyle(color: tokens.textTertiary),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: tokens.textSecondary,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.borderControl),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.borderControl),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: tokens.bluePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                SizedBox(
                  height: 66,
                  child: PageView(
                    controller: _filterController,
                    padEnds: false,
                    onPageChanged: (value) =>
                        setState(() => _filterPage = value),
                    children: [
                      _FilterChip(
                        icon: Icons.grid_view_rounded,
                        label: 'All rooms',
                        count: '${RoomCatalog.preview.length} rooms',
                        selected: _filter == _RoomFilter.all,
                        color: tokens.bluePrimary,
                        onTap: () => setState(() => _filter = _RoomFilter.all),
                      ),
                      _FilterChip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Attention',
                        count:
                            '${RoomCatalog.preview.where((r) => r.needsAttention).length} room',
                        selected: _filter == _RoomFilter.attention,
                        color: tokens.warning,
                        onTap: () =>
                            setState(() => _filter = _RoomFilter.attention),
                      ),
                      _FilterChip(
                        icon: Icons.circle,
                        label: 'Online',
                        count: '$totalDevices devices',
                        selected: _filter == _RoomFilter.online,
                        color: tokens.success,
                        onTap: () =>
                            setState(() => _filter = _RoomFilter.online),
                      ),
                      _FilterChip(
                        icon: Icons.circle,
                        label: 'Offline',
                        count:
                            '${RoomCatalog.preview.where((r) => r.isOffline).fold<int>(0, (sum, r) => sum + r.deviceCount)} devices',
                        selected: _filter == _RoomFilter.offline,
                        color: tokens.textTertiary,
                        onTap: () =>
                            setState(() => _filter = _RoomFilter.offline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CarouselDotIndicator(
                  itemCount: _filterCount,
                  pageIndex: _filterPage,
                  viewportFraction: _filterViewportFraction,
                  activeColor: tokens.bluePrimary,
                  inactiveColor: tokens.isDark
                      ? tokens.borderControl
                      : const Color(0xFFD6DDE8),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rooms.length} ${rooms.length == 1 ? 'room' : 'rooms'} · $totalDevices devices',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => InkWell(
                        onTap: () => _openSortMenu(buttonContext),
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 150,
                          height: 42,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    _sortLabel(_sort),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.bluePrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: tokens.bluePrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rooms.isEmpty)
                  const _EmptyRooms()
                else
                  ...rooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: RoomCard(room: room, onTap: () => _openRoom(room)),
                    ),
                  ),
                const SizedBox(height: 2),
                _AddRoomBanner(onTap: _addRoom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, required this.onTap});
  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final palette = _roomPalette(room.iconKey, tokens);
    final statusColor = room.needsAttention
        ? tokens.warning
        : room.isOffline
        ? tokens.textTertiary
        : tokens.success;
    return Semantics(
      button: true,
      label: '${room.name}, ${room.summary}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(15),
            border: tokens.isDark
                ? Border.all(color: tokens.borderSubtle)
                : null,
            boxShadow: tokens.isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x100B2448),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 350;
              return Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: compact ? 55 : 64,
                        height: compact ? 64 : 76,
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          palette.icon,
                          color: palette.foreground,
                          size: compact ? 28 : 33,
                        ),
                      ),
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.surfaceCard,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: compact ? 6 : 5,
                    child: _RoomSummary(room: room, statusColor: statusColor),
                  ),
                  if (!compact)
                    VerticalDivider(
                      width: 26,
                      thickness: 1,
                      color: tokens.isDark
                          ? tokens.borderSubtle
                          : const Color(0xFFE4EAF2),
                    ),
                  if (compact)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: tokens.chevron,
                      size: 28,
                    )
                  else
                    Expanded(flex: 5, child: _RoomCapabilities(room: room)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomSummary extends StatelessWidget {
  const _RoomSummary({required this.room, required this.statusColor});
  final Room room;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          room.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          room.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: room.needsAttention ? tokens.warning : tokens.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Icon(
              room.needsAttention
                  ? Icons.warning_amber_rounded
                  : room.isOffline
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_rounded,
              color: statusColor,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                room.connectivityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoomCapabilities extends StatelessWidget {
  const _RoomCapabilities({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: room.capabilities
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          _capabilityIcon(item.kind),
                          color: tokens.textSecondary,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          item.value,
                          style: TextStyle(
                            color: item.isWarning
                                ? tokens.warning
                                : tokens.bluePrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: tokens.chevron, size: 28),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 154,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? tokens.blueSelectedBg : tokens.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? tokens.bluePrimary : tokens.borderControl,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? (tokens.isDark ? tokens.blueSelectedText : color)
                      : color,
                  size: 29,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? (tokens.isDark
                                    ? tokens.blueSelectedText
                                    : const Color(0xFF102142))
                              : tokens.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.blueDarker,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tokens.buttonText, size: 25),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No rooms match your search.',
          style: TextStyle(color: tokens.textSecondary),
        ),
      ),
    );
  }
}

class _AddRoomBanner extends StatelessWidget {
  const _AddRoomBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.isDark
              ? tokens.surfaceElevated
              : const Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tokens.isDark
                ? tokens.borderSubtle
                : const Color(0xFFCFDDF4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.home_work_outlined,
                  color: tokens.bluePrimary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add more rooms or devices',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expand your smart home.',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.bluePrimary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sortLabel(_RoomSort sort) => switch (sort) {
  _RoomSort.nameAscending => 'Sort: A-Z',
  _RoomSort.nameDescending => 'Sort: Z-A',
  _RoomSort.deviceCount => 'Most devices',
  _RoomSort.attentionFirst => 'Attention first',
};

({Color background, Color foreground, IconData icon}) _roomPalette(
  String key,
  EHThemeTokens tokens,
) {
  if (tokens.isDark) {
    return switch (key) {
      'living' => (
        background: tokens.iconBgBlue,
        foreground: tokens.iconFgBlue,
        icon: Icons.weekend_rounded,
      ),
      'kitchen' => (
        background: tokens.iconBgKitchen,
        foreground: tokens.iconFgKitchen,
        icon: Icons.kitchen_outlined,
      ),
      'plant' => (
        background: tokens.iconBgPlant,
        foreground: tokens.iconFgPlant,
        icon: Icons.local_florist_outlined,
      ),
      _ => (
        background: tokens.iconBgWater,
        foreground: tokens.iconFgWater,
        icon: Icons.water_drop_outlined,
      ),
    };
  }
  return switch (key) {
    'living' => (
      background: const Color(0xFFFFF0DA),
      foreground: const Color(0xFF0C2145),
      icon: Icons.weekend_rounded,
    ),
    'kitchen' => (
      background: const Color(0xFFFFEAE8),
      foreground: const Color(0xFF0C2145),
      icon: Icons.kitchen_outlined,
    ),
    'plant' => (
      background: const Color(0xFFEDE9FF),
      foreground: const Color(0xFF0C2145),
      icon: Icons.local_florist_outlined,
    ),
    _ => (
      background: const Color(0xFFE5F1FF),
      foreground: const Color(0xFF0C2145),
      icon: Icons.water_drop_outlined,
    ),
  };
}

IconData _capabilityIcon(RoomCapabilityKind kind) => switch (kind) {
  RoomCapabilityKind.light => Icons.lightbulb_outline_rounded,
  RoomCapabilityKind.temperature => Icons.thermostat_outlined,
  RoomCapabilityKind.gasSensor => Icons.air_rounded,
  RoomCapabilityKind.soilMoisture ||
  RoomCapabilityKind.waterLevel => Icons.water_drop_outlined,
  RoomCapabilityKind.mistCare => Icons.cloud_outlined,
  RoomCapabilityKind.lowLevelAlert => Icons.notifications_none_rounded,
  RoomCapabilityKind.fan => Icons.air_rounded,
  RoomCapabilityKind.curtain => Icons.curtains_outlined,
  RoomCapabilityKind.lamp => Icons.light_rounded,
};
