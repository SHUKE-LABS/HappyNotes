import 'package:flutter/material.dart';
import 'package:happy_notes/services/account_service.dart';
import 'package:happy_notes/services/google_auth_service.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:happy_notes/dependency_injection.dart';
import 'package:happy_notes/services/seq_logger.dart';

class AuthProvider with ChangeNotifier {
  final AccountService _accountService = locator<AccountService>();
  final GoogleAuthService _googleAuthService = locator<GoogleAuthService>();

  String? _token;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    if (_isInitialized) return; // Prevent multiple initializations

    SeqLogger.info( 'AuthProvider.initAuth: Starting authentication initialization');
    _isLoading = true;
    notifyListeners();

    try {
      SeqLogger.info( 'AuthProvider.initAuth: Getting stored token...');
      final storedToken = await _accountService.getToken();
      SeqLogger.info( 'AuthProvider.initAuth: Stored token exists: ${storedToken != null && storedToken.isNotEmpty}');

      if (storedToken != null && storedToken.isNotEmpty) {
        // Validate token with timeout and fallback
        bool isValid = false;

        try {
          // Add timeout to token validation to prevent hanging
          SeqLogger.info( 'AuthProvider.initAuth: Starting network token validation...');
          isValid = await _accountService.isValidToken()
              .timeout(const Duration(seconds: 30));
          SeqLogger.info( 'AuthProvider.initAuth: Network token validation result: $isValid');
        } catch (e) {
          SeqLogger.info( 'AuthProvider.initAuth: Network validation failed: $e');
          rethrow;
        }

        if (isValid) {
          SeqLogger.info( 'AuthProvider.initAuth: Token is valid, setting up session...');
          _token = storedToken;
          try {
            await _accountService.setUserSession(token: _token)
                .timeout(const Duration(seconds: 30));
            SeqLogger.info( 'AuthProvider.initAuth: Session setup completed successfully');
          } catch (sessionError) {
            final hasCachedSettings = UserSession().userSettings?.isNotEmpty ?? false;
            SeqLogger.severe(
              'AuthProvider.initAuth: Session setup failed. Cached settings available: $hasCachedSettings. Error: $sessionError',
            );
            if (!hasCachedSettings) {
              rethrow;
            }
          }
        } else {
          SeqLogger.info( 'AuthProvider.initAuth: Token is invalid, clearing session...');
          _token = null; // Token is invalid or expired
          await _accountService.logout(); // Clear any stale session data
        }
      } else {
        SeqLogger.info( 'AuthProvider.initAuth: No stored token found');
      }
    } catch (e) {
      SeqLogger.severe( 'AuthProvider.initAuth: Failed to initialize authentication: $e');
      _error = 'Failed to initialize authentication: ${e.toString()}';
      _token = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      SeqLogger.info( 'AuthProvider.initAuth: Authentication initialization completed. isAuthenticated: ${_token != null}');
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountService.login(username, password);
      // After successful login, get the stored token
      _token = await _accountService.getToken();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _token = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle(String idToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountService.googleLogin(idToken);
      // After successful login, get the stored token
      _token = await _accountService.getToken();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _token = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountService.register(username, email, password);
      // After successful registration, get the stored token
      _token = await _accountService.getToken();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _token = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount({String? password, String? idToken}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountService.deleteAccount(password: password, idToken: idToken);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      await logout();
    } catch (e, stackTrace) {
      SeqLogger.warning(
        'Account deletion succeeded, but local logout failed: $e',
        e,
        stackTrace,
      );
      _token = null;
      _error = null;
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _accountService.logout();
    await _googleAuthService.signOut();

    _token = null;
    _error = null;
    _isLoading = false;
    notifyListeners();

    // Data clearing will be handled automatically by AppStateProvider
    // listening to auth state changes
  }

  /// Get current user ID from session
  int? get currentUserId => UserSession().id;

  /// Get current user email from session
  String? get currentUserEmail => UserSession().email;

  /// Retry authentication initialization
  /// Useful when network conditions improve or user manually retries
  Future<void> retryAuth() async {
    _isInitialized = false;
    _error = null;
    await initAuth();
  }
}
