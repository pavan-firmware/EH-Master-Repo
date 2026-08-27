import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Metadata-driven capability primitive for Multi-step Fan Speed Control.
/// Supports dynamic minSpeed, maxSpeed, and step configuration.
class FanSpeedControl extends StatelessWidget {
  const FanSpeedControl({
    super.key,
    required this.speed,
    required this.onSpeedChanged,
    this.minSpeed = 0,
    this.maxSpeed = 5,
    this.step = 1,
    this.label = 'Fan Speed',
  });

  final int speed;
  final ValueChanged<int> onSpeedChanged;
  final int minSpeed;
  final int maxSpeed;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final isRunning = speed > 0;

    // Generate supported speed steps from minSpeed..maxSpeed
    final steps = <int>[];
    for (int i = minSpeed; i <= maxSpeed; i += step) {
      steps.add(i);
    }
    if (!steps.contains(0) && minSpeed > 0) {
      // Prepend 0 for Off if not explicitly present
      steps.insert(0, 0);
    }

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
                Icons.mode_fan_off_rounded,
                color: isRunning ? tokens.bluePrimary : tokens.textSecondary,
                size: 22,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isRunning
                      ? (tokens.isDark
                            ? tokens.blueSelectedBg
                            : const Color(0xFFEAF1FF))
                      : (tokens.isDark
                            ? tokens.borderControl
                            : const Color(0xFFE0E4EC)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRunning ? 'Speed $speed' : 'Off',
                  style: TextStyle(
                    color: isRunning
                        ? tokens.bluePrimary
                        : tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: steps.map((level) {
              final isSelected = speed == level;
              final buttonLabel = level == 0 ? 'Off' : '$level';
              final isLast = level == steps.last;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 6),
                  child: InkWell(
                    onTap: () => onSpeedChanged(level),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tokens.bluePrimary
                            : (tokens.isDark
                                  ? tokens.surfaceCard
                                  : const Color(0xFFF0F4FA)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? tokens.bluePrimary
                              : tokens.borderControl,
                        ),
                      ),
                      child: Text(
                        buttonLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.white : tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
