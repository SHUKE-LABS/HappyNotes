import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/ember_user_account_api.dart';
import 'package:happy_notes/entities/ember_user_account.dart';
import 'package:happy_notes/exceptions/api_exception.dart';
import 'package:happy_notes/services/ember_user_account_service.dart';

class FakeEmberUserAccountApi extends EmberUserAccountApi {
  FakeEmberUserAccountApi() : super(dio: Dio());

  dynamic responseData = {'successful': true};
  String? lastAction;
  int? lastAccountId;
  EmberUserAccount? addedAccount;

  Response _response() => Response(
        requestOptions: RequestOptions(path: '/emberUserAccount/$lastAction'),
        data: responseData,
      );

  @override
  Future<Response> getAll() async {
    lastAction = 'getAll';
    return _response();
  }

  @override
  Future<Response> add(EmberUserAccount account) async {
    lastAction = 'add';
    addedAccount = account;
    return _response();
  }

  Future<Response> _idAction(String action, int accountId) async {
    lastAction = action;
    lastAccountId = accountId;
    return _response();
  }

  @override
  Future<Response> activate(int accountId) => _idAction('activate', accountId);

  @override
  Future<Response> disable(int accountId) => _idAction('disable', accountId);

  @override
  Future<Response> delete(int accountId) => _idAction('delete', accountId);

  @override
  Future<Response> test(int accountId) => _idAction('test', accountId);

  @override
  Future<Response> nextSyncType(int accountId) =>
      _idAction('nextSyncType', accountId);
}

void main() {
  late FakeEmberUserAccountApi api;
  late EmberUserAccountService service;

  setUp(() {
    api = FakeEmberUserAccountApi();
    service = EmberUserAccountService(emberUserAccountApi: api);
  });

  test('maps getAll response data to Ember accounts', () async {
    api.responseData = {
      'successful': true,
      'data': [
        {
          'id': 3,
          'userId': 4,
          'emberUrl': 'https://ember.example',
          'apiKey': '****',
          'syncType': 1,
          'status': 'Untested',
        },
      ],
    };

    final accounts = await service.getAll();

    expect(accounts.single.id, 3);
    expect(accounts.single.emberUrl, 'https://ember.example');
  });

  test('add creates a public-only account', () async {
    expect(await service.add('https://ember.example', 'secret'), isTrue);

    expect(api.addedAccount?.emberUrl, 'https://ember.example');
    expect(api.addedAccount?.apiKey, 'secret');
    expect(api.addedAccount?.syncType, EmberUserAccount.publicOnlySyncType);
  });

  test('forwards account IDs for account actions', () async {
    await service.activate(9);
    expect((api.lastAction, api.lastAccountId), ('activate', 9));

    await service.disable(10);
    expect((api.lastAction, api.lastAccountId), ('disable', 10));

    await service.test(11);
    expect((api.lastAction, api.lastAccountId), ('test', 11));

    await service.nextSyncType(12);
    expect((api.lastAction, api.lastAccountId), ('nextSyncType', 12));

    await service.delete(13);
    expect((api.lastAction, api.lastAccountId), ('delete', 13));
  });

  test('throws ApiException for unsuccessful responses', () async {
    api.responseData = {
      'successful': false,
      'errorCode': 'EMBER_TEST_FAILED',
      'message': 'Could not connect',
    };

    expect(() => service.test(1), throwsA(isA<ApiException>()));
  });
}
