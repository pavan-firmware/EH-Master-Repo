import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/api/api_client.dart';
import 'package:smart_home_application_v1/core/config/app_config.dart';
import 'package:smart_home_application_v1/core/services/connectivity_service.dart';
import 'package:smart_home_application_v1/core/services/context_presence_service.dart';
import 'package:smart_home_application_v1/core/services/edge_control_service.dart';
import 'package:smart_home_application_v1/core/services/energy_automation_service.dart';
import 'package:smart_home_application_v1/core/services/energy_cost_service.dart';
import 'package:smart_home_application_v1/core/services/energy_predictive_service.dart';
import 'package:smart_home_application_v1/core/services/energy_service.dart';
import 'package:smart_home_application_v1/core/services/fleet_management_service.dart';
import 'package:smart_home_application_v1/core/services/intelligence_service.dart';
import 'package:smart_home_application_v1/core/services/matter_service.dart';
import 'package:smart_home_application_v1/core/services/product_catalog_service.dart';
import 'package:smart_home_application_v1/core/services/reliability_service.dart';
import 'package:smart_home_application_v1/core/services/sync_service.dart';

void main() {
  group('Backend Base URL Centralization & Propagation Tests', () {
    setUp(() {
      AppConfig.setBaseUrl(null);
    });

    tearDown(() {
      AppConfig.setBaseUrl(null);
    });

    test('All services resolve to canonical AppConfig.backendBaseUrl by default', () {
      final canonicalUrl = AppConfig.backendBaseUrl;
      expect(canonicalUrl, isNotEmpty);

      final apiClient = ApiClient(baseUrl: canonicalUrl);
      final syncService = SyncService();
      final energyService = EnergyService();
      final energyAutomationService = EnergyAutomationService();
      final energyCostService = EnergyCostService();
      final energyPredictiveService = EnergyPredictiveService();
      final intelligenceService = HomeIntelligenceService();
      final fleetService = FleetManagementService();
      final matterService = MatterService();
      final connectivityService = ConnectivityService();
      final edgeService = EdgeControlService();
      final catalogService = ProductCatalogClientService();
      final presenceService = ContextPresenceService();
      final reliabilityService = ReliabilityService();

      expect(apiClient.baseUrl, equals(canonicalUrl));
      expect(syncService.baseUrl, equals(canonicalUrl));
      expect(energyService.baseUrl, equals(canonicalUrl));
      expect(energyAutomationService.baseUrl, equals(canonicalUrl));
      expect(energyCostService.baseUrl, equals(canonicalUrl));
      expect(energyPredictiveService.baseUrl, equals(canonicalUrl));
      expect(intelligenceService.baseUrl, equals(canonicalUrl));
      expect(fleetService.baseUrl, equals(canonicalUrl));
      expect(matterService.baseUrl, equals(canonicalUrl));
      expect(connectivityService.baseUrl, equals(canonicalUrl));
      expect(edgeService.baseUrl, equals(canonicalUrl));
      expect(catalogService.baseUrl, equals(canonicalUrl));
      expect(presenceService.baseUrl, equals(canonicalUrl));
      expect(reliabilityService.baseUrl, equals(canonicalUrl));
    });

    test('Runtime override dynamically updates default for all services uniformly', () {
      const customUrl = 'http://127.0.0.1:3000';
      AppConfig.setBaseUrl(customUrl);

      expect(AppConfig.backendBaseUrl, equals(customUrl));

      final apiClient = ApiClient(baseUrl: AppConfig.backendBaseUrl);
      final syncService = SyncService();
      final energyService = EnergyService();
      final energyAutomationService = EnergyAutomationService();
      final energyCostService = EnergyCostService();
      final energyPredictiveService = EnergyPredictiveService();
      final intelligenceService = HomeIntelligenceService();
      final fleetService = FleetManagementService();
      final matterService = MatterService();
      final connectivityService = ConnectivityService();
      final edgeService = EdgeControlService();
      final catalogService = ProductCatalogClientService();
      final presenceService = ContextPresenceService();
      final reliabilityService = ReliabilityService();

      expect(apiClient.baseUrl, equals(customUrl));
      expect(syncService.baseUrl, equals(customUrl));
      expect(energyService.baseUrl, equals(customUrl));
      expect(energyAutomationService.baseUrl, equals(customUrl));
      expect(energyCostService.baseUrl, equals(customUrl));
      expect(energyPredictiveService.baseUrl, equals(customUrl));
      expect(intelligenceService.baseUrl, equals(customUrl));
      expect(fleetService.baseUrl, equals(customUrl));
      expect(matterService.baseUrl, equals(customUrl));
      expect(connectivityService.baseUrl, equals(customUrl));
      expect(edgeService.baseUrl, equals(customUrl));
      expect(catalogService.baseUrl, equals(customUrl));
      expect(presenceService.baseUrl, equals(customUrl));
      expect(reliabilityService.baseUrl, equals(customUrl));
    });

    test('Explicit baseUrl parameter overrides default AppConfig', () {
      AppConfig.setBaseUrl('http://127.0.0.1:3000');
      const explicitUrl = 'http://192.168.1.100:3000';

      final syncService = SyncService(baseUrl: explicitUrl);
      final energyService = EnergyService(baseUrl: explicitUrl);
      final catalogService = ProductCatalogClientService(baseUrl: explicitUrl);

      expect(syncService.baseUrl, equals(explicitUrl));
      expect(energyService.baseUrl, equals(explicitUrl));
      expect(catalogService.baseUrl, equals(explicitUrl));
    });
  });
}
