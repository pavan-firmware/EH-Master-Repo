import '../models/legal_document_models.dart';

/// Versioned, UI-independent legal content source.
///
/// Every unknown legal or operational fact is deliberately marked for human
/// input instead of being inferred from a feature name or a design document.
class LegalDocumentRepository {
  const LegalDocumentRepository._();

  static const _metaVersion = '0.1-draft';
  static const _date = '2026-11-04';
  static const _status = LegalDocumentStatus.draftPendingReview;

  static const documents = <String, LegalDocument>{
    'security_document': LegalDocument(
      id: 'security_document',
      title: 'Security',
      version: _metaVersion,
      lastUpdated: _date,
      status: _status,
      sections: [
        LegalSection(
          id: 'overview',
          heading: '1. Overview',
          body:
              'EH Home is a smart-home control platform. This draft describes controls visible in the repository and identifies controls that still require verification.',
        ),
        LegalSection(
          id: 'account',
          heading: '2. Account security',
          body:
              'The app and backend contain authenticated session and token flows. Exact expiry, password hashing configuration, recovery, and multi-factor authentication should be confirmed against the deployed environment.',
          bullets: [
            'Status: Partially implemented',
            'MFA: [TO BE VERIFIED]',
            'Password storage and recovery policy: [TO BE VERIFIED]',
          ],
        ),
        LegalSection(
          id: 'device',
          heading: '3. Device identity and authentication',
          body:
              'Device registration, claiming, trust, and removal flows exist in the project. The exact production provisioning and decommissioning guarantees require hardware and deployment verification.',
          bullets: [
            'Status: Partially implemented',
            'Hardware-backed identity: [TO BE VERIFIED]',
          ],
        ),
        LegalSection(
          id: 'communication',
          heading: '4. Communication security',
          body:
              'The repository documents MQTT transport and TLS/mTLS design. This page does not claim that every local path, commissioning path, or deployed environment uses the same protection.',
          bullets: [
            'Cloud/device MQTT TLS or mTLS: Partially implemented / deployment-dependent',
            'Local and Bluetooth protection: [TO BE VERIFIED]',
            'End-to-end encryption: Not claimed',
          ],
        ),
        LegalSection(
          id: 'firmware',
          heading: '5. Firmware and hardware security',
          body:
              'Signed OTA and rollback-related tooling and documentation are present. Secure boot, flash encryption, debug locking, anti-rollback enforcement, and credential isolation must be verified on the target hardware.',
          bullets: [
            'Status: Partially implemented',
            'Certifications: None claimed',
          ],
        ),
        LegalSection(
          id: 'authorization',
          heading: '6. Authorization and home isolation',
          body:
              'Backend home authorization and owner/member access-control code and tests are present. Deployment configuration and operational review remain required.',
          bullets: [
            'Status: Implemented in source; deployment verification pending',
          ],
        ),
        LegalSection(
          id: 'operations',
          heading: '7. Monitoring and incident response',
          body:
              'Operational logging and observability code exists. No SOC, ISO certification, SLA, or incident-response time is claimed.',
          bullets: [
            'Status: Partially implemented',
            'Security score: Not provided',
          ],
        ),
        LegalSection(
          id: 'responsibilities',
          heading: '8. User responsibilities and limitations',
          body:
              'Keep accounts, Wi-Fi, devices, and electrical installations secure. EH Home is not a certified safety system and cannot guarantee uninterrupted operation.',
        ),
        LegalSection(
          id: 'review',
          heading: '9. Version and review',
          body:
              'Draft – Pending Legal Review. Last updated: 2026-11-04. Approval metadata: [TO BE PROVIDED].',
        ),
      ],
    ),
    'privacy_policy': LegalDocument(
      id: 'privacy_policy',
      title: 'Privacy Policy',
      version: _metaVersion,
      lastUpdated: _date,
      status: _status,
      sections: [
        LegalSection(
          id: 'scope',
          heading: '1. Introduction and scope',
          body:
              'This draft applies to the EH Home app and its supported home, device, automation, activity, and presence features.',
        ),
        LegalSection(
          id: 'categories',
          heading: '2. Information we process',
          body:
              'Account and home configuration, device and automation configuration, activity records, presence/context signals, permissions, and diagnostics may be processed where the corresponding feature is used. Required, optional, and generated classification should be confirmed for each production release.',
        ),
        LegalSection(
          id: 'permissions',
          heading: '3. Permissions',
          body:
              'The app requests platform permissions needed for supported nearby-device setup, notifications, and location-related flows. The app should only use a permission for the feature described in its permission screen; continuous tracking is not claimed.',
        ),
        LegalSection(
          id: 'use_storage',
          heading: '4. Use and storage',
          body:
              'Data may be held in app storage, secure storage, device storage, backend databases, caches, and backups depending on the feature. Exact locations, encryption configuration, hosting region, processors, and retention periods are [TO BE VERIFIED].',
        ),
        LegalSection(
          id: 'sharing',
          heading: '5. Sharing',
          body:
              'No third-party sharing arrangement is asserted here without dependency and deployment verification. Verified providers and processing roles: [TO BE PROVIDED].',
        ),
        LegalSection(
          id: 'retention',
          heading: '6. Retention and deletion',
          body:
              'Category-specific retention schedules and deletion behavior for live data, backups, audit records, and legal retention are [TO BE PROVIDED]. Account closure workflow: [TO BE VERIFIED].',
        ),
        LegalSection(
          id: 'rights',
          heading: '7. Rights and law',
          body:
              'This draft is intended to be reviewed against the Digital Personal Data Protection Act, 2023 and applicable rules in force at publication, the Information Technology Act, 2000, and the Consumer Protection Act, 2019. It does not claim compliance or create deadlines.',
        ),
        LegalSection(
          id: 'contact',
          heading: '8. Contact and grievance',
          body:
              'Privacy contact: [TO BE PROVIDED]\nGrievance contact: [TO BE PROVIDED]\nLegal entity and registered address: [TO BE VERIFIED]',
        ),
        LegalSection(
          id: 'children',
          heading: '9. Children and changes',
          body:
              'Children’s privacy position and policy-change notice process: [TO BE PROVIDED].',
        ),
      ],
    ),
    'terms_of_service': LegalDocument(
      id: 'terms_of_service',
      title: 'Terms of Service',
      version: _metaVersion,
      lastUpdated: _date,
      status: _status,
      sections: [
        LegalSection(
          id: 'acceptance',
          heading: '1. Acceptance and definitions',
          body:
              'EH Home is a smart-home control platform. Using the app or connected devices is subject to the final terms approved by the responsible legal entity.',
        ),
        LegalSection(
          id: 'accounts',
          heading: '2. Eligibility, accounts, and access',
          body:
              'Users are responsible for accurate account details, protecting credentials, and only inviting people who should access the home.',
        ),
        LegalSection(
          id: 'devices',
          heading: '3. Homes, devices, and compatibility',
          body:
              'Registration, commissioning, ownership, membership, and supported-device behavior depend on the device, firmware, network, and app version.',
        ),
        LegalSection(
          id: 'local_cloud',
          heading: '4. Local and cloud functionality',
          body:
              'Cloud or internet outages affect cloud-dependent features. Local control depends on device, firmware, and network capability. No uninterrupted-operation guarantee is made.',
        ),
        LegalSection(
          id: 'safety',
          heading: '5. Safety and user responsibility',
          body:
              'EH Home is not a certified safety system. Users are responsible for safe installation, rated electrical work by qualified persons, secure networks, and checking automation before enabling it.',
        ),
        LegalSection(
          id: 'updates',
          heading: '6. Updates and third-party services',
          body:
              'Software and firmware updates may change behavior. Third-party services, network providers, and device compatibility may be outside EH Home’s control.',
        ),
        LegalSection(
          id: 'legal',
          heading: '7. Liability, termination, and disputes',
          body:
              'Warranty, limitation of liability, indemnification, suspension, termination, governing law, jurisdiction, dispute resolution, and contact terms require authorized legal drafting and are [TO BE PROVIDED].',
        ),
      ],
    ),
    'data_practices': LegalDocument(
      id: 'data_practices',
      title: 'Data Practices',
      version: _metaVersion,
      lastUpdated: _date,
      status: _status,
      sections: [
        LegalSection(
          id: 'map',
          heading: '1. Collection overview',
          body:
              'Account/home fields: account identity and home membership, for authentication and authorization. Device/configuration fields: device identity, capabilities, rooms, and settings, for control. Automation fields: triggers, conditions, and actions, for routines. Activity and telemetry: command and device events, for status and history. Presence/context: available signals and selected context, for supported automations. Exact field-level inventory: [TO BE VERIFIED].',
        ),
        LegalSection(
          id: 'storage',
          heading: '2. Storage map',
          body:
              'App memory/cache, secure storage, device storage, backend database, object storage, and backups are used only where the corresponding implementation exists. Object storage, backup retention, and hosting region: [TO BE VERIFIED].',
        ),
        LegalSection(
          id: 'lifecycle',
          heading: '3. Lifecycle',
          body:
              'Collection → validation → processing → storage → sync → retention → deletion. Each feature’s exact retention and deletion behavior is pending operational confirmation.',
        ),
        LegalSection(
          id: 'controls',
          heading: '4. Protection controls',
          body:
              'Authentication, authorization, rate limiting, structured logging, device trust, and transport protections are represented in source. Their production configuration and coverage are not a blanket guarantee.',
        ),
        LegalSection(
          id: 'third_party',
          heading: '5. Verified third-party providers',
          body:
              'Provider and SDK inventory must be reviewed for each release. No provider is declared “none” by assumption.',
        ),
        LegalSection(
          id: 'user_controls',
          heading: '6. User controls',
          body:
              'The app exposes permission status, supported privacy preferences, data details, export UI, and activity-history controls. Actual deletion scope and account closure workflow require verification.',
        ),
        LegalSection(
          id: 'not_collected',
          heading: '7. Data not collected',
          body:
              'No category is declared absent unless verified across app permissions, backend, firmware, and SDKs. Pending verification: precise location, contacts, camera, microphone, advertising identifiers, and continuous tracking.',
        ),
      ],
    ),
  };

  static LegalDocument get(String id) =>
      documents[id] ?? documents['privacy_policy']!;
}
