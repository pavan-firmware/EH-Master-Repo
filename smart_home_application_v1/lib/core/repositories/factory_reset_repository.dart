import '../models/factory_reset_models.dart';

abstract interface class FactoryResetRepository {
  Future<FactoryResetImpact> getImpact();
  Future<FactoryResetResult> executeReset({required String confirmation});
  Future<FactoryResetResult> verifyReset();
}

class PreviewFactoryResetRepository implements FactoryResetRepository {
  const PreviewFactoryResetRepository();

  @override
  Future<FactoryResetImpact> getImpact() async => const FactoryResetImpact(
        deviceId: 'SH-8EF248',
        deviceName: 'Smart Mist Maker',
        deviceModel: 'SH-8EF248',
        roomName: 'Plant Corner',
        online: true,
        routineCount: 2,
        routineNames: ['Plant care', 'Evening mist refresh'],
        activityPreserved: true,
        willHappen: [
          'The device\'s home configuration will be removed.',
          'Wi-Fi and network settings will be cleared.',
          'The device will return to setup mode.',
          'You will need to set up the device again.',
        ],
        willNotHappen: [
          'Your EH account will not be deleted.',
          'Other devices and homes will not be affected.',
          'Activity history will remain unless you delete it.',
        ],
      );

  @override
  Future<FactoryResetResult> executeReset({required String confirmation}) async {
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
