import 'dart:convert';

import 'package:happy_notes/apis/user_settings_api.dart';
import 'package:happy_notes/entities/user_settings.dart';
import 'package:happy_notes/exceptions/api_exception.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettingsService {
  static const _persistedSettingsKey = 'userSettings';

  final UserSettingsApi _userSettingsApi;
  UserSettingsService({required UserSettingsApi userSettingsApi})
      : _userSettingsApi = userSettingsApi;

  Future<List<UserSettings>> getAll({bool Function()? shouldApply}) async {
    List<dynamic> apiResult = (await _userSettingsApi.getAll()).data['data'];
    final settings = apiResult.map(_deserializeUserSettings).toList();
    if (shouldApply == null || shouldApply()) {
      await _replaceSessionSettings(settings);
    }
    return settings;
  }

  Future<List<UserSettings>> loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedSettings = prefs.getString(_persistedSettingsKey);
    if (encodedSettings == null || encodedSettings.isEmpty) {
      _setSessionSettings(const <UserSettings>[]);
      return <UserSettings>[];
    }

    try {
      final decodedSettings = jsonDecode(encodedSettings);
      if (decodedSettings is! List) {
        throw const FormatException('Persisted user settings are not a list');
      }

      final settings = decodedSettings.map(_deserializeUserSettings).toList();
      _setSessionSettings(settings);
      return settings;
    } catch (_) {
      await prefs.remove(_persistedSettingsKey);
      _setSessionSettings(const <UserSettings>[]);
      return <UserSettings>[];
    }
  }

  Future<void> clearPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistedSettingsKey);
  }

  Future<bool> upsert(String settingName, String settingValue) async {
    final apiResult =
        (await _userSettingsApi.upsert(settingName, settingValue)).data;
    if (!apiResult['successful']) throw ApiException(apiResult);
    final currentSettings = List<UserSettings>.from(
        UserSession().userSettings ?? const <UserSettings>[]);
    final index =
        currentSettings.indexWhere((el) => el.settingName == settingName);
    if (index >= 0) {
      currentSettings[index].settingValue = settingValue;
    } else {
      currentSettings.add(
        UserSettings(
          id: 0,
          userId: UserSession().id ?? 0,
          settingName: settingName,
          settingValue: settingValue,
        ),
      );
    }
    await _replaceSessionSettings(currentSettings);
    return true;
  }

  UserSettings _deserializeUserSettings(dynamic json) {
    return UserSettings.fromJson(Map<String, dynamic>.from(json));
  }

  void _setSessionSettings(List<UserSettings> settings) {
    final existingSettings = UserSession().userSettings;
    if (existingSettings == null) {
      UserSession().userSettings = List<UserSettings>.from(settings);
      return;
    }

    existingSettings
      ..clear()
      ..addAll(settings);
  }

  Future<void> _replaceSessionSettings(List<UserSettings> settings) async {
    _setSessionSettings(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _persistedSettingsKey,
      jsonEncode(settings.map((setting) => setting.toJson()).toList()),
    );
  }
}
