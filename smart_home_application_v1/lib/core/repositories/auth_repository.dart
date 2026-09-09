import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final bool emailVerified;
  final String role;

  UserProfile({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.role = 'USER',
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      role: json['role'] as String? ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'emailVerified': emailVerified,
    'role': role,
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
    String? refresh;
    String? userJsonStr;
    try {
      refresh = await _storage.read(key: _refreshTokenKey);
      userJsonStr = await _storage.read(key: _userProfileKey);
    } catch (_) {}

    if (refresh == null || refresh.isEmpty) {
      await logout();
      return;
    }

    _refreshToken = refresh;
    if (userJsonStr != null) {
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(userJsonStr));
      } catch (_) {}
    }

    // Validate refresh token against backend
    final refreshed = await refreshSession();
    if (!refreshed) {
      await logout();
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
  }

  Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;

    try {
      final data = await _apiClient.post(
        '/api/v1/auth/refresh',
        body: {'refreshToken': _refreshToken},
      );
      if (data != null && data is Map<String, dynamic>) {
        await _saveAuthData(data);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refresh() async {
    final success = await refreshSession();
    if (!success) {
      await logout();
    }
    return success;
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await _apiClient.delete(
          '/api/v1/auth/logout',
          body: {'refreshToken': _refreshToken},
        );
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userProfileKey);
    } catch (_) {}
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    _accessToken = data['accessToken'];
    _refreshToken = data['refreshToken'];
    if (data['user'] != null && data['user'] is Map<String, dynamic>) {
      _currentUser = UserProfile.fromJson(data['user']);
    }

    try {
      await _storage.write(key: _accessTokenKey, value: _accessToken);
      await _storage.write(key: _refreshTokenKey, value: _refreshToken);
      if (_currentUser != null) {
        await _storage.write(
          key: _userProfileKey,
          value: jsonEncode(_currentUser!.toJson()),
        );
      }
    } catch (_) {}
  }
}
