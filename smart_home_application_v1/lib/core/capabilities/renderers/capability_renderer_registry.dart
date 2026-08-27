import 'package:flutter/material.dart';
import '../models/capability_models.dart';
import '../widgets/switch_control.dart';
import '../widgets/fan_speed_control.dart';
import '../widgets/brightness_control.dart';
import '../widgets/cct_control.dart';

typedef CapabilityWidgetBuilder =
    Widget Function(
      BuildContext context,
      ResolvedDeviceChannel channel,
      void Function(ResolvedDeviceChannel updated) onChannelUpdated,
    );

/// Controlled Registry for Capability UI Renderers.
/// The backend provides capability names & configurations; Flutter owns the known renderer implementations.
class CapabilityRendererRegistry {
  CapabilityRendererRegistry._() {
    _registerBuiltinRenderers();
  }

  static final CapabilityRendererRegistry instance =
      CapabilityRendererRegistry._();

  final Map<String, CapabilityWidgetBuilder> _renderers = {};

  void _registerBuiltinRenderers() {
    // Switch / Relay Renderer
    register('switch', (context, channel, onUpdated) {
      return SwitchControl(
        isOn: channel.powerState,
        isPending: channel.isPending,
        label: channel.name,
        onChanged: (val) {
          onUpdated(channel.copyWith(powerState: val, isPending: true));
        },
      );
    });
    register('relay', (context, channel, onUpdated) {
      return SwitchControl(
        isOn: channel.powerState,
        isPending: channel.isPending,
        label: channel.name,
        onChanged: (val) {
          onUpdated(channel.copyWith(powerState: val, isPending: true));
        },
      );
    });

    // Metadata-driven Fan Speed Renderer
    register('fan_speed', (context, channel, onUpdated) {
      return FanSpeedControl(
        speed: channel.fanSpeed,
        minSpeed: channel.fanMinSpeed,
        maxSpeed: channel.fanMaxSpeed,
        step: channel.fanStep,
        onSpeedChanged: (speed) {
          onUpdated(channel.copyWith(fanSpeed: speed, powerState: speed > 0));
        },
      );
    });

    // Metadata-driven Brightness Dimmer Renderer
    register('brightness', (context, channel, onUpdated) {
      return BrightnessControl(
        level: channel.brightnessLevel,
        min: channel.brightnessMin,
        max: channel.brightnessMax,
        step: channel.brightnessStep,
        onLevelChanged: (level) {
          onUpdated(
            channel.copyWith(brightnessLevel: level, powerState: level > 0),
          );
        },
      );
    });

    // Metadata-driven CCT Tunable White Renderer
    register('cct', (context, channel, onUpdated) {
      return CCTControl(
        kelvin: channel.cctKelvin,
        minKelvin: channel.cctMinKelvin,
        maxKelvin: channel.cctMaxKelvin,
        stepKelvin: channel.cctStepKelvin,
        onKelvinChanged: (k) {
          onUpdated(channel.copyWith(cctKelvin: k));
        },
      );
    });
  }

  /// Register a new renderer (e.g. for future products like Smart Curtain without rewriting core UI).
  void register(String capabilityId, CapabilityWidgetBuilder builder) {
    _renderers[capabilityId] = builder;
  }

  bool hasRenderer(String capabilityId) => _renderers.containsKey(capabilityId);

  Widget? buildWidget(
    BuildContext context,
    String capabilityId,
    ResolvedDeviceChannel channel,
    void Function(ResolvedDeviceChannel updated) onChannelUpdated,
  ) {
    final builder = _renderers[capabilityId];
    if (builder == null) return null;
    return builder(context, channel, onChannelUpdated);
  }
}
