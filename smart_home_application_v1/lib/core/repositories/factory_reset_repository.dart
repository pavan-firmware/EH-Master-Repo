import '../../app/home_controller.dart';
import '../models/factory_reset_models.dart';
import '../models/routine_models.dart';

abstract interface class FactoryResetRepository {
  Future<FactoryResetImpact> getImpact();
  Future<FactoryResetResult> executeReset({required String confirmation});
  Future<FactoryResetResult> verifyReset();
}

class PreviewFactoryResetRepository implements FactoryResetRepository {
  const PreviewFactoryResetRepository();

  @override
  Future<FactoryResetImpact> getImpact() async {
    final ctrl = HomeController.instance;
    final homeName = ctrl?.activeSpaceName ?? 'Current Home';
    final primary = ctrl?.connectedDeviceSummary ??
        (ctrl?.devices.isNotEmpty == true ? ctrl!.devices.first : null);
    final routines = PreviewRoutineRepository.liveRoutines;

    return FactoryResetImpact(
      deviceId: primary?.id ?? (ctrl?.activeHomeId ?? 'home_main'),
      deviceName: primary?.name ?? homeName,
      deviceModel: primary?.model ?? 'EH-HOME-HUB',
      roomName: primary?.roomName.isNotEmpty == true ? primary!.roomName : 'All Rooms',
      online: primary?.online ?? true,
      routineCount: routines.length,
      routineNames: routines.map((r) => r.name).take(3).toList(),
      activityPreserved: true,
      willHappen: const [
        'The device\'s home configuration will be removed.',
        'Wi-Fi and network settings will be cleared.',
        'The device will return to setup mode.',
        'You will need to set up the device again.',
      ],
      willNotHappen: const [
        'Your EH account will not be deleted.',
        'Other devices and homes will not be affected.',
        'Activity history will remain unless you delete it.',
      ],
    );
  }

  @override
  Future<FactoryResetResult> executeReset({
    required String confirmation,
  }) async {
    if (confirmation != 'RESET') {
      return const FactoryResetResult(
        success: false,
        message: 'Type RESET to continue.',
        state: FactoryResetState.confirmationRequired,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return const FactoryResetResult(
      success: true,
      message: 'Reset command sent to device.',
      state: FactoryResetState.resetting,
    );
  }

  @override
  Future<FactoryResetResult> verifyReset() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return const FactoryResetResult(
      success: true,
      message: 'Device returned to setup mode.',
      state: FactoryResetState.completed,
    );
  }
}
