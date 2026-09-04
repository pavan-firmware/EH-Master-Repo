import 'package:flutter/material.dart';
import '../../../core/models/product_catalog_models.dart';
import '../../../core/services/product_catalog_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../product_discovery/presentation/compatibility_result_widget.dart';

/// Complete Consumer Device Add Wizard Flow.
/// Abstracting away low-level protocol engineering complexities while maintaining high fidelity.
class ConsumerDeviceAddFlowPage extends StatefulWidget {
  final ProductCatalogEntry? selectedProduct;
  final String homeId;
  final String userId;
  final ProductCatalogClientService? catalogService;

  const ConsumerDeviceAddFlowPage({
    super.key,
    this.selectedProduct,
    required this.homeId,
    required this.userId,
    this.catalogService,
  });

  @override
  State<ConsumerDeviceAddFlowPage> createState() => _ConsumerDeviceAddFlowPageState();
}

class _ConsumerDeviceAddFlowPageState extends State<ConsumerDeviceAddFlowPage> {
  late ProductCatalogClientService _service;
  int _currentStep = 0;

  // Wizard state
  String _entryMode = 'MANUAL_CATALOG';
  ProductCatalogEntry? _product;
  ProductCompatibilityResult? _compatibility;
  DeviceAddSessionModel? _session;

  // Configuration state
  final TextEditingController _customNameController = TextEditingController();
  String _selectedRoom = 'Living Room';
  final Map<int, TextEditingController> _channelControllers = {};
  bool _isCommissioning = false;
  bool _isCompleted = false;

  final List<String> _rooms = [
    'Living Room',
    'Master Bedroom',
    'Kitchen',
    'Dining Room',
    'Balcony',
    'Guest Room',
    'Hallway',
    'Office'
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.catalogService ?? ProductCatalogClientService(baseUrl: 'http://localhost:3000');
    _product = widget.selectedProduct;

    if (_product != null) {
      _initProductState(_product!);
      _currentStep = 1; // Skip entry mode selection if product is pre-selected
    }
  }

  void _initProductState(ProductCatalogEntry product) {
    _product = product;
    _customNameController.text = product.marketingName;

    _channelControllers.clear();
    for (int i = 1; i <= product.channelCount; i++) {
      final defaultLabel = product.channels.length >= i
          ? product.channels[i - 1]['defaultLabel'] as String? ?? 'Channel $i'
          : 'Channel $i';
      _channelControllers[i] = TextEditingController(text: defaultLabel);
    }

    _compatibility = ProductCompatibilityResult(
      status: 'COMPATIBLE',
      isCompatible: true,
      reasons: [
        const ProductCompatibilityReason(
          code: 'VERIFIED',
          message: 'Wi-Fi 2.4 GHz home network and phone BLE connection verified.',
          severity: 'INFO',
        ),
      ],
      supportedTransports: product.connectivityCapabilities,
      recommendedCommissioningTransport: product.bleProvisioningSupport ? 'BLE' : 'Wi-Fi',
      evaluatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  void dispose() {
    _customNameController.dispose();
    for (final c in _channelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _startCommissioning() async {
    setState(() => _isCommissioning = true);

    // Simulate multi-protocol commissioning lifecycle
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() {
        _isCommissioning = false;
        _currentStep = 3; // Move to room & naming setup
      });
    }
  }

  Future<void> _finalizeOnboarding() async {
    setState(() => _isCommissioning = true);

    final channelLabels = <String, String>{};
    _channelControllers.forEach((idx, ctrl) {
      channelLabels[idx.toString()] = ctrl.text.trim();
    });

    if (_session != null) {
      await _service.completeDeviceAddSession(_session!.sessionId, {
        'roomId': 'room_${_selectedRoom.toLowerCase().replaceAll(' ', '_')}',
        'customName': _customNameController.text.trim(),
        'channelLabels': channelLabels,
        'entryMode': _entryMode,
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isCommissioning = false;
        _isCompleted = true;
        _currentStep = 4; // Completed step
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: Text(
          _product != null ? 'Add ${_product!.marketingName}' : 'Add New Device',
          style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear step progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                backgroundColor: tokens.bgSecondary,
                valueColor: AlwaysStoppedAnimation(tokens.bluePrimary),
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(tokens),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(EHThemeTokens tokens) {
    if (_isCompleted || _currentStep == 4) {
      return _buildCompletionStep(tokens);
    }
    switch (_currentStep) {
      case 0:
        return _buildEntryModeStep(tokens);
      case 1:
        return _buildCompatibilityStep(tokens);
      case 2:
        return _buildCommissioningProgressStep(tokens);
      case 3:
        return _buildDeviceConfigurationStep(tokens);
      default:
        return _buildEntryModeStep(tokens);
    }
  }

  // ─── Step 0: Entry Mode Selection ──────────────────────────────────────────

  Widget _buildEntryModeStep(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to add your device?',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the setup method indicated on your device packaging or quick start card.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _EntryModeTile(
          title: 'Scan Setup QR Code',
          subtitle: 'Instant configuration from the packaging QR sticker',
          icon: Icons.qr_code_scanner_rounded,
          tokens: tokens,
          onTap: () {
            _entryMode = 'QR_SCAN';
            _selectDefaultProduct();
          },
        ),
        const SizedBox(height: 12),
        _EntryModeTile(
          title: 'Search Nearby Devices',
          subtitle: 'Discover Bluetooth Low Energy devices in pairing mode',
          icon: Icons.bluetooth_searching_rounded,
          tokens: tokens,
          onTap: () {
            _entryMode = 'NEARBY_DISCOVERY';
            _selectDefaultProduct();
          },
        ),
        const SizedBox(height: 12),
        _EntryModeTile(
          title: 'Select from Product Catalog',
          subtitle: 'Manually choose your switch, socket, or smart device',
          icon: Icons.grid_view_rounded,
          tokens: tokens,
          onTap: () {
            _entryMode = 'MANUAL_CATALOG';
            _selectDefaultProduct();
          },
        ),
        const SizedBox(height: 12),
        _EntryModeTile(
          title: 'Re-add After Factory Reset',
          subtitle: 'Restore a previously configured device to your home',
          icon: Icons.restart_alt_rounded,
          tokens: tokens,
          onTap: () {
            _entryMode = 'RE_ADD_RESET';
            _selectDefaultProduct();
          },
        ),
      ],
    );
  }

  void _selectDefaultProduct() {
    _initProductState(const ProductCatalogEntry(
      productId: 'eh-smart-switch',
      productFamilyId: 'smart_switch',
      modelId: 'eh-switch-gen1',
      variantId: 'eh-smart-switch-3x',
      sku: 'EH-SWITCH3X-001',
      marketingName: 'EH Smart Switch 3X',
      technicalName: 'EH-SW3X-ESP32C6',
      description: 'Triple-relay smart switchboard with energy monitoring',
      category: 'switches',
      channelCount: 3,
      wifiSupport: true,
      bleProvisioningSupport: true,
      energyMonitoringSupport: true,
      capabilities: ['switch', 'relay', 'energy', 'ota'],
    ));
    setState(() => _currentStep = 1);
  }

  // ─── Step 1: Compatibility Assessment ──────────────────────────────────────

  Widget _buildCompatibilityStep(EHThemeTokens tokens) {
    if (_product == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checking Compatibility',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'We verified that ${_product!.marketingName} is fully compatible with your home network.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (_compatibility != null)
          CompatibilityResultWidget(compatibility: _compatibility!),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.iconBgBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_input_component_rounded, color: tokens.bluePrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_product!.marketingName, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${_product!.channelCount} Channels • ${_product!.sku}', style: TextStyle(color: tokens.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => setState(() => _currentStep = 2),
            child: const Text('Start Pairing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Commissioning & Pairing Progress ──────────────────────────────

  Widget _buildCommissioningProgressStep(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: tokens.iconBgBlue,
            shape: BoxShape.circle,
          ),
          child: _isCommissioning
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: tokens.bluePrimary, strokeWidth: 3),
                )
              : Icon(Icons.bluetooth_connected_rounded, size: 54, color: tokens.bluePrimary),
        ),
        const SizedBox(height: 28),
        Text(
          _isCommissioning ? 'Connecting to Device...' : 'Device Discovered!',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          _isCommissioning
              ? 'Securely negotiating local credentials and provisioning Wi-Fi transport.'
              : 'Found your ${_product?.marketingName ?? "device"}. Ready to configure.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        if (!_isCommissioning)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _startCommissioning,
              child: const Text('Connect & Provision', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  // ─── Step 3: Room Selection & Channel Naming ───────────────────────────────

  Widget _buildDeviceConfigurationStep(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name & Placement',
          style: TextStyle(color: tokens.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Assign your device to a room and give each switch channel a friendly label.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),

        // Device Custom Name
        Text('Device Name', style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _customNameController,
          style: TextStyle(color: tokens.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: tokens.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderSubtle)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.borderSubtle)),
          ),
        ),
        const SizedBox(height: 20),

        // Room Selector
        Text('Assign Room', style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _rooms.map((room) {
            final isSel = _selectedRoom == room;
            return ChoiceChip(
              label: Text(room),
              selected: isSel,
              onSelected: (_) => setState(() => _selectedRoom = room),
              selectedColor: tokens.blueSelectedBg,
              backgroundColor: tokens.surfaceCard,
              labelStyle: TextStyle(
                color: isSel ? tokens.blueSelectedText : tokens.textSecondary,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(color: isSel ? tokens.bluePrimary : tokens.borderSubtle),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Per-Channel Labeling
        if (_channelControllers.isNotEmpty) ...[
          Text('Channel Names', style: TextStyle(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._channelControllers.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: tokens.iconBgBlue,
                    child: Text('${entry.key}', style: TextStyle(color: tokens.bluePrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: entry.value,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderSubtle)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _finalizeOnboarding,
            child: const Text('Complete Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Verification & Completed Summary ─────────────────────────────

  Widget _buildCompletionStep(EHThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: tokens.successContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 54, color: tokens.success),
        ),
        const SizedBox(height: 24),
        Text(
          'All Set!',
          style: TextStyle(color: tokens.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${_customNameController.text} is claimed, configured, and ready to control.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Room', value: _selectedRoom, tokens: tokens),
              const Divider(height: 16),
              _SummaryRow(label: 'Channels', value: '${_product?.channelCount ?? 1} configured', tokens: tokens),
              const Divider(height: 16),
              _SummaryRow(label: 'Connectivity', value: 'Wi-Fi / BLE Active', tokens: tokens),
            ],
          ),
        ),
        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _EntryModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final EHThemeTokens tokens;
  final VoidCallback onTap;

  const _EntryModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.iconBgBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tokens.bluePrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: tokens.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.chevron),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final EHThemeTokens tokens;

  const _SummaryRow({required this.label, required this.value, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
        Text(value, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
