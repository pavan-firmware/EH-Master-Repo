import 'package:flutter/material.dart';

import '../../../app/home_controller.dart';
import '../../../core/models/routine_models.dart';
import '../../../core/repositories/cloud_home_repository.dart';
import '../../../core/repositories/cloud_routine_repository.dart';
import '../../../core/services/edge_routine_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import 'automations_page.dart';

/// Shows a dialog prompting the user to disable the active routine before manual control
Future<bool> confirmRoutineInterruption(BuildContext context, Routine routine) async {
  return await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Routine in Progress'),
      content: Text(
        'This switch is currently running routine "${routine.name}".\n\nTurn off the routine to enable manual control?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dCtx, false);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoutineDetailPage(
                  routine: routine,
                  repository: const PreviewRoutineRepository(),
                ),
              ),
            );
          },
          child: const Text('View Routine'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dCtx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await const PreviewRoutineRepository().disableRoutine(routine.id);
            final ctrl = HomeController.instance;
            if (ctrl != null) {
              if (ctrl.repository is CloudHomeRepository) {
                try {
                  final cloudRepo = CloudRoutineRepository(
                    (ctrl.repository as CloudHomeRepository).client,
                    activeHomeId: ctrl.activeHomeId,
                  );
                  await cloudRepo.disableRoutine(routine.id);
                } catch (_) {}
              }
              for (final action in routine.actions) {
                final devId = action.deviceId.isNotEmpty
                    ? action.deviceId
                    : (ctrl.devices.isNotEmpty ? ctrl.devices.first.id : '');
                final channels = action.channelIndex == 0
                    ? [1, 2, 3, 4]
                    : [action.channelIndex];
                for (final ch in channels) {
                  if (devId.isNotEmpty) {
                    if (action.targetState || action.isToggle) {
                      await ctrl.setDeviceChannelPower(
                        deviceId: devId,
                        channelIndex: ch,
                        value: false,
                      );
                    }
                    EdgeRoutineSyncService.instance.clearActiveRoutineExecution(devId, ch);
                  }
                }
              }
              await ctrl.refreshUpcomingRoutines();
              ctrl.notifyListeners();
            }
            if (dCtx.mounted) Navigator.pop(dCtx, true);
          },
          child: const Text('Turn Off Routine'),
        ),
      ],
    ),
  ) ?? false;
}

/// Compact badge displayed when a switch or control is actively participating in a routine
class ActiveRoutineBadge extends StatelessWidget {
  const ActiveRoutineBadge({
    super.key,
    required this.routine,
    this.showRoutineName = false,
  });

  final Routine routine;
  final bool showRoutineName;

  @override
  Widget build(BuildContext context) {
    final text = showRoutineName ? 'Routine: ${routine.name}' : 'In Routine';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD97706),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoutineDetailPage(
                    routine: routine,
                    repository: const PreviewRoutineRepository(),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }
}

/// Full-card warning overlay that completely replaces normal control UI while a routine is running
class RoutineControlWarningOverlay extends StatelessWidget {
  const RoutineControlWarningOverlay({
    super.key,
    required this.routine,
    required this.controlTitle,
    this.isFullWidth = false,
  });

  final Routine routine;
  final String controlTitle;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    const warningAmber = Color(0xFFF59E0B);
    const warningText = Color(0xFFB45309);

    void onStopRoutinePressed() {
      confirmRoutineInterruption(context, routine);
    }

    if (isFullWidth) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.isDark
              ? const Color(0xFF231B0E)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: warningAmber.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: warningAmber.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: warningAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: warningAmber,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controlTitle.replaceAll('\n', ' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This control is being operated by a routine right now.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.isDark ? const Color(0xFFFCD34D) : warningText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onStopRoutinePressed,
              style: FilledButton.styleFrom(
                backgroundColor: warningAmber,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Stop Routine',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    // Compact Card Overlay (Half-width / Favourite tile)
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? const Color(0xFF231B0E)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warningAmber.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: warningAmber.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: warningAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: warningAmber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  controlTitle.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This control is being operated by a routine right now.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.isDark ? const Color(0xFFFCD34D) : warningText,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 26,
            child: FilledButton(
              onPressed: onStopRoutinePressed,
              style: FilledButton.styleFrom(
                backgroundColor: warningAmber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Stop Routine',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

