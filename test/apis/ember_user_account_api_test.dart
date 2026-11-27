import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/apis/ember_user_account_api.dart';

class _RecordingDio implements Dio {
  String? requestedPath;
  dynamic requestedData;

  @override
  noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #post) {
      requestedPath = invocation.positionalArguments.single as String;
      requestedData = invocation.namedArguments[#data];
      return Future.value(
        Response<dynamic>(
          requestOptions: RequestOptions(path: requestedPath!, method: 'POST'),
          data: {'successful': true},
        ),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test('posts the account id when changing the sync type', () async {
    final dio = _RecordingDio();

    await EmberUserAccountApi(dio: dio).nextSyncType(42);

    expect(dio.requestedPath, '/emberUserAccount/nextSyncType');
    expect(dio.requestedData, {'accountId': 42});
  });
}
