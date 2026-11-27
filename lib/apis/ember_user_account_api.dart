import 'package:dio/dio.dart';

import '../dio_client.dart';
import '../entities/ember_user_account.dart';

class EmberUserAccountApi {
  final Dio _dio;

  EmberUserAccountApi({Dio? dio}) : _dio = dio ?? DioClient.getInstance();

  Future<Response> getAll() {
    return _dio.get('/emberUserAccount/getAll');
  }

  Future<Response> add(EmberUserAccount account) {
    return _dio.post('/emberUserAccount/add', data: account.toJson());
  }

  Future<Response> activate(int accountId) {
    return _dio.post(
      '/emberUserAccount/activate',
      data: _accountData(accountId),
    );
  }

  Future<Response> disable(int accountId) {
    return _dio.post(
      '/emberUserAccount/disable',
      data: _accountData(accountId),
    );
  }

  Future<Response> delete(int accountId) {
    return _dio.delete(
      '/emberUserAccount/delete',
      data: _accountData(accountId),
    );
  }

  Future<Response> test(int accountId) {
    return _dio.post('/emberUserAccount/test', data: _accountData(accountId));
  }

  Future<Response> nextSyncType(int accountId) {
    return _dio.post(
      '/emberUserAccount/nextSyncType',
      data: _accountData(accountId),
    );
  }

  Map<String, int> _accountData(int accountId) => {'accountId': accountId};
}
