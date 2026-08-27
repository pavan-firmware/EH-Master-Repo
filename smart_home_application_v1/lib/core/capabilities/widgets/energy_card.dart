import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/capability_models.dart';

/// Capability primitive for Real-Time & Cumulative Energy Telemetry.
/// Strictly capability-driven: displays real measurements, renders '--' for missing/unavailable fields,
/// and never fabricates fake telemetry.
class EnergyCard extends StatelessWidget {
  const EnergyCard({
    super.key,
    required this.telemetry,
    this.title = 'Energy & Power Monitoring',
  });

  final EnergyTelemetryData telemetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final powerStr = telemetry.powerW != null
        ? '${telemetry.powerW!.toStringAsFixed(1)} W'
        : '--';
    final energyStr = telemetry.energyKwh != null
        ? '${telemetry.energyKwh!.toStringAsFixed(2)} kWh'
        : '--';
    final voltageStr = telemetry.voltageV != null
        ? '${telemetry.voltageV!.toStringAsFixed(1)} V'
        : '--';
    final currentStr = telemetry.currentA != null
        ? '${telemetry.currentA!.toStringAsFixed(2)} A'
        : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x100B2448),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.isDark
                      ? tokens.iconBgGreen
                      : const Color(0xFFE9F7EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: tokens.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Deterministic fixed-point telemetry',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Real-time Power',
                  value: powerStr,
                  icon: Icons.flash_on_rounded,
                  color: tokens.bluePrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Total Energy',
                  value: energyStr,
                  icon: Icons.pie_chart_rounded,
                  color: tokens.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'AC Voltage',
                  value: voltageStr,
                  icon: Icons.electric_meter_rounded,
                  color: tokens.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'RMS Current',
                  value: currentStr,
                  icon: Icons.speed_rounded,
                  color: tokens.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.isDark ? tokens.surfaceElevated : tokens.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
