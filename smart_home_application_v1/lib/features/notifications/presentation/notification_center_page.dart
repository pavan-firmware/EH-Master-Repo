import 'package:flutter/material.dart';
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
  NotificationCategory _selectedCategory = NotificationCategory.all;
  NotificationSeverity? _selectedSeverity;
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;

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
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _notifications = _notifications.map((n) => n.copyWith(readAt: now)).toList();
          _unreadCount = 0;
        });
      }
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
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
                      selectedColor: tokens.bluePrimary.withAlpha(40),
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
                      selectedColor: sColor.withAlpha(40),
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

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
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
                    : _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 56,
                                  color: tokens.textSecondary.withAlpha(120),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                              itemBuilder: (context, index) {
                                final item = _notifications[index];
                                return NotificationCard(
                                  item: item,
                                  onTap: () => _markAsRead(item),
                                  onAction: (it) => _handleNotificationAction(it),
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
