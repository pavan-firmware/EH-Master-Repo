import '../models/settings_help_models.dart';

/// Single source of truth for contextual Settings help. IDs are stable and
/// intentionally independent of translated/display titles.
class SettingsHelpRepository {
  const SettingsHelpRepository._();

  static const _default = SettingsHelpContent(
    id: 'settings',
    title: 'Settings',
    purpose: 'Manage your home, account, devices, preferences, and privacy.',
    usefulBecause:
        'It keeps configuration and safety-sensitive actions in one place.',
    howItWorks:
        'Choose a section to review its current state or change a supported setting.',
    actions: ['Review the section that matches what you want to change.'],
    limitations: [
      'Only controls currently implemented by EH Home are available.',
    ],
  );

  static const _contents = <String, SettingsHelpContent>{
    'settings': _default,
    'privacy': SettingsHelpContent(
      id: 'privacy',
      title: 'Privacy',
      purpose:
          'Review data categories, app permissions, and available privacy controls.',
      usefulBecause:
          'It shows what the app can access and which optional sharing controls are available.',
      howItWorks:
          'Permission status is read from the platform; supported preferences are stored through the privacy repository.',
      actions: [
        'Open a data category for details.',
        'Review permissions and optional diagnostic or analytics controls.',
        'Open the legal and security documents.',
      ],
      limitations: [
        'Account deletion, retention schedules, and legal contacts are not fully implemented in the app.',
      ],
    ),
    'security': SettingsHelpContent(
      id: 'security',
      title: 'Security',
      purpose:
          'Describe the security controls that are implemented, partial, planned, or unavailable.',
      usefulBecause:
          'It makes security boundaries and remaining gaps visible before you rely on the system.',
      howItWorks:
          'The document is maintained from verified repository evidence and is labelled as a draft until legal review.',
      actions: [
        'Read each control section and its status.',
        'Use the limitations and review checklist to identify gaps.',
      ],
      limitations: [
        'This is not a certification, security score, or guarantee of uninterrupted operation.',
      ],
    ),
    'privacy_policy': SettingsHelpContent(
      id: 'privacy_policy',
      title: 'Privacy Policy',
      purpose: 'Explain what information EH Home may process and why.',
      usefulBecause:
          'It provides a readable record of data handling and unresolved policy decisions.',
      howItWorks:
          'The policy is displayed from the shared legal document source and includes version and draft metadata.',
      actions: [
        'Review collection, storage, sharing, retention, and deletion sections.',
      ],
      limitations: [
        'Contact details, entity details, hosting, and retention values remain placeholders where source evidence is missing.',
      ],
      status: SettingsHelpStatus.partial,
    ),
    'terms_of_service': SettingsHelpContent(
      id: 'terms_of_service',
      title: 'Terms of Service',
      purpose: 'Set out the proposed rules and limitations for using EH Home.',
      usefulBecause:
          'It explains responsibilities for installation, connectivity, accounts, and automation.',
      howItWorks:
          'The terms are shown as a versioned draft pending authorized legal review.',
      actions: [
        'Read the usage, safety, availability, and termination sections.',
      ],
      limitations: [
        'The document is not effective legal advice or an approved contract until reviewed.',
      ],
      status: SettingsHelpStatus.partial,
    ),
    'data_practices': SettingsHelpContent(
      id: 'data_practices',
      title: 'Data Practices',
      purpose: 'Show operational data flows from collection through deletion.',
      usefulBecause:
          'It connects user-visible data categories to the app and backend behavior.',
      howItWorks:
          'The tables are generated from the shared legal content source and identify pending verification items.',
      actions: [
        'Review the collection map, storage map, lifecycle, controls, and retention sections.',
      ],
      limitations: [
        'Only source-verified fields are listed; unknown retention and hosting details are explicitly pending.',
      ],
      status: SettingsHelpStatus.partial,
    ),
    'home_context': SettingsHelpContent(
      id: 'home_context',
      title: 'Home Context & Modes',
      purpose:
          'Choose the current context used by supported routines and presence rules.',
      usefulBecause:
          'A clear context helps supported automations decide which rules should be considered.',
      howItWorks:
          'Supported modes are HOME, AWAY, SLEEP, VACATION, GUEST, and QUIET_HOURS. Priority is manual, scheduled, presence, then default.',
      actions: [
        'Select a mode.',
        'Review scheduled and presence sources where available.',
        'Clear or set expiry only when the screen exposes that control.',
      ],
      limitations: [
        'Changing a mode does not itself claim to switch lights, security, or other devices unless a configured automation does so.',
      ],
    ),
    'presence': SettingsHelpContent(
      id: 'presence',
      title: 'Presence & Occupancy',
      purpose:
          'Review presence signals and the occupancy state used by supported context logic.',
      usefulBecause:
          'It helps explain why a context or routine may be selected.',
      howItWorks:
          'The page combines the available presence sources and shows their current state.',
      actions: [
        'Review sources and timestamps.',
        'Inspect source details before relying on an occupancy result.',
      ],
      limitations: [
        'Presence is not a safety guarantee and can be stale, unavailable, or affected by permissions and connectivity.',
      ],
    ),
    'edge_control': SettingsHelpContent(
      id: 'edge_control',
      title: 'Local-First Edge Control',
      purpose:
          'Show commands and routines that can execute through the local device path.',
      usefulBecause:
          'Local execution can reduce dependence on internet connectivity for supported devices.',
      howItWorks:
          'The app reconciles supported routines and commands with reachable edge devices.',
      actions: [
        'Review local reachability and execution status.',
        'Inspect failures before retrying a command.',
      ],
      limitations: [
        'Local operation depends on device firmware, network reachability, and feature support. Cloud-dependent features still need the cloud.',
      ],
    ),
    'recovery': SettingsHelpContent(
      id: 'recovery',
      title: 'Disaster Recovery & Resilience',
      purpose:
          'Review backup, restore, and resilience state for supported home data.',
      usefulBecause:
          'It makes recovery readiness and restore limitations visible.',
      howItWorks:
          'The page reports repository-backed backup and recovery state; it does not create guarantees about backups that are not present.',
      actions: [
        'Review backup history and available recovery actions.',
        'Read restore impact before proceeding.',
      ],
      limitations: [
        'A backup is not a substitute for safe local operation; unavailable or pending backups cannot be treated as recoverable.',
      ],
    ),
    'tariffs': SettingsHelpContent(
      id: 'tariffs',
      title: 'Energy & Electricity Tariffs',
      purpose: 'Manage tariff inputs used by energy cost calculations.',
      usefulBecause: 'Accurate tariff inputs make cost estimates more useful.',
      howItWorks:
          'The energy service uses saved tariff periods and rates when calculating supported estimates.',
      actions: [
        'Review existing periods.',
        'Add or edit a rate only when you have the correct utility information.',
      ],
      limitations: [
        'Estimates depend on entered rates and available telemetry; they are not utility bills.',
      ],
    ),
  };

  static SettingsHelpContent forScreen(String id) {
    final normalized = id.trim().toLowerCase();
    return _contents[normalized] ?? _contents[_alias(normalized)] ?? _default;
  }

  static String _alias(String id) {
    if (id.contains('privacy')) return 'privacy';
    if (id.contains('security')) return 'security';
    if (id.contains('terms')) return 'terms_of_service';
    if (id.contains('data')) return 'data_practices';
    if (id.contains('presence')) return 'presence';
    if (id.contains('context') || id.contains('mode')) return 'home_context';
    if (id.contains('edge')) return 'edge_control';
    if (id.contains('recovery') || id.contains('disaster')) return 'recovery';
    if (id.contains('tariff') || id.contains('energy')) return 'tariffs';
    return 'settings';
  }
}
