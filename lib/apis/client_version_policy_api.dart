import 'package:dio/dio.dart';

import '../dio_client.dart';
import '../models/client_version_policy.dart';

class ClientVersionPolicyApi {
  final Dio _dio;

  ClientVersionPolicyApi({Dio? dio}) : _dio = dio ?? DioClient.getInstance();

  Future<ClientVersionPolicy> getPolicy(String platform) async {
    final response = await _dio.get(
      '/ClientVersionPolicy/Get',
      queryParameters: {'platform': platform},
      options: Options(headers: {'AllowAnonymous': true}),
    );

    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw FormatException('Client version policy returned HTTP $statusCode');
    }

    final body = response.data;
    if (body is! Map || body['successful'] != true) {
      throw const FormatException(
          'Client version policy response was unsuccessful');
    }

    return ClientVersionPolicy.fromJson(body['data']);
  }
}
