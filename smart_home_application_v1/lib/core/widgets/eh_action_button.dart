import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standardized action & selection control adhering to EH Home design system.
///
/// Handles selected, unselected, and loading states consistently across
/// both Light and Dark themes.
class EHSelectionButton extends StatelessWidget {
  const EHSelectionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    this.isLoading = false,
    this.height = 46.0,
    this.selectedBackgroundColor,
    this.selectedForegroundColor,
    this.unselectedBackgroundColor,
    this.unselectedForegroundColor,
    this.unselectedBorderColor,
    this.borderRadius = 14.0,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Color? selectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? unselectedBackgroundColor;
  final Color? unselectedForegroundColor;
  final Color? unselectedBorderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final bg = isSelected
        ? (selectedBackgroundColor ?? tokens.bluePrimary)
        : (unselectedBackgroundColor ?? (tokens.isDark ? tokens.surfaceElevated : tokens.surfaceCard));

    final fg = isSelected
        ? (selectedForegroundColor ?? tokens.buttonText)
        : (unselectedForegroundColor ?? (tokens.isDark ? tokens.textPrimary : tokens.bluePrimary));

    final border = isSelected
        ? BorderSide.none
        : BorderSide(
            color: unselectedBorderColor ?? tokens.borderControl,
            width: 1.2,
          );

    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border,
        ),
        elevation: isSelected ? 1.0 : 0.0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (isLoading || onPressed == null) ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
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
