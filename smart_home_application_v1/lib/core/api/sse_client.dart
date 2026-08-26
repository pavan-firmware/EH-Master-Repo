import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SseEvent {
  final String id;
  final String event;
  final String data;

  SseEvent({this.id = '', this.event = 'message', this.data = ''});
}

class SseClient {
  final ApiClient _apiClient;
  http.Client? _httpClient;
  StreamSubscription? _subscription;
  final _eventController = StreamController<SseEvent>.broadcast();
  
  String _lastEventId = '';
  bool _isConnecting = false;
  bool _isConnected = false;
  int _retryDelayMs = 1000;
  Timer? _reconnectTimer;
  
  String? _currentHomeId;
  
  SseClient(this._apiClient);
  
  Stream<SseEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect(String homeId) async {
    _currentHomeId = homeId;
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;
    _connectInternal();
  }
  
  Future<void> _connectInternal() async {
    if (_currentHomeId == null) return;
    
    _reconnectTimer?.cancel();
    _httpClient?.close();
    _httpClient = http.Client();
    
    final token = _apiClient.getAccessToken != null ? await _apiClient.getAccessToken!() : null;
    if (token == null) {
      _scheduleReconnect();
      return;
    }

    try {
      final uri = Uri.parse('${_apiClient.baseUrl}/api/v1/homes/$_currentHomeId/stream');
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache'
        ..headers['Authorization'] = 'Bearer $token';
        
      if (_lastEventId.isNotEmpty) {
        request.headers['Last-Event-ID'] = _lastEventId;
      }
      
      final response = await _httpClient!.send(request);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _isConnected = true;
        _isConnecting = false;
        _retryDelayMs = 1000; // Reset backoff
        
        String buffer = '';
        _subscription = response.stream.transform(utf8.decoder).listen(
          (chunk) {
            buffer += chunk;
            _processBuffer(buffer, (event) {
              if (event.id.isNotEmpty) {
                _lastEventId = event.id;
              }
              _eventController.add(event);
            });
            buffer = _trimBuffer(buffer);
          },
          onError: (e) {
            _handleDisconnect();
          },
          onDone: () {
            _handleDisconnect();
          },
          cancelOnError: true,
        );
      } else if (response.statusCode == 401) {
        // Attempt refresh
        final refreshed = _apiClient.onRefreshToken != null ? await _apiClient.onRefreshToken!() : false;
        if (refreshed) {
          _connectInternal();
        } else {
          _handleDisconnect(fatal: true);
        }
      } else {
        _handleDisconnect();
      }
    } catch (e) {
      _handleDisconnect();
    }
  }
  
  void _processBuffer(String buffer, void Function(SseEvent) onEvent) {
    final eventsRaw = buffer.split('\n\n');
    for (int i = 0; i < eventsRaw.length - 1; i++) {
      final block = eventsRaw[i];
      if (block.trim().isEmpty) continue;
      
      String id = '';
      String eventType = 'message';
      String data = '';
      
      for (final line in block.split('\n')) {
        if (line.startsWith('id:')) {
          id = line.substring(3).trim();
        } else if (line.startsWith('event:')) {
          eventType = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final dataVal = line.substring(5).trimLeft();
          data = data.isEmpty ? dataVal : '$data\n$dataVal';
        }
      }
      
      onEvent(SseEvent(id: id, event: eventType, data: data));
    }
  }
  
  String _trimBuffer(String buffer) {
    final lastIndex = buffer.lastIndexOf('\n\n');
    if (lastIndex == -1) return buffer;
    return buffer.substring(lastIndex + 2);
  }
  
  void _handleDisconnect({bool fatal = false}) {
    _isConnected = false;
    _isConnecting = false;
    _subscription?.cancel();
    _httpClient?.close();
    
    if (!fatal && _currentHomeId != null) {
      _scheduleReconnect();
    }
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _retryDelayMs), () {
      _retryDelayMs = (_retryDelayMs * 2).clamp(1000, 30000);
      _connectInternal();
    });
  }

  void disconnect() {
    _currentHomeId = null;
    _reconnectTimer?.cancel();
    _handleDisconnect(fatal: true);
  }
}
