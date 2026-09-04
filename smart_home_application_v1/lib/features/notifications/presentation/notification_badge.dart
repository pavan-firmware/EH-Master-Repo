import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.count,
    this.onTap,
    this.icon = Icons.notifications_outlined,
    this.size = 24,
  });

  final int count;
  final VoidCallback? onTap;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final iconWidget = Icon(icon, size: size, color: tokens.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
