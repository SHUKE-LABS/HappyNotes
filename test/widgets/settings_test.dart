import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/app_constants.dart';
import 'package:happy_notes/dependency_injection.dart' as di;
import 'package:happy_notes/entities/user_settings.dart';
import 'package:happy_notes/providers/auth_provider.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:happy_notes/screens/settings/settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../test_helpers/seq_logger_setup.dart';

class StubAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  String? get token => null;

  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  bool get isInitialized => true;

  @override
  int? get currentUserId => null;

  @override
  String? get currentUserEmail => null;

  @override
  Future<void> initAuth() async {}

  @override
  Future<bool> login(String username, String password) async => false;

  @override
  Future<bool> register(String username, String email, String password) async => false;

  @override
  Future<bool> signInWithGoogle(String idToken) async => false;

  @override
  Future<void> logout() async {}

  @override
  Future<void> retryAuth() async {}
}

void main() {
  group('Settings widget', () {
    setUp(() async {
      setupSeqLoggerForTesting();
      await GetIt.instance.reset();
      di.init();
      PackageInfo.setMockInitialValues(
        appName: 'HappyNotes',
        packageName: 'com.shukebeta.happynotes',
        version: '2.0.0',
        buildNumber: '101',
        buildSignature: '',
      );
      UserSession().userSettings = [
        UserSettings(id: 1, userId: 123, settingName: AppConstants.markdownIsEnabled, settingValue: '0'),
        UserSettings(id: 2, userId: 123, settingName: AppConstants.privateNoteOnlyIsEnabled, settingValue: '0'),
        UserSettings(id: 3, userId: 123, settingName: AppConstants.pageSize, settingValue: '20'),
        UserSettings(id: 4, userId: 123, settingName: AppConstants.timezone, settingValue: 'Pacific/Auckland'),
      ];
    });

    tearDown(() async {
      UserSession().userSettings = null;
      await GetIt.instance.reset();
    });

    testWidgets('rebuild reflects latest settings from user session', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: StubAuthProvider(),
          child: const MaterialApp(home: Settings()),
        ),
      );
      await tester.pump();

      var switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isFalse);
      expect(switches[1].value, isFalse);

      UserSession().userSettings = [
        UserSettings(id: 1, userId: 123, settingName: AppConstants.markdownIsEnabled, settingValue: '1'),
        UserSettings(id: 2, userId: 123, settingName: AppConstants.privateNoteOnlyIsEnabled, settingValue: '1'),
        UserSettings(id: 3, userId: 123, settingName: AppConstants.pageSize, settingValue: '20'),
        UserSettings(id: 4, userId: 123, settingName: AppConstants.timezone, settingValue: 'Pacific/Auckland'),
      ];

      final dynamic state = tester.state<SettingsState>(find.byType(Settings));
      state.setState(() {});
      await tester.pump();

      switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isTrue);
    });

    testWidgets('shows sync-target entries including Fanfou and Ember', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: StubAuthProvider(),
          child: const MaterialApp(home: Settings()),
        ),
      );
      await tester.pump();

      expect(find.text('Telegram Sync'), findsOneWidget);
      expect(find.text('Mastodon Sync'), findsOneWidget);
      expect(find.text('Fanfou Sync'), findsOneWidget);
      expect(find.text('Ember Sync'), findsOneWidget);
    });

    testWidgets('shows the store version and build number', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: StubAuthProvider(),
          child: const MaterialApp(home: Settings()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Version: 2.0.0 (101) · ${AppConfig.version}'),
          findsOneWidget);
    });
  });
}
