import 'package:flutter/material.dart';
import '../../../core/models/product_catalog_models.dart';
import '../../../core/theme/app_theme.dart';

/// Generic, metadata-driven ProductCard widget.
/// Works for all current and future product families without SKU hardcoding.
class ProductCard extends StatelessWidget {
  final ProductCatalogEntry product;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddTap,
  });

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'switches':
        return Icons.toggle_on_rounded;
      case 'sockets':
        return Icons.power_rounded;
      case 'lighting':
        return Icons.lightbulb_rounded;
      case 'fans':
        return Icons.air_rounded;
      case 'climate':
        return Icons.thermostat_rounded;
      case 'sensors':
        return Icons.sensors_rounded;
      case 'energy':
        return Icons.bolt_rounded;
      default:
        return Icons.device_hub_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon + Badges
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tokens.iconBgBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(product.category),
                        color: tokens.bluePrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.marketingName,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.sku,
                            style: TextStyle(
                              color: tokens.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.productStatus == 'ACTIVE'
                            ? tokens.successContainer
                            : tokens.warningContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.productStatus == 'ACTIVE' ? 'Available' : product.productStatus,
                        style: TextStyle(
                          color: product.productStatus == 'ACTIVE'
                              ? tokens.success
                              : tokens.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  product.description,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Channels & Features Chip Row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FeatureChip(
                      label: '${product.channelCount} ${product.channelCount == 1 ? "Channel" : "Channels"}',
                      icon: Icons.layers_outlined,
                      tokens: tokens,
                    ),
                    if (product.wifiSupport)
                      _FeatureChip(
                        label: 'Wi-Fi',
                        icon: Icons.wifi_rounded,
                        tokens: tokens,
                      ),
                    if (product.bleProvisioningSupport)
                      _FeatureChip(
                        label: 'BLE',
                        icon: Icons.bluetooth_rounded,
                        tokens: tokens,
                      ),
                    if (product.energyMonitoringSupport)
                      _FeatureChip(
                        label: 'Energy Meter',
                        icon: Icons.bolt_rounded,
                        tokens: tokens,
                        isHighlight: true,
                      ),
                    if (product.matterSupport)
                      _FeatureChip(
                        label: 'Matter',
                        icon: Icons.hub_outlined,
                        tokens: tokens,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.electricalSpecifications['voltageRange'] as String? ?? '90-250V AC',
                      style: TextStyle(
                        color: tokens.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: onAddTap ?? onTap,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('View & Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final EHThemeTokens tokens;
  final bool isHighlight;

  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.tokens,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight ? tokens.iconBgOrange : tokens.bgSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight ? tokens.gold.withValues(alpha: 0.3) : tokens.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isHighlight ? tokens.goldBright : tokens.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? tokens.goldBright : tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
