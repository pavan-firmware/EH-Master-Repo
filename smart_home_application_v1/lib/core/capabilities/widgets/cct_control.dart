import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Metadata-driven capability primitive for Correlated Color Temperature.
/// Supports dynamic minKelvin, maxKelvin, and stepKelvin configuration.
class CCTControl extends StatelessWidget {
  const CCTControl({
    super.key,
    required this.kelvin,
    required this.onKelvinChanged,
    this.minKelvin = 2700,
    this.maxKelvin = 6500,
    this.stepKelvin = 100,
    this.label = 'Color Temperature',
  });

  final int kelvin;
  final ValueChanged<int> onKelvinChanged;
  final int minKelvin;
  final int maxKelvin;
  final int stepKelvin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final clampedKelvin = kelvin.clamp(minKelvin, maxKelvin);
    final divisions = ((maxKelvin - minKelvin) / stepKelvin).round().clamp(
      1,
      100,
    );

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
              const Icon(
                Icons.color_lens_rounded,
                color: Color(0xFFFFB84D),
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
                '${clampedKelvin}K',
                style: TextStyle(
                  color: tokens.bluePrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Gradient representation of color temperature
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9E3D), // Warm
                  Color(0xFFFFE2A3), // Neutral
                  Color(0xFFD6EEFF), // Cool daylight
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              trackHeight: 8,
            ),
            child: Slider(
              value: clampedKelvin.toDouble(),
              min: minKelvin.toDouble(),
              max: maxKelvin.toDouble(),
              divisions: divisions,
              onChanged: (v) => onKelvinChanged(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Warm (${minKelvin}K)',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
              Text(
                'Cool (${maxKelvin}K)',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
