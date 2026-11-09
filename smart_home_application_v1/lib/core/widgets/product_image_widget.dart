import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/product_asset_resolver.dart';

/// Metadata-driven remote product image loader with offline caching and fallback.
class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final double? size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? placeholderColor;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.fallbackIcon = Icons.device_hub_rounded,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(8);

    // Normalize asset paths that might have an accidental leading slash
    final rawUrl = imageUrl?.trim();
    final cleanAssetUrl = (rawUrl != null && rawUrl.startsWith('/assets/'))
        ? rawUrl.substring(1)
        : rawUrl;

    final isExplicitAsset = cleanAssetUrl != null && cleanAssetUrl.startsWith('assets/');

    // Prioritize bundled APK artwork for 100% offline reliability
    String? localAssetPath;
    if (isExplicitAsset) {
      localAssetPath = cleanAssetUrl;
    } else if (cleanAssetUrl != null && cleanAssetUrl.isNotEmpty) {
      localAssetPath = resolveBundledProductAsset(cleanAssetUrl);
      if (localAssetPath == null) {
        final variantMatch = RegExp(r'(eh-smart-[a-z0-9-]+)').firstMatch(cleanAssetUrl);
        if (variantMatch != null) {
          localAssetPath = resolveBundledProductAsset(variantMatch.group(1));
        }
      }
    }

    Widget imageContent;

    if (localAssetPath != null && localAssetPath.isNotEmpty) {
      imageContent = Image.asset(
        localAssetPath,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // If local asset failed, try network if applicable, else show icon
          if (cleanAssetUrl != null && (cleanAssetUrl.startsWith('http://') || cleanAssetUrl.startsWith('https://') || cleanAssetUrl.startsWith('/api/'))) {
            final netUrl = cleanAssetUrl.startsWith('/')
                ? '${AppConfig.backendBaseUrl}$cleanAssetUrl'
                : cleanAssetUrl;
            return Image.network(
              netUrl,
              width: effectiveWidth,
              height: effectiveHeight,
              fit: fit,
              errorBuilder: (ctx, err, st) => _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight),
            );
          }
          return _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight);
        },
      );
    } else {
      final normalizedUrl = cleanAssetUrl != null && cleanAssetUrl.startsWith('/')
          ? '${AppConfig.backendBaseUrl}$cleanAssetUrl'
          : cleanAssetUrl;
      final isNetwork = normalizedUrl != null &&
          (normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://'));

      if (isNetwork) {
        imageContent = Image.network(
          normalizedUrl,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder(context, effectiveWidth, effectiveHeight);
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight);
          },
        );
      } else {
        imageContent = _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight);
      }
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: imageContent,
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context, [double? effectiveWidth, double? effectiveHeight]) {
    final w = effectiveWidth ?? width ?? size;
    final h = effectiveHeight ?? height ?? size;
    return Container(
      width: w,
      height: h,
      color: placeholderColor ?? Colors.black12,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildFallbackPlaceholder(BuildContext context, [double? effectiveWidth, double? effectiveHeight]) {
    final w = effectiveWidth ?? width ?? size;
    final h = effectiveHeight ?? height ?? size;
    return Container(
      width: w,
      height: h,
      color: placeholderColor ?? Colors.black12,
      child: Center(
        child: Icon(
          _effectiveFallbackIcon(),
          size: (w != null && h != null) ? (w < h ? w * 0.5 : h * 0.5) : 24,
          color: Colors.grey,
        ),
      ),
    );
  }

  IconData _effectiveFallbackIcon() {
    final value = (imageUrl ?? '').toLowerCase();
    if (value.contains('fan')) return Icons.mode_fan_off_rounded;
    if (value.contains('socket') || value.contains('plug')) return Icons.power_rounded;
    if (value.contains('switch')) return Icons.toggle_on_rounded;
    if (value.contains('light') || value.contains('lamp') || value.contains('cct')) return Icons.lightbulb_outline_rounded;
    if (value.contains('sensor')) return Icons.sensors_rounded;
    if (value.contains('hub') || value.contains('controller')) return Icons.hub_rounded;
    return fallbackIcon;
  }
}
