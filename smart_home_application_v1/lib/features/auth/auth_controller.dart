import 'package:flutter/foundation.dart';
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

  AuthController(this._authRepository) {
    _restoreFuture = _authRepository
        .restoreSession()
        .timeout(const Duration(seconds: 10))
        .then((_) {
          if (_state == AuthState.unknown) {
            _state = _authRepository.isAuthenticated
                ? AuthState.authenticated
                : AuthState.unauthenticated;
            notifyListeners();
          }
        })
        .catchError((_) {
          if (_state == AuthState.unknown) {
            _state = AuthState.unauthenticated;
            notifyListeners();
          }
        });
  }

  Future<void>? get restoreFuture => _restoreFuture;

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  UserProfile? get currentUser => _authRepository.currentUser;

  Future<bool> login(String email, String password) async {
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.login(email, password);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.failure;
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.register(email, password);
      // Wait for login or auto-login depending on backend behavior. Let's just login.
      await _authRepository.login(email, password);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.failure;
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _state = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
