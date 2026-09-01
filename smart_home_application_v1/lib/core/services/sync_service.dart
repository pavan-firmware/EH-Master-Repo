import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sync_models.dart';

/// EH Home — Client Synchronization & Local Offline Cache Service (Phase 17)
class SyncService extends ChangeNotifier {
  final String baseUrl;
  final http.Client? httpClient;
  final String? Function()? getAuthToken;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  SyncBootstrapBundle? _cachedBundle;
  SyncBootstrapBundle? get cachedBundle => _cachedBundle;

  final List<PendingMutation> _pendingMutations = [];
  List<PendingMutation> get pendingMutations => List.unmodifiable(_pendingMutations);

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String? _lastError;
  String? get lastError => _lastError;

  SyncService({
    this.baseUrl = 'http://127.0.0.1:3000',
    this.httpClient,
    this.getAuthToken,
    SyncBootstrapBundle? initialCachedBundle,
  }) : _cachedBundle = initialCachedBundle;

  void setOnlineStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    if (!_isOnline) {
      _setStatus(SyncStatus.offline);
    } else {
      _setStatus(_pendingMutations.isNotEmpty
          ? SyncStatus.pendingChanges
          : SyncStatus.synced);
    }
    notifyListeners();
  }

  void queueMutation(PendingMutation mutation) {
    _pendingMutations.add(mutation);
    if (!_isOnline) {
      _setStatus(SyncStatus.offline);
    } else {
      _setStatus(SyncStatus.pendingChanges);
    }
    notifyListeners();
  }

  void clearPendingMutations() {
    _pendingMutations.clear();
    _setStatus(SyncStatus.synced);
    notifyListeners();
  }

  void setCachedBundle(SyncBootstrapBundle bundle) {
    _cachedBundle = bundle;
    _lastSyncTime = bundle.syncedAt;
    _setStatus(SyncStatus.synced);
    notifyListeners();
  }

  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  /// Bootstrap full state bundle from backend for cold starts or cloud recovery
  Future<SyncBootstrapBundle> bootstrapSync({
    String? homeId,
    String clientDeviceId = 'mobile_flutter_app',
  }) async {
    if (!_isOnline) {
      _setStatus(SyncStatus.offline);
      if (_cachedBundle != null) return _cachedBundle!;
      throw Exception('Cannot bootstrap while offline with no local cache');
    }

    _setStatus(SyncStatus.syncing);
    _lastError = null;

    try {
      final client = httpClient ?? http.Client();
      final token = getAuthToken != null ? getAuthToken!() : null;

      final queryParams = <String, String>{
        'clientDeviceId': clientDeviceId,
      };
      if (homeId != null) {
        queryParams['homeId'] = homeId;
      }

      final uri = Uri.parse('$baseUrl/api/v1/sync/bootstrap')
          .replace(queryParameters: queryParams);

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await client.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('Bootstrap failed with status ${response.statusCode}: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final bundle = SyncBootstrapBundle.fromJson(data);

      _cachedBundle = bundle;
      _lastSyncTime = DateTime.now();
      _setStatus(_pendingMutations.isNotEmpty
          ? SyncStatus.pendingChanges
          : SyncStatus.synced);

      return bundle;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Flushes queued offline mutations to backend and applies ID reconciliations
  Future<ReconciliationSummary> reconcilePending({required String homeId}) async {
    if (_pendingMutations.isEmpty) {
      _setStatus(SyncStatus.synced);
      return ReconciliationSummary(
        reconciledAt: DateTime.now(),
        totalMutations: 0,
        acceptedCount: 0,
        rejectedCount: 0,
        conflictCount: 0,
        results: const [],
      );
    }

    if (!_isOnline) {
      _setStatus(SyncStatus.offline);
      throw Exception('Cannot reconcile mutations while offline');
    }

    _setStatus(SyncStatus.syncing);
    _lastError = null;

    try {
      final client = httpClient ?? http.Client();
      final token = getAuthToken != null ? getAuthToken!() : null;

      final uri = Uri.parse('$baseUrl/api/v1/sync/reconcile');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final mutationsToReconcile = List<PendingMutation>.from(_pendingMutations);
      final bodyPayload = {
        'homeId': homeId,
        'mutations': mutationsToReconcile.map((m) => m.toJson()).toList(),
      };

      final response = await client.post(
        uri,
        headers: headers,
        body: json.encode(bodyPayload),
      );

      if (response.statusCode != 200) {
        throw Exception('Reconciliation failed with status ${response.statusCode}: ${response.body}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final summary = ReconciliationSummary.fromJson(data);

      // Remove accepted mutations from queue
      final acceptedIds = summary.results
          .where((r) => r.status == 'ACCEPTED')
          .map((r) => r.mutationId)
          .toSet();

      _pendingMutations.removeWhere((m) => acceptedIds.contains(m.mutationId));

      _lastSyncTime = summary.reconciledAt;

      if (summary.conflictCount > 0) {
        _setStatus(SyncStatus.conflict);
      } else if (summary.rejectedCount > 0 && _pendingMutations.isEmpty) {
        _setStatus(SyncStatus.synced);
      } else if (_pendingMutations.isNotEmpty) {
        _setStatus(SyncStatus.pendingChanges);
      } else {
        _setStatus(SyncStatus.synced);
      }

      return summary;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Request sanitized data export from cloud
  Future<Map<String, dynamic>> exportData({String? homeId}) async {
    final client = httpClient ?? http.Client();
    final token = getAuthToken != null ? getAuthToken!() : null;

    final queryParams = <String, String>{};
    if (homeId != null) {
      queryParams['homeId'] = homeId;
    }

    final uri = Uri.parse('$baseUrl/api/v1/sync/export')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Data export failed: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
