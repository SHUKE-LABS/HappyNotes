import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/seq_logger.dart';
import '../utils/client_platform.dart';

/// Adds the client identity required by the API request log.
class ClientIdentityInterceptor extends Interceptor {
  final Future<PackageInfo> Function() _packageInfoLoader;
  final String _platform;
  Future<PackageInfo>? _packageInfoFuture;

  ClientIdentityInterceptor({
    Future<PackageInfo> Function()? packageInfoLoader,
    String? platform,
  })  : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _platform = platform ?? getClientPlatform();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Client-Platform'] = _platform;

    try {
      final packageInfo = await (_packageInfoFuture ??= _packageInfoLoader());
      options.headers['X-Client-Version'] = packageInfo.version;
      options.headers['X-Client-Build'] = packageInfo.buildNumber;
    } catch (error, stackTrace) {
      // Identity headers remain present even if platform metadata is
      // unavailable. An API request must not fail because telemetry failed.
      options.headers['X-Client-Version'] = '';
      options.headers['X-Client-Build'] = '';
      try {
        SeqLogger.warning(
          'Client identity unavailable: $error',
          error,
          stackTrace,
        );
      } catch (_) {
        // Logging may not be initialized in an isolated test or early startup.
      }
    }

    handler.next(options);
  }
}
