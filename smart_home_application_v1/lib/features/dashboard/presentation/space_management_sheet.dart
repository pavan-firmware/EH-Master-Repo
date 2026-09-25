import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpaceManagementSheet extends StatefulWidget {
  const SpaceManagementSheet({
    super.key,
    required this.spaces,
    required this.activeSpaceId,
    required this.onSelectSpace,
    required this.onCreateSpace,
    required this.onUpdateSpace,
    required this.onDeleteSpace,
  });

  final List<Map<String, dynamic>> spaces;
  final String activeSpaceId;
  final ValueChanged<String> onSelectSpace;
  final void Function(String name, String icon) onCreateSpace;
  final void Function(String id, String name, String icon) onUpdateSpace;
  final ValueChanged<String> onDeleteSpace;

  @override
  State<SpaceManagementSheet> createState() => _SpaceManagementSheetState();
}

class _SpaceManagementSheetState extends State<SpaceManagementSheet> {
  bool _isCreating = false;
  String? _editingSpaceId;
  final TextEditingController _nameController = TextEditingController();
  String _selectedIcon = 'home';
  late List<Map<String, dynamic>> _spacesList;
  late String _currentActiveSpaceId;

  @override
  void initState() {
    super.initState();
    _currentActiveSpaceId = widget.activeSpaceId;
    _spacesList = widget.spaces.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  final List<Map<String, dynamic>> _iconOptions = const [
    {'key': 'home', 'icon': Icons.home_rounded, 'label': 'Home'},
    {'key': 'business', 'icon': Icons.business_rounded, 'label': 'Office'},
    {'key': 'storefront', 'icon': Icons.storefront_rounded, 'label': 'Shop'},
    {'key': 'cottage', 'icon': Icons.cottage_rounded, 'label': 'Villa / 2nd'},
    {'key': 'warehouse', 'icon': Icons.warehouse_rounded, 'label': 'Warehouse'},
    {'key': 'apartment', 'icon': Icons.apartment_rounded, 'label': 'Flat'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _resolveIcon(String key) {
    return switch (key) {
      'business' => Icons.business_rounded,
      'storefront' => Icons.storefront_rounded,
      'cottage' => Icons.cottage_rounded,
      'warehouse' => Icons.warehouse_rounded,
      'apartment' => Icons.apartment_rounded,
      _ => Icons.home_rounded,
    };
  }

  void _startCreate() {
    setState(() {
      _isCreating = true;
      _editingSpaceId = null;
      _nameController.clear();
      _selectedIcon = 'business';
    });
  }

  void _startEdit(Map<String, dynamic> space) {
    setState(() {
      _isCreating = false;
      _editingSpaceId = space['id'] as String;
      _nameController.text = (space['name'] as String? ?? '').trim();
      _selectedIcon = (space['icon'] as String? ?? 'home');
    });
  }

  void _cancelForm() {
    setState(() {
      _isCreating = false;
      _editingSpaceId = null;
      _nameController.clear();
    });
  }

  void _submitForm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_isCreating) {
      widget.onCreateSpace(name, _selectedIcon);
      Navigator.of(context).pop();
    } else if (_editingSpaceId != null) {
      widget.onUpdateSpace(_editingSpaceId!, name, _selectedIcon);
      final idx = _spacesList.indexWhere((s) => s['id'] == _editingSpaceId);
      if (idx >= 0) {
        _spacesList[idx]['name'] = name;
        _spacesList[idx]['icon'] = _selectedIcon;
      }
      setState(() {
        _editingSpaceId = null;
        _nameController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: tokens.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
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
                      'Manage Spaces',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Switch, customize or add new places',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (!_isCreating && _editingSpaceId == null)
                  FilledButton.icon(
                    onPressed: _startCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.bluePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Inline Create/Edit Form
            if (_isCreating || _editingSpaceId != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.bluePrimary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCreating ? 'New Space Details' : 'Edit Space',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'e.g. Office, Downtown Shop, Warehouse',
                        hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: tokens.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Choose Icon',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _iconOptions.map((opt) {
                        final key = opt['key'] as String;
                        final icon = opt['icon'] as IconData;
                        final label = opt['label'] as String;
                        final isSel = _selectedIcon == key;
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? tokens.bluePrimary : tokens.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? tokens.bluePrimary : tokens.borderSubtle,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: isSel ? Colors.white : tokens.textPrimary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSel ? Colors.white : tokens.textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _cancelForm,
                          child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submitForm,
                          style: FilledButton.styleFrom(backgroundColor: tokens.bluePrimary),
                          child: Text(_isCreating ? 'Save Space' : 'Update Space'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Spaces List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _spacesList.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sp = _spacesList[index];
                final spId = sp['id'] as String;
                final spName = sp['name'] as String;
                final spIconKey = sp['icon'] as String? ?? 'home';
                final isActive = spId == _currentActiveSpaceId;
                final isDefault = index == 0 || spId == 'home_default';

                return InkWell(
                  onTap: () {
                    setState(() => _currentActiveSpaceId = spId);
                    widget.onSelectSpace(spId);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? tokens.bluePrimary.withValues(alpha: 0.12)
                          : tokens.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? tokens.bluePrimary
                            : tokens.borderSubtle,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive
                                ? tokens.bluePrimary.withValues(alpha: 0.2)
                                : tokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _resolveIcon(spIconKey),
                            color: isActive ? tokens.bluePrimary : tokens.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    spName,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tokens.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Primary',
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isActive ? 'Currently Active' : 'Tap to switch',
                                style: TextStyle(
                                  color: isActive ? tokens.bluePrimary : tokens.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded, color: tokens.bluePrimary, size: 22)
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: tokens.textSecondary, size: 18),
                                onPressed: () => _startEdit(sp),
                                tooltip: 'Edit',
                              ),
                              if (!isDefault)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: tokens.surfaceCard,
                                        title: Text('Delete $spName?', style: TextStyle(color: tokens.textPrimary)),
                                        content: Text(
                                          'Are you sure you want to remove this space? All associated local devices and settings for $spName will be deleted.',
                                          style: TextStyle(color: tokens.textSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(),
                                            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                             onPressed: () {
                                                Navigator.of(ctx).pop();
                                                widget.onDeleteSpace(spId);
                                                setState(() {
                                                  _spacesList.removeWhere((s) => s['id'] == spId);
                                                  if (_currentActiveSpaceId == spId && _spacesList.isNotEmpty) {
                                                    _currentActiveSpaceId = _spacesList.first['id'] as String;
                                                  }
                                                });
                                              },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  tooltip: 'Delete',
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
