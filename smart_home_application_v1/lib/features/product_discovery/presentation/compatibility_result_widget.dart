import 'package:flutter/material.dart';
import '../../../core/models/product_catalog_models.dart';
import '../../../core/theme/app_theme.dart';

/// Renders multi-dimensional compatibility assessment with clear severity badges and remedies.
class CompatibilityResultWidget extends StatelessWidget {
  final ProductCompatibilityResult compatibility;
  final VoidCallback? onRetry;

  const CompatibilityResultWidget({
    super.key,
    required this.compatibility,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    final isOk = compatibility.status == 'COMPATIBLE';
    final isPartial = compatibility.status == 'PARTIALLY_COMPATIBLE';

    final Color statusColor = isOk
        ? tokens.success
        : isPartial
            ? tokens.goldBright
            : tokens.error;

    final Color statusContainer = isOk
        ? tokens.successContainer
        : isPartial
            ? tokens.goldContainer
            : tokens.errorContainer;

    final IconData statusIcon = isOk
        ? Icons.check_circle_rounded
        : isPartial
            ? Icons.warning_amber_rounded
            : Icons.cancel_rounded;

    final String statusTitle = isOk
        ? 'Fully Compatible'
        : isPartial
            ? 'Partially Compatible'
            : 'Incompatible with Environment';

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Commissioning via ${compatibility.recommendedCommissioningTransport}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onRetry,
                  tooltip: 'Re-evaluate compatibility',
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Diagnostic Reasons
          if (compatibility.reasons.isNotEmpty) ...[
            Text(
              'Diagnostic Assessment:',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...compatibility.reasons.map((r) => _ReasonItem(reason: r, tokens: tokens)),
          ],

          // Unsupported Features (if any)
          if (compatibility.unsupportedFeatures.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: tokens.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Inactive features in current setup: ${compatibility.unsupportedFeatures.join(", ")}',
                      style: TextStyle(color: tokens.textTertiary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonItem extends StatelessWidget {
  final ProductCompatibilityReason reason;
  final EHThemeTokens tokens;

  const _ReasonItem({
    required this.reason,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color badgeBg;
    switch (reason.severity.toUpperCase()) {
      case 'BLOCKING':
        badgeColor = tokens.error;
        badgeBg = tokens.errorContainer;
        break;
      case 'WARNING':
        badgeColor = tokens.goldBright;
        badgeBg = tokens.goldContainer;
        break;
      default:
        badgeColor = tokens.bluePrimary;
        badgeBg = tokens.iconBgBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              reason.severity,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.message,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (reason.remedy != null && reason.remedy!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Action: ${reason.remedy!}',
                      style: TextStyle(
                        color: tokens.bluePrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
