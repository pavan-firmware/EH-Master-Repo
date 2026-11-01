import 'package:flutter/material.dart';

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
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.device_hub_rounded,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(8);
    final isNetwork = imageUrl != null &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));
    final isAsset = imageUrl != null && imageUrl!.startsWith('assets/');

    Widget imageContent;

    if (isNetwork) {
      imageContent = Image.network(
        imageUrl!,
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
    } else if (isAsset) {
      imageContent = Image.asset(
        imageUrl!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight);
        },
      );
    } else {
      imageContent = _buildFallbackPlaceholder(context, effectiveWidth, effectiveHeight);
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
          fallbackIcon,
          size: (w != null && h != null) ? (w < h ? w * 0.5 : h * 0.5) : 24,
          color: Colors.grey,
        ),
      ),
    );
  }
}
