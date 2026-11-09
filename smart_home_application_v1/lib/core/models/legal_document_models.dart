import 'package:flutter/foundation.dart';

enum LegalDocumentStatus { draftPendingReview, approved }

@immutable
class LegalSection {
  const LegalSection({
    required this.id,
    required this.heading,
    required this.body,
    this.bullets = const [],
  });
  final String id;
  final String heading;
  final String body;
  final List<String> bullets;
}

@immutable
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.lastUpdated,
    required this.status,
    required this.sections,
  });
  final String id;
  final String title;
  final String version;
  final String lastUpdated;
  final LegalDocumentStatus status;
  final List<LegalSection> sections;
}
