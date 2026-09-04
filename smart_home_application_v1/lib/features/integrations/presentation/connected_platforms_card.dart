import 'package:flutter/material.dart';
import '../../../core/models/matter_models.dart';
import '../../../core/theme/app_theme.dart';

/// Presentation card displaying connected external platforms (Apple Home, Google Home, Alexa, etc.)
class ConnectedPlatformsCard extends StatelessWidget {
  final List<ExternalPlatformLinkModel> platformLinks;
  final ValueChanged<ExternalPlatformType>? onConnectPlatform;
  final ValueChanged<ExternalPlatformLinkModel>? onDisconnectPlatform;
  final ValueChanged<ExternalPlatformLinkModel>? onSyncPlatform;

  const ConnectedPlatformsCard({
    super.key,
    required this.platformLinks,
    this.onConnectPlatform,
    this.onDisconnectPlatform,
    this.onSyncPlatform,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final platforms = [
      ExternalPlatformType.appleHome,
      ExternalPlatformType.googleHome,
      ExternalPlatformType.amazonAlexa,
    ];

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, color: tokens.bluePrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Connected Ecosystems',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...platforms.map((platform) {
            final link = platformLinks.cast<ExternalPlatformLinkModel?>().firstWhere(
                  (l) => l?.platformType == platform,
                  orElse: () => null,
                );
            return _buildPlatformRow(context, platform, link, tokens);
          }),
        ],
      ),
    );
  }

  Widget _buildPlatformRow(
    BuildContext context,
    ExternalPlatformType platform,
    ExternalPlatformLinkModel? link,
    dynamic tokens,
  ) {
    final isConnected = link != null && link.status == PlatformLinkStatus.active;
    final name = _getPlatformDisplayName(platform);
    final icon = _getPlatformIcon(platform);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isConnected
                  ? tokens.bluePrimary.withValues(alpha: 0.12)
                  : tokens.bgSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isConnected ? tokens.bluePrimary : tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isConnected
                      ? 'Linked (Fabric ${link.fabricId.substring(0, link.fabricId.length > 8 ? 8 : link.fabricId.length)})'
                      : 'Not connected',
                  style: TextStyle(
                    color: isConnected ? tokens.success : tokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected) ...[
            if (onSyncPlatform != null)
              IconButton(
                icon: Icon(Icons.sync, size: 18, color: tokens.textSecondary),
                tooltip: 'Sync State',
                onPressed: () => onSyncPlatform?.call(link),
              ),
            if (onDisconnectPlatform != null)
              IconButton(
                icon: Icon(Icons.link_off, size: 18, color: tokens.error),
                tooltip: 'Disconnect',
                onPressed: () => onDisconnectPlatform?.call(link),
              ),
          ] else ...[
            TextButton(
              onPressed: () => onConnectPlatform?.call(platform),
              style: TextButton.styleFrom(
                foregroundColor: tokens.bluePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }

  String _getPlatformDisplayName(ExternalPlatformType type) {
    switch (type) {
      case ExternalPlatformType.appleHome:
        return 'Apple Home';
      case ExternalPlatformType.googleHome:
        return 'Google Home';
      case ExternalPlatformType.amazonAlexa:
        return 'Amazon Alexa';
      case ExternalPlatformType.samsungSmartThings:
        return 'Samsung SmartThings';
      case ExternalPlatformType.homeAssistant:
        return 'Home Assistant';
      case ExternalPlatformType.genericMatterController:
        return 'Generic Matter Controller';
    }
  }

  IconData _getPlatformIcon(ExternalPlatformType type) {
    switch (type) {
      case ExternalPlatformType.appleHome:
        return Icons.apple;
      case ExternalPlatformType.googleHome:
        return Icons.home_outlined;
      case ExternalPlatformType.amazonAlexa:
        return Icons.graphic_eq;
      case ExternalPlatformType.samsungSmartThings:
        return Icons.devices_other;
      case ExternalPlatformType.homeAssistant:
        return Icons.assistant;
      case ExternalPlatformType.genericMatterController:
        return Icons.hub_outlined;
    }
  }
}
