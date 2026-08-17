import '../models/capability_models.dart';

/// Pure functional capability resolver.
/// Computes a [ResolvedDevice] from product metadata, user customizations, and runtime state.
class CapabilityResolver {
  const CapabilityResolver._();

  static ResolvedDevice resolve({
    required ProductVariantDefinition productVariant,
    required String deviceId,
    required String customDeviceName,
    required CapabilityConnectionState connectionState,
    Map<int, String> channelLabels = const {},
    Map<int, Map<String, dynamic>> channelStates = const {},
    EnergyTelemetryData? energyTelemetry,
  }) {
    final channels = productVariant.channels.map((chDef) {
      final idx = chDef.channelIndex;
      final customName = channelLabels[idx];
      final name = (customName != null && customName.trim().isNotEmpty)
          ? customName
          : chDef.defaultLabel;

      final state = channelStates[idx] ?? {};
      final powerState = (state['power'] as bool?) ?? false;
      final fanSpeed = (state['speed'] as int?) ?? 0;
      final brightnessLevel = (state['brightness'] as int?) ?? 100;
      final cctKelvin = (state['cct'] as int?) ?? 4000;
      final isPending = (state['isPending'] as bool?) ?? false;

      return ResolvedDeviceChannel(
        channelIndex: idx,
        name: name,
        capabilities: chDef.capabilities,
        capabilityConfigs: chDef.capabilityConfigs,
        powerState: powerState,
        fanSpeed: fanSpeed,
        brightnessLevel: brightnessLevel,
        cctKelvin: cctKelvin,
        isPending: isPending,
      );
    }).toList();

    return ResolvedDevice(
      deviceId: deviceId,
      productVariantId: productVariant.productVariantId,
      displayName: customDeviceName.isNotEmpty
          ? customDeviceName
          : productVariant.displayName,
      connectionState: connectionState,
      channels: channels,
      capabilities: productVariant.capabilities,
      energyTelemetry: energyTelemetry,
      heroImageUrl: productVariant.heroImageUrl,
    );
  }
}
