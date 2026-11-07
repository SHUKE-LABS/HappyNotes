import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/client_version_policy_api.dart';
import 'package:happy_notes/models/client_version_policy.dart';
import 'package:happy_notes/services/client_version_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePolicyApi extends ClientVersionPolicyApi {
  final ClientVersionPolicy? policy;
  final Object? error;
  int calls = 0;
  String? platform;

  _FakePolicyApi({this.policy, this.error}) : super(dio: Dio());

  @override
  Future<ClientVersionPolicy> getPolicy(String value) async {
    calls++;
    platform = value;
    if (error != null) throw error!;
    return policy!;
  }
}

PackageInfo _packageInfo({String buildNumber = '101'}) {
  return PackageInfo(
    appName: 'HappyNotes',
    packageName: 'com.shukebeta.happynotes',
    version: '2.0.0',
    buildNumber: buildNumber,
  );
}

ClientVersionPolicy _policy(
    {int minSupportedBuild = 0, int latestBuild = 101}) {
  return ClientVersionPolicy(
    minSupportedBuild: minSupportedBuild,
    latestVersion: '2.1.0',
    latestBuild: latestBuild,
    storeUrl: 'https://example.com/happynotes',
  );
}

Future<SharedPreferences> _preferences() => SharedPreferences.getInstance();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns a forced update when the build is below the minimum', () async {
    final api = _FakePolicyApi(policy: _policy(minSupportedBuild: 102));
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'ios',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    final prompt = await service.checkForUpdate();

    expect(prompt?.type, ClientUpdateType.forced);
    expect(prompt?.latestBuild, 101);
    expect(api.platform, 'ios');
  });

  test('returns a soft update below the latest build and remembers dismissal',
      () async {
    final api = _FakePolicyApi(policy: _policy(latestBuild: 102));
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'android',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    final prompt = await service.checkForUpdate();
    expect(prompt?.type, ClientUpdateType.soft);

    await service.dismissSoftUpdate(prompt!);
    expect(await service.checkForUpdate(), isNull);

    final nextService = ClientVersionUpdateService(
      policyApi: api,
      platform: 'android',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );
    expect(await nextService.checkForUpdate(), isNull);
  });

  test('shows no prompt when the current build is current', () async {
    final api = _FakePolicyApi(policy: _policy());
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'ios',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    expect(await service.checkForUpdate(), isNull);
  });

  test('fails open when the policy request fails', () async {
    final api = _FakePolicyApi(
        error: DioException(requestOptions: RequestOptions(path: '/policy')));
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'ios',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    expect(await service.checkForUpdate(), isNull);
  });

  test('never calls the policy endpoint for web', () async {
    final api = _FakePolicyApi(policy: _policy(latestBuild: 102));
    final service = ClientVersionUpdateService(
      policyApi: api,
      platform: 'web',
      packageInfoLoader: () async => _packageInfo(),
      preferencesLoader: _preferences,
    );

    expect(await service.checkForUpdate(), isNull);
    expect(api.calls, 0);
  });
}
