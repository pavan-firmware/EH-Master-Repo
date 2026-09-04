import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/models/product_catalog_models.dart';
import 'package:smart_home_application_v1/core/theme/app_theme.dart';
import 'package:smart_home_application_v1/features/product_discovery/presentation/product_card.dart';
import 'package:smart_home_application_v1/features/product_discovery/presentation/compatibility_result_widget.dart';
import 'package:smart_home_application_v1/features/product_discovery/presentation/product_detail_page.dart';
import 'package:smart_home_application_v1/features/product_discovery/presentation/product_discovery_page.dart';
import 'package:smart_home_application_v1/features/device_add/presentation/consumer_device_add_flow_page.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: EHAppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Phase 27 — Product Catalog & Discovery Models', () {
    test('ProductCatalogEntry fromJson parses canonical entry accurately', () {
      final json = {
        'productId': 'eh-smart-switch',
        'productFamilyId': 'smart_switch',
        'modelId': 'eh-switch-gen1',
        'variantId': 'eh-smart-switch-3x',
        'sku': 'EH-SW3X-001',
        'marketingName': 'EH Smart Switch 3X',
        'technicalName': 'EH-SW3X-ESP32C6',
        'description': 'Triple-channel switchboard',
        'productStatus': 'ACTIVE',
        'visibility': 'PUBLIC',
        'category': 'switches',
        'channelCount': 3,
        'capabilities': ['switch', 'relay', 'energy', 'ota'],
        'controls': ['channel_1', 'channel_2', 'channel_3'],
        'telemetry': ['v_mv', 'i_ma', 'p_mw', 'e_tot_wh'],
        'matterSupport': false,
        'threadSupport': false,
        'wifiSupport': true,
        'bleProvisioningSupport': true,
        'energyMonitoringSupport': true,
        'localControlSupport': true,
        'images': {
          'hero': 'assets/products/smart_switch_3x/hero.png',
          'front': 'assets/products/smart_switch_3x/front.png',
        },
      };

      final entry = ProductCatalogEntry.fromJson(json);

      expect(entry.variantId, 'eh-smart-switch-3x');
      expect(entry.marketingName, 'EH Smart Switch 3X');
      expect(entry.category, 'switches');
      expect(entry.channelCount, 3);
      expect(entry.energyMonitoringSupport, true);
      expect(entry.wifiSupport, true);
      expect(entry.images.hero, 'assets/products/smart_switch_3x/hero.png');
    });

    test('ProductDiscoveryResponse parses products, categories, and families', () {
      final json = {
        'total': 7,
        'page': 1,
        'limit': 20,
        'totalPages': 1,
        'categories': [
          {'id': 'switches', 'displayName': 'Smart Switches', 'count': 4},
          {'id': 'sockets', 'displayName': 'Smart Sockets', 'count': 3},
        ],
        'families': [
          {'id': 'smart_switch', 'displayName': 'Smart Switches', 'category': 'switches', 'count': 4},
        ],
        'availableCapabilities': ['switch', 'relay', 'energy'],
        'products': [
          {
            'productId': 'eh-smart-switch',
            'productFamilyId': 'smart_switch',
            'modelId': 'eh-switch-gen1',
            'variantId': 'eh-smart-switch-1x',
            'sku': 'EH-SW1X-001',
            'marketingName': 'EH Smart Switch 1X',
            'technicalName': 'EH-SW1X-ESP32C6',
            'description': 'Single-channel switch',
            'category': 'switches',
            'channelCount': 1,
          }
        ]
      };

      final resp = ProductDiscoveryResponse.fromJson(json);

      expect(resp.total, 7);
      expect(resp.categories.length, 2);
      expect(resp.families.length, 1);
      expect(resp.products.length, 1);
      expect(resp.products[0].marketingName, 'EH Smart Switch 1X');
    });

    test('ProductSearchResult parses search items and relevance scores', () {
      final json = {
        'query': 'Switch 3X',
        'total': 1,
        'results': [
          {
            'product': {
              'productId': 'eh-smart-switch',
              'productFamilyId': 'smart_switch',
              'modelId': 'eh-switch-gen1',
              'variantId': 'eh-smart-switch-3x',
              'sku': 'EH-SW3X-001',
              'marketingName': 'EH Smart Switch 3X',
              'technicalName': 'EH-SW3X-ESP32C6',
              'description': 'Triple-channel switch',
              'category': 'switches',
              'channelCount': 3,
            },
            'matchedFields': ['marketingName', 'sku'],
            'relevanceScore': 0.95,
          }
        ]
      };

      final search = ProductSearchResult.fromJson(json);

      expect(search.query, 'Switch 3X');
      expect(search.total, 1);
      expect(search.results[0].product.variantId, 'eh-smart-switch-3x');
      expect(search.results[0].relevanceScore, 0.95);
    });

    test('ProductCompatibilityResult parses status, reasons, and transports', () {
      final json = {
        'status': 'PARTIALLY_COMPATIBLE',
        'isCompatible': true,
        'reasons': [
          {
            'code': 'BLE_UNAVAILABLE',
            'message': 'Bluetooth disabled on phone',
            'severity': 'WARNING',
            'remedy': 'Turn on Bluetooth in phone settings',
          }
        ],
        'supportedTransports': ['WIFI_MQTT', 'BLE'],
        'recommendedCommissioningTransport': 'BLE',
        'unsupportedFeatures': ['thread_mesh'],
        'evaluatedAt': '2026-09-04T12:00:00Z',
      };

      final compat = ProductCompatibilityResult.fromJson(json);

      expect(compat.status, 'PARTIALLY_COMPATIBLE');
      expect(compat.isCompatible, true);
      expect(compat.reasons.length, 1);
      expect(compat.reasons[0].code, 'BLE_UNAVAILABLE');
      expect(compat.reasons[0].severity, 'WARNING');
      expect(compat.reasons[0].remedy, 'Turn on Bluetooth in phone settings');
      expect(compat.unsupportedFeatures, ['thread_mesh']);
    });

    test('DeviceAddSessionModel parses session stages and channel labels', () {
      final json = {
        'sessionId': 'das_0194fe23',
        'homeId': 'home_01',
        'userId': 'user_01',
        'entryMode': 'MANUAL_CATALOG',
        'stage': 'PRODUCT_SELECTED',
        'productVariantId': 'eh-smart-switch-3x',
        'customDeviceName': 'Living Room Switch',
        'channelLabels': {'1': 'Chandelier', '2': 'Fan'},
        'compatibilityStatus': 'COMPATIBLE',
        'createdAt': '2026-09-04T12:05:00Z',
        'updatedAt': '2026-09-04T12:05:00Z',
      };

      final session = DeviceAddSessionModel.fromJson(json);

      expect(session.sessionId, 'das_0194fe23');
      expect(session.stage, 'PRODUCT_SELECTED');
      expect(session.channelLabels['1'], 'Chandelier');
      expect(session.channelLabels['2'], 'Fan');
    });
  });

  group('Phase 27 — Flutter UI Presentation Widgets', () {
    const testProduct = ProductCatalogEntry(
      productId: 'eh-smart-switch',
      productFamilyId: 'smart_switch',
      modelId: 'eh-switch-gen1',
      variantId: 'eh-smart-switch-3x',
      sku: 'EH-SW3X-001',
      marketingName: 'EH Smart Switch 3X',
      technicalName: 'EH-SW3X-ESP32C6',
      description: 'Triple-channel modular smart switchboard with high-accuracy energy monitoring.',
      category: 'switches',
      channelCount: 3,
      wifiSupport: true,
      bleProvisioningSupport: true,
      energyMonitoringSupport: true,
      capabilities: ['switch', 'relay', 'energy', 'ota'],
      channels: [
        {'channelIndex': 1, 'defaultLabel': 'Channel 1'},
        {'channelIndex': 2, 'defaultLabel': 'Channel 2'},
        {'channelIndex': 3, 'defaultLabel': 'Channel 3'},
      ],
    );

    testWidgets('ProductCard renders marketing name, SKU, channels and energy chips', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        ProductCard(product: testProduct),
      ));

      expect(find.text('EH Smart Switch 3X'), findsOneWidget);
      expect(find.text('EH-SW3X-001'), findsOneWidget);
      expect(find.text('3 Channels'), findsOneWidget);
      expect(find.text('Energy Meter'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('BLE'), findsOneWidget);
    });

    testWidgets('CompatibilityResultWidget renders status and diagnostic reason', (tester) async {
      const compat = ProductCompatibilityResult(
        status: 'COMPATIBLE',
        isCompatible: true,
        reasons: [
          ProductCompatibilityReason(
            code: 'WIFI_READY',
            message: 'Home network 2.4 GHz Wi-Fi confirmed.',
            severity: 'INFO',
          )
        ],
        supportedTransports: ['WIFI_MQTT', 'BLE'],
        recommendedCommissioningTransport: 'BLE',
        evaluatedAt: '2026-09-04T12:00:00Z',
      );

      await tester.pumpWidget(_wrapWithTheme(
        const CompatibilityResultWidget(compatibility: compat),
      ));

      expect(find.text('Fully Compatible'), findsOneWidget);
      expect(find.text('Commissioning via BLE'), findsOneWidget);
      expect(find.text('Home network 2.4 GHz Wi-Fi confirmed.'), findsOneWidget);
    });

    testWidgets('ProductDetailPage renders hero, specs, and Add This Device button', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        ProductDetailPage(product: testProduct),
      ));

      expect(find.text('EH Smart Switch 3X'), findsWidgets);
      expect(find.text('Electrical Specifications'), findsOneWidget);
      expect(find.text('Channels & Controls (3)'), findsOneWidget);
      expect(find.text('Add This Device'), findsOneWidget);
    });

    testWidgets('ProductDiscoveryPage renders search bar and product cards', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        const ProductDiscoveryPage(),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Product Discovery'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Products'), findsOneWidget);
      expect(find.text('EH Smart Switch 3X'), findsWidgets);
    });

    testWidgets('ConsumerDeviceAddFlowPage progresses through onboarding steps', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        ConsumerDeviceAddFlowPage(
          selectedProduct: testProduct,
          homeId: 'home_01',
          userId: 'user_01',
        ),
      ));

      await tester.pumpAndSettle();

      // Step 1: Checking Compatibility
      expect(find.text('Checking Compatibility'), findsOneWidget);
      expect(find.text('Start Pairing'), findsOneWidget);

      // Tap Start Pairing -> Step 2
      await tester.tap(find.text('Start Pairing'));
      await tester.pumpAndSettle();

      expect(find.text('Device Discovered!'), findsOneWidget);
      expect(find.text('Connect & Provision'), findsOneWidget);
    });
  });
}
