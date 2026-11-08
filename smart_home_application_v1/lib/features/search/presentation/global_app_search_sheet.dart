import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/home_controller.dart';
import '../../../app/theme_controller.dart';
import '../../../core/capabilities/repositories/product_catalog_repository.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../../../core/services/product_asset_resolver.dart';
import '../../devices/presentation/device_control_page.dart';

enum SearchItemKind {
  device,
  channel,
  room,
  space,
  feature,
  setting,
}

class SearchResultItem {
  SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.icon,
    this.iconColor,
    this.keywords = const [],
    this.actionPayload,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final SearchItemKind kind;
  final IconData icon;
  final Color? iconColor;
  final List<String> keywords;
  final dynamic actionPayload;
  /// Pre-resolved bundled product image path (for device/channel items).
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'kind': kind.name,
        'iconCode': icon.codePoint,
      };

  static SearchResultItem? fromJson(Map<String, dynamic> json) {
    try {
      final kindName = json['kind'] as String? ?? 'setting';
      final kind = SearchItemKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => SearchItemKind.setting,
      );
      return SearchResultItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        kind: kind,
        icon: _getIconForKind(kind),
      );
    } catch (_) {
      return null;
    }
  }

  static IconData _getIconForKind(SearchItemKind kind) {
    switch (kind) {
      case SearchItemKind.device:
        return Icons.toggle_on_rounded;
      case SearchItemKind.channel:
        return Icons.power_settings_new_rounded;
      case SearchItemKind.room:
        return Icons.meeting_room_rounded;
      case SearchItemKind.space:
        return Icons.home_work_rounded;
      case SearchItemKind.feature:
        return Icons.stars_rounded;
      case SearchItemKind.setting:
        return Icons.settings_outlined;
    }
  }
}

class GlobalAppSearchSheet extends StatefulWidget {
  const GlobalAppSearchSheet({
    super.key,
    required this.homeController,
    required this.onOpenRoom,
    required this.onOpenSettings,
    required this.onOpenActivity,
    required this.onOpenNotifications,
    required this.onOpenInsights,
    required this.onOpenAddDevice,
    required this.onOpenRoutines,
  });

  final HomeController homeController;
  final ValueChanged<RoomPreview> onOpenRoom;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAddDevice;
  final VoidCallback onOpenRoutines;

  static Future<void> show(
    BuildContext context, {
    required HomeController homeController,
    required ValueChanged<RoomPreview> onOpenRoom,
    required VoidCallback onOpenSettings,
    required VoidCallback onOpenActivity,
    required VoidCallback onOpenNotifications,
    required VoidCallback onOpenInsights,
    required VoidCallback onOpenAddDevice,
    required VoidCallback onOpenRoutines,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlobalAppSearchSheet(
        homeController: homeController,
        onOpenRoom: onOpenRoom,
        onOpenSettings: onOpenSettings,
        onOpenActivity: onOpenActivity,
        onOpenNotifications: onOpenNotifications,
        onOpenInsights: onOpenInsights,
        onOpenAddDevice: onOpenAddDevice,
        onOpenRoutines: onOpenRoutines,
      ),
    );
  }

  @override
  State<GlobalAppSearchSheet> createState() => _GlobalAppSearchSheetState();
}

class _GlobalAppSearchSheetState extends State<GlobalAppSearchSheet> {
  static const String _prefHistoryKey = 'eh_global_search_history_v1';
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResultItem> _history = [];
  List<SearchResultItem> _allIndex = [];
  List<SearchResultItem> _filteredResults = [];

  @override
  void initState() {
    super.initState();
    _buildIndex();
    _loadHistory();
    _queryController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefHistoryKey) ?? [];
      final parsed = <SearchResultItem>[];
      for (final raw in list) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          final item = SearchResultItem.fromJson(decoded);
          if (item != null) parsed.add(item);
        }
      }
      if (mounted) {
        setState(() => _history = parsed);
      }
    } catch (_) {}
  }

  Future<void> _saveHistoryItem(SearchResultItem item) async {
    try {
      _history.removeWhere((h) => h.id == item.id || (h.title == item.title && h.kind == item.kind));
      _history.insert(0, item);
      if (_history.length > 8) {
        _history = _history.sublist(0, 8);
      }
      final prefs = await SharedPreferences.getInstance();
      final encoded = _history.map((h) => json.encode(h.toJson())).toList();
      await prefs.setStringList(_prefHistoryKey, encoded);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefHistoryKey);
      setState(() => _history.clear());
    } catch (_) {}
  }

  Future<void> _removeFromHistory(String id) async {
    try {
      setState(() => _history.removeWhere((h) => h.id == id));
      final prefs = await SharedPreferences.getInstance();
      final encoded = _history.map((h) => json.encode(h.toJson())).toList();
      await prefs.setStringList(_prefHistoryKey, encoded);
    } catch (_) {}
  }

  int _getChannelCountFor(ConnectedDeviceSummary dev) {
    final modelLower = dev.model.toLowerCase();
    if (modelLower.contains('4x') || modelLower.contains('4-ch') || modelLower.contains('4ch')) return 4;
    if (modelLower.contains('3x') || modelLower.contains('3-ch') || modelLower.contains('3ch')) return 3;
    if (modelLower.contains('2x') || modelLower.contains('2-ch') || modelLower.contains('2ch')) return 2;
    if (modelLower.contains('1x') || modelLower.contains('socket') || modelLower.contains('plug')) return 1;
    return 4;
  }

  void _buildIndex() {
    final list = <SearchResultItem>[];
    final ctrl = widget.homeController;

    // 1. Devices and Individual Channels
    for (final dev in ctrl.devices) {
      // Resolve product image once for this device (used for both device tile and channel tiles)
      final devImg = resolveBundledProductAsset(
        MockProductCatalogRepository.resolveCanonicalProductVariant(
          variantId: dev.model,
          deviceName: dev.name,
        ),
      ) ?? resolveBundledProductAsset(dev.name);

      list.add(
        SearchResultItem(
          id: 'dev_${dev.id}',
          title: dev.name,
          subtitle: '${dev.roomName} • ${dev.model} • ${dev.online ? "Online" : "Offline"}',
          kind: SearchItemKind.device,
          icon: dev.model.toLowerCase().contains('socket')
              ? Icons.power_rounded
              : Icons.toggle_on_rounded,
          iconColor: const Color(0xFF3B82F6),
          keywords: [
            dev.name.toLowerCase(),
            dev.roomName.toLowerCase(),
            dev.model.toLowerCase(),
            'switch',
            'socket',
            'relay',
            'device',
            'channel',
            'control',
          ],
          actionPayload: dev,
          imageUrl: devImg,
        ),
      );

      // Individual Channels for this device
      final chCount = _getChannelCountFor(dev);
      final customLabels = DeviceStorageService.getChannelLabels(dev.id);
      for (int i = 1; i <= chCount; i++) {
        final label = customLabels[i] ?? 'Channel $i (Switch $i)';
        final isOn = ctrl.getDeviceChannelPower(dev.id, i);
        list.add(
          SearchResultItem(
            id: 'ch_${dev.id}_$i',
            title: '${dev.name}: $label',
            subtitle: '${dev.roomName} • Currently ${isOn ? "ON" : "OFF"} • Tap to manage',
            kind: SearchItemKind.channel,
            icon: isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
            iconColor: isOn ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
            keywords: [
              label.toLowerCase(),
              'channel $i',
              'switch $i',
              'relay $i',
              dev.name.toLowerCase(),
              dev.roomName.toLowerCase(),
              isOn ? 'on' : 'off',
              'light',
              'fan',
              'power',
            ],
            actionPayload: {'device': dev, 'channel': i},
            imageUrl: devImg,
          ),
        );
      }
    }

    // 2. Rooms
    for (final room in ctrl.rooms) {
      list.add(
        SearchResultItem(
          id: 'room_${room.id}',
          title: room.name,
          subtitle: '${room.deviceCount} connected devices',
          kind: SearchItemKind.room,
          icon: Icons.meeting_room_rounded,
          iconColor: const Color(0xFF10B981),
          keywords: [room.name.toLowerCase(), 'room', 'space', 'zone', 'chamber', 'living', 'bed', 'kitchen'],
          actionPayload: RoomPreview(
            id: room.id,
            name: room.name,
            deviceCount: room.deviceCount,
            devicesOnCount: room.deviceCount,
            summary: '${room.deviceCount} connected devices',
            status: 'online',
            isAttention: false,
            freshness: TelemetryFreshness.current,
            iconKey: room.iconKey,
          ),
        ),
      );
    }

    // 3. Spaces
    for (final sp in ctrl.spaces) {
      final sId = sp['id']?.toString() ?? '';
      final sName = sp['name']?.toString() ?? 'Space';
      list.add(
        SearchResultItem(
          id: 'space_$sId',
          title: '$sName (Space)',
          subtitle: sId == ctrl.activeSpaceId ? 'Currently Active Space' : 'Tap to switch active space',
          kind: SearchItemKind.space,
          icon: sName.toLowerCase().contains('office')
              ? Icons.business_rounded
              : Icons.home_work_rounded,
          iconColor: const Color(0xFF8B5CF6),
          keywords: [sName.toLowerCase(), 'space', 'home', 'office', 'place', 'location', 'switch space'],
          actionPayload: sId,
        ),
      );
    }

    // 4. Daily Life Device Lifecycle & Relocation Features
    list.addAll([
      SearchResultItem(
        id: 'feat_add_device',
        title: 'Add New Device (Pairing / BLE)',
        subtitle: 'Commission a new smart switch, socket, or panel',
        kind: SearchItemKind.feature,
        icon: Icons.add_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        keywords: ['add', 'new', 'pair', 'bluetooth', 'ble', 'commission', 'setup', 'install', 'connect'],
        actionPayload: 'add_device',
      ),
      SearchResultItem(
        id: 'feat_change_room',
        title: 'Change Device Room / Location',
        subtitle: 'Reassign physical device location (e.g. from Bedroom to Hall or Kitchen)',
        kind: SearchItemKind.feature,
        icon: Icons.edit_location_alt_rounded,
        iconColor: const Color(0xFF3B82F6),
        keywords: ['change room', 'move room', 'location', 'reassign', 'relocate', 'bedroom', 'kitchen', 'hall'],
        actionPayload: 'change_room',
      ),
      SearchResultItem(
        id: 'feat_move_space',
        title: 'Move Device to Another Space',
        subtitle: 'Transfer device between spaces (e.g. use Home product in Office)',
        kind: SearchItemKind.feature,
        icon: Icons.swap_horiz_rounded,
        iconColor: const Color(0xFF8B5CF6),
        keywords: ['transfer space', 'move space', 'home to office', 'migrate', 'office', 'secondary space'],
        actionPayload: 'move_space',
      ),
      SearchResultItem(
        id: 'feat_change_wifi',
        title: 'Change Wi-Fi Network & Password',
        subtitle: 'Update router credentials on connected smart devices',
        kind: SearchItemKind.setting,
        icon: Icons.wifi_password_rounded,
        iconColor: const Color(0xFFF59E0B),
        keywords: ['wifi', 'wi-fi', 'password', 'ssid', 'router', 'network', 'change wifi', 'reconnect'],
        actionPayload: 'change_wifi',
      ),
      SearchResultItem(
        id: 'feat_reset_device',
        title: 'Forget & Factory Reset Device',
        subtitle: 'Erase NVS, reset to pairing mode for fresh setup from scratch',
        kind: SearchItemKind.setting,
        icon: Icons.restart_alt_rounded,
        iconColor: const Color(0xFFEF4444),
        keywords: ['forget', 'reset', 'factory', 'boot button', 'fresh setup', 're-pair', 'delete'],
        actionPayload: 'reset_device',
      ),
      SearchResultItem(
        id: 'feat_add_room',
        title: 'Add New Custom Room / Zone',
        subtitle: 'Create a new room in your active space',
        kind: SearchItemKind.feature,
        icon: Icons.add_home_rounded,
        iconColor: const Color(0xFF10B981),
        keywords: ['add room', 'new room', 'create room', 'zone', 'chamber', 'balcony', 'garage'],
        actionPayload: 'add_room',
      ),
      SearchResultItem(
        id: 'feat_add_space',
        title: 'Add New Space (Office / Farmhouse)',
        subtitle: 'Create a new isolated smart space partition',
        kind: SearchItemKind.feature,
        icon: Icons.add_business_rounded,
        iconColor: const Color(0xFF8B5CF6),
        keywords: ['add space', 'new space', 'create space', 'office', 'second home', 'shop'],
        actionPayload: 'add_space',
      ),
      SearchResultItem(
        id: 'feat_away_mode',
        title: 'Away Mode / Eco Mode',
        subtitle: 'Turn off all appliances and enable energy savings',
        kind: SearchItemKind.feature,
        icon: Icons.eco_rounded,
        iconColor: const Color(0xFF10B981),
        keywords: ['away', 'eco', 'leave', 'vacation', 'turn all off', 'save energy'],
        actionPayload: 'away_mode',
      ),
      SearchResultItem(
        id: 'feat_theme',
        title: 'Toggle Dark / Light Theme',
        subtitle: 'Switch between sleek dark mode and light theme',
        kind: SearchItemKind.setting,
        icon: Icons.dark_mode_rounded,
        iconColor: const Color(0xFF6366F1),
        keywords: ['theme', 'dark', 'light', 'mode', 'color', 'night', 'appearance'],
        actionPayload: 'theme',
      ),
      SearchResultItem(
        id: 'feat_lan_mode',
        title: 'Local LAN Mode (Direct Wi-Fi Control)',
        subtitle: 'Connect directly to your devices over local Wi-Fi without cloud',
        kind: SearchItemKind.feature,
        icon: Icons.wifi_tethering_rounded,
        iconColor: const Color(0xFFF59E0B),
        keywords: ['lan', 'local', 'offline', 'direct', 'wifi', 'subnet', 'mode', 'ping'],
        actionPayload: 'lan_mode',
      ),
      SearchResultItem(
        id: 'feat_routines',
        title: 'Routines & Automation',
        subtitle: 'Configure smart schedules, timers, and triggered scenes',
        kind: SearchItemKind.feature,
        icon: Icons.schedule_rounded,
        iconColor: const Color(0xFF6366F1),
        keywords: ['routine', 'schedule', 'timer', 'automation', 'scene', 'sunrise', 'sunset', 'night'],
        actionPayload: 'routines',
      ),
      SearchResultItem(
        id: 'feat_insights',
        title: 'Energy & Usage Insights',
        subtitle: 'Monitor energy consumption, active load, and daily charts',
        kind: SearchItemKind.feature,
        icon: Icons.insights_rounded,
        iconColor: const Color(0xFF06B6D4),
        keywords: ['energy', 'power', 'watt', 'kwh', 'usage', 'chart', 'insight', 'analytics', 'telemetry', 'voltage', 'current'],
        actionPayload: 'insights',
      ),
      SearchResultItem(
        id: 'feat_notifications',
        title: 'Notification Center & Alerts',
        subtitle: 'View security triggers, safety alerts, and system notices',
        kind: SearchItemKind.feature,
        icon: Icons.notifications_none_rounded,
        iconColor: const Color(0xFFEC4899),
        keywords: ['notification', 'alert', 'notice', 'warning', 'security', 'trip', 'safety', 'bell', 'messages'],
        actionPayload: 'notifications',
      ),
      SearchResultItem(
        id: 'feat_activity',
        title: 'Activity & Audit Log',
        subtitle: 'Review timeline of switch actuations, physical button presses, and cloud events',
        kind: SearchItemKind.feature,
        icon: Icons.history_rounded,
        iconColor: const Color(0xFF64748B),
        keywords: ['activity', 'log', 'history', 'timeline', 'events', 'audits', 'who', 'switched'],
        actionPayload: 'activity',
      ),
      SearchResultItem(
        id: 'feat_ota',
        title: 'Firmware Updates (OTA)',
        subtitle: 'Check for over-the-air firmware improvements for your hardware',
        kind: SearchItemKind.setting,
        icon: Icons.system_update_rounded,
        iconColor: const Color(0xFF3B82F6),
        keywords: ['ota', 'firmware', 'update', 'upgrade', 'esp32', 'version'],
        actionPayload: 'settings',
      ),
      SearchResultItem(
        id: 'feat_settings',
        title: 'App Settings & Preferences',
        subtitle: 'Manage theme, security, account profile, notifications & OTA updates',
        kind: SearchItemKind.setting,
        icon: Icons.settings_outlined,
        iconColor: const Color(0xFF3B82F6),
        keywords: ['settings', 'preferences', 'profile', 'account', 'theme', 'dark', 'light', 'ota', 'firmware', 'version', 'config'],
        actionPayload: 'settings',
      ),
    ]);

    _allIndex = list;
  }

  void _onSearchChanged() {
    final q = _queryController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredResults.clear());
      return;
    }

    final terms = q.split(' ').where((t) => t.isNotEmpty).toList();
    final matches = _allIndex.where((item) {
      final title = item.title.toLowerCase();
      final sub = item.subtitle.toLowerCase();
      return terms.every((term) =>
          title.contains(term) ||
          sub.contains(term) ||
          item.keywords.any((k) => k.contains(term)));
    }).toList();

    setState(() {
      _filteredResults = matches;
    });
  }

  void _handleSelect(SearchResultItem item) async {
    await _saveHistoryItem(item);
    if (!mounted) return;
    Navigator.of(context).pop();

    switch (item.kind) {
      case SearchItemKind.device:
        if (item.actionPayload is ConnectedDeviceSummary) {
          final dev = item.actionPayload as ConnectedDeviceSummary;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeviceControlPage(
                device: dev,
                homeController: widget.homeController,
              ),
            ),
          );
        }
        break;

      case SearchItemKind.channel:
        if (item.actionPayload is Map) {
          final payload = item.actionPayload as Map;
          final dev = payload['device'] as ConnectedDeviceSummary;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeviceControlPage(
                device: dev,
                homeController: widget.homeController,
              ),
            ),
          );
        }
        break;

      case SearchItemKind.room:
        if (item.actionPayload is RoomPreview) {
          widget.onOpenRoom(item.actionPayload as RoomPreview);
        }
        break;

      case SearchItemKind.space:
        if (item.actionPayload is String) {
          widget.homeController.selectSpace(item.actionPayload as String);
        }
        break;

      case SearchItemKind.feature:
      case SearchItemKind.setting:
        final action = item.actionPayload?.toString();
        if (action == 'add_device') widget.onOpenAddDevice();
        if (action == 'lan_mode') widget.homeController.switchToLanMode();
        if (action == 'routines') widget.onOpenRoutines();
        if (action == 'insights') widget.onOpenInsights();
        if (action == 'notifications') widget.onOpenNotifications();
        if (action == 'activity') widget.onOpenActivity();
        if (action == 'settings') widget.onOpenSettings();
        if (action == 'theme') {
          try {
            final themeCtrl = ThemeScope.of(context);
            themeCtrl.setThemeMode(themeCtrl.isDarkMode ? ThemeMode.light : ThemeMode.dark);
          } catch (_) {}
        }
        if (action == 'away_mode') {
          widget.homeController.toggleAwayMode(!widget.homeController.awayMode);
        }
        if (action == 'add_room') {
          _promptAddRoom();
        }
        if (action == 'add_space') {
          _promptAddSpace();
        }
        if (action == 'change_room' || action == 'move_space' || action == 'change_wifi' || action == 'reset_device') {
          final dev = widget.homeController.devices.isNotEmpty ? widget.homeController.devices.first : null;
          if (dev != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceControlPage(
                  device: dev,
                  homeController: widget.homeController,
                ),
              ),
            );
          } else {
            widget.onOpenAddDevice();
          }
        }
        break;
    }
  }

  Future<void> _promptAddRoom() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Balcony, Study Room'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.homeController.addCustomRoom(name);
    }
  }

  Future<void> _promptAddSpace() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Office, Workshop'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.homeController.createSpace(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isQuerying = _queryController.text.trim().isNotEmpty;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: tokens.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Search Header Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF4FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? tokens.bluePrimary
                              : tokens.borderSubtle,
                          width: _focusNode.hasFocus ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search switches, rooms, spaces, settings...',
                          hintStyle: TextStyle(
                            color: tokens.textTertiary,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: tokens.bluePrimary,
                            size: 22,
                          ),
                          suffixIcon: _queryController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  color: tokens.textSecondary,
                                  onPressed: () {
                                    _queryController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content: Results or History
            Flexible(
              child: isQuerying
                  ? _buildResultsList(tokens)
                  : _buildHistoryAndQuickLinks(tokens),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(EHThemeTokens tokens) {
    if (_filteredResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: tokens.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No matches found',
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching for "Switch 1", "Living Room", "Office", "Wi-Fi", or "Theme"',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _filteredResults.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: tokens.borderSubtle.withValues(alpha: 0.5)),
      itemBuilder: (context, index) {
        final item = _filteredResults[index];
        return _buildItemTile(item, tokens);
      },
    );
  }

  Widget _buildHistoryAndQuickLinks(EHThemeTokens tokens) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: tokens.bluePrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._history.map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (item.iconColor ?? tokens.bluePrimary).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: item.iconColor ?? tokens.bluePrimary,
                  size: 18,
                ),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: tokens.textTertiary,
                onPressed: () => _removeFromHistory(item.id),
              ),
              onTap: () => _handleSelect(item),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],

        Text(
          'Quick Shortcuts',
          style: TextStyle(
            color: tokens.textTertiary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildShortcutChip('Add Device', Icons.add_rounded, () {
              Navigator.of(context).pop();
              widget.onOpenAddDevice();
            }, tokens),
            _buildShortcutChip('Local LAN Mode', Icons.wifi_tethering_rounded, () {
              Navigator.of(context).pop();
              widget.homeController.switchToLanMode();
            }, tokens),
            _buildShortcutChip('Routines', Icons.schedule_rounded, () {
              Navigator.of(context).pop();
              widget.onOpenRoutines();
            }, tokens),
            _buildShortcutChip('Energy Insights', Icons.insights_rounded, () {
              Navigator.of(context).pop();
              widget.onOpenInsights();
            }, tokens),
            _buildShortcutChip('Notifications', Icons.notifications_none_rounded, () {
              Navigator.of(context).pop();
              widget.onOpenNotifications();
            }, tokens),
            _buildShortcutChip('Settings', Icons.settings_outlined, () {
              Navigator.of(context).pop();
              widget.onOpenSettings();
            }, tokens),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutChip(String label, IconData icon, VoidCallback onTap, EHThemeTokens tokens) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.bluePrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(SearchResultItem item, EHThemeTokens tokens) {
    return InkWell(
      onTap: () => _handleSelect(item),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(item.kind == SearchItemKind.device || item.kind == SearchItemKind.channel ? 4 : 10),
              decoration: BoxDecoration(
                color: (item.iconColor ?? tokens.bluePrimary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: (item.kind == SearchItemKind.device || item.kind == SearchItemKind.channel)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ProductImageWidget(
                        imageUrl: item.imageUrl,
                        size: 28,
                        fallbackIcon: item.icon,
                        placeholderColor: Colors.transparent,
                      ),
                    )
                  : Icon(
                      item.icon,
                      color: item.iconColor ?? tokens.bluePrimary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: tokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
