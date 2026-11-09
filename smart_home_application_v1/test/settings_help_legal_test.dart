import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/repositories/legal_document_repository.dart';
import 'package:smart_home_application_v1/core/repositories/settings_help_repository.dart';

void main() {
  test('contextual help uses stable screen-specific content', () {
    final privacy = SettingsHelpRepository.forScreen('privacy');
    final context = SettingsHelpRepository.forScreen('home_context');
    expect(privacy.id, 'privacy');
    expect(context.id, 'home_context');
    expect(privacy.purpose, isNot(context.purpose));
    expect(context.howItWorks, contains('HOME'));
  });

  test('all legal documents are versioned drafts with review gaps visible', () {
    for (final id in const [
      'security_document',
      'privacy_policy',
      'terms_of_service',
      'data_practices',
    ]) {
      final document = LegalDocumentRepository.get(id);
      expect(document.version, isNotEmpty);
      expect(document.lastUpdated, isNotEmpty);
      expect(document.sections, isNotEmpty);
      expect(
        document.sections.any((section) => section.body.contains('[TO BE')),
        isTrue,
        reason: '$id should expose unresolved human-review items',
      );
    }
  });
}
