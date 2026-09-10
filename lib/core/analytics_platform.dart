import 'package:oons/core/analytics_stub.dart'
    if (dart.library.html) 'package:oons/core/analytics_web.dart' as impl;

/// Platform bridge for GA4 / Firebase.
abstract final class AnalyticsPlatform {
  static Future<void> initNative() => impl.initNative();

  static Future<void> logEvent(String name, Map<String, Object>? params) =>
      impl.logEvent(name, params);

  static Future<void> logScreen(String name, {String? path}) =>
      impl.logScreen(name, path: path);

  static Future<void> setUserId(String? id) => impl.setUserId(id);

  static Future<void> setUserProperties(Map<String, String> props) =>
      impl.setUserProperties(props);
}
