import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/repositories/auth_repository.dart';

enum AuthState {
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
  failure,
}

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthState _state = AuthState.unknown;
  String? _errorMessage;
  Future<void>? _restoreFuture;
  int _currentOperationId = 0;

  AuthController(this._authRepository) {
    final opId = ++_currentOperationId;
    _restoreFuture = _authRepository
        .restoreSession()
        .timeout(const Duration(seconds: 2))
        .then((_) {
          if (opId == _currentOperationId && _state == AuthState.unknown) {
            _state = _authRepository.isAuthenticated
                ? AuthState.authenticated
                : AuthState.unauthenticated;
            notifyListeners();
          }
        })
        .catchError((_) {
          if (opId == _currentOperationId && _state == AuthState.unknown) {
            _state = _authRepository.isAuthenticated
                ? AuthState.authenticated
                : AuthState.unauthenticated;
            notifyListeners();
          }
        });
  }

  Future<void>? get restoreFuture => _restoreFuture;

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  UserProfile? get currentUser => _authRepository.currentUser;

  void updateBaseUrl(String url) {
    _authRepository.apiClient.baseUrl = url;
  }

  Future<bool> login(String email, String password) async {
    final opId = ++_currentOperationId;
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.login(email, password);
      if (opId == _currentOperationId) {
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (opId == _currentOperationId) {
        _state = AuthState.failure;
        _errorMessage = _mapLoginError(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> register(String email, String password, {String? fullName}) async {
    final opId = ++_currentOperationId;
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.register(email, password, fullName: fullName);
      await _authRepository.login(email, password);
      if (opId == _currentOperationId) {
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (opId == _currentOperationId) {
        _state = AuthState.failure;
        _errorMessage = _mapRegisterError(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? timezone,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    _errorMessage = null;
    try {
      await _authRepository.updateProfile(
        fullName: fullName,
        timezone: timezone,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    ++_currentOperationId;
    // Invalidate local state immediately
    _state = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.logout();
    } catch (_) {
      // Local logout remains unauthenticated even if backend revocation encounters error
    }
  }

  String _mapLoginError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 ||
          error.code == 'INVALID_CREDENTIALS' ||
          error.message.toLowerCase().contains('invalid email or password') ||
          error.message.toLowerCase().contains('incorrect')) {
        return error.message.isNotEmpty
            ? error.message
            : 'Incorrect email or password.';
      }
      if (error.statusCode == 404 || error.code == 'USER_NOT_FOUND') {
        return 'Account not found. Please check your email or create an account.';
      }
      if (error.statusCode == 429 || error.code == 'TOO_MANY_REQUESTS') {
        return 'Too many login attempts. Please try again later.';
      }
      if (error.statusCode == 400) {
        return error.message.isNotEmpty
            ? error.message
            : 'Please check your email and password format.';
      }
      if (error.statusCode == 0 ||
          error.message.toLowerCase().contains('network') ||
          error.message.toLowerCase().contains('socket') ||
          error.message.toLowerCase().contains('connection')) {
        return 'Unable to connect. Check your connection and try again.';
      }
      if (error.statusCode >= 500) {
        return 'Something went wrong. Please try again.';
      }
      return error.message.isNotEmpty ? error.message : 'Invalid email or password.';
    }

    final str = error.toString().toLowerCase();
    if (str.contains('network') || str.contains('socket') || str.contains('connection')) {
      return 'Unable to connect. Check your connection and try again.';
    }
    return 'Invalid email or password.';
  }

  String _mapRegisterError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409 ||
          error.code == 'DUPLICATE_EMAIL' ||
          error.message.toLowerCase().contains('already exists')) {
        return 'An account with this email already exists. Please sign in.';
      }
      if (error.statusCode == 429 || error.code == 'TOO_MANY_REQUESTS') {
        return 'Too many attempts. Please try again later.';
      }
      if (error.statusCode == 400) {
        return error.message.isNotEmpty
            ? error.message
            : 'Please check your registration details.';
      }
      if (error.statusCode == 0 ||
          error.message.toLowerCase().contains('network') ||
          error.message.toLowerCase().contains('socket') ||
          error.message.toLowerCase().contains('connection')) {
        return 'Unable to connect. Check your connection and try again.';
      }
      if (error.statusCode >= 500) {
        return 'Something went wrong. Please try again.';
      }
      return error.message.isNotEmpty ? error.message : 'Registration failed.';
    }
    return 'Registration failed. Please try again.';
  }
}
