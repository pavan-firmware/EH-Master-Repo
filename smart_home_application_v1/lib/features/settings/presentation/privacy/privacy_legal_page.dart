import 'package:flutter/material.dart';

import '../../../../core/models/legal_document_models.dart';
import '../../../../core/repositories/legal_document_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../settings_ui.dart';

class PrivacyLegalPage extends StatelessWidget {
  const PrivacyLegalPage({super.key, required this.title, required this.kind});

  final String title;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final document = LegalDocumentRepository.get(switch (kind) {
      'security' => 'security_document',
      'privacy' => 'privacy_policy',
      'terms' => 'terms_of_service',
      _ => 'data_practices',
    });
    final tokens = context.ehColors;
    return NestedSettingsScaffold(
      title: title,
      screenId: document.id,
      subtitle: 'Draft – Pending Legal Review',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          SettingsSurface(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Version ${document.version}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Last updated ${document.lastUpdated}',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                  SettingsStatusChip(
                    label: 'Draft – Pending Legal Review',
                    color: tokens.warning,
                    background: tokens.warningContainer,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SettingsSurface(
            child: ExpansionTile(
              title: const Text(
                'Contents',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                for (final section in document.sections)
                  ListTile(dense: true, title: Text(section.heading)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final section in document.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _LegalSectionView(section: section, tokens: tokens),
            ),
          SettingsSurface(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Legal review checklist: confirm company identity and address, privacy and grievance contacts, retention periods, hosting location, processors, rights workflows, consent, deletion, and children’s policy.',
                style: TextStyle(color: tokens.textSecondary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section, required this.tokens});
  final LegalSection section;
  final EHThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        section.heading,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: tokens.textPrimary,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        section.body,
        style: TextStyle(height: 1.5, color: tokens.textPrimary),
      ),
      for (final bullet in section.bullets)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: TextStyle(color: tokens.bluePrimary)),
              Expanded(
                child: Text(
                  bullet,
                  style: TextStyle(height: 1.4, color: tokens.textSecondary),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
