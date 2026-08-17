import 'package:flutter/material.dart';

import '../../../core/models/home_dashboard_models.dart';
import '../../../core/models/room_models.dart';
import '../../../core/theme/app_theme.dart';

/// One reusable detail page renders all room types from typed capabilities.
class RoomContextPage extends StatelessWidget {
  const RoomContextPage({super.key, required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final current = room.telemetryFreshness == TelemetryFreshness.current;
    final temperature = room.capabilities
        .where((item) => item.kind == RoomCapabilityKind.temperature)
        .firstOrNull;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 106),
          children: [
            Row(
              children: [
                _HeaderButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${room.deviceCount} devices  ·  ${room.isOnline ? 'All online' : 'State unavailable'}',
                        style: TextStyle(
                          color: room.isOnline
                              ? tokens.success
                              : tokens.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderButton(icon: Icons.star_border_rounded, onTap: () {}),
                const SizedBox(width: 8),
                _HeaderButton(icon: Icons.more_horiz_rounded, onTap: () {}),
              ],
            ),
            const SizedBox(height: 24),
            _RoomHero(
              room: room,
              temperature: temperature?.value,
              current: current,
            ),
            const SizedBox(height: 27),
            Text(
              'Quick controls',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: room.devices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 13),
                itemBuilder: (_, index) =>
                    _QuickDeviceCard(device: room.devices[index]),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Devices',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add device'),
                ),
              ],
            ),
            ...room.devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DeviceRow(device: device),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Room insights',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: tokens.bluePrimary),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('See history'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InsightsCard(insights: room.insights),
          ],
        ),
      ),
    );
  }
}

class _RoomHero extends StatelessWidget {
  const _RoomHero({
    required this.room,
    required this.temperature,
    required this.current,
  });
  final Room room;
  final String? temperature;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(25),
        border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D0B2448),
                  blurRadius: 17,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 105,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _heroColors(room.iconKey, tokens),
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    left: 20,
                    bottom: 18,
                    child: Icon(
                      Icons.chair_rounded,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: Icon(
                      _roomHeroIcon(room.iconKey),
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const Positioned(
                    left: 18,
                    top: 18,
                    child: Text(
                      'ROOM PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.thermostat_outlined,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        temperature ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    current
                        ? room.status == RoomStatus.attention
                            ? 'Needs attention'
                            : 'Comfortable'
                        : 'State unavailable',
                    style: TextStyle(
                      color: current && room.status != RoomStatus.attention
                          ? tokens.success
                          : tokens.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Divider(height: 16, color: tokens.borderSubtle),
                  _HeroLine(
                    icon: Icons.water_drop_outlined,
                    text: room.id == 'living' ? 'Humidity 52%' : room.summary,
                  ),
                  const SizedBox(height: 4),
                  _HeroLine(
                    icon: Icons.schedule_rounded,
                    text: current
                        ? 'Updated just now'
                        : 'Telemetry ${room.telemetryFreshness.name}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Icon(icon, size: 19, color: tokens.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _QuickDeviceCard extends StatelessWidget {
  const _QuickDeviceCard({required this.device});
  final RoomDevice device;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final enabled = device.confidence == ActuatorConfidence.confirmed && false;
    final devColor = _deviceColor(device.kind, tokens);
    final devBg = tokens.isDark ? devColor.withValues(alpha: 0.18) : devColor.withValues(alpha: .12);

    return SizedBox(
      width: 146,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
          boxShadow: tokens.isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0D0B2448),
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: devBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _deviceIcon(device.kind),
                color: devColor,
                size: 27,
              ),
            ),
            const Spacer(),
            Text(
              device.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              device.value,
              style: TextStyle(
                color: devColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 11),
            Center(
              child: _UnavailableControl(kind: device.kind, enabled: enabled),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableControl extends StatelessWidget {
  const _UnavailableControl({required this.kind, required this.enabled});
  final RoomCapabilityKind kind;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    if (kind == RoomCapabilityKind.fan) {
      return SizedBox(
        width: 92,
        child: LinearProgressIndicator(
          value: .4,
          minHeight: 6,
          backgroundColor: tokens.isDark ? tokens.borderControl : null,
          valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
        ),
      );
    }
    if (kind == RoomCapabilityKind.curtain) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chevron_left_rounded, color: tokens.textSecondary),
          const SizedBox(width: 9),
          CircleAvatar(
            radius: 15,
            backgroundColor: tokens.surfaceElevated,
            child: Icon(Icons.pause_rounded, size: 18, color: tokens.textPrimary),
          ),
          const SizedBox(width: 9),
          Icon(Icons.chevron_right_rounded, color: tokens.textSecondary),
        ],
      );
    }
    return Container(
      width: 52,
      height: 30,
      decoration: BoxDecoration(
        color: tokens.isDark ? tokens.switchTrackOff : const Color(0xFFE1E5EB),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: tokens.isDark ? tokens.borderControl : const Color(0xFFC8CDD5),
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: tokens.isDark ? tokens.switchThumbOff : Colors.white,
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});
  final RoomDevice device;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final devColor = _deviceColor(device.kind, tokens);
    final devBg = tokens.isDark ? devColor.withValues(alpha: 0.18) : devColor.withValues(alpha: .12);

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: devBg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _deviceIcon(device.kind),
                color: devColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.type,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              device.value,
              style: TextStyle(
                color: tokens.bluePrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.chevron_right_rounded, color: tokens.chevron),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});
  final RoomInsights insights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final energy = _EnergySummary(insights: insights);
        final metrics = _InsightMetrics(insights: insights);
        final content = constraints.maxWidth < 390
            ? Column(children: [energy, Divider(height: 28, color: tokens.borderSubtle), metrics])
            : Row(
                children: [
                  Expanded(child: energy),
                  VerticalDivider(width: 26, color: tokens.borderSubtle),
                  Expanded(child: metrics),
                ],
              );
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
          ),
          child: content,
        );
      },
    );
  }
}

class _EnergySummary extends StatelessWidget {
  const _EnergySummary({required this.insights});
  final RoomInsights insights;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 19, color: tokens.warning),
            const SizedBox(width: 8),
            Text("Today's energy", style: TextStyle(fontWeight: FontWeight.w700, color: tokens.textPrimary)),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          insights.energyKwh,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          insights.energyChange,
          style: TextStyle(
            color: tokens.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        const _MiniChart(),
      ],
    );
  }
}

class _InsightMetrics extends StatelessWidget {
  const _InsightMetrics({required this.insights});
  final RoomInsights insights;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: [
        _InsightLine(
          icon: Icons.schedule_outlined,
          label: 'Most active',
          value: insights.activeWindow,
        ),
        Divider(height: 22, color: tokens.borderSubtle),
        _InsightLine(
          icon: Icons.thermostat_outlined,
          label: 'Avg. temperature',
          value: insights.averageTemperature,
        ),
        Divider(height: 22, color: tokens.borderSubtle),
        _InsightLine(
          icon: Icons.water_drop_outlined,
          label: 'Avg. humidity',
          value: insights.averageHumidity,
        ),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        Icon(icon, size: 19, color: tokens.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.textPrimary),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: tokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SizedBox(
      height: 38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          15,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: 8.0 + ((index * 11) % 28),
                color: tokens.bluePrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          shape: BoxShape.circle,
          border: tokens.isDark ? Border.all(color: tokens.borderSubtle) : null,
        ),
        child: Icon(icon, color: tokens.headerAction, size: 22),
      ),
    );
  }
}

List<Color> _heroColors(String key, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (key) {
      'living' => const [Color(0xFF5C472A), Color(0xFF332616)],
      'kitchen' => const [Color(0xFF6B3320), Color(0xFF381B11)],
      'plant' => const [Color(0xFF234D3D), Color(0xFF132B22)],
      _ => const [Color(0xFF1F486E), Color(0xFF10263B)],
    };
  }
  return switch (key) {
    'living' => const [Color(0xFFD5B68D), Color(0xFF8C6B4F)],
    'kitchen' => const [Color(0xFFFFC9B7), Color(0xFFE57C50)],
    'plant' => const [Color(0xFFBEE1D2), Color(0xFF4C9679)],
    _ => const [Color(0xFFBFDDF4), Color(0xFF5A91BF)],
  };
}

IconData _roomHeroIcon(String key) => switch (key) {
  'living' => Icons.weekend_rounded,
  'kitchen' => Icons.kitchen_outlined,
  'plant' => Icons.local_florist_outlined,
  _ => Icons.water_drop_outlined,
};

Color _deviceColor(RoomCapabilityKind kind, EHThemeTokens tokens) {
  if (tokens.isDark) {
    return switch (kind) {
      RoomCapabilityKind.light ||
      RoomCapabilityKind.lamp => tokens.gold,
      RoomCapabilityKind.fan => tokens.bluePrimary,
      RoomCapabilityKind.curtain => tokens.iconFgPurple,
      RoomCapabilityKind.temperature => tokens.iconFgWater,
      RoomCapabilityKind.gasSensor => tokens.warning,
      RoomCapabilityKind.soilMoisture ||
      RoomCapabilityKind.mistCare => tokens.iconFgPlant,
      _ => tokens.bluePrimary,
    };
  }
  return switch (kind) {
    RoomCapabilityKind.light ||
    RoomCapabilityKind.lamp => const Color(0xFFB88700),
    RoomCapabilityKind.fan => const Color(0xFF168DD1),
    RoomCapabilityKind.curtain => const Color(0xFF7953E8),
    RoomCapabilityKind.temperature => const Color(0xFF159B9E),
    RoomCapabilityKind.gasSensor => const Color(0xFFF26D12),
    RoomCapabilityKind.soilMoisture ||
    RoomCapabilityKind.mistCare => const Color(0xFF18A963),
    _ => const Color(0xFF3175B9),
  };
}

IconData _deviceIcon(RoomCapabilityKind kind) => switch (kind) {
  RoomCapabilityKind.light => Icons.lightbulb_outline_rounded,
  RoomCapabilityKind.lamp => Icons.light_rounded,
  RoomCapabilityKind.fan => Icons.air_rounded,
  RoomCapabilityKind.curtain => Icons.curtains_outlined,
  RoomCapabilityKind.temperature => Icons.thermostat_outlined,
  RoomCapabilityKind.gasSensor => Icons.air_rounded,
  RoomCapabilityKind.soilMoisture ||
  RoomCapabilityKind.waterLevel => Icons.water_drop_outlined,
  RoomCapabilityKind.mistCare => Icons.cloud_outlined,
  RoomCapabilityKind.lowLevelAlert => Icons.notifications_none_rounded,
};
