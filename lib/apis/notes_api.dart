import 'package:dio/dio.dart';

import '../app_config.dart';
import '../dio_client.dart';

class NotesApi {
  static final Dio _dio = DioClient.getInstance();

  static Future<Response> get(int noteId) async {
    return await _dio.get('/note/get/$noteId');
  }

  static Future<Response> getPublic(int noteId) async {
    return await _dio.get(
      '/Note/GetPublic/$noteId',
      options: Options(headers: {'AllowAnonymous': true}),
    );
  }

  static Future<Response> delete(int noteId) async {
    return await _dio.delete('/note/delete/$noteId');
  }

  static Future<Response> undelete(int noteId) async {
    return await _dio.post('/note/undelete/$noteId');
  }

  static Future<Response> post(Map<String, dynamic> params) async {
    return await _dio.post('/api/notev2', data: params);
  }

  static Future<Response> update(Map<String, dynamic> params) async {
    if (params['id'] == null) {
      throw ArgumentError('The "id" parameter is required for the update operation.');
    }
    return await _dio.put('/api/notev2/${params['id']}', data: params);
  }

  static Future<Response> latest(Map<String, dynamic> params) async {
    var pager = params['pageSize'] > 0 && params['pageNumber'] > 0
        ? '/${params['pageSize']}/${params['pageNumber']}'
        : '/${AppConfig.pageSize}/1';
    return await _dio.get('/notes/latest$pager');
  }

  static Future<Response> tagNotes(Map<String, dynamic> params) async {
    var pager = params['pageSize'] > 0 && params['pageNumber'] > 0
        ? '/${params['pageSize']}/${params['pageNumber']}'
        : '/${AppConfig.pageSize}/1';
    return await _dio.get('/notes/tag$pager', queryParameters: {'tag': params['tag']});
  }

  static Future<Response> myLatest(Map<String, dynamic> params) async {
    var pager = params['pageSize'] > 0 && params['pageNumber'] > 0
        ? '/${params['pageSize']}/${params['pageNumber']}'
        : '/${AppConfig.pageSize}/1';
    return await _dio.get('/notes/myLatest$pager');
  }

  static Future<Response> memories(Map<String, dynamic> params) async {
    return await _dio.get('/notes/memories?localTimeZone=${params['localTimeZone']}');
  }

  static Future<Response> memoriesOn(Map<String, dynamic> params) async {
    return await _dio.get('/notes/memoriesOn?localTimeZone=${params['localTimeZone']}&yyyyMMdd=${params['yyyyMMdd']}');
  }

  static Future<Response> getLinkedNotes(int noteId) async {
    return await _dio.get('/notes/linkedNotes/$noteId');
  }

  static Future<Response> latestDeleted(int pageSize, int pageNumber) async {
    return await _dio.get('/notes/latestDeleted/$pageSize/$pageNumber');
  }

  static Future<Response> purgeDeleted() async {
    return await _dio.delete('/notes/purgeDeleted');
  }

  static Future<Response> setIsPrivate(int noteId, bool isPrivate) async {
    return await _dio.post('/Note/SetIsPrivate/$noteId/privacy', data: {'isPrivate': isPrivate});
  }

  static Future<Response> searchNotes(String query, int pageSize, int pageNumber) async {
    // Ensure pageSize and pageNumber are valid, default if not
    final effectivePageSize = pageSize > 0 ? pageSize : AppConfig.pageSize;
    final effectivePageNumber = pageNumber > 0 ? pageNumber : 1;

    final path = '/notes/search/$effectivePageSize/$effectivePageNumber';
    final queryParams = {
      'query': query,
      'filter': 'normal', // Assuming 'normal' is the desired default filter
    };
    return await _dio.get(path, queryParameters: queryParams);
  }
}
