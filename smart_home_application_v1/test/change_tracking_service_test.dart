import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_application_v1/core/services/change_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChangeTrackingService.instance.init();
    await ChangeTrackingService.instance.clearChanges();
  });

  group('ChangeTrackingService Tests', () {
    test('Records new creation correctly', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'room',
        entityId: 'room_balcony',
        field: 'name',
        oldValue: null,
        newValue: 'Balcony',
        changeType: ChangeType.created,
      );

      expect(ChangeTrackingService.instance.hasPendingChanges, isTrue);
      expect(ChangeTrackingService.instance.pendingChanges.length, 1);
      final change = ChangeTrackingService.instance.pendingChanges.first;
      expect(change.entityType, 'room');
      expect(change.field, 'name');
      expect(change.newValue, 'Balcony');
      expect(change.changeType, ChangeType.created);
      expect(change.area, 'Spaces & Rooms');
      expect(change.displaySummary, 'Room added: Balcony');
    });

    test('Records modifications and tracks changes by area', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: 'dev_123',
        field: 'name',
        oldValue: 'Smart Switch',
        newValue: 'Living Room Main Light',
        changeType: ChangeType.modified,
      );

      final changes = ChangeTrackingService.instance.changesByArea;
      expect(changes.containsKey('Connected Hardware Nodes'), isTrue);
      expect(changes['Connected Hardware Nodes']!.length, 1);
      expect(changes['Connected Hardware Nodes']!.first.displaySummary,
          'Device renamed: Smart Switch → Living Room Main Light');
    });

    test('Created entity then deleted locally cancels out completely', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'room',
        entityId: 'room_temp',
        field: 'name',
        oldValue: null,
        newValue: 'Temporary Room',
        changeType: ChangeType.created,
      );
      expect(ChangeTrackingService.instance.hasPendingChanges, isTrue);

      await ChangeTrackingService.instance.recordChange(
        entityType: 'room',
        entityId: 'room_temp',
        field: 'name',
        oldValue: 'Temporary Room',
        newValue: null,
        changeType: ChangeType.deleted,
      );

      expect(ChangeTrackingService.instance.hasPendingChanges, isFalse);
      expect(ChangeTrackingService.instance.pendingChanges, isEmpty);
    });

    test('Modified entity then deleted preserves original oldValue and marks deleted', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: 'dev_old',
        field: 'name',
        oldValue: 'Original Switch',
        newValue: 'Updated Switch',
        changeType: ChangeType.modified,
      );

      await ChangeTrackingService.instance.recordChange(
        entityType: 'device',
        entityId: 'dev_old',
        field: 'name',
        oldValue: 'Updated Switch',
        newValue: null,
        changeType: ChangeType.deleted,
      );

      expect(ChangeTrackingService.instance.hasPendingChanges, isTrue);
      final change = ChangeTrackingService.instance.pendingChanges.first;
      expect(change.changeType, ChangeType.deleted);
      expect(change.oldValue, 'Original Switch');
      expect(change.newValue, isNull);
    });

    test('Reverting value back to original oldValue removes pending change', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'home',
        entityId: 'home_1',
        field: 'timezone',
        oldValue: 'UTC',
        newValue: 'America/New_York',
        changeType: ChangeType.modified,
      );
      expect(ChangeTrackingService.instance.hasPendingChanges, isTrue);

      // Revert back
      await ChangeTrackingService.instance.recordChange(
        entityType: 'home',
        entityId: 'home_1',
        field: 'timezone',
        oldValue: 'America/New_York',
        newValue: 'UTC',
        changeType: ChangeType.modified,
      );

      expect(ChangeTrackingService.instance.hasPendingChanges, isFalse);
    });

    test('Identical oldValue and newValue is ignored', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'home',
        entityId: 'home_1',
        field: 'timezone',
        oldValue: 'Asia/Kolkata',
        newValue: 'Asia/Kolkata',
        changeType: ChangeType.modified,
      );

      expect(ChangeTrackingService.instance.hasPendingChanges, isFalse);
    });

    test('clearChanges clears all records', () async {
      await ChangeTrackingService.instance.recordChange(
        entityType: 'room',
        entityId: 'r1',
        field: 'name',
        oldValue: null,
        newValue: 'Kitchen',
        changeType: ChangeType.created,
      );
      expect(ChangeTrackingService.instance.hasPendingChanges, isTrue);

      await ChangeTrackingService.instance.clearChanges();
      expect(ChangeTrackingService.instance.hasPendingChanges, isFalse);
      expect(ChangeTrackingService.instance.pendingChanges, isEmpty);
    });
  });
}

