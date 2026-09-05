import 'package:flutter/material.dart';
import '../../../core/models/operational_readiness_models.dart';
import '../../../core/repositories/operational_readiness_repository.dart';

class SystemOperationalStatusPage extends StatefulWidget {
  const SystemOperationalStatusPage({
    super.key,
    required this.repository,
  });

  final OperationalReadinessRepository repository;

  @override
  State<SystemOperationalStatusPage> createState() => _SystemOperationalStatusPageState();
}

class _SystemOperationalStatusPageState extends State<SystemOperationalStatusPage> {
  bool _isLoading = true;
  String? _errorMessage;
  SystemReadinessModel? _readiness;
  OperationalDiagnosticsModel? _diagnostics;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final readiness = await widget.repository.getSystemReadiness();
      OperationalDiagnosticsModel? diagnostics;
      try {
        diagnostics = await widget.repository.getOperationalDiagnostics();
      } catch (_) {
        // Administrative diagnostics may be optional if role is not admin
      }

      if (mounted) {
        setState(() {
          _readiness = readiness;
          _diagnostics = diagnostics;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'READY':
      case 'PASS':
      case 'HEALTHY':
      case 'CONNECTED':
      case 'RUNNING':
        return Colors.green;
      case 'DEGRADED':
      case 'STANDBY':
        return Colors.amber;
      case 'NOT_READY':
      case 'FAIL':
      case 'UNAVAILABLE':
      case 'DISCONNECTED':
      case 'SHUTTING_DOWN':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Operational Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Failed to retrieve system status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    final readiness = _readiness;
    if (readiness == null) return const SizedBox.shrink();

    final statusColor = _getStatusColor(readiness.status);

    return RefreshIndicator(
      onRefresh: _fetchStatus,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner
          Card(
            color: statusColor.withAlpha(30),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: statusColor, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    readiness.isReady ? Icons.check_circle : Icons.warning,
                    color: statusColor,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Status: ${readiness.status}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Service: ${readiness.service} (${readiness.version})',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subsystems Status
          const Text(
            'Core Infrastructure Dependencies',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDependencyCard('Database (PostgreSQL)', readiness.databaseCheck, Icons.storage),
          _buildDependencyCard('Cache & Lock (Redis)', readiness.redisCheck, Icons.memory),
          _buildDependencyCard('Messaging Broker (MQTT)', readiness.mqttCheck, Icons.swap_horiz),
          _buildDependencyCard('Background Workers', readiness.workersCheck, Icons.engineering),

          const SizedBox(height: 16),

          // Platform & Migration Metadata
          const Text(
            'Release & Schema Metadata',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildMetadataRow('Backend Version', readiness.version),
                  _buildMetadataRow('Schema Level', 'v${readiness.schemaVersionNumber ?? 26}'),
                  _buildMetadataRow('Latest Migration', readiness.latestMigration ?? '026_disaster_recovery_state_resilience'),
                  if (_diagnostics != null) ...[
                    _buildMetadataRow('Environment', _diagnostics!.environment),
                    _buildMetadataRow('Lifecycle State', _diagnostics!.lifecycleState),
                    _buildMetadataRow('Uptime (Seconds)', '${_diagnostics!.uptimeSeconds}s'),
                  ],
                  _buildMetadataRow('Last Checked', readiness.timestamp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDependencyCard(String name, String status, IconData icon) {
    final color = _getStatusColor(status);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
