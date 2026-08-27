import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Computes carousel dot count for a [PageView] with partial viewport cards.
int carouselIndicatorCount(int itemCount, double viewportFraction) {
  if (itemCount <= 0) return 0;
  if (itemCount == 1) return 1;
  final visibleSlots = (1 / viewportFraction).ceil();
  return math.max(1, itemCount - visibleSlots + 1);
}

/// Maps a [PageView] page index to the active dot for partial-viewport carousels.
int carouselActiveDotIndex(
  int pageIndex,
  int itemCount,
  double viewportFraction,
) {
  final dots = carouselIndicatorCount(itemCount, viewportFraction);
  if (dots <= 1 || itemCount <= 1) return 0;
  return ((pageIndex / (itemCount - 1)) * (dots - 1)).round().clamp(
    0,
    dots - 1,
  );
}

class CarouselDotIndicator extends StatelessWidget {
  const CarouselDotIndicator({
    super.key,
    required this.itemCount,
    required this.pageIndex,
    required this.viewportFraction,
    this.activeColor,
    this.inactiveColor,
  });

  final int itemCount;
  final int pageIndex;
  final double viewportFraction;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final count = carouselIndicatorCount(itemCount, viewportFraction);
    if (count <= 1) return const SizedBox.shrink();
    final active = carouselActiveDotIndex(
      pageIndex,
      itemCount,
      viewportFraction,
    );
    final tokens = context.ehColors;
    final resolvedActive = activeColor ?? tokens.bluePrimary;
    final resolvedInactive =
        inactiveColor ??
        (tokens.isDark ? tokens.borderControl : const Color(0xFFD7DCE5));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == active ? 9 : 8,
          height: index == active ? 9 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: index == active ? resolvedActive : resolvedInactive,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Disables accidental text selection while scrolling tab screens.
class ScrollFriendlyPage extends StatelessWidget {
  const ScrollFriendlyPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SelectionContainer.disabled(child: child);
}
