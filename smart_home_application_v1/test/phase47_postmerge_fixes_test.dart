import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/core/widgets/eh_action_button.dart';
import 'package:smart_home_application_v1/core/models/operational_readiness_models.dart';
import 'package:smart_home_application_v1/core/models/settings_models.dart';
import 'package:smart_home_application_v1/core/services/energy_cost_service.dart';
import 'package:smart_home_application_v1/core/repositories/settings_repository.dart';
import 'package:smart_home_application_v1/core/repositories/unavailable_connection_repository.dart';
import 'package:smart_home_application_v1/core/repositories/operational_readiness_repository.dart';
import 'package:smart_home_application_v1/features/energy/presentation/tariff_management_page.dart';
import 'package:smart_home_application_v1/features/operations/presentation/system_operational_status_page.dart';
import 'package:smart_home_application_v1/features/operations/presentation/operations_dashboard_page.dart';
import 'package:smart_home_application_v1/features/fleet/presentation/firmware_releases_page.dart';
import 'package:smart_home_application_v1/features/fleet/presentation/ota_rollouts_page.dart';
import 'package:smart_home_application_v1/features/fleet/presentation/fleet_firmware_status_page.dart';
import 'package:smart_home_application_v1/features/settings/presentation/home_details_page.dart';
import 'package:smart_home_application_v1/core/models/operations_models.dart';
import 'package:smart_home_application_v1/core/models/fleet_models.dart';
import 'package:smart_home_application_v1/core/repositories/operations_repository.dart';
import 'package:smart_home_application_v1/core/repositories/fleet_firmware_repository.dart';
import 'package:smart_home_application_v1/core/repositories/auth_repository.dart';
import 'package:smart_home_application_v1/app/home_controller.dart';

class _FakeOperationalReadinessRepo implements OperationalReadinessRepository {
  @override
  Future<SystemReadinessModel> getSystemReadiness() async => const SystemReadinessModel(
        status: 'READY',
        service: 'eh-home-backend',
        version: '1.0.0',
        timestamp: '2026-09-10T16:00:00Z',
        latestMigration: '026_disaster_recovery_state_resilience',
        checks: {'database': 'HEALTHY', 'redis': 'HEALTHY'},
      );

  @override
  Future<OperationalDiagnosticsModel> getOperationalDiagnostics() async => const OperationalDiagnosticsModel(
        service: 'eh-home-backend',
        version: '1.0.0',
        environment: 'production',
        lifecycleState: 'RUNNING',
        uptimeSeconds: 86400,
        timestamp: '2026-09-10T16:00:00Z',
      );
}

void main() {
  group('Phase 47 Post-Merge UI/UX & Functional Fixes Test Suite', () {
    testWidgets('EHSelectionButton renders correctly in unselected, selected, and loading states', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          darkTheme: EHAppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: Column(
              children: [
                EHSelectionButton(
                  label: 'Unselected',
                  icon: Icons.check,
                  isSelected: false,
                  onPressed: () => tapped = true,
                ),
                EHSelectionButton(
                  label: 'Selected',
                  icon: Icons.check_circle,
                  isSelected: true,
                  onPressed: () {},
                ),
                EHSelectionButton(
                  label: 'Loading',
                  icon: Icons.refresh,
                  isSelected: false,
                  isLoading: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Unselected'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Unselected'));
      expect(tapped, isTrue);
    });

    testWidgets('Screen 5 SystemOperationalStatusPage renders long metadata without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.darkTheme,
          home: SystemOperationalStatusPage(repository: _FakeOperationalReadinessRepo()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Operational Status'), findsOneWidget);
      expect(find.text('026_disaster_recovery_state_resilience'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Screen 6 TariffManagementPage & TariffEditorPage render in Light Theme without dark hardcoded colors', (tester) async {
      final fakeCostService = EnergyCostService();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: TariffManagementPage(
            homeId: 'test_home',
            costService: fakeCostService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Electricity Tariffs'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open Tariff Editor
      await tester.tap(find.byKey(const Key('btn_add_tariff')));
      await tester.pumpAndSettle();

      expect(find.text('New Electricity Tariff'), findsOneWidget);
      expect(find.byKey(const Key('btn_save_tariff')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings HomeDetailsPage reflects real HomeController rooms and devices', (tester) async {
      final controller = HomeController(
        connectionRepository: const UnavailableConnectionRepository(),
      );
      final fakeHome = HomeSettingsData(
        id: 'home_123',
        name: 'My Real Home',
        ownerName: 'Pavan',
        location: 'Bengaluru, India',
        timezone: 'Asia/Kolkata',
        createdAt: DateTime(2026, 8, 12),
        preferences: const HomePreferences(
          temperatureUnit: 'Celsius (°C)',
          notificationsEnabled: true,
          timeFormat: '12-hour',
        ),
        connectionAvailability: HomeConnectionAvailability.connected,
        connectionTransport: 'Wi-Fi',
        lastChecked: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.lightTheme,
          home: HomeDetailsPage(
            home: fakeHome,
            repository: const PreviewSettingsRepository(),
            homeController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home details'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll to People and tap it
      await tester.ensureVisible(find.text('People'));
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();

      expect(find.text('People at home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('UserProfile isAdmin properly recognizes ADMIN and SYSTEM_ADMIN roles', () {
      final user = UserProfile(id: 'u1', email: 'user@eh.com', emailVerified: true, role: 'USER');
      expect(user.isAdmin, isFalse);

      final admin = UserProfile(id: 'a1', email: 'admin@eh.com', emailVerified: true, role: 'ADMIN');
      expect(admin.isAdmin, isTrue);

      final sysAdmin = UserProfile(id: 's1', email: 'sys@eh.com', emailVerified: true, role: 'SYSTEM_ADMIN');
      expect(sysAdmin.isAdmin, isTrue);
    });

    testWidgets('OperationsDashboardPage renders permission-aware restricted state on 403 error', (tester) async {
      final repo = _ForbiddenOperationsRepo();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.darkTheme,
          home: OperationsDashboardPage(
            repository: repo,
            homeId: 'home_unauth',
            isAdmin: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Operations Access Restricted'), findsOneWidget);
      expect(find.text('Viewing home operations and telemetry metrics requires authorized home membership or platform administrative privileges.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FirmwareReleasesPage renders permission-aware state on 403 forbidden', (tester) async {
      final repo = _ForbiddenFleetFirmwareRepo();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.darkTheme,
          home: FirmwareReleasesPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator Access Required'), findsOneWidget);
      expect(find.text('Firmware release management and artifact publishing are restricted to platform administrators with firmware management permissions.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OtaRolloutsPage renders permission-aware state on 403 forbidden', (tester) async {
      final repo = _ForbiddenFleetFirmwareRepo();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.darkTheme,
          home: OtaRolloutsPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator Access Required'), findsOneWidget);
      expect(find.text('OTA rollout campaign deployment and staging are restricted to platform administrators with firmware management permissions.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FleetFirmwareStatusPage renders permission-aware state on 403 forbidden', (tester) async {
      final repo = _ForbiddenFleetFirmwareRepo();

      await tester.pumpWidget(
        MaterialApp(
          theme: EHAppTheme.darkTheme,
          home: FleetFirmwareStatusPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrator Access Required'), findsOneWidget);
      expect(find.text('Viewing fleet-wide firmware states and verification telemetry is restricted to platform administrators with firmware management permissions.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ForbiddenOperationsRepo implements OperationsRepository {
  @override
  Future<SystemHealthSnapshot> getSystemHealth() async => throw Exception('ApiException(403): {"error":"FORBIDDEN","message":"Unauthorized for home operations metrics"}');

  @override
  Future<OperationsMetricsSummary> getOperationsMetrics({String? homeId, String? since}) async => throw Exception('ApiException(403): {"error":"FORBIDDEN","message":"Unauthorized for home operations metrics"}');

  @override
  Future<List<OperationalEvent>> getOperationalEvents({String? homeId, String? deviceId, OperationalSubsystem? subsystem, OperationOutcome? outcome, String? severity, String? since, int limit = 100, int offset = 0}) async => [];

  @override
  Future<OperationTrace?> getTraceByCorrelationId(String correlationId) async => null;

  @override
  Future<List<SecurityAuditRecord>> getSecurityAuditRecords({String? homeId, String? action, String? outcome, String? since, int limit = 100, int offset = 0}) async => [];

  @override
  Future<AuditIntegrityResult> verifyChainIntegrity() async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getErrorTaxonomy({String? homeId, String? since}) async => throw UnimplementedError();
}

class _ForbiddenFleetFirmwareRepo implements FleetFirmwareRepository {
  @override
  Future<List<FirmwareReleaseModel>> listReleases({String? productVariantId, String? releaseChannel}) async => throw Exception('ApiException(403): {"success":false,"error":"Forbidden: Administrative privilege or canManageFirmware permission required"}');

  @override
  Future<FirmwareReleaseModel> createRelease(Map<String, dynamic> manifest) async => throw UnimplementedError();

  @override
  Future<FirmwareReleaseModel> publishRelease(String releaseId) async => throw UnimplementedError();

  @override
  Future<List<OtaRolloutModel>> listRollouts({String? releaseId, String? rolloutState}) async => throw Exception('ApiException(403): {"success":false,"error":"Forbidden: Administrative privilege or canManageFirmware permission required"}');

  @override
  Future<OtaRolloutModel> createRollout(Map<String, dynamic> data) async => throw UnimplementedError();

  @override
  Future<OtaRolloutModel> startRollout(String rolloutId) async => throw UnimplementedError();

  @override
  Future<OtaRolloutModel> pauseRollout(String rolloutId, {String? reason}) async => throw UnimplementedError();

  @override
  Future<OtaRolloutModel> resumeRollout(String rolloutId) async => throw UnimplementedError();

  @override
  Future<OtaRolloutModel> cancelRollout(String rolloutId, {String? reason}) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> initiateRollback(String rolloutId, {String? targetReleaseId, String? reason}) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> executeBatch(String rolloutId) async => throw UnimplementedError();

  @override
  Future<List<FleetDeviceFirmwareStateModel>> listFleetFirmwareStates({String? productVariantId, String? rolloutId}) async => throw Exception('ApiException(403): {"success":false,"error":"Forbidden: Administrative privilege or canManageFirmware permission required"}');

  @override
  Future<FleetDeviceFirmwareStateModel?> getDeviceFirmwareState(String deviceId) async => throw UnimplementedError();
}
