import 'package:dio/dio.dart';
import '../entities/user.dart';
import '../dio_client.dart';

class AccountApi {
  static final Dio _dio = DioClient.getInstance();

  Future<Response> login(Map<String, dynamic> params) async {
    final options = Options(
      headers: {'AllowAnonymous': true},
    );
    return await _dio.post('/account/login', data: params, options: options);
  }

  Future<Response> register(Map<String, dynamic> params) async {
    final options = Options(
      headers: {'AllowAnonymous': true},
    );
    return await _dio.post('/account/register', data: params, options: options);
  }

  Future<Response> googleLogin(String idToken) async {
    final options = Options(
      headers: {'AllowAnonymous': true},
    );
    return await _dio.post('/account/googleLogin', data: {'idToken': idToken}, options: options);
  }

  Future<Response> deleteAccount(Map<String, dynamic> confirmation) async {
    return await _dio.delete('/Account/DeleteAccount', data: confirmation);
  }

  Future<Response> refreshToken() async {
    return await _dio.post('/account/refreshToken', data: {});
  }

  static Future<User> getMyInformation() async {
    final response = await _dio.get('/account/myInformation');
    // Assuming the API returns { "data": { ...user fields... }, ... }
    if (response.data != null && response.data['data'] != null) {
      return User.fromJson(response.data['data']);
    } else {
      // Consider throwing a more specific exception based on API response
      throw Exception('Failed to load user information');
    }
  }

  static Future<Response> changePassword(String currentPassword, String newPassword) async {
    return await _dio.post('/account/changePassword', data: {
      'CurrentPassword': currentPassword,
      'NewPassword': newPassword,
    });
  }
}
