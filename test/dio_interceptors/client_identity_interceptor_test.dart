import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/dio_interceptors/client_identity_interceptor.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _CapturingRequestHandler extends RequestInterceptorHandler {
  final completed = Completer<RequestOptions>();

  @override
  void next(RequestOptions options) {
    completed.complete(options);
    super.next(options);
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

Future<RequestOptions> _runInterceptor(
    ClientIdentityInterceptor interceptor) async {
  final options = RequestOptions(path: '/test', method: 'GET');
  final handler = _CapturingRequestHandler();
  interceptor.onRequest(options, handler);
  return handler.completed.future;
}

void main() {
  test('adds all client identity headers from package info', () async {
    final options = await _runInterceptor(
      ClientIdentityInterceptor(
        platform: 'ios',
        packageInfoLoader: () async => _packageInfo(),
      ),
    );

    expect(options.headers['X-Client-Platform'], 'ios');
    expect(options.headers['X-Client-Version'], '2.0.0');
    expect(options.headers['X-Client-Build'], '101');
  });

  test('caches package info while adding headers to every request', () async {
    var loads = 0;
    final interceptor = ClientIdentityInterceptor(
      platform: 'web',
      packageInfoLoader: () async {
        loads++;
        return _packageInfo();
      },
    );

    final first = await _runInterceptor(interceptor);
    final second = await _runInterceptor(interceptor);

    expect(loads, 1);
    expect(first.headers['X-Client-Platform'], 'web');
    expect(second.headers['X-Client-Version'], '2.0.0');
  });

  test('keeps identity headers present when package info fails', () async {
    final options = await _runInterceptor(
      ClientIdentityInterceptor(
        platform: 'android',
        packageInfoLoader: () async => throw StateError('plugin unavailable'),
      ),
    );

    expect(options.headers['X-Client-Platform'], 'android');
    expect(options.headers['X-Client-Version'], '');
    expect(options.headers['X-Client-Build'], '');
  });
}
