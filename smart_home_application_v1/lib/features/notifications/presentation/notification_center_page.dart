import 'package:flutter/material.dart';
import '../../../app/home_controller.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'notification_card.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    required this.repository,
    this.homeId,
    this.onNavigateTarget,
  });

  final NotificationRepository repository;
  final String? homeId;
  final void Function(String? actionType, String? actionTarget)? onNavigateTarget;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  NotificationCategory _selectedCategory = NotificationCategory.all;
  NotificationSeverity? _selectedSeverity;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant NotificationCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository || oldWidget.homeId != widget.homeId) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.repository.getNotifications(
        homeId: widget.homeId,
        category: _selectedCategory,
        severity: _selectedSeverity,
      );
      final count = await widget.repository.getUnreadCount(homeId: widget.homeId);

      if (mounted) {
        setState(() {
          _notifications = list;
          _unreadCount = count;
          _isLoading = false;
          _selectedIds.removeWhere((id) => !_notifications.any((n) => n.id == id));
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await widget.repository.markAsRead(item.id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == item.id);
          if (idx >= 0) {
            _notifications[idx] = item.copyWith(readAt: DateTime.now());
          }
          if (_unreadCount > 0) _unreadCount--;
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await widget.repository.markAllAsRead(homeId: widget.homeId);
      HomeController.instance?.clearAllAlerts();
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _notifications = _notifications.map((n) => n.copyWith(readAt: now)).toList();
          _unreadCount = 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissNotification(NotificationItem item) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
      _selectedIds.remove(item.id);
      if (_unreadCount > 0 && !item.isRead) _unreadCount--;
    });
    await widget.repository.deleteNotification(item.id);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final idsToDelete = _selectedIds.toList();
    setState(() {
      _notifications.removeWhere((n) => idsToDelete.contains(n.id));
      _selectedIds.clear();
      _isSelectionMode = false;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    });
    await widget.repository.deleteNotifications(idsToDelete);
  }

  Future<void> _confirmClearAll() async {
    if (_notifications.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will permanently remove all notifications and routine execution logs from your device and cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _notifications.clear();
        _selectedIds.clear();
        _isSelectionMode = false;
        _unreadCount = 0;
      });
      await widget.repository.clearAllNotifications(homeId: widget.homeId);
    }
  }

  Future<void> _handleNotificationAction(NotificationItem item) async {
    if (item.actionType == null) return;

    try {
      await widget.repository.performAction(item.id, item.actionType!);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == item.id);
          if (idx >= 0) {
            _notifications[idx] = item.copyWith(
              readAt: item.readAt ?? DateTime.now(),
              actionState: 'ACTIONED',
            );
          }
        });
      }
    } catch (_) {}

    if (widget.onNavigateTarget != null) {
      widget.onNavigateTarget!(item.actionType, item.actionTarget);
    }
  }

  void _onCategorySelected(NotificationCategory category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _loadNotifications();
  }

  void _onSeveritySelected(NotificationSeverity? severity) {
    if (_selectedSeverity == severity) {
      setState(() {
        _selectedSeverity = null;
      });
    } else {
      setState(() {
        _selectedSeverity = severity;
      });
    }
    _loadNotifications();
  }

  Color _severityColor(NotificationSeverity sev) {
    switch (sev) {
      case NotificationSeverity.critical:
        return const Color(0xFFEF4444);
      case NotificationSeverity.error:
        return const Color(0xFFF97316);
      case NotificationSeverity.warning:
        return const Color(0xFFF59E0B);
      case NotificationSeverity.notice:
        return const Color(0xFF3B82F6);
      case NotificationSeverity.info:
        return const Color(0xFF6B7280);
    }
  }

  List<NotificationItem> get _filteredNotifications {
    return _notifications.where((n) {
      if (_selectedCategory != NotificationCategory.all && n.category != _selectedCategory) {
        return false;
      }
      if (_selectedSeverity != null && n.severity != _selectedSeverity) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final currentList = _filteredNotifications;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: tokens.textPrimary),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} selected' : 'Notifications',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: _selectedIds.length == currentList.length ? 'Deselect all' : 'Select all',
              icon: Icon(
                _selectedIds.length == currentList.length
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                color: tokens.textPrimary,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == currentList.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(currentList.map((e) => e.id));
                  }
                });
              },
            ),
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
          ] else ...[
            if (_unreadCount > 0)
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            if (_notifications.isNotEmpty) ...[
              IconButton(
                tooltip: 'Select items',
                icon: Icon(Icons.checklist_rounded, color: tokens.textPrimary),
                onPressed: () => setState(() => _isSelectionMode = true),
              ),
              IconButton(
                tooltip: 'Clear all',
                icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                onPressed: _confirmClearAll,
              ),
            ],
          ],
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: (_isSelectionMode && _selectedIds.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} item(s) selected',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ...NotificationCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.label),
                      selected: isSelected,
                      onSelected: (_) => _onCategorySelected(cat),
                      selectedColor: tokens.bluePrimary.withValues(alpha: 0.2),
                      checkmarkColor: tokens.bluePrimary,
                      labelStyle: TextStyle(
                        color: isSelected ? tokens.bluePrimary : tokens.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                ...NotificationSeverity.values.map((sev) {
                  final isSelected = _selectedSeverity == sev;
                  final sColor = _severityColor(sev);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(sev.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => _onSeveritySelected(sev),
                      selectedColor: sColor.withValues(alpha: 0.2),
                      checkmarkColor: sColor,
                      labelStyle: TextStyle(
                        color: isSelected ? sColor : tokens.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: _loadNotifications,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : currentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 56,
                                  color: tokens.textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "You're all caught up with your home alerts.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              itemCount: currentList.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final item = currentList[index];
                                final isSelected = _selectedIds.contains(item.id);

                                final card = NotificationCard(
                                  item: item,
                                  onTap: _isSelectionMode
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedIds.remove(item.id);
                                            } else {
                                              _selectedIds.add(item.id);
                                            }
                                          });
                                        }
                                      : () => _markAsRead(item),
                                  onAction: (it) => _handleNotificationAction(it),
                                );

                                if (_isSelectionMode) {
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedIds.remove(item.id);
                                        } else {
                                          _selectedIds.add(item.id);
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: tokens.bluePrimary,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedIds.add(item.id);
                                              } else {
                                                _selectedIds.remove(item.id);
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(child: card),
                                      ],
                                    ),
                                  );
                                }

                                return Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                  ),
                                  onDismissed: (_) => _dismissNotification(item),
                                  child: card,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
