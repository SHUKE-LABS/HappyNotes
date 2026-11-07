import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/client_version_policy_api.dart';

class _FakeDio implements Dio {
  int statusCode = 200;
  dynamic responseData;
  String? requestedPath;
  Map<String, dynamic>? requestedQuery;
  Options? requestedOptions;
  Object? error;

  @override
  noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      requestedPath = invocation.positionalArguments.first.toString();
      requestedQuery =
          invocation.namedArguments[#queryParameters] as Map<String, dynamic>?;
      requestedOptions = invocation.namedArguments[#options] as Options?;
      if (error != null) return Future<Response<dynamic>>.error(error!);
      return Future.value(
        Response<dynamic>(
          requestOptions: RequestOptions(path: requestedPath!, method: 'GET'),
          statusCode: statusCode,
          data: responseData,
        ),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late _FakeDio dio;

  setUp(() {
    dio = _FakeDio();
    dio.responseData = {
      'successful': true,
      'data': {
        'minSupportedBuild': 100,
        'latestVersion': '2.1.0',
        'latestBuild': 110,
        'storeUrl': 'https://example.com/happynotes',
      },
    };
  });

  test('requests the anonymous policy endpoint and parses its ApiResult data',
      () async {
    final policy = await ClientVersionPolicyApi(dio: dio).getPolicy('ios');

    expect(policy.minSupportedBuild, 100);
    expect(policy.latestVersion, '2.1.0');
    expect(policy.latestBuild, 110);
    expect(policy.storeUrl, 'https://example.com/happynotes');
    expect(dio.requestedPath, '/ClientVersionPolicy/Get');
    expect(dio.requestedQuery, {'platform': 'ios'});
    expect(dio.requestedOptions?.headers?['AllowAnonymous'], isTrue);
  });

  test('rejects an unsuccessful response', () async {
    dio.responseData = {'successful': false, 'data': null};

    expect(
      () => ClientVersionPolicyApi(dio: dio).getPolicy('android'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a response with missing policy fields', () async {
    dio.responseData = {
      'successful': true,
      'data': {'minSupportedBuild': 100},
    };

    expect(
      () => ClientVersionPolicyApi(dio: dio).getPolicy('ios'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a non-success HTTP response', () async {
    dio.statusCode = 503;

    expect(
      () => ClientVersionPolicyApi(dio: dio).getPolicy('android'),
      throwsA(isA<FormatException>()),
    );
  });
}
