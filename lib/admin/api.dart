
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:oons/data/api.dart';

const _staffTokenKey = 'staff_access';

class StaffApi {
  StaffApi() {
    _dio = Dio(BaseOptions(
      baseUrl: '${apiHost()}/api/v1',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        o.baseUrl = '${apiHost()}/api/v1';
        final t = token ?? readToken();
        token = t;
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        o.headers['X-Locale'] = Hive.box('prefs').get('locale', defaultValue: 'ar');
        h.next(o);
      },
      onError: (e, h) {
        String msg = e.message ?? 'error';
        final body = e.response?.data;
        if (body is Map) {
          final err = body['error'];
          if (err is Map && err['message'] != null) msg = '${err['message']}';
        }
        h.reject(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          error: ApiException(e.response?.statusCode ?? 0, msg),
        ));
      },
    ));
  }

  late final Dio _dio;
  String? token;

  String? readToken() {
    try {
      final v = Hive.box('prefs').get(_staffTokenKey);
      return v is String && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> persistToken(String? value) async {
    token = value;
    final box = Hive.box('prefs');
    if (value == null || value.isEmpty) {
      await box.delete(_staffTokenKey);
    } else {
      await box.put(_staffTokenKey, value);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query);
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    try {
      final r = await _dio.post(path, data: data);
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    required String fileField,
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        ...fields,
        fileField: MultipartFile.fromBytes(bytes, filename: filename),
      });
      final r = await _dio.post(
        path,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    try {
      final r = await _dio.patch(path, data: data);
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final r = await _dio.delete(path);
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  /// Authenticated binary GET (CSV exports, etc.).
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final data = r.data;
      if (data == null || data.isEmpty) {
        throw ApiException(r.statusCode ?? 0, 'empty export');
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  /// Fetch a protected `/uploads/…` blob (ID / fish / entry) with the staff token.
  ///
  /// Uses `package:http` (browser fetch) with an absolute same-origin URL on web.
  /// Dio + forbidden headers (Accept-Encoding) was silently failing in Chrome.
  Future<Uint8List?> uploadBytes(String path) async {
    try {
      final t = token ?? readToken();
      if (t == null || t.isEmpty) return null;
      final clean = path.trim();
      if (clean.isEmpty) return null;

      final uri = _uploadUri(clean);
      final r = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $t',
          'Accept': 'image/*,application/pdf,*/*',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 45));
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      if (r.bodyBytes.isEmpty) return null;
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Uri _uploadUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final q = {'v': '${DateTime.now().millisecondsSinceEpoch}'};
    if (kIsWeb) {
      // Same-origin on bo.oons.app — nginx proxies /uploads → API.
      return Uri.base.replace(path: path.split('?').first, queryParameters: q);
    }
    final host = apiHost().isNotEmpty ? apiHost() : 'https://api.oons.app';
    return Uri.parse('$host$path').replace(queryParameters: {
      ...Uri.parse('$host$path').queryParameters,
      ...q,
    });
  }
}

final staffApi = StaffApi();
