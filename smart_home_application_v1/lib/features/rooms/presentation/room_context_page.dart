import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../devices/presentation/device_control_page.dart';

enum _RoomQuickControlViewMode { brick, carousel, list }

/// One reusable detail page renders all room types from typed capabilities.
class RoomContextPage extends StatefulWidget {
  const RoomContextPage({
    super.key,
    required this.room,
    this.homeController,
    this.onAddDevice,
  });

  final Room room;
  final HomeController? homeController;
  final VoidCallback? onAddDevice;

  @override
  State<RoomContextPage> createState() => _RoomContextPageState();
}

class _RoomContextPageState extends State<RoomContextPage> {
  _RoomQuickControlViewMode _viewMode = _RoomQuickControlViewMode.brick;

  void _showRoomControlCustomization(
    BuildContext context,
    Room currentRoom,
    List<RoomCapability> allCaps,
  ) {
    final tokens = context.ehColors;
    final saved = DeviceStorageService.getRoomQuickControls(currentRoom.name);
    final selected = List<String>.from(saved ?? allCaps.map((c) => c.id));

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
                        '${currentRoom.name} Controls',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                    'Select which device controls to keep in this room\'s quick controls section.',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (allCaps.isNotEmpty)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: allCaps.length,
                        separatorBuilder: (_, _) => Divider(
                          color: tokens.borderSubtle,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final cap = allCaps[index];
                          final isChecked = selected.contains(cap.id);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: tokens.bluePrimary,
                            title: Text(
                              cap.label,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              cap.value.toLowerCase() == 'on' ? 'State: Active · ON' : 'State: Standby · OFF',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            value: isChecked,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  selected.add(cap.id);
                                } else {
                                  selected.remove(cap.id);
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
                      onPressed: () async {
                        await DeviceStorageService.saveRoomQuickControls(
                          currentRoom.name,
                          selected,
                        );
                        if (sheetCtx.mounted) {
                          Navigator.of(sheetCtx).pop();
                        }
                        setState(() {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Room Controls',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
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

  void _showRenameDialog(BuildContext context, Room currentRoom) async {
    final textCtrl = TextEditingController(text: currentRoom.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Room'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Room name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && textCtrl.text.trim().isNotEmpty && widget.homeController != null) {
      await widget.homeController!.renameRoom(
        roomId: currentRoom.id,
        oldName: currentRoom.name,
        newName: textCtrl.text.trim(),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, Room currentRoom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${currentRoom.name}"? Any devices assigned to this room will be unassigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.homeController != null) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      await widget.homeController!.deleteRoom(roomId: currentRoom.id, roomName: currentRoom.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.homeController != null) {
      return AnimatedBuilder(
        animation: widget.homeController!,
        builder: (context, _) => _buildPage(context),
      );
    }
    return _buildPage(context);
  }

  Widget _buildPage(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveRoom = widget.homeController != null
        ? widget.homeController!.rooms.firstWhere(
            (r) => r.id == widget.room.id || r.name == widget.room.name,
            orElse: () => widget.room,
          )
        : widget.room;

    final current = effectiveRoom.telemetryFreshness == TelemetryFreshness.current;
    final temperature = effectiveRoom.capabilities
        .where((item) => item.kind == RoomCapabilityKind.temperature)
        .firstOrNull;

    // Get live capabilities (channels) for this room from homeController if available
    final capabilities = effectiveRoom.capabilities;
    final devices = effectiveRoom.devices;

    // Filter quick controls based on user customization for this room
    final savedRoomQuickIds = DeviceStorageService.getRoomQuickControls(effectiveRoom.name);
    final displayCapabilities = (savedRoomQuickIds != null && savedRoomQuickIds.isNotEmpty)
        ? capabilities.where((c) => savedRoomQuickIds.contains(c.id)).toList()
        : capabilities;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await widget.homeController?.loadHomeData();
          },
          color: tokens.bluePrimary,
          backgroundColor: tokens.surfaceCard,
          displacement: 24,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 106),
          children: [
            Row(
              children: [
                _HeaderButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        effectiveRoom.name,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        devices.isEmpty
                            ? '0 devices  ·  No devices'
                            : '${devices.length} ${devices.length == 1 ? "device" : "devices"}  ·  ${effectiveRoom.isOnline ? 'All online' : 'Offline'}',
                        style: TextStyle(
                          color: devices.isEmpty
                              ? tokens.textTertiary
                              : (effectiveRoom.isOnline
                                  ? tokens.success
                                  : tokens.textTertiary),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderButton(icon: Icons.star_border_rounded, onTap: () {}),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Icon(Icons.more_horiz_rounded, color: tokens.textPrimary, size: 22),
                  ),
                  color: tokens.surfaceCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (action) {
                    if (action == 'rename') {
                      _showRenameDialog(context, effectiveRoom);
                    } else if (action == 'delete') {
                      _showDeleteDialog(context, effectiveRoom);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: tokens.textPrimary),
                          const SizedBox(width: 10),
                          Text('Rename room', style: TextStyle(color: tokens.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: tokens.warning),
                          const SizedBox(width: 10),
                          Text('Delete room', style: TextStyle(color: tokens.warning)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _RoomHero(
              room: effectiveRoom,
              temperature: temperature?.value,
              current: current,
            ),
            const SizedBox(height: 27),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick controls',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (capabilities.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => _showRoomControlCustomization(
                      context,
                      effectiveRoom,
                      capabilities,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Customize',
                      style: TextStyle(
                        color: tokens.bluePrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
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
                          mode: _RoomQuickControlViewMode.brick,
                          icon: Icons.dashboard_customize_rounded,
                          tooltip: 'Adaptive Brick Layout',
                          tokens: tokens,
                        ),
                        _modeButton(
                          mode: _RoomQuickControlViewMode.carousel,
                          icon: Icons.view_carousel_rounded,
                          tooltip: 'Horizontal Carousel',
                          tokens: tokens,
                        ),
                        _modeButton(
                          mode: _RoomQuickControlViewMode.list,
                          icon: Icons.view_agenda_rounded,
                          tooltip: 'List View',
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 15),

            // Adaptive Brick / Carousel / List for Room Quick Controls
            if (displayCapabilities.isNotEmpty) ...[
              if (_viewMode == _RoomQuickControlViewMode.brick)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final halfWidth = (maxWidth - 12) / 2;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: displayCapabilities.map((cap) {
                        final isFullWidth = cap.kind == RoomCapabilityKind.fan ||
                            cap.kind == RoomCapabilityKind.curtain ||
                            cap.label.toLowerCase().contains('dimmer') ||
                            cap.label.toLowerCase().contains('ac') ||
                            cap.label.toLowerCase().contains('climate');

                        return SizedBox(
                          width: isFullWidth ? maxWidth : halfWidth,
                          child: _AdaptiveRoomQuickControlCard(
                            capability: cap,
                            isFullWidth: isFullWidth,
                            homeController: widget.homeController,
                          ),
                        );
                      }).toList(),
                    );
                  },
                )
              else if (_viewMode == _RoomQuickControlViewMode.carousel)
                SizedBox(
                  height: 175,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayCapabilities.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => _AdaptiveRoomQuickControlCard(
                      capability: displayCapabilities[index],
                      isFullWidth: false,
                      homeController: widget.homeController,
                    ),
                  ),
                )
              else
                Column(
                  children: displayCapabilities.map((cap) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdaptiveRoomQuickControlCard(
                      capability: cap,
                      isFullWidth: true,
                      homeController: widget.homeController,
                    ),
                  )).toList(),
                ),
            ] else if (devices.isNotEmpty)
              SizedBox(
                height: 175,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: devices.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 13),
                  itemBuilder: (_, index) => _QuickDeviceCard(
                    device: devices[index],
                    homeController: widget.homeController,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'No quick controls yet. Add a device to begin.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Devices',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAddDevice,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.bluePrimary,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add device'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceRow(
                  device: device,
                  homeController: widget.homeController,
                ),
              ),
            ),

            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Room insights',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.bluePrimary,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('See history'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InsightsCard(insights: effectiveRoom.insights),
          ],
        ),
      ),
    ),
  );
  }

  Widget _modeButton({
    required _RoomQuickControlViewMode mode,
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

class _RoomHero extends StatelessWidget {
  const _RoomHero({
    required this.room,
    required this.temperature,
    required this.current,
  });

  final Room room;
  final String? temperature;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final hero = _heroColors(room.iconKey, tokens);

    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hero,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ROOM PREVIEW',
                        style: TextStyle(
                          color: tokens.textPrimary.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        _roomHeroIcon(room.iconKey),
                        color: tokens.textPrimary,
                        size: 42,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    _roomHeroIcon(room.iconKey),
                    size: 32,
                    color: tokens.textPrimary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.thermostat_outlined,
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      temperature ?? '—',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  current
                      ? (room.status == RoomStatus.normal
                          ? 'Comfortable'
                          : (room.isOffline ? 'Offline' : 'Attention needed'))
                      : 'State unavailable',
                  style: TextStyle(
                    color: current && room.status == RoomStatus.normal
                        ? tokens.success
                        : (room.isOffline ? tokens.textSecondary : tokens.warning),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _HeroMeta(
                  icon: Icons.water_drop_outlined,
                  text: room.summary,
                ),
                const SizedBox(height: 4),
                _HeroMeta(
                  icon: Icons.access_time_rounded,
                  text: current ? 'Updated just now' : 'Telemetry stale',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Icon(icon, size: 16, color: tokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _AdaptiveRoomQuickControlCard extends StatelessWidget {
  const _AdaptiveRoomQuickControlCard({
    required this.capability,
    required this.isFullWidth,
    this.homeController,
  });

  final RoomCapability capability;
  final bool isFullWidth;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isOn = capability.value.toLowerCase() == 'on';

    String devId = capability.id;
    int chIdx = 1;
    if (capability.id.contains('_ch')) {
      final parts = capability.id.split('_ch');
      devId = parts[0];
      chIdx = int.tryParse(parts[1]) ?? 1;
    }

    final isSocket = capability.label.toLowerCase().contains('socket');
    final icon = isSocket ? Icons.power_rounded : _deviceIcon(capability.kind);
    final devColor = isSocket ? tokens.bluePrimary : _deviceColor(capability.kind, tokens);

    if (isFullWidth) {
      return _buildWideCard(context, tokens, devColor, icon, isOn, devId, chIdx);
    }
    return _buildCompactCard(context, tokens, devColor, icon, isOn, devId, chIdx);
  }

  Widget _buildCompactCard(
    BuildContext context,
    EHThemeTokens tokens,
    Color devColor,
    IconData icon,
    bool isOn,
    String devId,
    int chIdx,
  ) {
    final isOnline = capability.isOnline;
    return Opacity(
      opacity: isOnline ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isOn && isOnline) ? devColor.withValues(alpha: 0.45) : tokens.borderSubtle,
            width: (isOn && isOnline) ? 1.5 : 1.0,
          ),
          boxShadow: (isOn && isOnline)
              ? [
                  BoxShadow(
                    color: devColor.withValues(alpha: 0.10),
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
                    color: (isOn && isOnline)
                        ? devColor
                        : tokens.isDark
                            ? const Color(0xFF253347)
                            : const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: (isOn && isOnline) ? Colors.white : tokens.textTertiary,
                    size: 22,
                  ),
                ),
                Switch.adaptive(
                  value: isOn && isOnline,
                  activeThumbColor: devColor,
                  activeTrackColor: devColor.withValues(alpha: 0.35),
                  inactiveThumbColor: tokens.switchThumbOff,
                  inactiveTrackColor: tokens.switchTrackOff,
                  onChanged: (isOnline && homeController != null)
                      ? (val) {
                          homeController!.setDeviceChannelPower(
                            deviceId: devId,
                            channelIndex: chIdx,
                            value: val,
                          );
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              capability.label,
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
              !isOnline
                  ? 'Offline · Unavailable'
                  : (isOn ? 'Active · ON' : 'Standby · OFF'),
              style: TextStyle(
                color: !isOnline
                    ? tokens.textTertiary
                    : (isOn ? tokens.success : tokens.textTertiary),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCard(
    BuildContext context,
    EHThemeTokens tokens,
    Color devColor,
    IconData icon,
    bool isOn,
    String devId,
    int chIdx,
  ) {
    final isFan = capability.kind == RoomCapabilityKind.fan;
    final isOnline = capability.isOnline;

    return Opacity(
      opacity: isOnline ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isOn && isOnline) ? devColor.withValues(alpha: 0.45) : tokens.borderSubtle,
            width: (isOn && isOnline) ? 1.5 : 1.0,
          ),
          boxShadow: (isOn && isOnline)
              ? [
                  BoxShadow(
                    color: devColor.withValues(alpha: 0.10),
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
                    color: (isOn && isOnline)
                        ? devColor
                        : tokens.isDark
                            ? const Color(0xFF253347)
                            : const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: (isOn && isOnline) ? Colors.white : tokens.textTertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capability.label,
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
                        !isOnline
                            ? 'Offline · Unavailable'
                            : (isOn
                                ? (isFan ? 'Fan Speed: Active' : 'Power: Active · ON')
                                : 'Standby · OFF'),
                        style: TextStyle(
                          color: !isOnline
                              ? tokens.textTertiary
                              : (isOn ? tokens.success : tokens.textTertiary),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isOn && isOnline,
                  activeThumbColor: devColor,
                  activeTrackColor: devColor.withValues(alpha: 0.35),
                  inactiveThumbColor: tokens.switchThumbOff,
                  inactiveTrackColor: tokens.switchTrackOff,
                  onChanged: (isOnline && homeController != null)
                      ? (val) {
                          homeController!.setDeviceChannelPower(
                            deviceId: devId,
                            channelIndex: chIdx,
                            value: val,
                          );
                        }
                      : null,
                ),
              ],
            ),
            if (isFan && isOn && isOnline) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _speedChip('1', true, devColor, tokens),
                  _speedChip('2', false, devColor, tokens),
                  _speedChip('3', false, devColor, tokens),
                  _speedChip('4', false, devColor, tokens),
                  _speedChip('Turbo', false, devColor, tokens),
                ],
              ),
            ],
          ],
        ),
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

class _QuickDeviceCard extends StatelessWidget {
  const _QuickDeviceCard({
    required this.device,
    this.homeController,
  });

  final RoomDevice device;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isOn = device.value.toLowerCase() == 'on';
    final liveDev = homeController?.devices.cast<ConnectedDeviceSummary?>().firstWhere(
          (d) => d?.id == device.id,
          orElse: () => null,
        );
    final isOnline = (liveDev != null)
        ? liveDev.online
        : (device.confidence != ActuatorConfidence.unavailable);
    final isSocket = device.name.toLowerCase().contains('socket') ||
        device.type.toLowerCase().contains('socket');
    final icon = isSocket ? Icons.power_rounded : _deviceIcon(device.kind);
    final devColor = isSocket ? tokens.bluePrimary : _deviceColor(device.kind, tokens);

    return SizedBox(
      width: 150,
      child: Opacity(
        opacity: isOnline ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (isOn && isOnline)
                  ? devColor.withValues(alpha: 0.5)
                  : tokens.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isOn && isOnline)
                      ? devColor
                      : tokens.isDark
                          ? const Color(0xFF253347)
                          : const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: (isOn && isOnline) ? Colors.white : tokens.textTertiary,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                device.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                !isOnline ? 'Offline' : (isOn ? 'On' : 'Off'),
                style: TextStyle(
                  color: !isOnline ? tokens.textTertiary : (isOn ? devColor : tokens.textTertiary),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Switch.adaptive(
                  value: isOn && isOnline,
                  activeThumbColor: devColor,
                  activeTrackColor: devColor.withValues(alpha: 0.35),
                  inactiveThumbColor: tokens.switchThumbOff,
                  inactiveTrackColor: tokens.switchTrackOff,
                  onChanged: (isOnline && homeController != null)
                      ? (val) {
                          homeController!.setDeviceChannelPower(
                            deviceId: device.id,
                            channelIndex: 1,
                            value: val,
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    this.homeController,
  });

  final RoomDevice device;
  final HomeController? homeController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isSocket = device.name.toLowerCase().contains('socket') ||
        device.type.toLowerCase().contains('socket');
    final icon = isSocket ? Icons.power_rounded : _deviceIcon(device.kind);
    final devColor = isSocket ? tokens.bluePrimary : _deviceColor(device.kind, tokens);
    final devBg = tokens.isDark
        ? devColor.withValues(alpha: 0.18)
        : devColor.withValues(alpha: 0.12);

    // Look up full device summary from homeController if available
    final devSummary = homeController?.devices.cast<ConnectedDeviceSummary?>().firstWhere(
      (d) => d?.id == device.id,
      orElse: () => null,
    );
    final isOnline = devSummary?.online ?? (device.confidence != ActuatorConfidence.unavailable);

    return InkWell(
      onTap: () {
        if (homeController != null && devSummary != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeviceControlPage(
                device: devSummary,
                homeController: homeController!,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: devBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: devColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${device.type} • 3 Channels',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.bluePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage',
                        style: TextStyle(
                          color: tokens.bluePrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          color: tokens.bluePrimary, size: 16),
                    ],
                  ),
                ),
              ],
            ),

            if (homeController != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Multi-channel quick controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) {
                  final chIdx = i + 1;
                  final isChOn = homeController!.getDeviceChannelPower(
                    device.id,
                    chIdx,
                    defaultValue: chIdx == 1 && homeController!.livingRoomLightOn,
                  );
                  final chLabel = isSocket ? 'Outlet $chIdx' : 'Switch $chIdx';

                  return Opacity(
                    opacity: isOnline ? 1.0 : 0.55,
                    child: InkWell(
                      onTap: isOnline
                          ? () {
                              homeController!.setDeviceChannelPower(
                                deviceId: device.id,
                                channelIndex: chIdx,
                                value: !isChOn,
                              );
                            }
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: (isChOn && isOnline)
                              ? tokens.bluePrimary
                              : tokens.isDark
                                  ? const Color(0xFF1B283A)
                                  : const Color(0xFFEFF3F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSocket ? Icons.power_rounded : Icons.lightbulb_rounded,
                              size: 14,
                              color: (isChOn && isOnline) ? Colors.white : tokens.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chLabel,
                              style: TextStyle(
                                color: (isChOn && isOnline) ? Colors.white : tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});
  final RoomInsights insights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final energy = _EnergySummary(insights: insights);
        final metrics = _InsightMetrics(insights: insights);
        final content = constraints.maxWidth < 390
            ? Column(
                children: [
                  energy,
                  Divider(height: 28, color: tokens.borderSubtle),
                  metrics,
                ],
              )
            : Row(
                children: [
                  Expanded(child: energy),
                  VerticalDivider(width: 26, color: tokens.borderSubtle),
                  Expanded(child: metrics),
                ],
              );
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: tokens.isDark
                ? Border.all(color: tokens.borderSubtle)
                : null,
          ),
          child: content,
        );
      },
    );
  }
}

class _EnergySummary extends StatelessWidget {
  const _EnergySummary({required this.insights});
  final RoomInsights insights;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 19, color: tokens.warning),
            const SizedBox(width: 8),
            Text(
              "Today's energy",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          insights.energyKwh,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          insights.energyChange,
          style: TextStyle(color: tokens.warning, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        const _MiniChart(),
      ],
    );
  }
}

class _InsightMetrics extends StatelessWidget {
  const _InsightMetrics({required this.insights});
  final RoomInsights insights;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: [
        _InsightLine(
          icon: Icons.schedule_outlined,
          label: 'Most active',
          value: insights.activeWindow,
        ),
        Divider(height: 22, color: tokens.borderSubtle),
        _InsightLine(
          icon: Icons.thermostat_outlined,
          label: 'Avg. temperature',
          value: insights.averageTemperature,
        ),
        Divider(height: 22, color: tokens.borderSubtle),
        _InsightLine(
          icon: Icons.water_drop_outlined,
          label: 'Avg. humidity',
          value: insights.averageHumidity,
        ),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Icon(icon, size: 19, color: tokens.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.textPrimary),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: tokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SizedBox(
      height: 38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          15,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: 8.0 + ((index * 11) % 28),
                color: tokens.bluePrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          shape: BoxShape.circle,
          border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
        ),
        child: Icon(icon, color: tokens.headerAction, size: 22),
      ),
    );
  }
}

List<Color> _heroColors(String key, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (key) {
      'living' => const [Color(0xFF5C472A), Color(0xFF332616)],
      'kitchen' => const [Color(0xFF6B3320), Color(0xFF381B11)],
      'plant' => const [Color(0xFF234D3D), Color(0xFF132B22)],
      _ => const [Color(0xFF1F486E), Color(0xFF10263B)],
    };
  }
  return switch (key) {
    'living' => const [Color(0xFFD5B68D), Color(0xFF8C6B4F)],
    'kitchen' => const [Color(0xFFFFC9B7), Color(0xFFE57C50)],
    'plant' => const [Color(0xFFBEE1D2), Color(0xFF4C9679)],
    _ => const [Color(0xFFBFDDF4), Color(0xFF5A91BF)],
  };
}

IconData _roomHeroIcon(String key) => switch (key) {
  'living' => Icons.weekend_rounded,
  'kitchen' => Icons.kitchen_outlined,
  'plant' => Icons.local_florist_outlined,
  _ => Icons.water_drop_outlined,
};

Color _deviceColor(RoomCapabilityKind kind, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (kind) {
      RoomCapabilityKind.light || RoomCapabilityKind.lamp => tokens.gold,
      RoomCapabilityKind.fan => tokens.bluePrimary,
      RoomCapabilityKind.curtain => tokens.iconFgPurple,
      RoomCapabilityKind.temperature => tokens.iconFgWater,
      RoomCapabilityKind.gasSensor => tokens.warning,
      RoomCapabilityKind.soilMoisture ||
      RoomCapabilityKind.mistCare => tokens.iconFgPlant,
      _ => tokens.bluePrimary,
    };
  }
  return switch (kind) {
    RoomCapabilityKind.light ||
    RoomCapabilityKind.lamp => const Color(0xFFB88700),
    RoomCapabilityKind.fan => const Color(0xFF168DD1),
    RoomCapabilityKind.curtain => const Color(0xFF7953E8),
    RoomCapabilityKind.temperature => const Color(0xFF159B9E),
    RoomCapabilityKind.gasSensor => const Color(0xFFF26D12),
    RoomCapabilityKind.soilMoisture ||
    RoomCapabilityKind.mistCare => const Color(0xFF18A963),
    _ => const Color(0xFF3175B9),
  };
}

IconData _deviceIcon(RoomCapabilityKind kind) => switch (kind) {
  RoomCapabilityKind.socket => Icons.power_rounded,
  RoomCapabilityKind.switchControl => Icons.toggle_on_rounded,
  RoomCapabilityKind.light => Icons.lightbulb_outline_rounded,
  RoomCapabilityKind.lamp => Icons.light_rounded,
  RoomCapabilityKind.fan => Icons.air_rounded,
  RoomCapabilityKind.curtain => Icons.curtains_outlined,
  RoomCapabilityKind.temperature => Icons.thermostat_outlined,
  RoomCapabilityKind.gasSensor => Icons.air_rounded,
  RoomCapabilityKind.soilMoisture ||
  RoomCapabilityKind.waterLevel => Icons.water_drop_outlined,
  RoomCapabilityKind.mistCare => Icons.cloud_outlined,
  RoomCapabilityKind.lowLevelAlert => Icons.notifications_none_rounded,
};
