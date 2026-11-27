import 'package:happy_notes/apis/account_api.dart';
import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/services/user_settings_service.dart';
import 'package:happy_notes/utils/token_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../exceptions/api_exception.dart';
import '../screens/account/user_session.dart';
import '../services/seq_logger.dart';

class AccountService {
  final AccountApi _accountApi;
  final UserSettingsService _userSettingsService;
  final TokenUtils _tokenUtils;
  Future<void>? _refreshTokenInFlight;

  AccountService({
    required AccountApi accountApi,
    required UserSettingsService userSettingsService,
    required TokenUtils tokenUtils,
  })  : _accountApi = accountApi,
        _userSettingsService = userSettingsService,
        _tokenUtils = tokenUtils;

  Future<dynamic> login(String username, String password) async {
    var params = {'username': username, 'password': password};
    final apiResult = (await _accountApi.login(params)).data;
    if (apiResult['successful']) {
      await _storeToken(apiResult['data']['token']);
    } else {
      throw ApiException(apiResult);
    }
    return apiResult;
  }

  Future<void> logout() async {
    await _clearToken();
  }

  Future<dynamic> googleLogin(String idToken) async {
    final apiResult = (await _accountApi.googleLogin(idToken)).data;
    if (apiResult['successful']) {
      await _storeToken(apiResult['data']['token']);
    } else {
      throw ApiException(apiResult);
    }
    return apiResult;
  }

  Future<dynamic> deleteAccount({String? password, String? idToken}) async {
    final confirmation = <String, dynamic>{};
    if (password != null && password.isNotEmpty) {
      confirmation['password'] = password;
    }
    if (idToken != null && idToken.isNotEmpty) {
      confirmation['idToken'] = idToken;
    }

    if (confirmation.length != 1) {
      throw ArgumentError('Exactly one account deletion confirmation is required');
    }

    final apiResult = (await _accountApi.deleteAccount(confirmation)).data;
    if (apiResult['successful']) {
      return apiResult;
    }
    throw ApiException(apiResult);
  }

  Future<dynamic> register(String username, String email, String password) async {
    var params = {'username': username, 'email': email, 'password': password};
    var apiResult = (await _accountApi.register(params)).data;
    if (apiResult['successful']) {
      await _storeToken(apiResult['data']['token']);
    } else {
      throw ApiException(apiResult);
    }
    return apiResult;
  }

  Future<dynamic> _refreshToken() async {
    try {
      var apiResponse = (await _accountApi.refreshToken()).data;
      if (apiResponse['successful']) {
        await _storeToken(apiResponse['data']['token']);
        SeqLogger.info('Token refreshed successfully');
      } else {
        SeqLogger.severe('Token refresh failed: ${apiResponse['message'] ?? 'Unknown error'}');
        throw ApiException(apiResponse);
      }
    } catch (e) {
      SeqLogger.severe('Token refresh error: ${e.toString()}');
      rethrow;
    }
  }

  final _tokenKey = 'accessToken';
  final _baseUrlKey = 'baseUrl';
  final String _payloadUserIdKey = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';
  final String _payloadEmailKey = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';

  Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, AppConfig.apiBaseUrl);
    await prefs.setString(_tokenKey, token);
    try {
      await setUserSession(token: token);
    } catch (e) {
      await _clearToken();
      rethrow;
    }
  }

  Future<void> setUserSession({String? token}) async {
    token ??= await getToken();
    var payload = await _tokenUtils.decodeToken(token!);
    UserSession().id = int.parse(payload[_payloadUserIdKey]);
    UserSession().email = payload[_payloadEmailKey];
    UserSession().userSettings = await _userSettingsService.getAll();
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_baseUrlKey);
    UserSession().id = null;
    UserSession().email = null;
    UserSession().userSettings = null;
  }

  Future<String?> getToken() async {
    SeqLogger.info('AccountService.getToken: Getting token from SharedPreferences...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      SeqLogger.info('AccountService.getToken: Token exists in storage: ${token != null && token.isNotEmpty}');

      if (token != null && token != '') {
        try {
          var remainingTime = await _tokenUtils.getTokenRemainingTime(token);
          SeqLogger.info('AccountService.getToken: Token remaining time: ${remainingTime.inDays} days, ${remainingTime.inHours} hours');

          if (remainingTime.inDays <= 30) {
            SeqLogger.info('AccountService.getToken: Token needs refresh (${remainingTime.inDays} days remaining) - starting fire-and-forget refresh');
            // Fire-and-forget refresh for all platforms - cleaner and faster
            _refreshTokenFireAndForget();
          } else {
            SeqLogger.info('AccountService.getToken: Token is fresh, no refresh needed');
          }
        } catch (e) {
          SeqLogger.severe('AccountService.getToken: Error checking token expiration: ${e.toString()}');
          // Continue with existing token if expiration check fails
        }
      }
      return token;
    } catch (e) {
      SeqLogger.severe('AccountService.getToken: Critical error accessing SharedPreferences: $e');
      return null;
    }
  }

  /// Fire-and-forget token refresh for all platforms
  /// This method starts token refresh in background without blocking the caller
  void _refreshTokenFireAndForget() {
    if (_refreshTokenInFlight != null) {
      return;
    }

    // Use unawaited to explicitly indicate this is fire-and-forget
    // ignore: unawaited_futures
    _refreshTokenInFlight = _refreshToken().timeout(const Duration(seconds: 30)).then(
      (value) {
        SeqLogger.info('AccountService: Fire-and-forget token refresh completed successfully');
      },
    ).catchError((error) {
      SeqLogger.severe('AccountService: Fire-and-forget token refresh failed: $error');
      // Error is logged but doesn't affect the current operation
    }).whenComplete(() {
      _refreshTokenInFlight = null;
    });
  }

  Future<bool> isValidToken() async {
    SeqLogger.info('AccountService.isValidToken: Starting network token validation...');
    if (await _isSameEnv()) {
      // Get token directly without triggering refresh to avoid race conditions
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      SeqLogger.info('AccountService.isValidToken: Retrieved token directly from storage: ${token != null && token.isNotEmpty}');

      if (token != null && token != '') {
        try {
          final remainingTime = await _tokenUtils.getTokenRemainingTime(token);
          final isValid = remainingTime.inSeconds >= 1;
          SeqLogger.info('AccountService.isValidToken: Token remaining: ${remainingTime.inSeconds}s, valid: $isValid');
          return isValid;
        } catch (e) {
          SeqLogger.severe('AccountService.isValidToken: Token validation error: ${e.toString()}');
          return false;
        }
      } else {
        SeqLogger.info('AccountService.isValidToken: No token available');
      }
    } else {
      SeqLogger.info('AccountService.isValidToken: Environment changed, token invalid');
    }
    return false;
  }

  // if env changes, even the token is valid, we still need to ask user to log in
  Future<bool> _isSameEnv() async {
    final prefs = await SharedPreferences.getInstance();
    final previousBaseUrl = prefs.getString(_baseUrlKey);
    return previousBaseUrl == AppConfig.apiBaseUrl;
  }
}
