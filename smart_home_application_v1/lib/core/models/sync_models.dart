import 'package:flutter/foundation.dart';

/// Sync status state machine representation
enum SyncStatus {
  synced,
  syncing,
  offline,
  pendingChanges,
  conflict,
  error,
}

/// A queued offline mutation awaiting cloud reconciliation
@immutable
class PendingMutation {
  final String mutationId;
  final String entityType; // 'home', 'room', 'device', 'scene', 'automation', 'profile', 'notification_preference'
  final String? entityId;
  final String mutationType; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime clientTimestamp;
  final int retryCount;

  const PendingMutation({
    required this.mutationId,
    required this.entityType,
    this.entityId,
    required this.mutationType,
    required this.payload,
    required this.clientTimestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'mutationId': mutationId,
        'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        'mutationType': mutationType,
        'payload': payload,
        'clientTimestamp': clientTimestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> json) =>
      PendingMutation(
        mutationId: json['mutationId'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String?,
        mutationType: json['mutationType'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        clientTimestamp: DateTime.parse(json['clientTimestamp'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

/// Result of an individual mutation reconciliation
@immutable
class MutationResult {
  final String mutationId;
  final String status; // 'ACCEPTED', 'REJECTED', 'CONFLICT'
  final String? reason;
  final String? serverEntityId;
  final Map<String, dynamic>? authoritativeData;

  const MutationResult({
    required this.mutationId,
    required this.status,
    this.reason,
    this.serverEntityId,
    this.authoritativeData,
  });

  factory MutationResult.fromJson(Map<String, dynamic> json) => MutationResult(
        mutationId: json['mutationId'] as String,
        status: json['status'] as String,
        reason: json['reason'] as String?,
        serverEntityId: json['serverEntityId'] as String?,
        authoritativeData: json['authoritativeData'] != null
            ? Map<String, dynamic>.from(json['authoritativeData'] as Map)
            : null,
      );
}

/// Aggregate reconciliation summary returned by cloud
@immutable
class ReconciliationSummary {
  final DateTime reconciledAt;
  final int totalMutations;
  final int acceptedCount;
  final int rejectedCount;
  final int conflictCount;
  final List<MutationResult> results;

  const ReconciliationSummary({
    required this.reconciledAt,
    required this.totalMutations,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.conflictCount,
    required this.results,
  });

  factory ReconciliationSummary.fromJson(Map<String, dynamic> json) =>
      ReconciliationSummary(
        reconciledAt: DateTime.parse(json['reconciledAt'] as String),
        totalMutations: json['totalMutations'] as int? ?? 0,
        acceptedCount: json['acceptedCount'] as int? ?? 0,
        rejectedCount: json['rejectedCount'] as int? ?? 0,
        conflictCount: json['conflictCount'] as int? ?? 0,
        results: (json['results'] as List? ?? [])
            .map((r) => MutationResult.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );
}

/// Full bootstrap snapshot bundle for instant local cache restoration
@immutable
class SyncBootstrapBundle {
  final int schemaVersion;
  final DateTime syncedAt;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> homes;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> automations;
  final List<Map<String, dynamic>> scenes;
  final List<Map<String, dynamic>> schedules;
  final Map<String, dynamic>? notificationPreferences;

  const SyncBootstrapBundle({
    required this.schemaVersion,
    required this.syncedAt,
    required this.user,
    required this.homes,
    required this.members,
    required this.rooms,
    required this.devices,
    required this.automations,
    required this.scenes,
    required this.schedules,
    this.notificationPreferences,
  });

  factory SyncBootstrapBundle.fromJson(Map<String, dynamic> json) =>
      SyncBootstrapBundle(
        schemaVersion: json['schemaVersion'] as int? ?? 1,
        syncedAt: DateTime.parse(json['syncedAt'] as String),
        user: Map<String, dynamic>.from(json['user'] as Map? ?? {}),
        homes: (json['homes'] as List? ?? [])
            .map((h) => Map<String, dynamic>.from(h as Map))
            .toList(),
        members: (json['members'] as List? ?? [])
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList(),
        rooms: (json['rooms'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        devices: (json['devices'] as List? ?? [])
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList(),
        automations: (json['automations'] as List? ?? [])
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList(),
        scenes: (json['scenes'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList(),
        schedules: (json['schedules'] as List? ?? [])
            .map((sc) => Map<String, dynamic>.from(sc as Map))
            .toList(),
        notificationPreferences: json['notificationPreferences'] != null
            ? Map<String, dynamic>.from(json['notificationPreferences'] as Map)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'syncedAt': syncedAt.toIso8601String(),
        'user': user,
        'homes': homes,
        'members': members,
        'rooms': rooms,
        'devices': devices,
        'automations': automations,
        'scenes': scenes,
        'schedules': schedules,
        'notificationPreferences': notificationPreferences,
      };
}
