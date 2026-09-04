import 'package:flutter/material.dart';
import '../../../core/models/product_catalog_models.dart';
import '../../../core/services/product_catalog_service.dart';
import '../../../core/theme/app_theme.dart';
import 'product_card.dart';
import 'product_detail_page.dart';
import '../../device_add/presentation/consumer_device_add_flow_page.dart';

/// Consumer-facing Product Discovery hub for exploring catalog, searching SKUs, and initiating onboarding.
class ProductDiscoveryPage extends StatefulWidget {
  final ProductCatalogClientService? catalogService;
  final String? homeId;
  final String? userId;

  const ProductDiscoveryPage({
    super.key,
    this.catalogService,
    this.homeId,
    this.userId,
  });

  @override
  State<ProductDiscoveryPage> createState() => _ProductDiscoveryPageState();
}

class _ProductDiscoveryPageState extends State<ProductDiscoveryPage> {
  final TextEditingController _searchController = TextEditingController();
  late ProductCatalogClientService _service;

  String _selectedCategory = 'all';
  List<ProductCatalogEntry> _products = [];
  List<ProductCategoryModel> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.catalogService ?? ProductCatalogClientService(baseUrl: 'http://localhost:3000');
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final res = await _service.loadDiscovery(
      category: _selectedCategory == 'all' ? null : _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _products = res.products;
          _categories = res.categories;
        } else {
          // Provide baseline fallback items if backend is offline in mock mode
          _products = _getFallbackProducts();
          _categories = [
            const ProductCategoryModel(id: 'switches', displayName: 'Smart Switches', count: 4),
            const ProductCategoryModel(id: 'sockets', displayName: 'Smart Sockets', count: 3),
          ];
        }
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      _loadInitialData();
      return;
    }

    setState(() => _isLoading = true);
    final searchRes = await _service.searchProducts(
      query,
      category: _selectedCategory == 'all' ? null : _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (searchRes != null) {
          _products = searchRes.results.map((r) => r.product).toList();
        } else {
          _products = _getFallbackProducts().where((p) =>
            p.marketingName.toLowerCase().contains(query.toLowerCase()) ||
            p.sku.toLowerCase().contains(query.toLowerCase()) ||
            p.description.toLowerCase().contains(query.toLowerCase())
          ).toList();
        }
      });
    }
  }

  List<ProductCatalogEntry> _getFallbackProducts() {
    return const [
      ProductCatalogEntry(
        productId: 'eh-smart-switch',
        productFamilyId: 'smart_switch',
        modelId: 'eh-switch-gen1',
        variantId: 'eh-smart-switch-3x',
        sku: 'EH-SWITCH3X-001',
        marketingName: 'EH Smart Switch 3X',
        technicalName: 'EH-SW3X-ESP32C6',
        description: 'Triple-channel modular smart switchboard with high-accuracy energy monitoring.',
        category: 'switches',
        channelCount: 3,
        wifiSupport: true,
        bleProvisioningSupport: true,
        energyMonitoringSupport: true,
        capabilities: ['switch', 'relay', 'energy', 'ota'],
      ),
      ProductCatalogEntry(
        productId: 'eh-smart-switch',
        productFamilyId: 'smart_switch',
        modelId: 'eh-switch-gen1',
        variantId: 'eh-smart-switch-2x',
        sku: 'EH-SWITCH2X-001',
        marketingName: 'EH Smart Switch 2X',
        technicalName: 'EH-SW2X-ESP32C6',
        description: 'Dual-channel smart in-wall switch with independent channel energy measurement.',
        category: 'switches',
        channelCount: 2,
        wifiSupport: true,
        bleProvisioningSupport: true,
        energyMonitoringSupport: true,
        capabilities: ['switch', 'relay', 'energy', 'ota'],
      ),
      ProductCatalogEntry(
        productId: 'eh-smart-socket',
        productFamilyId: 'smart_socket',
        modelId: 'eh-socket-gen1',
        variantId: 'eh-smart-socket-2x',
        sku: 'EH-SOCKET2X-001',
        marketingName: 'EH Smart Socket 2X',
        technicalName: 'EH-SK2X-ESP32C6',
        description: 'Dual 16A smart wall socket with child safety shutter and surge telemetry.',
        category: 'sockets',
        channelCount: 2,
        wifiSupport: true,
        bleProvisioningSupport: true,
        energyMonitoringSupport: true,
        capabilities: ['switch', 'relay', 'energy', 'voltage', 'current', 'power', 'ota'],
      ),
    ];
  }

  void _openProductDetail(ProductCatalogEntry product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ProductDetailPage(
          product: product,
          onAddDevice: (p) => _startAddDeviceFlow(p),
        ),
      ),
    );
  }

  void _startAddDeviceFlow([ProductCatalogEntry? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ConsumerDeviceAddFlowPage(
          selectedProduct: product,
          homeId: widget.homeId ?? '0194fe23-7a1b-7890-a123-456789abcdef',
          userId: widget.userId ?? '0194fe23-7a1b-7890-a123-000000000001',
          catalogService: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        title: Text(
          'Product Discovery',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: tokens.headerAction),
            tooltip: 'Scan Device QR Code',
            onPressed: () => _startAddDeviceFlow(null),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search products, SKUs, or features...',
                hintStyle: TextStyle(color: tokens.textTertiary),
                prefixIcon: Icon(Icons.search_rounded, color: tokens.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: tokens.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: tokens.surfaceCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: tokens.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: tokens.borderSubtle),
                ),
              ),
            ),
          ),

          // Categories Horizontal Bar
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'All Products',
                  isSelected: _selectedCategory == 'all',
                  onTap: () {
                    setState(() => _selectedCategory = 'all');
                    _loadInitialData();
                  },
                  tokens: tokens,
                ),
                ..._categories.map((c) => _CategoryChip(
                      label: c.displayName,
                      isSelected: _selectedCategory == c.id,
                      onTap: () {
                        setState(() => _selectedCategory = c.id);
                        _loadInitialData();
                      },
                      tokens: tokens,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Product List / Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: tokens.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No matching products found',
                              style: TextStyle(color: tokens.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try adjusting your search query or category filters.',
                              style: TextStyle(color: tokens.textTertiary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return ProductCard(
                            product: product,
                            onTap: () => _openProductDetail(product),
                            onAddTap: () => _startAddDeviceFlow(product),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final EHThemeTokens tokens;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: tokens.blueSelectedBg,
        backgroundColor: tokens.surfaceCard,
        labelStyle: TextStyle(
          color: isSelected ? tokens.blueSelectedText : tokens.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        side: BorderSide(
          color: isSelected ? tokens.bluePrimary : tokens.borderSubtle,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
      ),
    );
  }
}
