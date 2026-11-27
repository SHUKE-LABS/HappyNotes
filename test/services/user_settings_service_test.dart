import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/user_settings_api.dart';
import 'package:happy_notes/app_constants.dart';
import 'package:happy_notes/entities/user_settings.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:happy_notes/services/user_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeUserSettingsApi extends UserSettingsApi {
  Response<dynamic>? getAllResponse;
  Response<dynamic>? upsertResponse;
  Map<String, String>? lastUpsertPayload;

  @override
  Future<Response> getAll() async {
    return getAllResponse!;
  }

  @override
  Future<Response> upsert(String settingName, String settingValue) async {
    lastUpsertPayload = {
      'settingName': settingName,
      'settingValue': settingValue,
    };
    return upsertResponse!;
  }
}

void main() {
  group('UserSettingsService', () {
    late FakeUserSettingsApi fakeApi;
    late UserSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      UserSession().id = 123;
      UserSession().email = 'test@example.com';
      UserSession().userSettings = null;
      fakeApi = FakeUserSettingsApi();
      service = UserSettingsService(userSettingsApi: fakeApi);
    });

    tearDown(() {
      UserSession().id = null;
      UserSession().email = null;
      UserSession().userSettings = null;
    });

    test('getAll stores fetched settings in session', () async {
      fakeApi.getAllResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/settings/getAll'),
        data: {
          'data': [
            {
              'id': 1,
              'userId': 123,
              'settingName': AppConstants.privateNoteOnlyIsEnabled,
              'settingValue': '1',
            },
          ],
        },
      );

      final settings = await service.getAll();

      expect(settings, hasLength(1));
      expect(
          UserSession().settings(AppConstants.privateNoteOnlyIsEnabled), '1');
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('userSettings')!), [
        {
          'id': 1,
          'userId': 123,
          'settingName': AppConstants.privateNoteOnlyIsEnabled,
          'settingValue': '1',
        },
      ]);
    });

    test('upsert appends missing settings in session', () async {
      UserSession().userSettings = [
        UserSettings(
          id: 1,
          userId: 123,
          settingName: AppConstants.pageSize,
          settingValue: '20',
        ),
      ];
      fakeApi.upsertResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/settings/upsert'),
        data: {'successful': true},
      );

      final result =
          await service.upsert(AppConstants.privateNoteOnlyIsEnabled, '1');

      expect(result, true);
      expect(fakeApi.lastUpsertPayload, {
        'settingName': AppConstants.privateNoteOnlyIsEnabled,
        'settingValue': '1',
      });
      expect(
          UserSession().settings(AppConstants.privateNoteOnlyIsEnabled), '1');
      expect(UserSession().settings(AppConstants.pageSize), '20');
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('userSettings')!), [
        {
          'id': 1,
          'userId': 123,
          'settingName': AppConstants.pageSize,
          'settingValue': '20',
        },
        {
          'id': 0,
          'userId': 123,
          'settingName': AppConstants.privateNoteOnlyIsEnabled,
          'settingValue': '1',
        },
      ]);
    });

    test('getAll preserves existing session list identity when refreshing',
        () async {
      final existingSettings = <UserSettings>[
        UserSettings(
          id: 1,
          userId: 123,
          settingName: AppConstants.pageSize,
          settingValue: '20',
        ),
      ];
      UserSession().userSettings = existingSettings;
      fakeApi.getAllResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/settings/getAll'),
        data: {
          'data': [
            {
              'id': 2,
              'userId': 123,
              'settingName': AppConstants.privateNoteOnlyIsEnabled,
              'settingValue': '1',
            },
          ],
        },
      );

      await service.getAll();

      expect(identical(UserSession().userSettings, existingSettings), true);
      expect(existingSettings, hasLength(1));
      expect(existingSettings.first.settingName,
          AppConstants.privateNoteOnlyIsEnabled);
      expect(existingSettings.first.settingValue, '1');
    });

    test('loadPersistedSettings restores settings without an API call',
        () async {
      SharedPreferences.setMockInitialValues({
        'userSettings': jsonEncode([
          {
            'id': 3,
            'userId': 123,
            'settingName': AppConstants.pageSize,
            'settingValue': '30',
          },
        ]),
      });

      final settings = await service.loadPersistedSettings();

      expect(settings, hasLength(1));
      expect(UserSession().settings(AppConstants.pageSize), '30');
    });

    test('getAll skips applying results when the session is stale', () async {
      UserSession().userSettings = [
        UserSettings(
          id: 1,
          userId: 123,
          settingName: AppConstants.pageSize,
          settingValue: '20',
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'userSettings': jsonEncode(UserSession()
            .userSettings!
            .map((setting) => setting.toJson())
            .toList()),
      });
      fakeApi.getAllResponse = Response<dynamic>(
        requestOptions: RequestOptions(path: '/settings/getAll'),
        data: {
          'data': [
            {
              'id': 2,
              'userId': 123,
              'settingName': AppConstants.privateNoteOnlyIsEnabled,
              'settingValue': '1',
            },
          ],
        },
      );

      await service.getAll(shouldApply: () => false);

      expect(UserSession().settings(AppConstants.pageSize), '20');
      expect(UserSession().settings(AppConstants.privateNoteOnlyIsEnabled),
          isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('userSettings')!), [
        {
          'id': 1,
          'userId': 123,
          'settingName': AppConstants.pageSize,
          'settingValue': '20',
        },
      ]);
    });

    test('clearPersistedSettings removes the cached settings', () async {
      SharedPreferences.setMockInitialValues({'userSettings': '[]'});

      await service.clearPersistedSettings();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userSettings'), isNull);
    });
  });
}
