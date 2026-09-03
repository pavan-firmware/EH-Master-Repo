import 'package:flutter/material.dart';
import '../../../core/models/reliability_models.dart';
import '../../../core/services/reliability_service.dart';

/// Phase 25 — Recovery History Page
///
/// Audit trail of all recovery attempts for a device, showing lifecycle:
/// Action → Accepted → Verify → RECOVERED / PARTIALLY_RECOVERED / FAILED
class RecoveryHistoryPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final ReliabilityService reliabilityService;

  const RecoveryHistoryPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.reliabilityService,
  });

  @override
  State<RecoveryHistoryPage> createState() => _RecoveryHistoryPageState();
}

class _RecoveryHistoryPageState extends State<RecoveryHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.reliabilityService.loadRecoveryHistory(widget.deviceId);
    });
  }

  Color _statusColor(RecoveryStatus status) => switch (status) {
    RecoveryStatus.recovered => const Color(0xFF22C55E),
    RecoveryStatus.partiallyRecovered => const Color(0xFFF59E0B),
    RecoveryStatus.failed => const Color(0xFFEF4444),
    RecoveryStatus.verifying => const Color(0xFF60A5FA),
    RecoveryStatus.executing => const Color(0xFF8B5CF6),
    RecoveryStatus.pending => const Color(0xFF9CA3AF),
  };

  IconData _statusIcon(RecoveryStatus status) => switch (status) {
    RecoveryStatus.recovered => Icons.check_circle_rounded,
    RecoveryStatus.partiallyRecovered => Icons.warning_amber_rounded,
    RecoveryStatus.failed => Icons.cancel_rounded,
    RecoveryStatus.verifying => Icons.hourglass_top_rounded,
    RecoveryStatus.executing => Icons.sync_rounded,
    RecoveryStatus.pending => Icons.schedule_rounded,
  };

  String _statusLabel(RecoveryStatus status) => switch (status) {
    RecoveryStatus.recovered => 'Recovered',
    RecoveryStatus.partiallyRecovered => 'Partially Recovered',
    RecoveryStatus.failed => 'Failed',
    RecoveryStatus.verifying => 'Verifying',
    RecoveryStatus.executing => 'Executing',
    RecoveryStatus.pending => 'Pending',
  };

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
              'Recovery History',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.reliabilityService,
        builder: (context, _) {
          final svc = widget.reliabilityService;
          if (svc.loading && svc.recoveryHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final history = svc.recoveryHistory;

          return RefreshIndicator(
            onRefresh: () => svc.loadRecoveryHistory(widget.deviceId),
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, color: colorScheme.onSurfaceVariant, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No recovery attempts yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recovery actions will appear here.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final attempt = history[index];
                      final color = _statusColor(attempt.status);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(_statusIcon(attempt.status), color: color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  attempt.actionType.toDisplayLabel(),
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusLabel(attempt.status),
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            // Recovery lifecycle steps
                            _LifecycleStep(
                              label: 'Action initiated',
                              ts: attempt.initiatedAt,
                              done: true,
                            ),
                            _LifecycleStep(
                              label: 'Command accepted',
                              ts: null,
                              done: attempt.commandAccepted,
                            ),
                            _LifecycleStep(
                              label: 'Verified',
                              ts: attempt.completedAt,
                              done: [
                                RecoveryStatus.recovered,
                                RecoveryStatus.partiallyRecovered,
                                RecoveryStatus.failed,
                              ].contains(attempt.status),
                            ),
                            if (attempt.failureReason != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${attempt.failureReason}',
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _LifecycleStep extends StatelessWidget {
  final String label;
  final DateTime? ts;
  final bool done;

  const _LifecycleStep({required this.label, this.ts, required this.done});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: done ? const Color(0xFF22C55E) : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        if (ts != null) ...[
          const Spacer(),
          Text(
            '${ts!.hour.toString().padLeft(2, '0')}:${ts!.minute.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ]),
    );
  }
}
