import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../api/sse_client.dart';

class SSEEventEnvelope {
  final int schemaVersion;
  final String eventId;
  final String type;
  final String occurredAt;
  final String homeId;
  final String? deviceId;
  final Map<String, dynamic> payload;

  SSEEventEnvelope({
    required this.schemaVersion,
    required this.eventId,
    required this.type,
    required this.occurredAt,
    required this.homeId,
    this.deviceId,
    required this.payload,
  });

  factory SSEEventEnvelope.fromJson(Map<String, dynamic> json) {
    return SSEEventEnvelope(
      schemaVersion: json['schemaVersion'] as int,
      eventId: json['eventId'] as String,
      type: json['type'] as String,
      occurredAt: json['occurredAt'] as String,
      homeId: json['homeId'] as String,
      deviceId: json['deviceId'] as String?,
      payload: json['payload'] as Map<String, dynamic>,
    );
  }
}

class RealtimeEventService extends ChangeNotifier {
  final SseClient _sseClient;
  StreamSubscription? _subscription;

  final _eventController = StreamController<SSEEventEnvelope>.broadcast();

  RealtimeEventService(this._sseClient) {
    _subscription = _sseClient.events.listen(_onSseEvent);
  }

  Stream<SSEEventEnvelope> get events => _eventController.stream;

  void _onSseEvent(SseEvent event) {
    if (event.data.isEmpty) return;
    try {
      final json = jsonDecode(event.data);
      if (json is Map<String, dynamic>) {
        final envelope = SSEEventEnvelope.fromJson(json);
        _eventController.add(envelope);
      }
    } catch (e) {
      debugPrint('Error parsing SSE event: $e');
    }
  }

  void connect(String homeId) {
    _sseClient.connect(homeId);
  }

  void disconnect() {
    _sseClient.disconnect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _eventController.close();
    super.dispose();
  }
}
