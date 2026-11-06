import 'package:dio/dio.dart';

/// Same `implements Dio` + `noSuchMethod` trick as MockDio, but lets each
/// test configure the GET/PUT response instead of hard-coding it by path —
/// needed to drive the real NotesService through all of update()'s branches.
class FakeNotesDio implements Dio {
  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? putResponse;
  int getStatusCode = 200;
  Object? getError;
  String? lastGetPath;
  Options? lastGetOptions;

  @override
  noSuchMethod(Invocation invocation) {
    final path = invocation.positionalArguments.isNotEmpty ? invocation.positionalArguments[0].toString() : '/';

    if (invocation.memberName == #get) {
      lastGetPath = path;
      lastGetOptions = invocation.namedArguments[#options] as Options?;
      if (getError != null) return Future<Response>.error(getError!);
      return Future.value(Response(
        requestOptions: RequestOptions(path: path, method: 'GET'),
        statusCode: getStatusCode,
        data: getResponse,
      ));
    }
    if (invocation.memberName == #put) {
      return Future.value(Response(
        requestOptions: RequestOptions(path: path, method: 'PUT'),
        statusCode: 200,
        data: putResponse,
      ));
    }
    return super.noSuchMethod(invocation);
  }
}
