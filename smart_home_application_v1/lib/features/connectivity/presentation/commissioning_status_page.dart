import 'package:flutter/material.dart';
import '../../../core/models/connectivity_models.dart';
import '../../../core/services/connectivity_service.dart';

/// Phase 26 — Commissioning Status Page
///
/// Multi-step timeline visualizing commissioning lifecycle progress:
///   Discovered -> Ready -> Started -> Authenticating -> Joining -> Verifying -> Completed
class CommissioningStatusPage extends StatefulWidget {
  final String sessionId;
  final String deviceName;
  final CommissioningSession session;
  final ConnectivityService connectivityService;

  const CommissioningStatusPage({
    super.key,
    required this.sessionId,
    required this.deviceName,
    required this.session,
    required this.connectivityService,
  });

  @override
  State<CommissioningStatusPage> createState() => _CommissioningStatusPageState();
}

class _CommissioningStatusPageState extends State<CommissioningStatusPage> {
  final List<CommissioningStage> _pipeline = const [
    CommissioningStage.discovered,
    CommissioningStage.ready,
    CommissioningStage.started,
    CommissioningStage.authenticating,
    CommissioningStage.networkJoining,
    CommissioningStage.verifying,
    CommissioningStage.completed,
  ];

  int _stageIndex(CommissioningStage s) => _pipeline.indexOf(s);

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Commissioning?'),
        content: const Text('This will abort the pairing process for this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Pairing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Pairing')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await widget.connectivityService.cancelCommissioning(widget.sessionId);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel session'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentStage = widget.session.stage;
    final currentIdx = _stageIndex(currentStage);
    final isDone = currentStage == CommissioningStage.completed;
    final isFailed = currentStage == CommissioningStage.failed || currentStage == CommissioningStage.cancelled;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Text(widget.deviceName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF22C55E)
                    : isFailed
                    ? const Color(0xFFEF4444)
                    : colorScheme.primary,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (!isDone && !isFailed)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isDone ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    size: 28,
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStage.toDisplayLabel(),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Protocol: ${widget.session.transportType.toDisplayLabel()}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Pairing Pipeline',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // Timeline Steps
          ..._pipeline.asMap().entries.map((entry) {
            final idx = entry.key;
            final stage = entry.value;
            final isCompleted = currentIdx > idx || isDone;
            final isCurrent = currentIdx == idx && !isDone && !isFailed;
            final isLast = idx == _pipeline.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? const Color(0xFF22C55E)
                              : isCurrent
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent ? Colors.white : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isCompleted
                                ? const Color(0xFF22C55E)
                                : colorScheme.surfaceContainerHighest,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      stage.toDisplayLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCompleted || isCurrent
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          if (!isDone && !isFailed)
            OutlinedButton(
              onPressed: _handleCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
              ),
              child: const Text('Cancel Commissioning'),
            ),
        ],
      ),
    );
  }
}
