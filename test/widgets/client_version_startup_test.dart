import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/client_version_policy_api.dart';
import 'package:happy_notes/main.dart';
import 'package:happy_notes/models/client_version_policy.dart';
import 'package:happy_notes/services/client_version_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingPolicyApi extends ClientVersionPolicyApi {
  final response = Completer<ClientVersionPolicy>();
  int calls = 0;

  _PendingPolicyApi() : super(dio: Dio());

  @override
  Future<ClientVersionPolicy> getPolicy(String platform) {
    calls++;
    return response.future;
  }
}

PackageInfo _packageInfo() {
  return PackageInfo(
    appName: 'HappyNotes',
    packageName: 'com.shukebeta.happynotes',
    version: '2.0.0',
    buildNumber: '101',
  );
}

Future<SharedPreferences> _preferences() => SharedPreferences.getInstance();

void main() {
  testWidgets('renders the first frame before a failed policy check completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _PendingPolicyApi();
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'ios',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    await tester.pumpWidget(
      HappyNotesApp(
        clientVersionUpdateService: service,
        clientPlatformOverride: 'ios',
        home: const Scaffold(body: Text('app ready')),
      ),
    );
    await tester.pump();

    expect(find.text('app ready'), findsOneWidget);
    expect(api.calls, 1);
    expect(find.byType(AlertDialog), findsNothing);

    api.response.completeError(
      DioException(requestOptions: RequestOptions(path: '/policy')),
    );
    await tester.pumpAndSettle();

    expect(find.text('app ready'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
