import '../generated/product_asset_manifest.dart';

/// Resolves variant-scoped bundled artwork from the APK with intelligent
/// fallback to family artwork so physical devices always display actual
/// product hardware photos across all app sections.
String? resolveBundledProductAsset(String? variantOrModel) {
  if (variantOrModel == null || variantOrModel.trim().isEmpty) return null;
  final raw = variantOrModel.trim().toLowerCase();
  final value = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  // 1. Exact match in manifest (e.g. 'eh-smart-switch-3x')
  final exact = bundledProductAssetManifest[value] ??
      (value.startsWith('eh-') ? null : bundledProductAssetManifest['eh-$value']);
  if (exact != null && exact.isNotEmpty) return exact;

  // 2. Exact match by channel count if mentioned in value
  final isSwitch = value.contains('switch') || value.contains('sw') || value.contains('relay');
  final isSocket = value.contains('socket') || value.contains('sk') || value.contains('plug') || value.contains('outlet');
  final isFan = value.contains('fan');
  final isLight = value.contains('light') || value.contains('lamp') || value.contains('cct') || value.contains('bulb');

  if (isSwitch) {
    for (final ch in ['4x', '3x', '2x', '1x']) {
      if (value.contains(ch)) {
        final match = bundledProductAssetManifest['eh-smart-switch-$ch'];
        if (match != null && match.isNotEmpty) return match;
      }
    }
    // Return any available switch image in manifest
    for (final entry in bundledProductAssetManifest.entries) {
      if (entry.key.contains('switch')) return entry.value;
    }
    return 'assets/products/catalog/eh-smart-switch-3x/hero.webp';
  }

  if (isSocket) {
    for (final ch in ['4x', '3x', '2x', '1x']) {
      if (value.contains(ch)) {
        final match = bundledProductAssetManifest['eh-smart-socket-$ch'];
        if (match != null && match.isNotEmpty) return match;
      }
    }
    // Return any available socket image in manifest
    for (final entry in bundledProductAssetManifest.entries) {
      if (entry.key.contains('socket')) return entry.value;
    }
    return 'assets/products/catalog/eh-smart-socket-2x/hero.webp';
  }

  if (isFan) {
    for (final entry in bundledProductAssetManifest.entries) {
      if (entry.key.contains('fan')) return entry.value;
    }
    return 'assets/products/catalog/eh-smart-fan-1x/hero.webp';
  }

  if (isLight) {
    for (final entry in bundledProductAssetManifest.entries) {
      if (entry.key.contains('light') || entry.key.contains('cct')) return entry.value;
    }
    return 'assets/products/catalog/eh-smart-light-cct/hero.webp';
  }

  // 3. General fallback if string mentions smart device
  if (value.contains('smart') || value.contains('device') || value.contains('channel')) {
    return 'assets/products/catalog/eh-smart-switch-3x/hero.webp';
  }

  return null;
}
