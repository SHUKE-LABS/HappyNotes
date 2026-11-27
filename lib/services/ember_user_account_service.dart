import 'package:happy_notes/exceptions/api_exception.dart';

import '../apis/ember_user_account_api.dart';
import '../entities/ember_user_account.dart';

class EmberUserAccountService {
  final EmberUserAccountApi _emberUserAccountApi;

  EmberUserAccountService({required EmberUserAccountApi emberUserAccountApi})
      : _emberUserAccountApi = emberUserAccountApi;

  Future<List<EmberUserAccount>> getAll() async {
    final apiResult = (await _emberUserAccountApi.getAll()).data;
    _ensureSuccessful(apiResult);

    final accounts = apiResult['data'];
    if (accounts is! List) {
      throw const FormatException('Invalid Ember account response');
    }

    return accounts
        .map(
          (json) => EmberUserAccount.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<bool> add(String emberUrl, String apiKey) async {
    final account = EmberUserAccount(emberUrl: emberUrl, apiKey: apiKey);
    return _successful(await _emberUserAccountApi.add(account));
  }

  Future<bool> activate(int accountId) async {
    return _successful(await _emberUserAccountApi.activate(accountId));
  }

  Future<bool> disable(int accountId) async {
    return _successful(await _emberUserAccountApi.disable(accountId));
  }

  Future<bool> delete(int accountId) async {
    return _successful(await _emberUserAccountApi.delete(accountId));
  }

  Future<bool> test(int accountId) async {
    return _successful(await _emberUserAccountApi.test(accountId));
  }

  Future<bool> nextSyncType(int accountId) async {
    return _successful(await _emberUserAccountApi.nextSyncType(accountId));
  }

  bool _successful(dynamic response) {
    final apiResult = response.data;
    _ensureSuccessful(apiResult);
    return true;
  }

  void _ensureSuccessful(dynamic apiResult) {
    if (apiResult is! Map || apiResult['successful'] != true) {
      throw ApiException(apiResult);
    }
  }
}
