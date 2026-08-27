import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final bool emailVerified;

  UserProfile({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'emailVerified': emailVerified,
  };
}

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userProfileKey = 'auth_user_profile';

  String? _accessToken;
  String? _refreshToken;
  UserProfile? _currentUser;

  AuthRepository(this._apiClient) {
    _apiClient.getAccessToken = () async => _accessToken;
    _apiClient.onRefreshToken = () async => await refresh();
  }

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  Future<void> restoreSession() async {
    final access = await _storage.read(key: _accessTokenKey);
    final refresh = await _storage.read(key: _refreshTokenKey);
    final userJsonStr = await _storage.read(key: _userProfileKey);

    if (access != null && refresh != null && userJsonStr != null) {
      _accessToken = access;
      _refreshToken = refresh;
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(userJsonStr));
      } catch (_) {
        await logout();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _apiClient.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );

    await _saveAuthData(data);
  }

  Future<void> register(String email, String password) async {
    await _apiClient.post(
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    // Optional: Auto-login or wait for user to confirm
  }

  Future<bool> refresh() async {
    if (_refreshToken == null) return false;

    try {
      // Temporarily use refresh token to call refresh endpoint
      final uri = Uri.parse('${_apiClient.baseUrl}/api/v1/auth/refresh');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_refreshToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          await _saveAuthData(json['data']);
          return true;
        }
      }
      // If we get here, refresh failed
      await logout();
      return false;
    } catch (e) {
      // Network error during refresh doesn't invalidate session locally immediately,
      // but fails the current request.
      return false;
    }
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        // Attempt server logout, don't block on it
        final uri = Uri.parse('${_apiClient.baseUrl}/api/v1/auth/logout');
        await http
            .delete(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_refreshToken',
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userProfileKey);
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    _accessToken = data['accessToken'];
    _refreshToken = data['refreshToken'];
    _currentUser = UserProfile.fromJson(data['user']);

    await _storage.write(key: _accessTokenKey, value: _accessToken);
    await _storage.write(key: _refreshTokenKey, value: _refreshToken);
    await _storage.write(
      key: _userProfileKey,
      value: jsonEncode(_currentUser!.toJson()),
    );
  }
}
