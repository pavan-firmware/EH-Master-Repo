# Settings Help and Legal Audit

Status: implemented in the Flutter app; legal documents remain **Draft – Pending Legal Review**.

## Route audit

The shared `NestedSettingsScaffold` now supplies a back action and contextual Help action to nested Settings routes. Existing custom actions are preserved. Covered routes include Settings, Home Details, People at Home, Device Health, Help and Support, Privacy, Privacy permission/data details, Factory Reset, notification preferences, update preferences/history, and advanced fleet operations.

The shared Help action is also wired into the standalone Settings-adjacent pages for System Update, Home Context & Modes, Presence & Occupancy, Local-First Edge Control, Disaster Recovery & Resilience, Electricity Tariffs, and Cloud Sync & Recovery.

Stable IDs and content are maintained in:

- `smart_home_application_v1/lib/core/repositories/settings_help_repository.dart`
- `smart_home_application_v1/lib/core/models/settings_help_models.dart`

Unknown route IDs fall back to the Settings explanation rather than displaying a misleading screen-specific claim. Content includes purpose, usefulness, operation, actions, limitations, and an implementation status.

## Legal content

The former unsupported single-paragraph legal text was replaced with four structured documents:

- `security_document`
- `privacy_policy`
- `terms_of_service`
- `data_practices`

They are stored in `legal_document_repository.dart`, rendered by the shared legal page, and include version, last-updated date, draft status, numbered sections, contents, explicit placeholders, and a legal-review checklist.

Claims such as hardware-backed identity, universal mTLS, end-to-end encryption, certifications, retention periods, hosting location, and third-party sharing are not asserted without verification. Source-backed controls are labelled as implemented or partial and still require deployment/hardware review where appropriate.

## Verification

- `flutter analyze`: passes; one pre-existing `prefer_initializing_formals` info remains in `core/repositories/settings_repository.dart:26`.
- `flutter test test/settings_help_legal_test.dart`: 2 tests passed.
- Focused Settings/dark-theme suite: dark-theme checks and the new tests passed; two existing Settings navigation tests fail because the test environment lacks a platform implementation for `ReactiveBlePlatform.initialize()` while opening Add a device. This is unrelated to Help/legal rendering.

## Human input still required

- Legal entity, registered address, privacy contact, grievance contact, approval metadata.
- Production retention/deletion schedules, hosting region, processors, and backup/audit retention.
- Deployment verification for authentication expiry/recovery, transport coverage, hardware security configuration, OTA enforcement, and permission behavior.
- Authorized legal review before any document is treated as effective.
