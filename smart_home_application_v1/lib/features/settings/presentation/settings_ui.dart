import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SettingsColors {
  const SettingsColors._();

  static const ink = Color(0xFF102448);
  static const muted = Color(0xFF65738C);
  static const blue = Color(0xFF155CC8);
  static const paleBlue = Color(0xFFEAF1FF);
  static const green = Color(0xFF09944A);
  static const paleGreen = Color(0xFFE9F7EE);
  static const orange = Color(0xFFE87A15);
  static const paleOrange = Color(0xFFFFF4E5);
  static const red = Color(0xFFD92D20);
  static const purple = Color(0xFF7A3DD5);
  static const palePurple = Color(0xFFF3ECFF);
  static const paleLavender = Color(0xFFEDE7F6);
  static const background = Color(0xFFF6F8FC);
  static const line = Color(0xFFE5EAF2);
}

Color _adaptBadgeBg(Color bg, EHThemeTokens tokens) {
  if (!tokens.isDark) return bg;
  if (bg == SettingsColors.paleBlue ||
      bg == const Color(0xFFEAF1FF) ||
      bg == const Color(0xFFE8EFFF)) {
    return tokens.iconBgBlue;
  }
  if (bg == SettingsColors.paleGreen || bg == const Color(0xFFE9F7EE)) {
    return tokens.iconBgGreen;
  }
  if (bg == SettingsColors.paleOrange || bg == const Color(0xFFFFF4E5)) {
    return tokens.iconBgOrange;
  }
  if (bg == SettingsColors.palePurple ||
      bg == SettingsColors.paleLavender ||
      bg == const Color(0xFFF3ECFF) ||
      bg == const Color(0xFFEDE7F6)) {
    return tokens.iconBgPurple;
  }
  if (bg == Colors.white || bg == const Color(0xFFFFFFFF)) {
    return tokens.surfaceCard;
  }
  return tokens.iconBgBlue;
}

Color _adaptBadgeFg(Color fg, EHThemeTokens tokens) {
  if (!tokens.isDark) return fg;
  if (fg == SettingsColors.blue ||
      fg == const Color(0xFF155CC8) ||
      fg == const Color(0xFF1956A8) ||
      fg == const Color(0xFF1D58A7)) {
    return tokens.bluePrimary;
  }
  if (fg == SettingsColors.green ||
      fg == const Color(0xFF09944A) ||
      fg == const Color(0xFF16A95A)) {
    return tokens.success;
  }
  if (fg == SettingsColors.orange ||
      fg == const Color(0xFFE87A15) ||
      fg == const Color(0xFFF26D12)) {
    return tokens.warning;
  }
  if (fg == SettingsColors.red ||
      fg == const Color(0xFFD92D20) ||
      fg == const Color(0xFFC63D32)) {
    return tokens.errorText;
  }
  if (fg == SettingsColors.purple || fg == const Color(0xFF7A3DD5)) {
    return tokens.iconFgPurple;
  }
  return fg;
}

Widget settingsHelpAction(BuildContext context, {String? message}) {
  final tokens = context.ehColors;
  return IconButton(
    tooltip: 'Help',
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surfaceCard,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Text(
          message ?? 'This screen helps you manage your home settings safely.',
          style: TextStyle(color: tokens.textSecondary, height: 1.4),
        ),
      ),
    ),
    icon: Icon(Icons.help_outline_rounded, color: tokens.headerAction),
  );
}

class SettingsStatusChip extends StatelessWidget {
  const SettingsStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.leading,
  });

  final String label;
  final Color color;
  final Color background;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    Color resolvedBg = background;
    Color resolvedFg = color;

    if (tokens.isDark) {
      if (color == SettingsColors.green ||
          color == const Color(0xFF09944A) ||
          color == const Color(0xFF16A95A)) {
        resolvedFg = tokens.success;
        resolvedBg = tokens.successContainer;
      } else if (color == SettingsColors.orange ||
          color == const Color(0xFFE87A15) ||
          color == const Color(0xFFF26D12)) {
        resolvedFg = tokens.warning;
        resolvedBg = tokens.warningContainer;
      } else if (color == SettingsColors.blue ||
          color == const Color(0xFF155CC8)) {
        resolvedFg = tokens.blueSelectedText;
        resolvedBg = tokens.blueSelectedBg;
      } else if (color == SettingsColors.purple ||
          color == const Color(0xFF7A3DD5)) {
        resolvedFg = tokens.iconFgPurple;
        resolvedBg = tokens.iconBgPurple;
      } else if (color == SettingsColors.muted ||
          color == const Color(0xFF65738C)) {
        resolvedFg = tokens.textSecondary;
        resolvedBg = tokens.surfaceElevated;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resolvedFg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Widget settingsHeroIcon({
  required IconData icon,
  required Color color,
  required Color background,
  double diameter = 44,
  double iconSize = 22,
}) => Builder(
  builder: (context) {
    final tokens = context.ehColors;
    final resolvedBg = tokens.isDark
        ? _adaptBadgeBg(background, tokens)
        : background;
    final resolvedFg = tokens.isDark ? _adaptBadgeFg(color, tokens) : color;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: resolvedBg, shape: BoxShape.circle),
      child: Icon(icon, color: resolvedFg, size: iconSize),
    );
  },
);

class SettingsHeroActionFooter extends StatelessWidget {
  const SettingsHeroActionFooter({
    super.key,
    required this.lastCheckedLabel,
    required this.actionLabel,
    required this.onAction,
    this.checking = false,
    this.actionIcon = Icons.refresh_rounded,
  });

  final String lastCheckedLabel;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool checking;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, color: tokens.textSecondary, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                lastCheckedLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: checking ? null : onAction,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.blueDarker,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: checking
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.buttonText,
                    ),
                  )
                : Icon(actionIcon, size: 18),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class SettingsSectionLink extends StatelessWidget {
  const SettingsSectionLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: tokens.bluePrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class SettingsHeroCard extends StatelessWidget {
  const SettingsHeroCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.statusChip,
    this.footer,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? statusChip;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (statusChip != null) ...[
                        const SizedBox(height: 12),
                        statusChip!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            if (footer != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: tokens.borderSubtle),
              ),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsMetricRow extends StatelessWidget {
  const SettingsMetricRow({super.key, required this.metrics});

  final List<SettingsMetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            Container(width: 1, height: 42, color: tokens.borderSubtle),
          Expanded(child: metrics[i]),
        ],
      ],
    );
  }
}

class SettingsMetricItem extends StatelessWidget {
  const SettingsMetricItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.iconColor = SettingsColors.blue,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final resolvedIconColor = tokens.isDark && iconColor == SettingsColors.blue
        ? tokens.bluePrimary
        : (tokens.isDark ? _adaptBadgeFg(iconColor, tokens) : iconColor);

    final content = Column(
      children: [
        Icon(icon, color: resolvedIconColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: tokens.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

enum SettingsStepVisual { pending, active, completed, failed }

class SettingsStepperList extends StatelessWidget {
  const SettingsStepperList({super.key, required this.steps});

  final List<SettingsStepData> steps;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _SettingsStepRow(step: steps[i]),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Divider(height: 1, color: tokens.borderSubtle),
              ),
          ],
        ],
      ),
    );
  }
}

class SettingsStepData {
  const SettingsStepData({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final int index;
  final String title;
  final String subtitle;
  final SettingsStepVisual status;
}

class _SettingsStepRow extends StatelessWidget {
  const _SettingsStepRow({required this.step});
  final SettingsStepData step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final highlight =
        step.status == SettingsStepVisual.completed ||
        step.status == SettingsStepVisual.active;
    return Container(
      color: step.status == SettingsStepVisual.completed
          ? (tokens.isDark
                ? tokens.successContainer.withValues(alpha: 0.35)
                : SettingsColors.paleGreen.withValues(alpha: .35))
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _StepBadge(step: step),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: highlight ? tokens.textPrimary : tokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.subtitle,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (step.status == SettingsStepVisual.completed)
            Icon(Icons.check_circle_rounded, color: tokens.success, size: 22),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});
  final SettingsStepData step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final completed = step.status == SettingsStepVisual.completed;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: completed
            ? tokens.success
            : (tokens.isDark
                  ? tokens.successContainer
                  : SettingsColors.paleGreen),
        shape: BoxShape.circle,
      ),
      child: completed
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : Text(
              '${step.index}',
              style: TextStyle(
                color: completed ? Colors.white : tokens.success,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class SettingsSupportBanner extends StatelessWidget {
  const SettingsSupportBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Material(
      color: tokens.isDark ? tokens.surfaceElevated : SettingsColors.paleBlue,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsIconBadge(
                  icon: Icons.info_outline_rounded,
                  color: tokens.bluePrimary,
                  background: tokens.surfaceCard,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.blueDarker,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDestructiveActionBanner extends StatelessWidget {
  const SettingsDestructiveActionBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Material(
      color: tokens.isDark ? tokens.errorContainer : const Color(0xFFFFE8E8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tokens.isDark
                  ? const Color(0xFF5A2924)
                  : const Color(0xFFF5B8B8),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: tokens.isDark ? tokens.errorText : SettingsColors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.isDark
                            ? tokens.errorText
                            : SettingsColors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.isDark
                            ? tokens.textSecondary
                            : SettingsColors.ink,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.isDark ? tokens.errorText : SettingsColors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsInfoBanner extends StatelessWidget {
  const SettingsInfoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.icon = Icons.info_outline_rounded,
    this.background = SettingsColors.paleBlue,
    this.iconColor = SettingsColors.blue,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final resolvedBg = tokens.isDark ? tokens.surfaceElevated : background;
    final resolvedIconColor = tokens.isDark ? tokens.bluePrimary : iconColor;

    return Material(
      color: resolvedBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SettingsIconBadge(
                icon: icon,
                color: resolvedIconColor,
                background: tokens.surfaceCard,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(Icons.chevron_right_rounded, color: tokens.chevron)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsDestructiveBanner extends StatelessWidget {
  const SettingsDestructiveBanner({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.isDark ? tokens.errorContainer : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tokens.isDark
              ? const Color(0xFF5A2924)
              : const Color(0xFFFFD5D5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: tokens.isDark ? tokens.errorText : SettingsColors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.isDark
                        ? tokens.errorText
                        : SettingsColors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: tokens.isDark
                        ? tokens.textSecondary
                        : SettingsColors.ink,
                    height: 1.35,
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

class SettingsCheckList extends StatelessWidget {
  const SettingsCheckList({
    super.key,
    required this.items,
    this.positive = true,
  });

  final List<String> items;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return SettingsSurface(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    positive
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_rounded,
                    color: positive
                        ? tokens.success
                        : (tokens.isDark
                              ? tokens.iconFgPurple
                              : SettingsColors.purple),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(height: 1.35, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Divider(height: 1, color: tokens.borderSubtle),
              ),
          ],
        ],
      ),
    );
  }
}

class NestedSettingsScaffold extends StatelessWidget {
  const NestedSettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        backgroundColor: tokens.bgApp,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.headerAction),
        ),
        titleSpacing: 4,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: tokens.sectionHeading,
                fontSize: 13,
                letterSpacing: .35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SettingsSurface extends StatelessWidget {
  const SettingsSurface({
    super.key,
    required this.child,
    this.padding,
    this.color = Colors.white,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveBg = (color == Colors.white) ? tokens.surfaceCard : color;
    final effectiveBorder =
        borderColor ?? (tokens.isDark ? tokens.borderSubtle : null);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(18),
        border: effectiveBorder == null
            ? null
            : Border.all(color: effectiveBorder),
        boxShadow: tokens.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C1D2B4B),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: child,
    );
  }
}

class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({
    super.key,
    required this.icon,
    this.color = SettingsColors.blue,
    this.background = SettingsColors.paleBlue,
    this.size = 52,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveBg = tokens.isDark
        ? _adaptBadgeBg(background, tokens)
        : background;
    final effectiveFg = tokens.isDark ? _adaptBadgeFg(color, tokens) : color;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(icon, color: effectiveFg, size: size * .48),
    );
  }
}

class SettingsListItem extends StatelessWidget {
  const SettingsListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = SettingsColors.blue,
    this.iconBackground = SettingsColors.paleBlue,
    this.trailing,
    this.destructive = false,
    this.showDivider = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconBackground;
  final Widget? trailing;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final effectiveIconColor = destructive
        ? (tokens.isDark ? tokens.errorText : SettingsColors.red)
        : (tokens.isDark && iconColor == SettingsColors.blue
              ? tokens.bluePrimary
              : iconColor);

    final effectiveIconBg = destructive
        ? (tokens.isDark ? tokens.errorContainer : const Color(0xFFFFEEEE))
        : (tokens.isDark
              ? _adaptBadgeBg(iconBackground, tokens)
              : iconBackground);

    final effectiveTitleColor = destructive
        ? (tokens.isDark ? tokens.errorText : SettingsColors.red)
        : tokens.textPrimary;

    final effectiveChevronColor = destructive
        ? (tokens.isDark ? tokens.errorText : SettingsColors.red)
        : tokens.chevron;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Semantics(
              button: onTap != null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    SettingsIconBadge(
                      icon: icon,
                      color: effectiveIconColor,
                      background: effectiveIconBg,
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: effectiveTitleColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (trailing != null)
                      trailing!
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: effectiveChevronColor,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 76),
            child: Divider(height: 1, color: tokens.borderSubtle),
          ),
      ],
    );
  }
}

void showSettingsUnavailable(BuildContext context, {String? message}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          message ??
              'Secure setup is required before this home setting can be changed.',
        ),
      ),
    );
}
