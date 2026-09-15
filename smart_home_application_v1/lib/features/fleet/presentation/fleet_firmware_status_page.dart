import 'package:flutter/material.dart';

import '../../../core/models/fleet_models.dart';
import '../../../core/repositories/fleet_firmware_repository.dart';
import '../../../core/theme/app_theme.dart';

class FleetFirmwareStatusPage extends StatefulWidget {
  const FleetFirmwareStatusPage({
    super.key,
    required this.repository,
  });

  final FleetFirmwareRepository repository;

  @override
  State<FleetFirmwareStatusPage> createState() => _FleetFirmwareStatusPageState();
}

class _FleetFirmwareStatusPageState extends State<FleetFirmwareStatusPage> {
  late Future<List<FleetDeviceFirmwareStateModel>> _statesFuture;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  void _loadStates() {
    setState(() {
      _statesFuture = widget.repository.listFleetFirmwareStates();
    });
  }

  Color _getHealthColor(String health) {
    switch (health) {
      case 'HEALTH_VERIFIED':
        return Colors.green;
      case 'BOOT_VERIFIED':
      case 'INSTALLED':
        return Colors.blue;
      case 'DOWNLOADING':
      case 'REQUESTED':
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: const Text('Fleet Firmware Status'),
        backgroundColor: tokens.bgApp,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStates),
        ],
      ),
      body: FutureBuilder<List<FleetDeviceFirmwareStateModel>>(
        future: _statesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errStr = snapshot.error.toString();
            final isForbidden = errStr.contains('403') ||
                errStr.toLowerCase().contains('forbidden') ||
                errStr.toLowerCase().contains('administrative privilege');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: (isForbidden ? tokens.bluePrimary : tokens.error)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isForbidden
                            ? Icons.admin_panel_settings_outlined
                            : Icons.error_outline,
                        size: 48,
                        color: isForbidden ? tokens.bluePrimary : tokens.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isForbidden
                          ? 'Administrator Access Required'
                          : 'Unable to Load Device Fleet Status',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isForbidden
                          ? 'Viewing fleet-wide firmware states and verification telemetry is restricted to platform administrators with firmware management permissions.'
                          : 'Could not retrieve device fleet firmware records. Please check your connection and retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loadStates,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.bluePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final states = snapshot.data ?? [];
          if (states.isEmpty) {
            return Center(
              child: Text(
                'No device firmware records found',
                style: TextStyle(color: tokens.textSecondary, fontSize: 15),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: states.length,
            itemBuilder: (context, index) {
              final s = states[index];
              final healthColor = _getHealthColor(s.healthVerificationState);

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.deviceId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.healthVerificationState,
                              style: TextStyle(color: healthColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Product: ${s.productVariantId}'),
                      Text('Current Version: v${s.currentFirmwareVersion}'),
                      if (s.targetFirmwareVersion != null)
                        Text('Target Version: v${s.targetFirmwareVersion}'),
                      if (s.rolloutId != null)
                        Text('Active Rollout: ${s.rolloutId}'),
                      if (s.lastOtaResult != null)
                        Text('Last Result: ${s.lastOtaResult}'),
                      if (s.failureReason != null)
                        Text('Failure: ${s.failureReason}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
