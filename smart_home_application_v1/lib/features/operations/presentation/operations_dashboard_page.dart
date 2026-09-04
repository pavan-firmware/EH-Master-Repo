import 'package:flutter/material.dart';
import '../../../core/models/operations_models.dart';
import '../../../core/repositories/operations_repository.dart';
import '../../../core/theme/app_theme.dart';

class OperationsDashboardPage extends StatefulWidget {
  const OperationsDashboardPage({
    super.key,
    required this.repository,
    this.homeId,
    this.isAdmin = false,
  });

  final OperationsRepository repository;
  final String? homeId;
  final bool isAdmin;

  @override
  State<OperationsDashboardPage> createState() => _OperationsDashboardPageState();
}

class _OperationsDashboardPageState extends State<OperationsDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SystemHealthSnapshot? _healthSnapshot;
  OperationsMetricsSummary? _metricsSummary;
  List<OperationalEvent> _events = [];
  AuditIntegrityResult? _integrityResult;

  bool _isLoading = true;
  String? _errorMessage;
  OperationalSubsystem? _selectedSubsystem;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllOperationsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllOperationsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final health = await widget.repository.getSystemHealth();
      final metrics = await widget.repository.getOperationsMetrics(homeId: widget.homeId);
      final events = await widget.repository.getOperationalEvents(
        homeId: widget.homeId,
        subsystem: _selectedSubsystem,
        limit: 50,
      );

      AuditIntegrityResult? integrity;
      if (widget.isAdmin) {
        integrity = await widget.repository.verifyChainIntegrity();
      }

      if (mounted) {
        setState(() {
          _healthSnapshot = health;
          _metricsSummary = metrics;
          _events = events;
          _integrityResult = integrity;
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: const Text('Operations & Observability'),
        backgroundColor: tokens.surfaceCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllOperationsData,
            tooltip: 'Refresh Observability Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tokens.bluePrimary,
          labelColor: tokens.bluePrimary,
          unselectedLabelColor: tokens.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Health'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Metrics'),
            Tab(icon: Icon(Icons.timeline_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.shield_outlined), text: 'Audit Chain'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView(tokens)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHealthTab(tokens),
                    _buildMetricsTab(tokens),
                    _buildEventsTab(tokens),
                    _buildAuditChainTab(tokens),
                  ],
                ),
    );
  }

  Widget _buildErrorView(EHThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load operations data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllOperationsData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTab(EHThemeTokens tokens) {
    if (_healthSnapshot == null) {
      return const Center(child: Text('No health data available'));
    }

    final isHealthy = _healthSnapshot!.status == HealthStatus.healthy;
    final isDegraded = _healthSnapshot!.status == HealthStatus.degraded;

    final statusColor = isHealthy
        ? tokens.success
        : isDegraded
            ? tokens.warning
            : tokens.error;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withAlpha(38),
                  child: Icon(
                    isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Status: ${_healthSnapshot!.status.name.toUpperCase()}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last checked: ${_healthSnapshot!.timestamp.toLocal()}',
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Subsystem Health Checks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
        const SizedBox(height: 8),
        ..._healthSnapshot!.subsystems.entries.map((entry) {
          final subName = entry.key;
          final details = entry.value;
          final statusStr = (details['status'] as String?) ?? 'UNKNOWN';
          final latency = details['latencyMs'];

          final isSubHealthy = statusStr == 'HEALTHY';
          final isSubDegraded = statusStr == 'DEGRADED';
          final subColor = isSubHealthy
              ? tokens.success
              : isSubDegraded
                  ? tokens.warning
                  : tokens.error;

          return Card(
            color: tokens.surfaceCard,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: Icon(Icons.circle, color: subColor, size: 14),
              title: Text(subName, style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              subtitle: Text(
                'Status: $statusStr ${latency != null ? '• Latency: ${latency}ms' : ''}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
              trailing: Chip(
                label: Text(statusStr, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.bold)),
                backgroundColor: subColor.withAlpha(25),
                side: BorderSide.none,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricsTab(EHThemeTokens tokens) {
    if (_metricsSummary == null) {
      return const Center(child: Text('No operational metrics available'));
    }

    final m = _metricsSummary!;
    final successRateStr = m.isStatisticallySignificant && m.successRate != null
        ? '${(m.successRate! * 100).toStringAsFixed(1)}%'
        : 'N/A (< 5 events)';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!m.isStatisticallySignificant)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: tokens.warning.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.warning.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: tokens.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.sampleSizeNote ?? 'Sample size too small for statistical significance.',
                    style: TextStyle(color: tokens.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operational Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricTile('Total Events', '${m.totalEvents}', tokens.bluePrimary, tokens),
                    _buildMetricTile('Successes', '${m.successCount}', tokens.success, tokens),
                    _buildMetricTile('Failures', '${m.failureCount}', tokens.error, tokens),
                    _buildMetricTile('Success Rate', successRateStr, tokens.textPrimary, tokens),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Failure Taxonomy & Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
        const SizedBox(height: 8),
        if (m.failureCodes.isEmpty)
          Card(
            color: tokens.surfaceCard,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Zero failure codes recorded in current window')),
            ),
          )
        else
          ...m.failureCodes.entries.map((entry) {
            return Card(
              color: tokens.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Icon(Icons.bug_report_outlined, color: tokens.error),
                title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                trailing: Chip(
                  label: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, EHThemeTokens tokens) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
      ],
    );
  }

  Widget _buildEventsTab(EHThemeTokens tokens) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Subsystems'),
                selected: _selectedSubsystem == null,
                onSelected: (_) {
                  setState(() => _selectedSubsystem = null);
                  _loadAllOperationsData();
                },
              ),
              const SizedBox(width: 8),
              ...OperationalSubsystem.values.map((sub) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(sub.toDisplayString()),
                    selected: _selectedSubsystem == sub,
                    onSelected: (_) {
                      setState(() => _selectedSubsystem = sub);
                      _loadAllOperationsData();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: _events.isEmpty
              ? const Center(child: Text('No operational events recorded'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final e = _events[index];
                    final isSuccess = e.outcome == OperationOutcome.success;
                    final outcomeColor = isSuccess ? tokens.success : tokens.error;

                    return Card(
                      color: tokens.surfaceCard,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: outcomeColor.withAlpha(30),
                          child: Icon(
                            isSuccess ? Icons.check : Icons.close,
                            color: outcomeColor,
                            size: 18,
                          ),
                        ),
                        title: Text('${e.subsystem.toDisplayString()} • ${e.operation}',
                            style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                        subtitle: Text(
                          'Path: ${e.executionPath.name.toUpperCase()} • Duration: ${e.durationMs ?? 0}ms\nTime: ${e.timestamp.toLocal()}',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          e.outcome.name.toUpperCase(),
                          style: TextStyle(color: outcomeColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAuditChainTab(EHThemeTokens tokens) {
    if (!widget.isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: tokens.warning),
              const SizedBox(height: 16),
              Text('Admin Privileges Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
              const SizedBox(height: 8),
              Text('Viewing cryptographic hash chain integrity requires administrative role.',
                  textAlign: TextAlign.center, style: TextStyle(color: tokens.textSecondary)),
            ],
          ),
        ),
      );
    }

    final integrity = _integrityResult;
    if (integrity == null) {
      return const Center(child: Text('Audit verification data not loaded'));
    }

    final isValid = integrity.valid;
    final chainColor = isValid ? tokens.success : tokens.error;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: tokens.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: chainColor.withAlpha(38),
                  child: Icon(isValid ? Icons.verified_user : Icons.gpp_bad, color: chainColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid ? 'Cryptographic Hash Chain Valid' : 'Tamper Detected in Hash Chain!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: chainColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verified ${integrity.totalRecords} sequential security audit blocks.',
                        style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                      ),
                      if (integrity.brokenAtSequence != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Broken at sequence: #${integrity.brokenAtSequence}',
                          style: TextStyle(fontSize: 13, color: tokens.error, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
