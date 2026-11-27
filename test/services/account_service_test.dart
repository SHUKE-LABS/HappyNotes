import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/account_api.dart';
import 'package:happy_notes/apis/user_settings_api.dart';
import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/entities/user_settings.dart';
import 'package:happy_notes/exceptions/api_exception.dart';
import 'package:happy_notes/services/account_service.dart';
import 'package:happy_notes/services/user_settings_service.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:happy_notes/utils/token_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/seq_logger_setup.dart';

class FakeAccountApi extends AccountApi {
  int refreshCalls = 0;
  bool googleLoginShouldFail = false;
  Map<String, dynamic>? deleteConfirmation;
  bool deleteAccountShouldFail = false;

  @override
  Future<Response> login(Map<String, dynamic> params) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/account/login'),
      data: {
        'successful': true,
        'data': {'token': 'fresh-login-token'},
      },
    );
  }

  @override
  Future<Response> googleLogin(String idToken) async {
    if (googleLoginShouldFail) {
      return Response<dynamic>(
        requestOptions: RequestOptions(path: '/account/googleLogin'),
        data: {
          'successful': false,
          'message': 'Invalid idToken',
        },
      );
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/account/googleLogin'),
      data: {
        'successful': true,
        'data': {'token': 'fresh-google-token'},
      },
    );
  }

  @override
  Future<Response> deleteAccount(Map<String, dynamic> confirmation) async {
    deleteConfirmation = Map<String, dynamic>.from(confirmation);
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/Account/DeleteAccount'),
      data: deleteAccountShouldFail
          ? {
              'successful': false,
              'message': 'Account deletion confirmation failed',
              'errorCode': 400,
            }
          : {
              'successful': true,
              'message': 'Your account and all owned data have been deleted',
            },
    );
  }

  @override
  Future<Response> refreshToken() async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Response<dynamic>(
      requestOptions: RequestOptions(path: '/account/refreshToken'),
      data: {
        'successful': true,
        'data': {'token': 'refreshed-token'},
      },
    );
  }
}

class FakeUserSettingsService extends UserSettingsService {
  String? tokenSeenDuringGetAll;
  Completer<void>? getAllGate;

  FakeUserSettingsService() : super(userSettingsApi: FakeUserSettingsApi());

  @override
  Future<List<UserSettings>> getAll({bool Function()? shouldApply}) async {
    final prefs = await SharedPreferences.getInstance();
    tokenSeenDuringGetAll = prefs.getString('accessToken');
    await getAllGate?.future;
    final settings = <UserSettings>[];
    if (shouldApply == null || shouldApply()) {
      UserSession().userSettings = settings;
    }
    return settings;
  }
}

class FakeUserSettingsApi extends UserSettingsApi {}

class FakeTokenUtils extends TokenUtils {
  @override
  Future<Map<String, dynamic>> decodeToken(String token) async {
    return {
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier':
          '123',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress':
          'test@example.com',
      'exp':
          DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch ~/
              1000,
    };
  }

  @override
  Future<Duration> getTokenRemainingTime(String token) async {
    return const Duration(days: 10);
  }
}

void main() {
  group('AccountService', () {
    late FakeAccountApi fakeAccountApi;
    late FakeUserSettingsService fakeUserSettingsService;
    late AccountService accountService;

    setUp(() {
      setupSeqLoggerForTesting();
      SharedPreferences.setMockInitialValues({'accessToken': 'stored-token'});
      fakeAccountApi = FakeAccountApi();
      fakeUserSettingsService = FakeUserSettingsService();
      accountService = AccountService(
        accountApi: fakeAccountApi,
        userSettingsService: fakeUserSettingsService,
        tokenUtils: FakeTokenUtils(),
      );
    });

    test(
        'getToken only triggers one refresh while a refresh is already in flight',
        () async {
      await Future.wait([
        accountService.getToken(),
        accountService.getToken(),
        accountService.getToken(),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fakeAccountApi.refreshCalls, 1);
      expect(fakeUserSettingsService.tokenSeenDuringGetAll, isNull);
    });

    test('restoreUserSession loads persisted settings without fetching them',
        () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'stored-token',
        'baseUrl': AppConfig.apiBaseUrl,
        'userSettings':
            '[{"id":1,"userId":123,"settingName":"pageSize","settingValue":"30"}]',
      });

      await accountService.restoreUserSession(token: 'stored-token');

      expect(UserSession().id, 123);
      expect(UserSession().email, 'test@example.com');
      expect(UserSession().settings('pageSize'), '30');
      expect(fakeUserSettingsService.tokenSeenDuringGetAll, isNull);
    });

    test('restoreUserSession uses an empty settings list when cache is absent',
        () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'stored-token',
        'baseUrl': AppConfig.apiBaseUrl,
      });

      await accountService.restoreUserSession(token: 'stored-token');

      expect(UserSession().userSettings, isEmpty);
      expect(fakeUserSettingsService.tokenSeenDuringGetAll, isNull);
    });

    test('refreshUserSettings drops results after logout', () async {
      await accountService.restoreUserSession(token: 'stored-token');
      fakeUserSettingsService.getAllGate = Completer<void>();

      final refresh = accountService.refreshUserSettings(token: 'stored-token');
      await Future<void>.delayed(Duration.zero);
      await accountService.logout();
      fakeUserSettingsService.getAllGate!.complete();

      expect(await refresh, false);
      expect(UserSession().userSettings, isNull);
    });

    test('login stores token before loading user settings', () async {
      SharedPreferences.setMockInitialValues({});

      await accountService.login('user', 'pass');

      expect(
          fakeUserSettingsService.tokenSeenDuringGetAll, 'fresh-login-token');
    });

    test('googleLogin stores token before loading user settings', () async {
      SharedPreferences.setMockInitialValues({});

      await accountService.googleLogin('good-id-token');

      expect(
          fakeUserSettingsService.tokenSeenDuringGetAll, 'fresh-google-token');
    });

    test('googleLogin throws ApiException on failure', () async {
      fakeAccountApi.googleLoginShouldFail = true;

      expect(() => accountService.googleLogin('bad-id-token'),
          throwsA(isA<ApiException>()));
    });

    test(
        'deleteAccount sends only a password and leaves token cleanup to AuthProvider',
        () async {
      await accountService.deleteAccount(password: 'correct-password');

      expect(
          fakeAccountApi.deleteConfirmation, {'password': 'correct-password'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'stored-token');
    });

    test('deleteAccount sends only a Google ID token', () async {
      await accountService.deleteAccount(idToken: 'fresh-id-token');

      expect(fakeAccountApi.deleteConfirmation, {'idToken': 'fresh-id-token'});
    });

    test('deleteAccount preserves the token when the API rejects confirmation',
        () async {
      fakeAccountApi.deleteAccountShouldFail = true;

      await expectLater(
        accountService.deleteAccount(password: 'wrong-password'),
        throwsA(isA<ApiException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'stored-token');
    });

    test('logout clears persisted user settings', () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'stored-token',
        'baseUrl': 'https://example.test',
        'userSettings': '[{"settingName":"pageSize","settingValue":"20"}]',
      });

      await accountService.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), isNull);
      expect(prefs.getString('userSettings'), isNull);
      expect(UserSession().userSettings, isNull);
    });
  });
}
