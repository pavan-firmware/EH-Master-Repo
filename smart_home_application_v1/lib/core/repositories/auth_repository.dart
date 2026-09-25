import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final bool emailVerified;
  final String role;
  final String? fullName;

  UserProfile({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.role = 'USER',
    this.fullName,
  });

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    return email.split('@').first;
  }

  bool get isAdmin =>
      role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'SYSTEM_ADMIN';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      role: json['role'] as String? ?? 'USER',
      fullName: json['fullName'] as String? ?? json['full_name'] as String? ?? json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'emailVerified': emailVerified,
    'role': role,
    if (fullName != null) 'fullName': fullName,
  };
}

class AuthRepository {
  final ApiClient _apiClient;
  ApiClient get apiClient => _apiClient;
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
    String? access;
    String? refresh;
    String? userJsonStr;
    try {
      access = await _storage.read(key: _accessTokenKey);
      refresh = await _storage.read(key: _refreshTokenKey);
      userJsonStr = await _storage.read(key: _userProfileKey);
    } catch (_) {}

    if (refresh == null || refresh.isEmpty) {
      await logout();
      return;
    }

    _accessToken = access;
    _refreshToken = refresh;
    if (userJsonStr != null) {
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(userJsonStr));
      } catch (_) {}
    }

    // Attempt background token refresh asynchronously without blocking local startup
    _apiClient.post(
      '/api/v1/auth/refresh',
      body: {'refreshToken': _refreshToken},
    ).timeout(const Duration(milliseconds: 1500)).then((data) async {
      if (data != null && data is Map<String, dynamic>) {
        await _saveAuthData(data);
      }
    }).catchError((e) async {
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        await logout();
      }
    });
  }

  Future<void> login(String email, String password) async {
    final data = await _apiClient.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );

    await _saveAuthData(data);
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (fullName != null && fullName.trim().isNotEmpty) {
      body['fullName'] = fullName.trim();
    }
    await _apiClient.post(
      '/api/v1/auth/register',
      body: body,
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
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return false;
      }
      return true; // Keep session on server-side temporary errors
    } catch (_) {
      return true; // Network offline, don't invalidate session
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
    final tokenToRevoke = _refreshToken;

    // Immediately clear in-memory credentials
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    // Clean secure storage
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userProfileKey);
    } catch (_) {}

    // Best-effort backend token revocation
    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      try {
        await _apiClient.delete(
          '/api/v1/auth/logout',
          body: {'refreshToken': tokenToRevoke},
        );
      } catch (_) {}
    }
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? timezone,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (timezone != null) body['timezone'] = timezone;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final data = await _apiClient.patch(
      '/api/v1/account/profile',
      body: body,
    );

    UserProfile updated;
    if (data is Map<String, dynamic>) {
      if (_currentUser != null) {
        final updatedFullName = data['fullName'] as String? ??
            data['full_name'] as String? ??
            data['name'] as String? ??
            fullName ??
            _currentUser!.fullName;
        updated = UserProfile(
          id: _currentUser!.id,
          email: _currentUser!.email,
          emailVerified: _currentUser!.emailVerified,
          role: _currentUser!.role,
          fullName: updatedFullName,
        );
      } else {
        updated = UserProfile.fromJson(data);
      }
    } else if (_currentUser != null) {
      updated = UserProfile(
        id: _currentUser!.id,
        email: _currentUser!.email,
        emailVerified: _currentUser!.emailVerified,
        role: _currentUser!.role,
        fullName: fullName ?? _currentUser!.fullName,
      );
    } else {
      throw ApiException(statusCode: 500, message: 'Invalid profile response');
    }

    _currentUser = updated;
    try {
      await _storage.write(
        key: _userProfileKey,
        value: jsonEncode(updated.toJson()),
      );
    } catch (_) {}

    return updated;
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    UserProfile? userProfile;
    if (data['user'] != null && data['user'] is Map<String, dynamic>) {
      userProfile = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    }

    if (accessToken == null || refreshToken == null || userProfile == null) {
      throw ApiException(
        statusCode: 500,
        message: 'Invalid auth payload received from server',
      );
    }

    // 1. Persist to secure storage
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(
        key: _userProfileKey,
        value: jsonEncode(userProfile.toJson()),
      );
    } catch (_) {}

    // 2. Commit to in-memory state
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _currentUser = userProfile;
  }
}
