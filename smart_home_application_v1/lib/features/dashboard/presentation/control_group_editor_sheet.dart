import 'package:flutter/material.dart';
import '../../../core/models/connection_models.dart';
import '../../../core/models/home_dashboard_models.dart';
import '../../../core/services/device_storage_service.dart';
import '../../../core/theme/app_theme.dart';

class ControlGroupEditorSheet extends StatefulWidget {
  const ControlGroupEditorSheet({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.devices,
    this.selectedSingleControlIds = const [],
    this.existingGroups = const [],
    this.onSaveSingleControls,
    this.onCreateGroup,
    this.onUpdateGroup,
    this.onDeleteGroup,
    // Backward compatibility for single group edit dialog
    this.existingGroup,
    this.onSave,
    this.onDelete,
  });

  final String spaceId;
  final String spaceName;
  final List<ConnectedDeviceSummary> devices;
  final List<String> selectedSingleControlIds;
  final List<GroupControlItem> existingGroups;
  final ValueChanged<List<String>>? onSaveSingleControls;
  final void Function(String label, QuickControlKind kind, List<String> targetIds)? onCreateGroup;
  final ValueChanged<GroupControlItem>? onUpdateGroup;
  final ValueChanged<String>? onDeleteGroup;

  final GroupControlItem? existingGroup;
  final void Function(String label, QuickControlKind kind, List<String> targetIds)? onSave;
  final VoidCallback? onDelete;

  @override
  State<ControlGroupEditorSheet> createState() => _ControlGroupEditorSheetState();
}

class _ControlGroupEditorSheetState extends State<ControlGroupEditorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Set<String> _selectedSingleIds;
  late List<GroupControlItem> _groupsList;
  String _singleFilterQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedSingleIds = Set<String>.from(widget.selectedSingleControlIds);
    _groupsList = List<GroupControlItem>.from(widget.existingGroups);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildAllChannels() {
    final List<Map<String, dynamic>> allChannels = [];
    for (final dev in widget.devices) {
      final customLabels = DeviceStorageService.getChannelLabels(dev.id);
      final modelStr = dev.model.toLowerCase();
      final nameStr = dev.name.toLowerCase();
      final isSocket = nameStr.contains('socket') || modelStr.contains('socket');
      final is4X = nameStr.contains('4x') || modelStr.contains('4x');
      final is3X = nameStr.contains('3x') || modelStr.contains('3x');
      final is2X = nameStr.contains('2x') || modelStr.contains('2x');
      final channelCount = is4X ? 4 : (is3X ? 3 : (is2X ? 2 : 1));

      for (int ch = 1; ch <= channelCount; ch++) {
        final id = '${dev.id}_ch$ch';
        final customLabel = customLabels[ch];
        final prefix = isSocket ? 'Socket' : 'Switch';
        final chName = (customLabel != null && customLabel.trim().isNotEmpty)
            ? customLabel.trim()
            : '${dev.name} $prefix $ch';

        allChannels.add({
          'id': id,
          'deviceId': dev.id,
          'deviceName': dev.name,
          'channelIndex': ch,
          'roomName': dev.roomName.isEmpty ? 'Room' : dev.roomName,
          'title': chName,
        });
      }
    }
    return allChannels;
  }

  void _openGroupCreatorOrEditor({GroupControlItem? groupToEdit}) {
    final allChannels = _buildAllChannels();
    final labelCtrl = TextEditingController(text: groupToEdit?.label ?? '');
    QuickControlKind selectedKind = groupToEdit?.kind ?? QuickControlKind.switchControl;
    final Set<String> selectedTargets = Set<String>.from(groupToEdit?.targetControlIds ?? []);
    String filterQ = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final tokens = context.ehColors;
          final filtered = allChannels.where((c) {
            if (filterQ.isEmpty) return true;
            final q = filterQ.toLowerCase();
            return (c['title'] as String).toLowerCase().contains(q) ||
                (c['roomName'] as String).toLowerCase().contains(q) ||
                (c['deviceName'] as String).toLowerCase().contains(q);
          }).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: tokens.isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: tokens.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      groupToEdit == null ? 'Create Control Group' : 'Edit Group',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                      onPressed: () => Navigator.of(modalCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    labelStyle: TextStyle(color: tokens.textSecondary),
                    hintText: 'e.g. All Lights, Hall Fans, Night Switches',
                    hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Group Type',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildKindChip(QuickControlKind.switchControl, 'Switch', Icons.toggle_on_rounded, selectedKind, (k) => setSheetState(() => selectedKind = k), tokens),
                    const SizedBox(width: 8),
                    _buildKindChip(QuickControlKind.light, 'Light', Icons.lightbulb_outline_rounded, selectedKind, (k) => setSheetState(() => selectedKind = k), tokens),
                    const SizedBox(width: 8),
                    _buildKindChip(QuickControlKind.fan, 'Fan', Icons.mode_fan_off_rounded, selectedKind, (k) => setSheetState(() => selectedKind = k), tokens),
                    const SizedBox(width: 8),
                    _buildKindChip(QuickControlKind.socket, 'Socket', Icons.power_outlined, selectedKind, (k) => setSheetState(() => selectedKind = k), tokens),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setSheetState(() => filterQ = v),
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: tokens.textSecondary, size: 18),
                    hintText: 'Filter channels...',
                    hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select Target Channels (${selectedTargets.length} selected):',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: allChannels.isEmpty
                      ? Center(
                          child: Text(
                            'No devices in this space yet.',
                            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final c = filtered[idx];
                            final id = c['id'] as String;
                            final isSel = selectedTargets.contains(id);
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (isSel) {
                                    selectedTargets.remove(id);
                                  } else {
                                    selectedTargets.add(id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? tokens.bluePrimary.withValues(alpha: 0.12) : tokens.surfaceCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? tokens.bluePrimary : tokens.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isSel ? tokens.bluePrimary : tokens.textSecondary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c['title'] as String,
                                        style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      c['roomName'] as String,
                                      style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () {
                      final label = labelCtrl.text.trim();
                      if (label.isEmpty || selectedTargets.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a group name and choose at least one channel.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      if (groupToEdit != null) {
                        final updated = groupToEdit.copyWith(
                          label: label,
                          kind: selectedKind,
                          targetControlIds: selectedTargets.toList(),
                        );
                        widget.onUpdateGroup?.call(updated);
                        final idx = _groupsList.indexWhere((g) => g.id == updated.id);
                        if (idx >= 0) {
                          _groupsList[idx] = updated;
                        }
                      } else {
                        final newGroup = GroupControlItem(
                          id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
                          spaceId: widget.spaceId,
                          label: label,
                          kind: selectedKind,
                          targetControlIds: selectedTargets.toList(),
                          isEnabled: true,
                          isOn: false,
                        );
                        _groupsList.add(newGroup);
                        widget.onCreateGroup?.call(label, selectedKind, selectedTargets.toList());
                        widget.onSave?.call(label, selectedKind, selectedTargets.toList());
                      }
                      Navigator.of(modalCtx).pop();
                      setState(() {});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      groupToEdit == null ? 'Create Group' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildKindChip(
    QuickControlKind kind,
    String label,
    IconData icon,
    QuickControlKind selectedKind,
    ValueChanged<QuickControlKind> onSelect,
    dynamic tokens,
  ) {
    final isSel = selectedKind == kind;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(kind),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? tokens.bluePrimary : tokens.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? tokens.bluePrimary : tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.white : tokens.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? Colors.white : tokens.textPrimary,
                ),
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
    final allChannels = _buildAllChannels();

    final filteredChannels = allChannels.where((c) {
      if (_singleFilterQuery.isEmpty) return true;
      final q = _singleFilterQuery.toLowerCase();
      return (c['title'] as String).toLowerCase().contains(q) ||
          (c['roomName'] as String).toLowerCase().contains(q) ||
          (c['deviceName'] as String).toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: tokens.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Controls Manager',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage controls in ${widget.spaceName}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar: Single Controls vs Group Controls
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: tokens.bluePrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: tokens.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Single Controls (${_selectedSingleIds.length})'),
                Tab(text: 'Group Controls (${_groupsList.length})'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Single Controls Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _singleFilterQuery = val),
                            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded, color: tokens.textSecondary, size: 18),
                              hintText: 'Filter channels by name or room...',
                              hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.5)),
                              filled: true,
                              fillColor: tokens.surfaceCard,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedSingleIds.length == allChannels.length) {
                                _selectedSingleIds.clear();
                              } else {
                                _selectedSingleIds.addAll(allChannels.map((c) => c['id'] as String));
                              }
                            });
                          },
                          child: Text(
                            _selectedSingleIds.length == allChannels.length ? 'Clear' : 'Select All',
                            style: TextStyle(color: tokens.bluePrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: allChannels.isEmpty
                          ? Center(
                              child: Text(
                                'No devices configured in ${widget.spaceName} yet.\nCommission a device first.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredChannels.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final c = filteredChannels[index];
                                final id = c['id'] as String;
                                final isSel = _selectedSingleIds.contains(id);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSel) {
                                        _selectedSingleIds.remove(id);
                                      } else {
                                        _selectedSingleIds.add(id);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? tokens.bluePrimary.withValues(alpha: 0.12)
                                          : tokens.surfaceCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSel ? tokens.bluePrimary : tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          color: isSel ? tokens.bluePrimary : tokens.textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['title'] as String,
                                                style: TextStyle(
                                                  color: tokens.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '${c['deviceName']} • ${c['roomName']}',
                                                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: () {
                          widget.onSaveSingleControls?.call(_selectedSingleIds.toList());
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved ${_selectedSingleIds.length} quick controls for ${widget.spaceName}.'),
                              backgroundColor: tokens.bluePrimary,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.bluePrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Save Single Controls (${_selectedSingleIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Group Controls List & CRUD
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Custom Groups (${_groupsList.length})',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openGroupCreatorOrEditor(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('New Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.bluePrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _groupsList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.all_inclusive_rounded, size: 40, color: tokens.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No control groups created yet in ${widget.spaceName}.',
                                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap "+ New Group" above to toggle multiple devices together.',
                                    style: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _groupsList.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final grp = _groupsList[idx];
                                final iconData = grp.kind == QuickControlKind.light
                                    ? Icons.lightbulb_outline_rounded
                                    : grp.kind == QuickControlKind.fan
                                        ? Icons.air_rounded
                                        : grp.kind == QuickControlKind.socket
                                            ? Icons.power_rounded
                                            : Icons.toggle_on_rounded;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: tokens.bluePrimary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(iconData, color: tokens.bluePrimary, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              grp.label,
                                              style: TextStyle(
                                                color: tokens.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${grp.targetControlIds.length} target channels',
                                              style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit_rounded, color: tokens.bluePrimary, size: 20),
                                        onPressed: () => _openGroupCreatorOrEditor(groupToEdit: grp),
                                        tooltip: 'Edit Group',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          showDialog<void>(
                                            context: context,
                                            builder: (dialogCtx) => AlertDialog(
                                              title: const Text('Delete Group'),
                                              content: Text('Are you sure you want to delete "${grp.label}"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    widget.onDeleteGroup?.call(grp.id);
                                                    widget.onDelete?.call();
                                                    Navigator.of(dialogCtx).pop();
                                                    setState(() {
                                                      _groupsList.removeWhere((g) => g.id == grp.id);
                                                    });
                                                  },
                                                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        tooltip: 'Delete Group',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
