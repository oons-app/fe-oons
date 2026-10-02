import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/month_dates_copy.dart' show subApi;

/// Thin seam over the HTTP client for the customer subscription screens, so
/// widget tests can answer paths without a network. Failures surface as
/// [ApiException] (whose `message` is Arabic for subscription endpoints).
abstract class CustomerSubApi {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query});
  Future<Map<String, dynamic>> post(String path, {Object? data});
}

class LiveCustomerSubApi implements CustomerSubApi {
  const LiveCustomerSubApi();

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => subApi.get(path, query: query);

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => subApi.post(path, data: data);
}

final customerSubApiProvider = Provider<CustomerSubApi>((ref) => const LiveCustomerSubApi());

/// Opens an external URL (receipt PDF); overridable in tests.
final externalOpenerProvider = Provider<Future<void> Function(String url)>((ref) => openExternal);

/// Arabic text for any thrown error (never the raw exception).
String subErrorMessage(Object e, {String fallback = 'حصلت مشكلة. جرّبي تاني.'}) {
  if (e is ApiException) {
    if (e.isOffline) return 'مفيش اتصال بالإنترنت. جرّبي تاني.';
    final m = e.message.trim();
    if (m.isNotEmpty && RegExp(r'[؀-ۿ]').hasMatch(m)) return m;
    if (e.status == 404) return 'مش لاقيين ده. ممكن يكون اتغيّر.';
  }
  return fallback;
}
