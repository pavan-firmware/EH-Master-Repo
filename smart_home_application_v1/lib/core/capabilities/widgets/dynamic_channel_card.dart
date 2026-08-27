import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/capability_models.dart';
import '../renderers/capability_renderer_registry.dart';

/// Dynamic Channel Card rendering UI widgets for all supported capabilities of a channel.
class DynamicChannelCard extends StatelessWidget {
  const DynamicChannelCard({
    super.key,
    required this.channel,
    required this.onChannelUpdated,
  });

  final ResolvedDeviceChannel channel;
  final ValueChanged<ResolvedDeviceChannel> onChannelUpdated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final registry = CapabilityRendererRegistry.instance;

    // Filter capabilities that have registered UI renderers
    // Prioritize switch/relay first, then adjustments like fan_speed, brightness, cct
    final renderableCaps = channel.capabilities
        .where((cap) => registry.hasRenderer(cap))
        .toList();

    // Deduplicate switch and relay to avoid rendering 2 identical switches for the same channel
    if (renderableCaps.contains('switch') && renderableCaps.contains('relay')) {
      renderableCaps.remove('relay');
    }

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
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.isDark
                      ? tokens.blueSelectedBg
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${channel.channelIndex}',
                  style: TextStyle(
                    color: tokens.bluePrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (channel.isPending)
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          tokens.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...renderableCaps.map((capId) {
            final widget = registry.buildWidget(
              context,
              capId,
              channel,
              onChannelUpdated,
            );
            if (widget == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: widget,
            );
          }),
        ],
      ),
    );
  }
}
