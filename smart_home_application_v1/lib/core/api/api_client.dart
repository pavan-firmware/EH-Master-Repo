import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() =>
      'ApiException($statusCode): $message${code != null ? ' [$code]' : ''}';
}

/// Minimal API client with JWT injection and token refresh.
class ApiClient {
  final String baseUrl;
  final http.Client _client = http.Client();

  /// Callback to get the current access token
  Future<String?> Function()? getAccessToken;

  /// Callback to trigger a token refresh if we get a 401
  Future<bool> Function()? onRefreshToken;

  /// Callback if refresh fails (should trigger logout)
  void Function()? onSessionExpired;

  ApiClient({required this.baseUrl});

  Future<dynamic> get(String path) async {
    return _request('GET', path);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    return _request('POST', path, body: body);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    return _request('PUT', path, body: body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    return _request('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path) async {
    return _request('DELETE', path);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = getAccessToken != null ? await getAccessToken!() : null;

    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      if (method == 'POST') {
        response = await _client
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 10));
      } else if (method == 'PUT') {
        response = await _client
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 10));
      } else if (method == 'PATCH') {
        response = await _client
            .patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 10));
      } else if (method == 'DELETE') {
        response = await _client
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
      } else {
        response = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
      }
    } on Exception catch (e) {
      throw ApiException(statusCode: 0, message: 'Network error: $e');
    }

    if (response.statusCode == 401 && !isRetry && onRefreshToken != null) {
      // Attempt to refresh
      final refreshSuccess = await onRefreshToken!();
      if (refreshSuccess) {
        // Retry the original request exactly once
        return _request(method, path, body: body, isRetry: true);
      } else {
        // Refresh failed
        onSessionExpired?.call();
        throw ApiException(statusCode: 401, message: 'Session expired');
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic> && json.containsKey('data')) {
          return json['data'];
        }
        return json;
      } catch (_) {
        return response.body;
      }
    } else {
      String msg = 'API error';
      String? code;
      Map<String, dynamic>? details;

      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic> && json['error'] != null) {
          msg = json['error']['message'] ?? msg;
          code = json['error']['code'];
          details = json['error']['details'];
        }
      } catch (_) {
        msg = response.body;
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: msg,
        code: code,
        details: details,
      );
    }
  }
}
