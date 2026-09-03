import 'package:flutter/material.dart';
import '../../../core/models/connectivity_models.dart';

/// Phase 26 — Transport Selector
///
/// Segmented/Chip selector for switching active device transport with confirmation.
class TransportSelector extends StatelessWidget {
  final List<DeviceTransportType> availableTransports;
  final DeviceTransportType selectedTransport;
  final ValueChanged<DeviceTransportType> onTransportSelected;

  const TransportSelector({
    super.key,
    required this.availableTransports,
    required this.selectedTransport,
    required this.onTransportSelected,
  });

  IconData _iconFor(DeviceTransportType t) => switch (t) {
    DeviceTransportType.wifiMqtt => Icons.wifi_rounded,
    DeviceTransportType.ble => Icons.bluetooth_rounded,
    DeviceTransportType.thread => Icons.hub_rounded,
    DeviceTransportType.matter => Icons.all_inclusive_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableTransports.map((transport) {
        final isSelected = transport == selectedTransport;
        return ChoiceChip(
          avatar: Icon(_iconFor(transport), size: 16),
          label: Text(transport.toDisplayLabel()),
          selected: isSelected,
          onSelected: (selected) {
            if (selected && !isSelected) {
              onTransportSelected(transport);
            }
          },
        );
      }).toList(),
    );
  }
}
