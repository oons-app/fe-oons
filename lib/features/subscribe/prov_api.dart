import 'package:oons/data/api.dart';

/// Thin seam over the app's [api] client so the provider subscription screens
/// can be driven by a fake in widget tests.
abstract class ProApi {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query});
  Future<Map<String, dynamic>> post(String path, {Object? data});
  Future<Map<String, dynamic>> delete(String path);
}

class LiveProApi implements ProApi {
  const LiveProApi();
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => api.get(path, query: query);
  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => api.post(path, data: data);
  @override
  Future<Map<String, dynamic>> delete(String path) => api.delete(path);
}

final _arabicLetters = RegExp(r'[؀-ۿ]');

/// A message that is safe to show: the server's own Arabic message when it has
/// one, otherwise [fallback]. Never a raw exception string or English text.
String arError(Object e, {String fallback = 'حصلت مشكلة. جرّبي تاني.'}) {
  if (e is ApiException) {
    if (e.status == 0) return 'مفيش اتصال بالنت. جرّبي تاني.';
    if (_arabicLetters.hasMatch(e.message)) return e.message;
  }
  return fallback;
}

List<Map<String, dynamic>> mapList(Object? v) =>
    ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

int intOf(Object? v, [int d = 0]) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? d);
