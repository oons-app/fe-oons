import 'dart:html' as html;

/// Pixel cookies live on lady.oons.app / .oons.app, not on api.oons.app.
/// Forward them so CAPI can dedupe with the browser Pixel.
Map<String, String> metaForwardHeaders() {
  final out = <String, String>{};
  final fbp = _cookie('_fbp');
  final fbc = _cookie('_fbc') ?? _fbcFromClick();
  if (fbp != null && fbp.isNotEmpty) out['X-Fbp'] = fbp;
  if (fbc != null && fbc.isNotEmpty) out['X-Fbc'] = fbc;
  final href = html.window.location.href;
  if (href.isNotEmpty) out['X-Page-Url'] = href;
  return out;
}

String? _cookie(String name) {
  final raw = html.document.cookie ?? '';
  for (final part in raw.split(';')) {
    final kv = part.trim();
    final i = kv.indexOf('=');
    if (i <= 0) continue;
    if (kv.substring(0, i) == name) {
      return Uri.decodeComponent(kv.substring(i + 1));
    }
  }
  return null;
}

String? _fbcFromClick() {
  try {
    final stored = html.window.sessionStorage['oons_fbc'];
    if (stored != null && stored.isNotEmpty) return stored;
    final fbclid = Uri.base.queryParameters['fbclid'];
    if (fbclid == null || fbclid.isEmpty) return null;
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fbc = 'fb.1.$ts.$fbclid';
    html.window.sessionStorage['oons_fbc'] = fbc;
    return fbc;
  } catch (_) {
    return null;
  }
}
