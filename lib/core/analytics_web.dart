import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<void> initNative() async {}

void _gtag(List<Object?> args) {
  try {
    js_util.callMethod(js_util.globalThis, 'gtag', args);
  } catch (_) {}
}

Object? _js(Object? value) {
  if (value == null) return null;
  if (value is Map) return js_util.jsify(value);
  if (value is List) return js_util.jsify(value);
  return value;
}

void setDocumentTitle(String title) {
  final t = title.trim();
  if (t.isEmpty) return;
  html.document.title = t;
}

Future<void> logEvent(String name, Map<String, Object>? params) async {
  final merged = <String, Object>{
    if (params != null) ...params,
    // Helps GA4 “Page title” / DebugView when events fire without a new page_view.
    if (params == null || !params.containsKey('page_title')) 'page_title': html.document.title,
    if (params == null || !params.containsKey('page_path'))
      'page_path': html.window.location.pathname ?? '/',
  };
  _gtag(['event', name, _js(merged)]);
}

Future<void> logScreen(String name, {String? path}) async {
  final p = path ?? (html.window.location.pathname ?? '/');
  final title = name.trim().isEmpty ? p : name.trim();
  setDocumentTitle(title);
  final loc = html.window.location;
  final port = int.tryParse(loc.port ?? '');
  final pageLocation = Uri(
    scheme: loc.protocol?.replaceAll(':', '') ?? 'https',
    host: loc.hostname,
    port: (port == null || port == 0 || port == 80 || port == 443) ? null : port,
    path: p,
    query: (loc.search ?? '').replaceFirst('?', ''),
  ).toString();
  _gtag([
    'event',
    'page_view',
    _js({
      'page_title': title,
      'page_path': p,
      'page_location': pageLocation,
      'screen_name': title,
    }),
  ]);
  // Keep GA4 config in sync for subsequent automatic hits.
  try {
    _gtag([
      'config',
      'G-C8QWM0FP6T',
      _js({
        'page_title': title,
        'page_path': p,
        'page_location': pageLocation,
      }),
    ]);
  } catch (_) {}
}

Future<void> setUserId(String? id) async {
  _gtag([
    'config',
    'G-C8QWM0FP6T',
    _js({'user_id': id}),
  ]);
}

Future<void> setUserProperties(Map<String, String> props) async {
  _gtag(['set', 'user_properties', _js(props)]);
}
