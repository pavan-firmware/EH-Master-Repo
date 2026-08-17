enum RoutineAvailability { available, partiallyAvailable, unavailable }

enum RoutineExecutionResult { succeeded, failed }

enum RoutineValidationState { valid, incomplete, invalid, conflict, unsupported }

enum RoutineTriggerKind { soilMoisture, darkness, waterLevel }

enum RoutineActionKind { mistMaker, light, notification }

class DeviceCapabilityInfo {
  const DeviceCapabilityInfo({
    required this.id,
    required this.type,
    required this.readable,
    required this.writable,
    required this.operations,
  });

  final String id;
  final String type;
  final bool readable;
  final bool writable;
  final List<String> operations;
}

class RoutineDevice {
  const RoutineDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.online,
    required this.capabilities,
  });

  final String id;
  final String name;
  final String room;
  final bool online;
  final List<DeviceCapabilityInfo> capabilities;
}

class RoutineTrigger {
  const RoutineTrigger({
    required this.kind,
    required this.title,
    required this.detail,
    this.threshold,
  });

  final RoutineTriggerKind kind;
  final String title;
  final String detail;
  final double? threshold;
}

class RoutineCondition {
  const RoutineCondition({required this.title, required this.detail});
  final String title;
  final String detail;
}

class RoutineAction {
  const RoutineAction({
    required this.kind,
    required this.title,
    required this.detail,
    required this.deviceId,
  });

  final RoutineActionKind kind;
  final String title;
  final String detail;
  final String deviceId;
}

class RoutineSchedule {
  const RoutineSchedule({
    required this.label,
    required this.timezone,
    this.days = const [],
  });

  final String label;
  final String timezone;
  final List<String> days;
}

class RoutineExecution {
  const RoutineExecution({
    required this.id,
    required this.routineId,
    required this.startedAt,
    required this.completedAt,
    required this.result,
    required this.message,
    this.failureReason,
    this.affectedDevices = const [],
  });

  final String id;
  final String routineId;
  final DateTime startedAt;
  final DateTime completedAt;
  final RoutineExecutionResult result;
  final String message;
  final String? failureReason;
  final List<String> affectedDevices;
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.icon,
    required this.isFavorite,
    required this.enabled,
    required this.availability,
    required this.trigger,
    required this.conditions,
    required this.actions,
    required this.schedule,
    required this.involvedDevices,
    required this.lastExecution,
    required this.nextRun,
    required this.createdAt,
    required this.updatedAt,
    required this.summary,
  });

  final String id;
  final String name;
  final String icon;
  final bool isFavorite;
  final bool enabled;
  final RoutineAvailability availability;
  final RoutineTrigger trigger;
  final List<RoutineCondition> conditions;
  final List<RoutineAction> actions;
  final RoutineSchedule schedule;
  final List<RoutineDevice> involvedDevices;
  final RoutineExecution? lastExecution;
  final String? nextRun;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String summary;

  String get availabilityLabel => switch (availability) {
    RoutineAvailability.available => 'Ready to run',
    RoutineAvailability.partiallyAvailable => 'Some devices unavailable',
    RoutineAvailability.unavailable => 'Device unavailable',
  };

  String get statusLabel => enabled ? 'Enabled' : 'Disabled';
}

class RoutineDraft {
  RoutineDraft({
    this.name = '',
    this.icon = 'auto_awesome',
    this.isFavorite = false,
    this.trigger,
    this.conditions = const [],
    this.actions = const [],
    this.schedule,
    this.validation = const RoutineValidation(),
  });

  String name;
  String icon;
  bool isFavorite;
  RoutineTrigger? trigger;
  List<RoutineCondition> conditions;
  List<RoutineAction> actions;
  RoutineSchedule? schedule;
  RoutineValidation validation;
}

class RoutineValidation {
  const RoutineValidation({
    this.state = RoutineValidationState.incomplete,
    this.errors = const [],
    this.warnings = const [],
  });

  final RoutineValidationState state;
  final List<String> errors;
  final List<String> warnings;
  bool get isValid => state == RoutineValidationState.valid;
}

enum RepositoryResult { success, unavailable, unauthorized, unsupported, failed }

abstract class RoutineRepository {
  Future<List<Routine>> getRoutines();
  Future<Routine?> getRoutine(String id);
  Future<List<RoutineExecution>> getRecentExecutions(String id);
  Future<RepositoryResult> createRoutine(RoutineDraft draft);
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft);
  Future<RepositoryResult> deleteRoutine(String id);
  Future<RepositoryResult> enableRoutine(String id);
  Future<RepositoryResult> disableRoutine(String id);
  Future<RepositoryResult> executeRoutine(String id);
}

class PreviewRoutineRepository implements RoutineRepository {
  const PreviewRoutineRepository();

  static final _time = DateTime(2026, 8, 13, 14, 32);

  static final _devices = <RoutineDevice>[
    RoutineDevice(
      id: 'soil',
      name: 'Soil moisture sensor',
      room: 'Plant Corner',
      online: true,
      capabilities: [
        DeviceCapabilityInfo(
          id: 'soil-read',
          type: 'soilMoisture',
          readable: true,
          writable: false,
          operations: ['read'],
        ),
      ],
    ),
    RoutineDevice(
      id: 'mist',
      name: 'Mist maker',
      room: 'Plant Corner',
      online: false,
      capabilities: [
        DeviceCapabilityInfo(
          id: 'mist-power',
          type: 'power',
          readable: true,
          writable: true,
          operations: ['on', 'off', 'runFor'],
        ),
      ],
    ),
    RoutineDevice(
      id: 'living-light',
      name: 'Living room light',
      room: 'Living Room',
      online: true,
      capabilities: [
        DeviceCapabilityInfo(
          id: 'light-power',
          type: 'power',
          readable: true,
          writable: true,
          operations: ['on', 'off'],
        ),
      ],
    ),
    RoutineDevice(
      id: 'living-ldr',
      name: 'Light sensor',
      room: 'Living Room',
      online: true,
      capabilities: [
        DeviceCapabilityInfo(
          id: 'ambient-light',
          type: 'ambientLight',
          readable: true,
          writable: false,
          operations: ['read'],
        ),
      ],
    ),
    RoutineDevice(
      id: 'tank',
      name: 'Water level sensor',
      room: 'Water Tank',
      online: true,
      capabilities: [
        DeviceCapabilityInfo(
          id: 'water-level',
          type: 'waterLevel',
          readable: true,
          writable: false,
          operations: ['read'],
        ),
      ],
    ),
  ];

  static final _history = <String, List<RoutineExecution>>{
    'plant-care': [
      RoutineExecution(
        id: 'run-1',
        routineId: 'plant-care',
        startedAt: _time,
        completedAt: _time.add(const Duration(seconds: 30)),
        result: RoutineExecutionResult.failed,
        message: 'Couldnâ€™t start mist maker',
        failureReason: 'Mist maker is offline.',
        affectedDevices: ['mist'],
      ),
      RoutineExecution(
        id: 'run-2',
        routineId: 'plant-care',
        startedAt: DateTime(2026, 8, 12, 11, 8),
        completedAt: DateTime(2026, 8, 12, 11, 8, 1),
        result: RoutineExecutionResult.succeeded,
        message: 'Condition checked',
        affectedDevices: ['soil'],
      ),
      RoutineExecution(
        id: 'activity-run-plant-1',
        routineId: 'plant-care',
        startedAt: DateTime(2026, 8, 14, 17, 10),
        completedAt: DateTime(2026, 8, 14, 17, 10, 30),
        result: RoutineExecutionResult.succeeded,
        message: 'Mist maker ran for 30 seconds',
        affectedDevices: ['mist'],
      ),
    ],
    'night-light': [
      RoutineExecution(
        id: 'run-3',
        routineId: 'night-light',
        startedAt: DateTime(2026, 8, 12, 19, 20),
        completedAt: DateTime(2026, 8, 12, 19, 20, 1),
        result: RoutineExecutionResult.succeeded,
        message: 'Living room light turned on',
        affectedDevices: ['living-light'],
      ),
    ],
    'tank-reminder': [],
  };

  @override
  Future<List<Routine>> getRoutines() async => _routines;

  @override
  Future<Routine?> getRoutine(String id) async {
    for (final routine in _routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  @override
  Future<List<RoutineExecution>> getRecentExecutions(String id) async => _history[id] ?? [];

  @override
  Future<RepositoryResult> createRoutine(RoutineDraft draft) async => RepositoryResult.unsupported;

  @override
  Future<RepositoryResult> updateRoutine(String id, RoutineDraft draft) async => RepositoryResult.unsupported;

  @override
  Future<RepositoryResult> deleteRoutine(String id) async => RepositoryResult.unsupported;

  @override
  Future<RepositoryResult> enableRoutine(String id) async => RepositoryResult.unsupported;

  @override
  Future<RepositoryResult> disableRoutine(String id) async => RepositoryResult.unsupported;

  @override
  Future<RepositoryResult> executeRoutine(String id) async => RepositoryResult.unsupported;

  static final _routines = <Routine>[
    Routine(
      id: 'plant-care',
      name: 'Plant care',
      icon: 'plant',
      isFavorite: true,
      enabled: true,
      availability: RoutineAvailability.partiallyAvailable,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.soilMoisture,
        title: 'Soil moisture drops below 35%',
        detail: 'Mon â€“ Sun Â· All day',
        threshold: 35,
      ),
      conditions: const [RoutineCondition(title: 'Time', detail: 'All day')],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.mistMaker,
          title: 'Mist maker',
          detail: 'Run for 30 seconds',
          deviceId: 'mist',
        ),
      ],
      schedule: const RoutineSchedule(label: 'Every day Â· All day', timezone: 'Home timezone'),
      involvedDevices: [_devices[0], _devices[1]],
      lastExecution: _history['plant-care']!.first,
      nextRun: 'When soil is dry',
      createdAt: _time,
      updatedAt: _time,
      summary: 'When soil becomes dry, run the plant mist maker for 30 seconds.',
    ),
    Routine(
      id: 'night-light',
      name: 'Gentle night light',
      icon: 'night',
      isFavorite: false,
      enabled: true,
      availability: RoutineAvailability.available,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.darkness,
        title: 'Room becomes dark',
        detail: 'After sunset',
      ),
      conditions: const [],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.light,
          title: 'Living room light',
          detail: 'Turn on',
          deviceId: 'living-light',
        ),
      ],
      schedule: const RoutineSchedule(label: 'After sunset', timezone: 'Home timezone'),
      involvedDevices: [_devices[2], _devices[3]],
      lastExecution: _history['night-light']!.first,
      nextRun: 'After sunset',
      createdAt: _time,
      updatedAt: _time,
      summary: 'When the room gets dark, turn on the living room light.',
    ),
    Routine(
      id: 'tank-reminder',
      name: 'Tank reminder',
      icon: 'water',
      isFavorite: false,
      enabled: false,
      availability: RoutineAvailability.available,
      trigger: const RoutineTrigger(
        kind: RoutineTriggerKind.waterLevel,
        title: 'Water level drops below 20%',
        detail: 'Any time',
        threshold: 20,
      ),
      conditions: const [],
      actions: const [
        RoutineAction(
          kind: RoutineActionKind.notification,
          title: 'Phone notification',
          detail: 'Send me a reminder',
          deviceId: 'tank',
        ),
      ],
      schedule: const RoutineSchedule(label: 'Any time', timezone: 'Home timezone'),
      involvedDevices: [_devices[4]],
      lastExecution: null,
      nextRun: 'When water is low',
      createdAt: _time,
      updatedAt: _time,
      summary: 'When water is low, send a reminder to your phone.',
    ),
  ];
}

class RoutineValidator {
  const RoutineValidator();

  RoutineValidation validate(RoutineDraft draft) {
    final errors = <String>[];
    final warnings = <String>[];
    if (draft.name.trim().isEmpty) errors.add('Choose a name for this routine.');
    if (draft.trigger == null) errors.add('Choose what should trigger it.');
    if (draft.actions.isEmpty) errors.add('Choose at least one action.');
    if (draft.trigger?.threshold != null &&
        (draft.trigger!.threshold! < 0 || draft.trigger!.threshold! > 100)) {
      errors.add('Choose a threshold between 0 and 100.');
    }
    if (draft.actions.any((a) => a.detail.contains('seconds') && a.detail.startsWith('0'))) {
      errors.add('Action duration must be greater than zero.');
    }
    if (draft.actions.isNotEmpty && draft.trigger != null) {
      warnings.add('The routine will run when the trigger crosses its threshold.');
    }
    final state = errors.isNotEmpty
        ? RoutineValidationState.incomplete
        : warnings.isNotEmpty
        ? RoutineValidationState.valid
        : RoutineValidationState.valid;
    return RoutineValidation(state: state, errors: errors, warnings: warnings);
  }
}

