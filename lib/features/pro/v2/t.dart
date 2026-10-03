import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/pro_v2_copy.dart';

/// Provider v2 strings for the current language: `t(ref)('saved')`.
String Function(String key, [Map<String, Object> vars]) pv2(WidgetRef ref) => pv2Of(langOf(ref));

String Function(String key, [Map<String, Object> vars]) pv2Of(String lang) {
  final m = (Copy.of(lang)['pv2'] as Map).cast<String, String>();
  return (key, [vars = const {}]) {
    final raw = m[key] ?? ProV2Copy.ar[key] ?? key;
    return vars.isEmpty ? raw : ProV2Copy.fill(raw, vars);
  };
}
