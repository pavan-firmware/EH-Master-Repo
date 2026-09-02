import 'package:flutter/material.dart';
import '../../../core/models/fleet_models.dart';
import '../../../core/services/fleet_management_service.dart';
import 'firmware_update_card.dart';

/// EH Home — Device Fleet Management & Firmware Overview Dashboard (Phase 18)
class FleetHealthDashboardPage extends StatefulWidget {
  final FleetManagementService fleetService;
  final String? homeId;

  const FleetHealthDashboardPage({
    super.key,
    required this.fleetService,
    this.homeId,
  });

  @override
  State<FleetHealthDashboardPage> createState() => _FleetHealthDashboardPageState();
}

class _FleetHealthDashboardPageState extends State<FleetHealthDashboardPage> {
  String _selectedFilter = 'ALL'; // ALL, UPDATES, IN_PROGRESS, ISSUES

  @override
  void initState() {
    super.initState();
    _loadFleetStatus();
  }

  Future<void> _loadFleetStatus() async {
    try {
      await widget.fleetService.fetchFleetStatus(homeId: widget.homeId);
    } catch (_) {
      // Errors handled via fleetService.lastError
    }
  }

  void _showMaintenanceLogs(String? deviceId) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<DeviceMaintenanceLog>>(
          future: widget.fleetService.fetchMaintenanceHistory(
            homeId: widget.homeId,
            deviceId: deviceId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final logs = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maintenance & OTA History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: logs.isEmpty
                        ? const Center(child: Text('No maintenance logs found'))
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return ListTile(
                                leading: Icon(
                                  log.status == 'SUCCESS'
                                      ? Icons.check_circle_rounded
                                      : (log.status == 'ROLLED_BACK'
                                          ? Icons.undo_rounded
                                          : Icons.error_rounded),
                                  color: log.status == 'SUCCESS'
                                      ? Colors.green
                                      : (log.status == 'ROLLED_BACK' ? Colors.orange : Colors.red),
                                ),
                                title: Text('${log.operationType} (${log.status})'),
                                subtitle: Text(
                                  '${log.fromVersion != null ? 'v${log.fromVersion} -> ' : ''}v${log.toVersion ?? ''}\n${log.createdAt.toLocal().toString().split('.').first}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.fleetService,
      builder: (context, _) {
        final status = widget.fleetService.cachedFleetStatus;
        final isLoading = widget.fleetService.isLoading;
        final error = widget.fleetService.lastError;

        List<FleetDeviceSummary> displayedDevices = status?.devices ?? [];
        if (_selectedFilter == 'UPDATES') {
          displayedDevices = displayedDevices.where((d) => d.availableUpdate != null).toList();
        } else if (_selectedFilter == 'IN_PROGRESS') {
          displayedDevices = displayedDevices.where((d) => d.otaStatus != null && d.otaStatus != OtaOperationStatus.available).toList();
        } else if (_selectedFilter == 'ISSUES') {
          displayedDevices = displayedDevices.where((d) => d.connectionState == 'OFFLINE' || d.otaStatus == OtaOperationStatus.failed || d.otaStatus == OtaOperationStatus.rolledBack).toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fleet & Firmware Health'),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Maintenance Logs',
                onPressed: () => _showMaintenanceLogs(null),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: isLoading ? null : _loadFleetStatus,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadFleetStatus,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // KPI Metrics Grid
                if (status != null) ...[
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('Total', status.totalDevices.toString(), Icons.devices_rounded, Colors.blue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKpiCard('Online', status.onlineDevices.toString(), Icons.cloud_done_rounded, const Color(0xFF10B981))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKpiCard('Updates', status.otaUpdateAvailableCount.toString(), Icons.new_releases_rounded, Colors.orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKpiCard('In Progress', status.otaInProgressCount.toString(), Icons.sync_rounded, Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All (${status?.totalDevices ?? 0})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('UPDATES', 'Updates (${status?.otaUpdateAvailableCount ?? 0})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('IN_PROGRESS', 'In Progress (${status?.otaInProgressCount ?? 0})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ISSUES', 'Issues'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(error, style: const TextStyle(color: Colors.red)),
                  ),

                // Device Cards List
                if (displayedDevices.isEmpty && !isLoading)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No devices match the selected filter',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  )
                else
                  ...displayedDevices.map((dev) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: FirmwareUpdateCard(
                        deviceId: dev.deviceId,
                        homeId: dev.homeId ?? widget.homeId ?? '',
                        currentVersion: dev.firmwareVersion,
                        productVariantId: dev.productVariantId,
                        hardwareRevision: dev.hardwareRevision,
                        availableUpdate: dev.availableUpdate,
                        otaStatus: dev.otaStatus,
                        fleetService: widget.fleetService,
                        onUpdateTriggered: _loadFleetStatus,
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }
}
