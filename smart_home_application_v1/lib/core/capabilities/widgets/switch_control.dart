import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Capability primitive for Binary Switch & Relay Control.
class SwitchControl extends StatelessWidget {
  const SwitchControl({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.isPending = false,
    this.label = 'Power',
  });

  final bool isOn;
  final ValueChanged<bool> onChanged;
  final bool isPending;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final activeColor = tokens.bluePrimary;

    return Semantics(
      button: true,
      label: '$label ${isOn ? "On" : "Off"}',
      child: InkWell(
        onTap: isPending ? null : () => onChanged(!isOn),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOn
                ? (tokens.isDark ? tokens.blueSelectedBg : const Color(0xFFEAF1FF))
                : (tokens.isDark ? tokens.surfaceElevated : tokens.bgSecondary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOn ? activeColor : tokens.borderControl,
              width: isOn ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isOn
                      ? activeColor
                      : (tokens.isDark ? tokens.borderControl : const Color(0xFFE0E4EC)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: isOn ? Colors.white : tokens.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPending
                          ? 'Updating...'
                          : (isOn ? 'Turned On' : 'Turned Off'),
                      style: TextStyle(
                        color: isPending
                            ? tokens.warning
                            : (isOn ? activeColor : tokens.textSecondary),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isOn,
                onChanged: isPending ? null : onChanged,
                activeTrackColor: tokens.isDark ? tokens.blueDarker : const Color(0xFF90B8F0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
