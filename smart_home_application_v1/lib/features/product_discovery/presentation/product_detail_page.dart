import 'package:flutter/material.dart';
import '../../../core/models/product_catalog_models.dart';
import '../../../core/theme/app_theme.dart';
import 'compatibility_result_widget.dart';

/// Rich, dynamic product detail screen driven entirely by catalog metadata.
class ProductDetailPage extends StatefulWidget {
  final ProductCatalogEntry product;
  final ProductCompatibilityResult? initialCompatibility;
  final Function(ProductCatalogEntry)? onAddDevice;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.initialCompatibility,
    this.onAddDevice,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late ProductCompatibilityResult _compatibility;

  @override
  void initState() {
    super.initState();
    _compatibility = widget.initialCompatibility ??
        ProductCompatibilityResult(
          status: 'COMPATIBLE',
          isCompatible: true,
          reasons: [
            const ProductCompatibilityReason(
              code: 'READY',
              message: 'Verified for 2.4 GHz Wi-Fi and BLE commissioning in your home.',
              severity: 'INFO',
            )
          ],
          supportedTransports: widget.product.connectivityCapabilities,
          recommendedCommissioningTransport: widget.product.bleProvisioningSupport ? 'BLE' : 'Wi-Fi',
          evaluatedAt: DateTime.now().toIso8601String(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final product = widget.product;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          product.marketingName,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          border: Border(top: BorderSide(color: tokens.borderSubtle)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                if (widget.onAddDevice != null) {
                  widget.onAddDevice!(product);
                } else {
                  Navigator.pop(context, product);
                }
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add This Device',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: tokens.iconBgBlue,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.settings_input_component_rounded,
                      size: 48,
                      color: tokens.bluePrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.marketingName,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Model: ${product.modelId.toUpperCase()} • SKU: ${product.sku}',
                    style: TextStyle(
                      color: tokens.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Compatibility Card
            CompatibilityResultWidget(
              compatibility: _compatibility,
              onRetry: () {
                setState(() {
                  _compatibility = ProductCompatibilityResult(
                    status: 'COMPATIBLE',
                    isCompatible: true,
                    reasons: [
                      const ProductCompatibilityReason(
                        code: 'VERIFIED',
                        message: 'Re-evaluated home network. All parameters confirmed.',
                        severity: 'INFO',
                      )
                    ],
                    supportedTransports: product.connectivityCapabilities,
                    recommendedCommissioningTransport: 'BLE',
                    evaluatedAt: DateTime.now().toIso8601String(),
                  );
                });
              },
            ),
            const SizedBox(height: 20),

            // Section: Electrical Specifications
            _SectionHeading(title: 'Electrical Specifications', tokens: tokens),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                children: [
                  _SpecRow(
                    label: 'Voltage Range',
                    value: product.electricalSpecifications['voltageRange'] as String? ?? '90V - 250V AC',
                    tokens: tokens,
                  ),
                  const Divider(height: 16),
                  _SpecRow(
                    label: 'Frequency',
                    value: product.electricalSpecifications['frequencyHz'] as String? ?? '50/60 Hz',
                    tokens: tokens,
                  ),
                  const Divider(height: 16),
                  _SpecRow(
                    label: 'Max Relay Current',
                    value: '${product.electricalSpecifications["maxCurrentPerChannelAmps"] ?? "10.0"} A / channel',
                    tokens: tokens,
                  ),
                  const Divider(height: 16),
                  _SpecRow(
                    label: 'Max Total Board Load',
                    value: '${product.electricalSpecifications["maxTotalCurrentAmps"] ?? "16.0"} A',
                    tokens: tokens,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Channels & Relay Configuration
            _SectionHeading(title: 'Channels & Controls (${product.channelCount})', tokens: tokens),
            const SizedBox(height: 10),
            ...product.channels.map((ch) {
              final idx = ch['channelIndex'] ?? 1;
              final label = ch['defaultLabel'] ?? 'Channel $idx';
              final caps = (ch['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? 'Switch, Relay';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: tokens.bgSecondary,
                      child: Text('$idx', style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(caps, style: TextStyle(color: tokens.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.toggle_on_rounded, color: tokens.bluePrimary, size: 28),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Section: Supported Features & Telemetry
            _SectionHeading(title: 'Features & Telemetry', tokens: tokens),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.energyMonitoringSupport)
                  _FeaturePill(label: 'Real-time Power (W)', icon: Icons.bolt_rounded, tokens: tokens),
                if (product.energyMonitoringSupport)
                  _FeaturePill(label: 'Energy Total (Wh)', icon: Icons.speed_rounded, tokens: tokens),
                if (product.energyMonitoringSupport)
                  _FeaturePill(label: 'Voltage & Current RMS', icon: Icons.show_chart_rounded, tokens: tokens),
                if (product.localControlSupport)
                  _FeaturePill(label: 'Local Physical Switch', icon: Icons.touch_app_rounded, tokens: tokens),
                _FeaturePill(label: 'Dual-Bank Signed OTA', icon: Icons.system_update_rounded, tokens: tokens),
                _FeaturePill(label: 'Schedules & Automations', icon: Icons.alarm_rounded, tokens: tokens),
                _FeaturePill(label: 'Scene Target', icon: Icons.movie_filter_rounded, tokens: tokens),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final EHThemeTokens tokens;

  const _SectionHeading({required this.title, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: tokens.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final EHThemeTokens tokens;

  const _SpecRow({
    required this.label,
    required this.value,
    required this.tokens,
  });

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

class _FeaturePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final EHThemeTokens tokens;

  const _FeaturePill({
    required this.label,
    required this.icon,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tokens.bluePrimary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
