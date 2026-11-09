import 'package:flutter/foundation.dart';

enum SettingsHelpStatus { implemented, partial, planned, unavailable }

@immutable
class SettingsHelpContent {
  const SettingsHelpContent({
    required this.id,
    required this.title,
    required this.purpose,
    required this.usefulBecause,
    required this.howItWorks,
    required this.actions,
    required this.limitations,
    this.status = SettingsHelpStatus.implemented,
  });

  final String id;
  final String title;
  final String purpose;
  final String usefulBecause;
  final String howItWorks;
  final List<String> actions;
  final List<String> limitations;
  final SettingsHelpStatus status;
}
