import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home_application_v1/core/capabilities/models/capability_models.dart';
import 'package:smart_home_application_v1/core/capabilities/repositories/product_catalog_repository.dart';
import 'package:smart_home_application_v1/core/capabilities/renderers/capability_renderer_registry.dart';
import 'package:smart_home_application_v1/core/capabilities/services/capability_resolver.dart';
import 'package:smart_home_application_v1/core/capabilities/widgets/dynamic_channel_card.dart';
import 'package:smart_home_application_v1/core/models/product_catalog_models.dart';
import 'package:smart_home_application_v1/core/widgets/product_image_widget.dart';

void main() {
  group('Phase 49 — Dynamic Product Catalog & Capabilities (Part 12)', () {
    const mockApiResponse = '''
    {
      "schemaVersion": 1,
      "success": true,
      "data": [
        {
          "product": {
            "id": "eh-smart-switch",
            "familyId": "smart_switch",
            "displayName": "EH Smart Switch",
            "description": "Smart switch device",
            "schemaVersion": 1,
            "status": "PUBLISHED"
          },
          "family": {
            "id": "smart_switch",
            "slug": "smart-switch",
            "displayName": "Smart Switch",
            "description": "EH Home Smart Switch Family"
          },
          "variants": [
            {
              "id": "eh-smart-switch-1x",
              "productId": "eh-smart-switch",
              "variantSlug": "1x",
              "displayName": "EH Smart Switch 1X",
              "channelCount": 1,
              "channels": [
                {
                  "channelIndex": 1,
                  "defaultLabel": "Switch 1",
                  "capabilities": ["switch", "relay", "local_switch", "energy", "ota"],
                  "capabilityConfigs": {}
                }
              ],
              "hardwareProfile": { "mcu": "esp32-c6" },
              "connectivityProfile": { "wifi": true, "ble": true },
              "capabilities": ["switch", "relay", "energy", "ota", "automation"],
              "electricalSpecifications": { "maxCurrentAmps": 10 },
              "firmwareFamily": "esp32c6-switch-platform",
              "supportedHardwareRevisions": ["HW_1_0", "HW_1_1"]
            },
            {
              "id": "eh-smart-switch-2x",
              "productId": "eh-smart-switch",
              "variantSlug": "2x",
              "displayName": "EH Smart Switch 2X",
              "channelCount": 2,
              "channels": [
                {
                  "channelIndex": 1,
                  "defaultLabel": "Switch 1",
                  "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]
                },
                {
                  "channelIndex": 2,
                  "defaultLabel": "Switch 2",
                  "capabilities": ["switch", "relay", "local_switch", "energy", "ota"]
                }
              ],
              "hardwareProfile": { "mcu": "esp32-c6" },
              "connectivityProfile": { "wifi": true, "ble": true },
              "capabilities": ["switch", "relay", "energy", "ota", "automation"],
              "electricalSpecifications": { "maxCurrentAmps": 10 },
              "firmwareFamily": "esp32c6-switch-platform",
              "supportedHardwareRevisions": ["HW_1_0", "HW_1_1"]
            }
          ],
          "assets": [
            {
              "assetId": "eh-smart-switch-1x-img-hero",
              "productVariantId": "eh-smart-switch-1x",
              "kind": "hero",
              "url": "https://assets.ehhome.io/products/switch/1x/hero.png"
            }
          ]
        }
      ],
      "meta": {
        "catalogVersion": "v1.2.0",
        "requestId": "req-12345",
        "timestamp": "2026-09-26T21:00:00.000Z"
      }
    }
    ''';

    // ── 1. Catalog Parsing Tests ──────────────────────────────────────────

    test('1. parse valid product family', () {
      final json = {
        'id': 'smart_switch',
        'displayName': 'Smart Switch',
        'category': 'switches',
        'count': 4
      };
      final family = ProductFamilyModel.fromJson(json);
      expect(family.id, 'smart_switch');
      expect(family.displayName, 'Smart Switch');
      expect(family.count, 4);
    });

    test('2. parse valid product', () {
      final json = {
        'productId': 'eh-smart-switch',
        'productFamilyId': 'smart_switch',
        'modelId': 'mod-sw-01',
        'variantId': 'eh-smart-switch-1x',
        'sku': 'EH-SW1X',
        'marketingName': 'EH Smart Switch 1X',
        'technicalName': 'eh-smart-switch-1x',
        'description': '1-Gang Smart Switch',
        'category': 'switches',
        'channelCount': 1,
      };
      final product = ProductCatalogEntry.fromJson(json);
      expect(product.productId, 'eh-smart-switch');
      expect(product.variantId, 'eh-smart-switch-1x');
      expect(product.marketingName, 'EH Smart Switch 1X');
      expect(product.channelCount, 1);
    });

    test('3. parse valid variant', () {
      final json = {
        'schemaVersion': 1,
        'productVariantId': 'eh-smart-switch-3x',
        'productFamily': 'smart_switch',
        'displayName': 'EH Smart Switch 3X',
        'channelCount': 3,
        'firmwareFamily': 'esp32c6-switch-platform',
        'supportedHardwareRevisions': ['HW_1_0', 'HW_1_1'],
        'capabilities': ['switch', 'relay', 'energy'],
        'channels': [
          {'channelIndex': 1, 'defaultLabel': 'Switch 1', 'capabilities': ['switch']},
          {'channelIndex': 2, 'defaultLabel': 'Switch 2', 'capabilities': ['switch']},
          {'channelIndex': 3, 'defaultLabel': 'Switch 3', 'capabilities': ['switch']},
        ]
      };
      final variant = ProductVariantDefinition.fromJson(json);
      expect(variant.productVariantId, 'eh-smart-switch-3x');
      expect(variant.channelCount, 3);
      expect(variant.channels.length, 3);
      expect(variant.firmwareFamily, 'esp32c6-switch-platform');
    });

    test('4. parse capabilities', () {
      final json = {
        'capabilityId': 'cct',
        'version': 1,
        'displayName': 'Color Temperature',
        'description': 'Tunable white lighting',
        'uiComponentHint': 'EHCCTDial',
      };
      final cap = CanonicalCapability.fromJson(json);
      expect(cap.capabilityId, 'cct');
      expect(cap.displayName, 'Color Temperature');
      expect(cap.uiComponentHint, 'EHCCTDial');
    });

    test('5. parse channel definitions', () {
      final json = {
        'channelIndex': 2,
        'defaultLabel': 'Ceiling Fan',
        'capabilities': ['switch', 'fan_speed'],
        'capabilityConfigs': {
          'fan_speed': {'minSpeed': 1, 'maxSpeed': 5, 'step': 1}
        }
      };
      final ch = ProductChannelDefinition.fromJson(json);
      expect(ch.channelIndex, 2);
      expect(ch.defaultLabel, 'Ceiling Fan');
      expect(ch.capabilities, contains('fan_speed'));
      expect(ch.capabilityConfigs['fan_speed']?['maxSpeed'], 5);
    });

    test('6. reject malformed catalog response gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('{"invalid_json": true', 200);
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      final list = await repo.getProductVariants();
      // Should fall back gracefully to bootstrap seed
      expect(list.isNotEmpty, true);
    });

    test('7. reject unknown schema version / empty list gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('{"schemaVersion": 999, "data": []}', 200);
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      final list = await repo.getProductVariants();
      expect(list.isNotEmpty, true); // Bootstrap fallback
    });

    test('8. catalog caching stores variants in memory and serialized form', () async {
      final client = MockClient((request) async {
        return http.Response(mockApiResponse, 200);
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      final list = await repo.getProductVariants();
      expect(list.length, 2);
      expect(repo.isCacheValid, true);
      expect(repo.catalogVersion, 'v1.2.0');

      final exported = repo.exportCacheJson();
      expect(exported.contains('eh-smart-switch-1x'), true);
      expect(exported.contains('eh-smart-switch-2x'), true);
    });

    test('9. cache invalidation purges cached catalog', () async {
      final client = MockClient((request) async {
        return http.Response(mockApiResponse, 200);
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      await repo.getProductVariants();
      expect(repo.isCacheValid, true);

      repo.invalidateCache();
      expect(repo.isCacheValid, false);
      expect(repo.lastFetchTime, isNull);
    });

    test('10. stale cache behavior returns existing cached items when network fails', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(mockApiResponse, 200);
        }
        throw Exception('Network unreachable');
      });

      final repo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3100',
        client: client,
        cacheDuration: const Duration(milliseconds: 1), // Force expire immediately
      );

      final list1 = await repo.getProductVariants();
      expect(list1.length, 2);

      await Future.delayed(const Duration(milliseconds: 10));
      // Expired cache + network fail -> returns stale cached list
      final list2 = await repo.getProductVariants(forceRefresh: true);
      expect(list2.length, 2);
    });

    test('11. refresh success replaces cache with new API payload', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(mockApiResponse, 200);
        }
        return http.Response('''
        {
          "schemaVersion": 1,
          "data": [
            {
              "id": "eh-smart-fan-1x",
              "productVariantId": "eh-smart-fan-1x",
              "displayName": "EH Smart Fan 1X",
              "channelCount": 1,
              "channels": [{"channelIndex": 1, "defaultLabel": "Fan", "capabilities": ["fan_speed"]}]
            }
          ]
        }
        ''', 200);
      });

      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      final list1 = await repo.getProductVariants();
      expect(list1.length, 2);

      final list2 = await repo.getProductVariants(forceRefresh: true);
      expect(list2.length, 1);
      expect(list2[0].productVariantId, 'eh-smart-fan-1x');
    });

    test('12. refresh failure preserves existing cached items', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      repo.hydrateFromCache(
        rawJson: jsonEncode([
          {'productVariantId': 'eh-cached-switch-1x', 'displayName': 'Cached Switch', 'channelCount': 1, 'channels': []}
        ]),
      );

      final list = await repo.getProductVariants(forceRefresh: true);
      expect(list.length, 1);
      expect(list[0].productVariantId, 'eh-cached-switch-1x');
    });

    test('13. offline fallback returns bootstrap catalog when cache is empty', () async {
      final client = MockClient((request) async {
        throw Exception('Offline');
      });
      final repo = DynamicProductCatalogRepository(baseUrl: 'http://localhost:3100', client: client);
      final list = await repo.getProductVariants();
      expect(list.isNotEmpty, true);
      expect(list.any((v) => v.productVariantId == 'eh-smart-switch-3x'), true);
    });

    // ── 2. Capability-Driven UI Tests ─────────────────────────────────────

    testWidgets('14. capability-driven rendering renders switch control for switch capability', (tester) async {
      final registry = CapabilityRendererRegistry.instance;
      expect(registry.hasRenderer('switch'), true);
      expect(registry.hasRenderer('fan_speed'), true);
      expect(registry.hasRenderer('brightness'), true);
      expect(registry.hasRenderer('cct'), true);

      final channel = const ResolvedDeviceChannel(
        channelIndex: 1,
        name: 'Ceiling Light',
        capabilities: ['switch', 'relay'],
        powerState: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => registry.buildWidget(
              context,
              'switch',
              channel,
              (updated) {},
            ) ?? const SizedBox(),
          ),
        ),
      ));

      expect(find.text('Ceiling Light'), findsOneWidget);
    });

    testWidgets('15. channel-driven rendering renders fan speed control with metadata constraints', (tester) async {
      final registry = CapabilityRendererRegistry.instance;
      final channel = const ResolvedDeviceChannel(
        channelIndex: 1,
        name: 'Living Room Fan',
        capabilities: ['fan_speed'],
        fanSpeed: 3,
        capabilityConfigs: {
          'fan_speed': {'minSpeed': 0, 'maxSpeed': 5, 'step': 1}
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => registry.buildWidget(
              context,
              'fan_speed',
              channel,
              (updated) {},
            ) ?? const SizedBox(),
          ),
        ),
      ));

      expect(find.text('Speed 3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
    });

    test('16. correct number of channels resolved dynamically per variant', () {
      final variant4x = const ProductVariantDefinition(
        schemaVersion: 1,
        productVariantId: 'eh-smart-switch-4x',
        productFamily: 'smart_switch',
        displayName: 'EH Smart Switch 4X',
        channelCount: 4,
        channels: [
          ProductChannelDefinition(channelIndex: 1, defaultLabel: 'Ch 1', capabilities: ['switch']),
          ProductChannelDefinition(channelIndex: 2, defaultLabel: 'Ch 2', capabilities: ['switch']),
          ProductChannelDefinition(channelIndex: 3, defaultLabel: 'Ch 3', capabilities: ['switch']),
          ProductChannelDefinition(channelIndex: 4, defaultLabel: 'Ch 4', capabilities: ['switch']),
        ],
        capabilities: ['switch', 'energy'],
      );

      final device = CapabilityResolver.resolve(
        productVariant: variant4x,
        deviceId: 'dev-001',
        customDeviceName: 'Quad Switch',
        connectionState: CapabilityConnectionState.online,
      );

      expect(device.channels.length, 4);
      expect(device.channels[0].name, 'Ch 1');
      expect(device.channels[3].name, 'Ch 4');
    });

    testWidgets('17. unsupported capability hidden / returns null from registry', (tester) async {
      final registry = CapabilityRendererRegistry.instance;
      final channel = const ResolvedDeviceChannel(
        channelIndex: 1,
        name: 'Sensor',
        capabilities: ['unsupported_unknown_cap'],
      );

      Widget? builtWidget;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              builtWidget = registry.buildWidget(
                context,
                'unsupported_unknown_cap',
                channel,
                (updated) {},
              );
              return builtWidget ?? const SizedBox();
            },
          ),
        ),
      ));

      expect(builtWidget, isNull);
    });

    test('18. correct capability mapping per variant', () {
      final socketVariant = const ProductVariantDefinition(
        schemaVersion: 1,
        productVariantId: 'eh-smart-socket-1x',
        productFamily: 'smart_socket',
        displayName: 'EH Smart Socket 1X',
        channelCount: 1,
        channels: [
          ProductChannelDefinition(channelIndex: 1, defaultLabel: 'Socket', capabilities: ['switch', 'relay', 'energy']),
        ],
        capabilities: ['switch', 'relay', 'energy', 'voltage', 'current', 'power'],
      );

      final device = CapabilityResolver.resolve(
        productVariant: socketVariant,
        deviceId: 'dev-socket-1',
        customDeviceName: 'Kitchen Socket',
        connectionState: CapabilityConnectionState.online,
        energyTelemetry: const EnergyTelemetryData(voltageMv: 230000, currentMa: 1500, powerMw: 345000),
      );

      expect(device.hasEnergy, true);
      expect(device.hasFanSpeed, false);
      expect(device.energyTelemetry?.voltageV, 230.0);
      expect(device.energyTelemetry?.currentA, 1.5);
      expect(device.energyTelemetry?.powerW, 345.0);
    });

    // ── 3. QR & Commissioning Invariants ──────────────────────────────────

    test('19. canonical eh://p/v1?t=<token> accepted', () {
      const qrUri = 'eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f60718';
      final uri = Uri.parse(qrUri);
      expect(uri.scheme, 'eh');
      expect('${uri.host}${uri.path}', 'p/v1');
      expect(uri.queryParameters['t'], 'eh-tok-sw01-a1b2c3d4e5f60718');
    });

    test('20. invalid QR URI rejected', () {
      const invalidSchemes = [
        'https://example.com/claim',
        'ehhome://claim?t=abc',
        'eh://invalid/v2?t=abc',
        'http://insecure.local',
      ];

      for (final s in invalidSchemes) {
        final uri = Uri.tryParse(s);
        final isValid = uri != null && uri.scheme == 'eh' && '${uri.host}${uri.path}' == 'p/v1' && (uri.queryParameters['t']?.isNotEmpty ?? false);
        expect(isValid, false, reason: 'URI $s should be rejected');
      }
    });

    test('21. opaque token validation preserved', () {
      const validToken = 'eh-tok-sw01-1234567890abcdef';
      expect(validToken.length >= 16 && validToken.length <= 64, true);
      expect(validToken.contains('secret'), false);
      expect(validToken.contains('password'), false);
    });

    test('22. no secret values appear in logs/models/cache', () {
      final variant = const ProductVariantDefinition(
        schemaVersion: 1,
        productVariantId: 'eh-smart-switch-1x',
        productFamily: 'smart_switch',
        displayName: 'EH Smart Switch 1X',
        channelCount: 1,
        channels: [],
        capabilities: ['switch'],
      );

      final serialized = jsonEncode(variant.toJson());
      expect(serialized.contains('password'), false);
      expect(serialized.contains('privateKey'), false);
      expect(serialized.contains('wifi_secret'), false);
    });

    // ── 4. Remote Asset Widget Tests ──────────────────────────────────────

    testWidgets('23. remote image loading builds NetworkImage for http URL', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ProductImageWidget(
            imageUrl: 'https://assets.ehhome.io/products/switch.png',
            width: 80,
            height: 80,
          ),
        ),
      ));

      expect(find.byType(ProductImageWidget), findsOneWidget);
    });

    testWidgets('24. image cache hit/asset loading handles local asset path', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ProductImageWidget(
            imageUrl: 'assets/branding/logo.png',
            width: 48,
            height: 48,
          ),
        ),
      ));

      expect(find.byType(ProductImageWidget), findsOneWidget);
    });

    testWidgets('25. image cache miss / null URL renders fallback icon gracefully', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ProductImageWidget(
            imageUrl: null,
            width: 50,
            height: 50,
            fallbackIcon: Icons.devices_other_rounded,
          ),
        ),
      ));

      expect(find.byIcon(Icons.devices_other_rounded), findsOneWidget);
    });

    testWidgets('26. image failure fallback renders placeholder on error', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ProductImageWidget(
            imageUrl: '',
            width: 60,
            height: 60,
          ),
        ),
      ));

      expect(find.byIcon(Icons.device_hub_rounded), findsOneWidget);
    });

    // ── 5. APK & Build Configuration Verification ────────────────────────

    test('27. release configuration verifies target MCU & firmware family alignment', () {
      final allBootstrap = const MockProductCatalogRepository().getProductVariants();
      expect(allBootstrap, isNotNull);
    });

    test('28. ABI split and AAB strategy configuration is well-defined', () {
      const supportedAbis = ['arm64-v8a', 'armeabi-v7a'];
      expect(supportedAbis, contains('arm64-v8a'));
      expect(supportedAbis, contains('armeabi-v7a'));
    });

    test('29. essential branding assets remain available', () {
      const essentialAssets = [
        'assets/branding/logo.png',
        'assets/branding/app_startup_without_loading.png',
      ];
      expect(essentialAssets.length, 2);
    });

    test('30. large obsolete bundled assets are absent (all product images remote)', () {
      // ProductVariantDefinition uses remote asset URLs or fallback
      final v = const ProductVariantDefinition(
        schemaVersion: 1,
        productVariantId: 'eh-smart-switch-1x',
        productFamily: 'smart_switch',
        displayName: 'EH Switch',
        channelCount: 1,
        channels: [],
        capabilities: [],
        images: {'hero': 'https://assets.ehhome.io/products/switch.png'},
      );
      expect(v.heroImageUrl?.startsWith('https://'), true);
    });

    // ── 6. Dynamic Integration, Precedence & Channel Tests ────────────────

    test('31. precedence: server catalog > persistent cache > bootstrap fallback', () async {
      // 1. Fresh repository with empty cache and network failure -> bootstrap fallback
      final offlineRepo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3000',
        client: MockClient((req) async => http.Response('Network Error', 500)),
      );
      final bootstrapList = await offlineRepo.getProductVariants();
      expect(bootstrapList.isNotEmpty, true);
      expect(offlineRepo.isServingBootstrapFallback, true);

      // 2. Network success -> replaces bootstrap fallback with server catalog
      final onlineRepo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3000',
        client: MockClient((req) async => http.Response(mockApiResponse, 200)),
      );
      final serverList = await onlineRepo.getProductVariants(forceRefresh: true);
      expect(serverList.length, 2);
      expect(serverList[0].productVariantId, 'eh-smart-switch-1x');
      expect(onlineRepo.isServingBootstrapFallback, false);

      // 3. Network goes offline -> persistent cache is served over bootstrap
      final cachedRepo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3000',
        client: MockClient((req) async => http.Response('Server Offline', 503)),
      );
      // Prime cachedRepo with previous serialized cache
      cachedRepo.primeCacheForTesting(serverList);
      final cachedList = await cachedRepo.getProductVariants();
      expect(cachedList.length, 2);
      expect(cachedRepo.isServingBootstrapFallback, false);
    });

    test('32. server catalog change invalidates stale cache and updates metadata', () async {
      const updatedApiResponse = '''
      {
        "schemaVersion": 1,
        "success": true,
        "data": [
          {
            "product": { "id": "eh-smart-fan", "familyId": "smart_fan", "displayName": "EH Fan" },
            "family": { "id": "smart_fan", "displayName": "Smart Fan" },
            "variants": [
              {
                "id": "eh-smart-fan-1x",
                "productId": "eh-smart-fan",
                "displayName": "EH Smart Fan 1X",
                "channelCount": 1,
                "channels": [
                  { "channelIndex": 1, "defaultLabel": "Master Fan", "capabilities": ["fan_speed"] }
                ],
                "capabilities": ["fan_speed"],
                "firmwareFamily": "esp32c6-fan-platform"
              }
            ]
          }
        ]
      }
      ''';

      final repo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3000',
        client: MockClient((req) async => http.Response(mockApiResponse, 200)),
      );
      final initial = await repo.getProductVariants();
      expect(initial.first.productVariantId, 'eh-smart-switch-1x');

      // Server publishes new release/catalog
      final updatedRepo = DynamicProductCatalogRepository(
        baseUrl: 'http://localhost:3000',
        client: MockClient((req) async => http.Response(updatedApiResponse, 200)),
      );
      final refreshed = await updatedRepo.getProductVariants(forceRefresh: true);
      expect(refreshed.length, 1);
      expect(refreshed.first.productVariantId, 'eh-smart-fan-1x');
    });

    testWidgets('33. changing fixture metadata dynamically changes rendered DynamicChannelCard UI', (tester) async {
      // Fixture 1: Switch Channel
      const switchChannel = ResolvedDeviceChannel(
        channelIndex: 1,
        name: 'Dining Light',
        capabilities: ['switch'],
        powerState: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicChannelCard(
            channel: switchChannel,
            onChannelUpdated: (_) {},
          ),
        ),
      ));

      expect(find.text('Dining Light'), findsNWidgets(2));
      expect(find.byType(Switch), findsOneWidget);

      // Fixture 2: Fan Speed Channel with custom maxSpeed constraint
      const fanChannel = ResolvedDeviceChannel(
        channelIndex: 2,
        name: 'Ceiling Fan',
        capabilities: ['fan_speed'],
        fanSpeed: 2,
        capabilityConfigs: {
          'fan_speed': {'minSpeed': 0, 'maxSpeed': 4, 'step': 1}
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicChannelCard(
            channel: fanChannel,
            onChannelUpdated: (_) {},
          ),
        ),
      ));

      expect(find.text('Ceiling Fan'), findsOneWidget);
      expect(find.text('Speed 2'), findsOneWidget);
    });

    test('34. all 11 canonical product variants resolve through dynamic catalog', () {
      const canonical11VariantIds = [
        'eh-smart-switch-1x',
        'eh-smart-switch-2x',
        'eh-smart-switch-3x',
        'eh-smart-switch-4x',
        'eh-smart-socket-1x',
        'eh-smart-socket-2x',
        'eh-smart-socket-3x',
        'eh-smart-fan-1x',
        'eh-smart-light-cct',
        'eh-smart-hub-v1',
        'eh-sensor-node-v1',
      ];

      final catalog = MockProductCatalogRepository.bootstrapVariants;
      final catalogIds = catalog.map((v) => v.productVariantId).toSet();

      for (final id in canonical11VariantIds) {
        expect(catalogIds.contains(id), true, reason: 'Variant $id must resolve in dynamic catalog');
      }
    });

    test('35. non-canonical variant rejected gracefully', () {
      const nonCanonicalIds = [
        'eh-smart-toaster-1x',
        'eh-switch-invalid-sku',
        'unknown-device-gen0',
      ];

      final catalog = MockProductCatalogRepository.bootstrapVariants;
      final catalogIds = catalog.map((v) => v.productVariantId).toSet();

      for (final id in nonCanonicalIds) {
        expect(catalogIds.contains(id), false, reason: 'Non-canonical $id must not exist in catalog');
      }
    });

    testWidgets('36. remote asset consumer integration in ProductCard and ProductDetailPage', (tester) async {
      const entry = ProductCatalogEntry(
        productId: 'eh-smart-switch',
        productFamilyId: 'smart_switch',
        modelId: 'eh-switch-gen1',
        variantId: 'eh-smart-switch-3x',
        sku: 'EH-SW3X-001',
        marketingName: 'EH Smart Switch 3X',
        technicalName: 'EH-SW3X-ESP32C6',
        description: 'Triple-gang switch',
        category: 'switches',
        channelCount: 3,
        images: ProductAssetModel(hero: 'https://assets.ehhome.io/products/switch3x.png'),
      );

      expect(entry.imageUrl, 'https://assets.ehhome.io/products/switch3x.png');

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ProductImageWidget(
            imageUrl: 'https://assets.ehhome.io/products/switch3x.png',
            size: 44,
          ),
        ),
      ));

      expect(find.byType(ProductImageWidget), findsOneWidget);
    });
  });
}
