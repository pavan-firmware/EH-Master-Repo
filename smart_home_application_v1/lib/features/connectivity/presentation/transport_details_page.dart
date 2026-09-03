import 'package:flutter/material.dart';
import '../../../core/services/connectivity_service.dart';

/// Phase 26 — Transport Details Page
///
/// Detailed protocol capabilities inspection (direct IP, mesh capable,
/// low power, max payload, priority rank).
class TransportDetailsPage extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  final ConnectivityService connectivityService;

  const TransportDetailsPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Supported Protocols',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: connectivityService,
        builder: (context, _) {
          final transports = connectivityService.deviceTransports;
          if (transports.isEmpty) {
            return Center(
              child: Text(
                'No configured transport details available',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: transports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final t = transports[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.transportType.toDisplayLabel(),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Rank #${t.priorityRank}',
                            style: TextStyle(color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _CapabilityRow(label: 'Direct IP', isEnabled: t.directIp),
                    const SizedBox(height: 8),
                    _CapabilityRow(label: 'Mesh Capable', isEnabled: t.meshCapable),
                    const SizedBox(height: 8),
                    _CapabilityRow(label: 'Low Power', isEnabled: t.lowPower),
                    const SizedBox(height: 8),
                    _CapabilityRow(label: 'Local Only', isEnabled: t.localOnly),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Payload', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                        Text('${t.maxPayloadBytes} B', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _CapabilityRow({required this.label, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 14,
              color: isEnabled ? const Color(0xFF22C55E) : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isEnabled ? 'Supported' : 'No',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? const Color(0xFF22C55E) : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
