import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/data/e2e.dart';

const _labApiPref = 'debug_api_base';

/// Debug and profile only. Store release builds never read a user-set host.
bool get allowLabApiOverride => kDebugMode || kProfileMode;

/// Normalize a lab host (`192.168.1.5:8088` or a full URL). Empty string clears.
/// Returns null if the value is not a usable http(s) origin.
String? normalizeLabApiBase(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  if (s.contains(RegExp(r'\s'))) return null;
  if (!s.contains('://')) s = 'http://$s';
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty) return null;
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  if (u.userInfo.isNotEmpty) return null;
  if (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(u.host)) return null;
  if (u.hasPort) return '${u.scheme}://${u.host}:${u.port}';
  return '${u.scheme}://${u.host}';
}

String? labApiOverride() {
  if (!allowLabApiOverride) return null;
  try {
    if (!Hive.isBoxOpen('prefs')) return null;
    final v = Hive.box('prefs').get(_labApiPref);
    if (v is String && v.trim().isNotEmpty) {
      final n = normalizeLabApiBase(v);
      if (n != null && n.isNotEmpty) return n;
    }
  } catch (_) {}
  return null;
}

Future<void> setLabApiBase(String raw) async {
  final n = normalizeLabApiBase(raw);
  if (n == null) {
    throw const FormatException('Need an http(s) host, like 47.91.41.120:8088');
  }
  final box = Hive.box('prefs');
  if (n.isEmpty) {
    await box.delete(_labApiPref);
  } else {
    await box.put(_labApiPref, n);
  }
}

/// Host for the Go API.
///
/// Pass `--dart-define=API_BASE=https://api.oons.app` for store / native builds.
/// Physical phone (debug/profile): `--dart-define=API_BASE=http://47.91.41.120:8088`
/// (existing lab host — not a local Docker API) or the in-app Lab API field.
/// Simulator / Mac: default `http://127.0.0.1:8088` when you run `go run ./cmd/api`.
/// Release web always uses same-origin `/api` (lady + `{slug}.oons.app` + custom domains)
/// so the browser never hits a cross-origin CORS wall.
String apiHost() {
  final lab = labApiOverride();
  if (lab != null && lab.isNotEmpty) return lab;
  // Vanity/custom/lady web: nginx proxies /api → API. Avoids CORS on {slug}.oons.app.
  if (kIsWeb && kReleaseMode && !kProfileMode) {
    return '';
  }
  const defined = String.fromEnvironment('API_BASE');
  if (defined.isNotEmpty) return defined;
  if (kReleaseMode && !kProfileMode) {
    return 'https://api.oons.app';
  }
  return 'http://127.0.0.1:8088';
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  bool get isOffline => status == 0;
  bool get isPayFail => status == 402;
  bool get isNotFound => status == 404;

  @override
  String toString() => message.isEmpty ? 'error' : message;
}

class ApiClient {
  ApiClient({String? baseUrl}) {
    final host = baseUrl ?? apiHost();
    _dio = Dio(BaseOptions(
      baseUrl: '$host/api/v1',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        o.baseUrl = '${apiHost()}/api/v1';
        final t = await storage.read(key: 'access');
        _access = t;
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        o.headers['X-Locale'] = Hive.box('prefs').get('locale', defaultValue: 'ar');

        final path = o.path;
        final method = o.method.toUpperCase();
        final skipE2E = path.contains('crypto/session') ||
            path.contains('payments/webhook') ||
            path.contains('/me/alerts') ||
            path.endsWith('/alerts') ||
            path.contains('/categories') ||
            path.contains('/public/') ||
            path.contains('/legal') ||
            path.contains('/book-bootstrap') ||
            path.contains('/availability') ||
            (method == 'GET' && path.contains('/providers') && !path.contains('/bookings')) ||
            (method == 'GET' && path.endsWith('/home'));
        if (!skipE2E) {
          try {
            await e2e.ensure(_dio);
            final s = e2e.session;
            if (s != null) {
              o.headers['X-Oons-E2E'] = s.sessionId;
              final data = o.data;
              if (data != null && data is! FormData) {
                o.data = await s.sealJson(data);
                o.headers[Headers.contentTypeHeader] = Headers.jsonContentType;
              }
            }
          } catch (_) {}
        }
        h.next(o);
      },
      onResponse: (r, h) async {
        try {
          final data = r.data;
          if (data is Map && data['v'] == 1 && data['ct'] != null && e2e.session != null) {
            r.data = await e2e.session!.openJson(Map<String, dynamic>.from(data));
          }
        } catch (_) {}
        h.next(r);
      },
      onError: (e, h) async {
        final status = e.response?.statusCode ?? 0;
        var body = e.response?.data;
        if (body is Map && body['v'] == 1 && body['ct'] != null && e2e.session != null) {
          try {
            body = await e2e.session!.openJson(Map<String, dynamic>.from(body));
            e.response?.data = body;
          } catch (_) {}
        }
        final errMsg = body is Map && body['error'] is Map ? '${body['error']['message'] ?? ''}' : '';
        if (status == 401 && errMsg.contains('E2E')) {
          e2e.clear();
        }
        String msg = e.message ?? 'error';
        if (body is Map) {
          final err = body['error'];
          if (err is Map && err['message'] != null) {
            msg = '${err['message']}';
          }
        }
        h.reject(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          error: ApiException(status, msg),
        ));
      },
    ));
  }

  late final Dio _dio;
  final storage = const FlutterSecureStorage();
  final e2e = E2EController();
  String? _access;

  String? get accessToken => _access;

  String get host => _dio.options.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

  Future<Map<String, dynamic>> upload(String path, String field, List<int> bytes, {String filename = 'photo.jpg', void Function(double fraction)? onProgress}) async {
    try {
      await e2e.ensure(_dio);
      final s = e2e.session;
      var payload = bytes;
      final map = <String, dynamic>{};
      if (s != null) {
        payload = await s.sealBytes(bytes);
        map['e2e'] = '1';
      }
      map[field] = MultipartFile.fromBytes(payload, filename: filename);
      final r = await _dio.post(
        path,
        data: FormData.fromMap(map),
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (onProgress == null) return;
          if (total <= 0) {
            onProgress(0);
            return;
          }
          onProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
    }
  }

  Future<Map<String, dynamic>> uploadForm(String path, Map<String, dynamic> fields) async {
    try {
      final form = FormData.fromMap(fields);
      final r = await _dio.post(path, data: form, options: Options(contentType: 'multipart/form-data'));
      return unwrapEnvelope(r.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException(0, 'offline');
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

  Future<Map<String, dynamic>> post(String path, {Object? data, String? idem}) async {
    try {
      final r = await _dio.post(path, data: data, options: Options(headers: {
        if (idem != null) 'Idempotency-Key': idem,
      }));
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
}

Map<String, dynamic> unwrapEnvelope(dynamic d) {
  if (d is! Map) return {'data': d};
  final m = Map<String, dynamic>.from(d);
  if (m.containsKey('data')) {
    final data = m['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data == null) return {};
    return {'data': data};
  }
  return m;
}

final api = ApiClient();

/// Public client web origin for shareable provider links.
String publicWebBase() {
  const defined = String.fromEnvironment('PUBLIC_WEB_BASE');
  if (defined.isNotEmpty) return defined.replaceAll(RegExp(r'/+$'), '');
  final host = apiHost();
  if (host.isEmpty) {
    final o = Uri.base.origin;
    return (o.isEmpty || o == 'null') ? '' : o;
  }
  final u = Uri.tryParse(host);
  if (u != null && u.hasScheme && u.host.isNotEmpty) {
    var h = u.host;
    if (h.startsWith('api.')) h = h.substring(4);
    if (u.port == 8088) return '${u.scheme}://$h';
    return u.replace(host: h).origin;
  }
  return host.replaceAll(RegExp(r'/+$'), '');
}

/// Prefer vanity `https://{slug}.oons.app`. Path form remains available via [publicBookingPathUrl].
String publicBookingUrl(String slug, {String? customDomain}) {
  final s = slug.trim().toLowerCase();
  final custom = (customDomain ?? '').trim().toLowerCase();
  if (custom.isNotEmpty) {
    return 'https://$custom';
  }
  if (s.isEmpty) return publicWebBase();
  return 'https://$s.oons.app';
}

/// Always-works path on the customer app host.
String publicBookingPathUrl(String slug) {
  final s = slug.trim().toLowerCase();
  final base = publicWebBase();
  if (base.isEmpty) return '/p/$s';
  return '$base/p/$s';
}

/// Active custom booking domain from a provider payload, if TLS is live.
String? activeCustomDomain(Map? providerJson) {
  if (providerJson == null) return null;
  final list = providerJson['customDomains'];
  if (list is! List) return null;
  for (final raw in list) {
    if (raw is! Map) continue;
    if ('${raw['status']}' == 'verified' && '${raw['tlsStatus']}' == 'active') {
      final h = '${raw['host'] ?? ''}'.trim().toLowerCase();
      if (h.isNotEmpty) return h;
    }
  }
  return null;
}

String legalPageUrl(String id) {
  var base = publicWebBase();
  if (base.isEmpty) base = kIsWeb ? Uri.base.origin : 'https://lady.oons.app';
  return '$base/legal/$id';
}
