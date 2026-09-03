import 'package:flutter/material.dart';
import '../../../core/models/reliability_models.dart';
import '../../../core/services/reliability_service.dart';

/// Phase 25 — Device Diagnostics Page
///
/// Shows incident history, root-cause diagnosis details, and evidence viewer.
class DeviceDiagnosticsPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final ReliabilityService reliabilityService;

  const DeviceDiagnosticsPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.reliabilityService,
  });

  @override
  State<DeviceDiagnosticsPage> createState() => _DeviceDiagnosticsPageState();
}

class _DeviceDiagnosticsPageState extends State<DeviceDiagnosticsPage> {
  String? _diagnosingId;
  String? _lastDiagnosis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.reliabilityService.loadDeviceHealth(widget.deviceId);
    });
  }

  Future<void> _runDiagnosis(ReliabilityIncident incident) async {
    setState(() {
      _diagnosingId = incident.id;
      _lastDiagnosis = null;
    });
    final result = await widget.reliabilityService.diagnoseIncident(incident.id);
    setState(() {
      _diagnosingId = null;
      if (result != null) {
        _lastDiagnosis =
            '${result['diagnosis_type'] ?? result['diagnosisType']} — '
            'Confidence: ${((result['confidence'] as num?)?.toDouble() ?? 0) * 100 ~/ 1}%\n'
            '${result['root_cause'] ?? result['rootCause']}';
      }
    });
  }

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
              widget.deviceName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Diagnostics',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.reliabilityService,
        builder: (context, _) {
          final svc = widget.reliabilityService;

          if (svc.loading && svc.activeIncidents.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final incidents = svc.activeIncidents
              .where((i) => i.deviceId == widget.deviceId)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Last Diagnosis Result ──────────────────────────────
              if (_lastDiagnosis != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.science_outlined, color: Color(0xFF22C55E), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lastDiagnosis!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Incidents ─────────────────────────────────────────
              Text(
                'Active Incidents',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              if (incidents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No active incidents',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This device is operating normally.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...incidents.map((inc) {
                  final diagnosing = _diagnosingId == inc.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inc.title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inc.incidentType.toDisplayLabel(),
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Signals: ${inc.signalCount} · Status: ${inc.status}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                        ),
                        if (inc.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            inc.description!,
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: diagnosing ? null : () => _runDiagnosis(inc),
                            icon: diagnosing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.science_outlined, size: 16),
                            label: Text(diagnosing ? 'Diagnosing…' : 'Run Diagnosis'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
