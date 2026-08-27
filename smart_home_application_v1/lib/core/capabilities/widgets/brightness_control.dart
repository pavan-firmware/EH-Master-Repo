import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Metadata-driven capability primitive for Brightness Dimmer Control.
/// Supports dynamic min, max, and step configuration.
class BrightnessControl extends StatelessWidget {
  const BrightnessControl({
    super.key,
    required this.level,
    required this.onLevelChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.label = 'Brightness',
  });

  final int level;
  final ValueChanged<int> onLevelChanged;
  final int min;
  final int max;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final clampedLevel = level.clamp(min, max);
    final divisions = ((max - min) / step).round().clamp(1, 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.isDark ? tokens.surfaceElevated : tokens.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_rounded,
                color: clampedLevel > min ? tokens.gold : tokens.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$clampedLevel%',
                style: TextStyle(
                  color: tokens.bluePrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: tokens.gold,
              inactiveTrackColor: tokens.isDark
                  ? tokens.borderControl
                  : const Color(0xFFE0E4EC),
              thumbColor: tokens.gold,
              overlayColor: tokens.gold.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: clampedLevel.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: divisions,
              onChanged: (v) => onLevelChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
