import 'package:happy_notes/dio_interceptors/auth_interceptor.dart';
import 'package:happy_notes/dio_interceptors/client_identity_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'app_config.dart';

class DioClient {
  static Dio? _dio;

  DioClient._internal();

  static Dio getInstance() {
    if (_dio == null) {
      // Check if running in test mode with mocked Dio
      if (GetIt.instance.isRegistered<Dio>()) {
        _dio = GetIt.instance<Dio>();
        return _dio!;
      }

      _dio = Dio(); // Create Dio instance if not already created
      _dio!.options.baseUrl = AppConfig.apiBaseUrl;
      // Increase timeouts for better web performance and token validation
      _dio!.options.connectTimeout = const Duration(seconds: 30);
      _dio!.options.receiveTimeout = const Duration(seconds: 35);
      // _dio!.options.sendTimeout = const Duration(seconds: 20);

      _dio!.interceptors.add(ClientIdentityInterceptor());
      _dio!.interceptors.add(LogInterceptor(requestBody: true, responseBody: true)); // Add logging interceptor
      _dio!.interceptors.add(AuthInterceptor());
      _dio!.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.contentType = 'application/json';
          return handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          // Handle global response data here if needed
          return handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          // Handle global error here
          // AppLogger.e(e.toString());
          return handler.next(e);
        },
      ));
    }
    return _dio!;
  }
}
