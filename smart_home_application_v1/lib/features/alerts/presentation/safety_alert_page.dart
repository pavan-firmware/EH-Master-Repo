import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SafetyAlertPage extends StatelessWidget {
  const SafetyAlertPage({super.key});
  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final bg = tokens.isDark ? tokens.bgApp : const Color(0xFFFFF7F4);
    final iconBg = tokens.isDark ? tokens.warningContainer : const Color(0xFFFFE3D9);
    final warnColor = tokens.isDark ? tokens.warning : const Color(0xFFB9441D);
    final subColor = tokens.isDark ? tokens.textSecondary : const Color(0xFF684B41);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: tokens.headerAction),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: warnColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Kitchen needs attention',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your kitchen air sensor reported an unusual reading at 6:42 PM.',
                style: TextStyle(fontSize: 16, color: subColor),
              ),
              const SizedBox(height: 26),
              _SafetyStep(
                number: '1',
                text:
                    'Open windows and avoid using flames or electrical switches nearby.',
                numBg: iconBg,
                numColor: warnColor,
              ),
              _SafetyStep(
                number: '2',
                text:
                    'Check the area only if it is safe to do so. Leave the home if you smell gas.',
                numBg: iconBg,
                numColor: warnColor,
              ),
              _SafetyStep(
                number: '3',
                text:
                    'Call your local emergency service or gas supplier if you are concerned.',
                numBg: iconBg,
                numColor: warnColor,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.isDark ? tokens.blueDarker : null,
                    foregroundColor: tokens.textPrimary,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Acknowledge alert'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Acknowledging does not turn off home safety monitoring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyStep extends StatelessWidget {
  const _SafetyStep({
    required this.number,
    required this.text,
    required this.numBg,
    required this.numColor,
  });
  final String number;
  final String text;
  final Color numBg;
  final Color numColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: numBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: numColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 15, height: 1.35, color: tokens.textPrimary)),
          ),
        ],
      ),
    );
  }
}
