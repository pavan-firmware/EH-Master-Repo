import 'package:flutter/foundation.dart';

enum PresenceState {
  home,
  away,
  unknown,
  sleep;

  String toApiValue() {
    switch (this) {
      case PresenceState.home:
        return 'HOME';
      case PresenceState.away:
        return 'AWAY';
      case PresenceState.unknown:
        return 'UNKNOWN';
      case PresenceState.sleep:
        return 'SLEEP';
    }
  }

  static PresenceState fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'HOME':
        return PresenceState.home;
      case 'AWAY':
        return PresenceState.away;
      case 'SLEEP':
        return PresenceState.sleep;
      case 'UNKNOWN':
      default:
        return PresenceState.unknown;
    }
  }
}

enum PresenceSource {
  manual,
  mobileApp,
  lanWifi,
  ble,
  deviceActivity,
  sensor;

  String toApiValue() {
    switch (this) {
      case PresenceSource.manual:
        return 'manual';
      case PresenceSource.mobileApp:
        return 'mobile_app';
      case PresenceSource.lanWifi:
        return 'lan_wifi';
      case PresenceSource.ble:
        return 'ble';
      case PresenceSource.deviceActivity:
        return 'device_activity';
      case PresenceSource.sensor:
        return 'sensor';
    }
  }

  static PresenceSource fromApiValue(String? val) {
    switch (val?.toLowerCase()) {
      case 'manual':
        return PresenceSource.manual;
      case 'mobile_app':
      case 'mobileapp':
        return PresenceSource.mobileApp;
      case 'lan_wifi':
      case 'wifi':
        return PresenceSource.lanWifi;
      case 'ble':
      case 'bluetooth':
        return PresenceSource.ble;
      case 'device_activity':
        return PresenceSource.deviceActivity;
      case 'sensor':
        return PresenceSource.sensor;
      default:
        return PresenceSource.mobileApp;
    }
  }
}

enum ContextMode {
  home,
  away,
  sleep,
  vacation,
  guest,
  quietHours;

  String toApiValue() {
    switch (this) {
      case ContextMode.home:
        return 'HOME';
      case ContextMode.away:
        return 'AWAY';
      case ContextMode.sleep:
        return 'SLEEP';
      case ContextMode.vacation:
        return 'VACATION';
      case ContextMode.guest:
        return 'GUEST';
      case ContextMode.quietHours:
        return 'QUIET_HOURS';
    }
  }

  static ContextMode fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'HOME':
        return ContextMode.home;
      case 'AWAY':
        return ContextMode.away;
      case 'SLEEP':
        return ContextMode.sleep;
      case 'VACATION':
        return ContextMode.vacation;
      case 'GUEST':
        return ContextMode.guest;
      case 'QUIET_HOURS':
        return ContextMode.quietHours;
      default:
        return ContextMode.home;
    }
  }
}

enum PrecedenceTier {
  manualOverride,
  scheduledWindow,
  reconciledPresence,
  defaultFallback;

  static PrecedenceTier fromApiValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'MANUAL_OVERRIDE':
        return PrecedenceTier.manualOverride;
      case 'SCHEDULED_WINDOW':
        return PrecedenceTier.scheduledWindow;
      case 'RECONCILED_PRESENCE':
        return PrecedenceTier.reconciledPresence;
      case 'DEFAULT_FALLBACK':
      default:
        return PrecedenceTier.defaultFallback;
    }
  }
}

@immutable
class PresenceSignalModel {
  final String id;
  final String userId;
  final String homeId;
  final PresenceSource source;
  final PresenceState state;
  final double confidence;
  final Map<String, dynamic> evidence;
  final DateTime observedAt;
  final DateTime? expiresAt;

  const PresenceSignalModel({
    required this.id,
    required this.userId,
    required this.homeId,
    required this.source,
    required this.state,
    required this.confidence,
    this.evidence = const {},
    required this.observedAt,
    this.expiresAt,
  });

  factory PresenceSignalModel.fromJson(Map<String, dynamic> json) {
    return PresenceSignalModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      homeId: json['home_id']?.toString() ?? json['homeId']?.toString() ?? '',
      source: PresenceSource.fromApiValue(json['source']?.toString()),
      state: PresenceState.fromApiValue(json['state']?.toString()),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      evidence: json['evidence'] is Map ? Map<String, dynamic>.from(json['evidence'] as Map) : {},
      observedAt: json['observed_at'] != null
          ? DateTime.parse(json['observed_at'].toString())
          : (json['observedAt'] != null ? DateTime.parse(json['observedAt'].toString()) : DateTime.now()),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'].toString())
          : (json['expiresAt'] != null ? DateTime.parse(json['expiresAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'home_id': homeId,
        'source': source.toApiValue(),
        'state': state.toApiValue(),
        'confidence': confidence,
        'evidence': evidence,
        'observed_at': observedAt.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      };
}

@immutable
class UserPresenceState {
  final String userId;
  final PresenceState state;
  final double confidence;
  final PresenceSource source;
  final bool isStale;
  final DateTime? lastObservedAt;

  const UserPresenceState({
    required this.userId,
    required this.state,
    required this.confidence,
    required this.source,
    this.isStale = false,
    this.lastObservedAt,
  });

  factory UserPresenceState.fromJson(String userId, Map<String, dynamic> json) {
    return UserPresenceState(
      userId: userId,
      state: PresenceState.fromApiValue(json['state']?.toString()),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      source: PresenceSource.fromApiValue(json['source']?.toString()),
      isStale: json['isStale'] == true || json['is_stale'] == 1 || json['is_stale'] == true,
      lastObservedAt: json['observedAt'] != null
          ? DateTime.tryParse(json['observedAt'].toString())
          : (json['last_observed_at'] != null ? DateTime.tryParse(json['last_observed_at'].toString()) : null),
    );
  }
}

@immutable
class InferredRoomPresence {
  final String roomId;
  final bool isOccupied;
  final double confidence;
  final bool isInferred;
  final String inferenceReason;
  final DateTime? lastActivityAt;

  const InferredRoomPresence({
    required this.roomId,
    required this.isOccupied,
    required this.confidence,
    this.isInferred = true,
    this.inferenceReason = '',
    this.lastActivityAt,
  });

  factory InferredRoomPresence.fromJson(Map<String, dynamic> json) {
    return InferredRoomPresence(
      roomId: json['roomId']?.toString() ?? json['room_id']?.toString() ?? '',
      isOccupied: json['isOccupied'] == true || json['is_occupied'] == 1 || json['is_occupied'] == true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      isInferred: json['isInferred'] != false && json['is_inferred'] != false,
      inferenceReason: json['inferenceReason']?.toString() ?? json['inference_reason']?.toString() ?? '',
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.tryParse(json['lastActivityAt'].toString())
          : (json['last_activity_at'] != null ? DateTime.tryParse(json['last_activity_at'].toString()) : null),
    );
  }
}

@immutable
class PresenceSnapshotModel {
  final String homeId;
  final PresenceState state;
  final double confidence;
  final bool isOccupied;
  final int activeUserCount;
  final Map<String, UserPresenceState> userStates;
  final List<InferredRoomPresence> inferredRooms;
  final DateTime calculatedAt;

  const PresenceSnapshotModel({
    required this.homeId,
    required this.state,
    required this.confidence,
    required this.isOccupied,
    required this.activeUserCount,
    this.userStates = const {},
    this.inferredRooms = const [],
    required this.calculatedAt,
  });

  factory PresenceSnapshotModel.fromJson(Map<String, dynamic> json) {
    final rawUserStates = json['userStates'] ?? json['user_states'];
    final userMap = <String, UserPresenceState>{};
    if (rawUserStates is Map) {
      rawUserStates.forEach((k, v) {
        if (v is Map) {
          userMap[k.toString()] = UserPresenceState.fromJson(k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }

    final rawInferred = json['inferredRooms'] ?? json['inferred_rooms'];
    final roomList = <InferredRoomPresence>[];
    if (rawInferred is List) {
      for (final r in rawInferred) {
        if (r is Map) {
          roomList.add(InferredRoomPresence.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    return PresenceSnapshotModel(
      homeId: json['homeId']?.toString() ?? json['home_id']?.toString() ?? '',
      state: PresenceState.fromApiValue(json['state']?.toString()),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      isOccupied: json['isOccupied'] == true || json['is_occupied'] == 1 || json['is_occupied'] == true,
      activeUserCount: (json['activeUserCount'] as num?)?.toInt() ?? (json['active_user_count'] as num?)?.toInt() ?? 0,
      userStates: userMap,
      inferredRooms: roomList,
      calculatedAt: json['calculatedAt'] != null
          ? DateTime.parse(json['calculatedAt'].toString())
          : (json['calculated_at'] != null ? DateTime.parse(json['calculated_at'].toString()) : DateTime.now()),
    );
  }
}

@immutable
class ContextOverrideModel {
  final String id;
  final String userId;
  final ContextMode mode;
  final String reason;
  final DateTime? expiresAt;

  const ContextOverrideModel({
    required this.id,
    required this.userId,
    required this.mode,
    required this.reason,
    this.expiresAt,
  });

  factory ContextOverrideModel.fromJson(Map<String, dynamic> json) {
    return ContextOverrideModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      mode: ContextMode.fromApiValue(json['mode']?.toString()),
      reason: json['reason']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : (json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null),
    );
  }
}

@immutable
class HomeContextModel {
  final String homeId;
  final ContextMode mode;
  final ContextMode? previousMode;
  final PrecedenceTier precedenceTier;
  final ContextOverrideModel? activeOverride;
  final bool isVacation;
  final bool isOccupied;
  final double confidence;
  final DateTime updatedAt;

  const HomeContextModel({
    required this.homeId,
    required this.mode,
    this.previousMode,
    required this.precedenceTier,
    this.activeOverride,
    required this.isVacation,
    required this.isOccupied,
    required this.confidence,
    required this.updatedAt,
  });

  factory HomeContextModel.fromJson(Map<String, dynamic> json) {
    final overrideJson = json['activeOverride'] ?? json['active_override'];
    return HomeContextModel(
      homeId: json['homeId']?.toString() ?? json['home_id']?.toString() ?? '',
      mode: ContextMode.fromApiValue(json['mode']?.toString()),
      previousMode: json['previousMode'] != null ? ContextMode.fromApiValue(json['previousMode'].toString()) : null,
      precedenceTier: PrecedenceTier.fromApiValue(json['precedenceTier']?.toString() ?? json['precedence_tier']?.toString()),
      activeOverride: overrideJson is Map ? ContextOverrideModel.fromJson(Map<String, dynamic>.from(overrideJson)) : null,
      isVacation: json['isVacation'] == true || json['is_vacation'] == 1 || json['is_vacation'] == true,
      isOccupied: json['isOccupied'] == true || json['is_occupied'] == 1 || json['is_occupied'] == true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : (json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now()),
    );
  }
}

@immutable
class ContextTransitionModel {
  final String id;
  final String homeId;
  final ContextMode? fromMode;
  final ContextMode toMode;
  final String triggerSource;
  final String reason;
  final Map<String, dynamic> evidence;
  final DateTime createdAt;

  const ContextTransitionModel({
    required this.id,
    required this.homeId,
    this.fromMode,
    required this.toMode,
    required this.triggerSource,
    required this.reason,
    this.evidence = const {},
    required this.createdAt,
  });

  factory ContextTransitionModel.fromJson(Map<String, dynamic> json) {
    return ContextTransitionModel(
      id: json['id']?.toString() ?? '',
      homeId: json['home_id']?.toString() ?? json['homeId']?.toString() ?? '',
      fromMode: json['from_mode'] != null ? ContextMode.fromApiValue(json['from_mode'].toString()) : null,
      toMode: ContextMode.fromApiValue(json['to_mode']?.toString() ?? json['toMode']?.toString()),
      triggerSource: json['trigger_source']?.toString() ?? json['triggerSource']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      evidence: json['evidence'] is Map ? Map<String, dynamic>.from(json['evidence'] as Map) : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now()),
    );
  }
}
