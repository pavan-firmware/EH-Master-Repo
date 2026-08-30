import 'package:flutter/material.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/theme/app_theme.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    required this.repository,
    this.homeId,
  });

  final NotificationRepository repository;
  final String? homeId;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  NotificationCategory _selectedCategory = NotificationCategory.all;
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

  void _onCategorySelected(NotificationCategory category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _loadNotifications();
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.deviceOffline:
        return Icons.cloud_off_rounded;
      case NotificationType.deviceRecovered:
        return Icons.cloud_done_rounded;
      case NotificationType.commandFailed:
        return Icons.error_outline_rounded;
      case NotificationType.automationFailed:
      case NotificationType.sceneFailed:
      case NotificationType.scheduleFailed:
        return Icons.smart_toy_outlined;
      case NotificationType.otaAvailable:
      case NotificationType.otaFailed:
        return Icons.system_update_rounded;
      case NotificationType.securityEvent:
        return Icons.security_rounded;
      case NotificationType.systemEvent:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForPriority(NotificationPriority priority, BuildContext context) {
    final tokens = context.ehColors;
    switch (priority) {
      case NotificationPriority.critical:
        return Colors.redAccent.shade700;
      case NotificationPriority.high:
        return Colors.orange.shade800;
      case NotificationPriority.normal:
        return tokens.bluePrimary;
      case NotificationPriority.low:
        return tokens.textSecondary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
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
          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: NotificationCategory.values.map((cat) {
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
              }).toList(),
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
                                final iconColor = _getColorForPriority(item.priority, context);

                                return InkWell(
                                  onTap: () => _markAsRead(item),
                                  child: Container(
                                    color: item.isRead
                                        ? Colors.transparent
                                        : tokens.bluePrimary.withAlpha(10),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Icon avatar
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: iconColor.withAlpha(25),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getIconForType(item.type),
                                            color: iconColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Notification text & details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        color: tokens.textPrimary,
                                                        fontWeight: item.isRead
                                                            ? FontWeight.w600
                                                            : FontWeight.w800,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimestamp(item.createdAt),
                                                    style: TextStyle(
                                                      color: tokens.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.body,
                                                style: TextStyle(
                                                  color: tokens.textSecondary,
                                                  fontSize: 13,
                                                  height: 1.3,
                                                ),
                                              ),
                                              if (item.isCritical) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'CRITICAL SAFETY ALERT',
                                                    style: TextStyle(
                                                      color: Colors.red.shade900,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Unread blue dot indicator
                                        if (!item.isRead) ...[
                                          const SizedBox(width: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: tokens.bluePrimary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
