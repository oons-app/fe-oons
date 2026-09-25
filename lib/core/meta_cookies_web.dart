import 'dart:html' as html;

/// Pixel cookies live on lady.oons.app / .oons.app, not on api.oons.app.
/// Forward them so CAPI can match the browser Pixel.
Map<String, String> metaForwardHeaders() {
  persistMetaClickIds();
  final out = <String, String>{};
  final fbp = _cookie('_fbp');
  final fbc = _cookie('_fbc') ?? _cookie('oons_fbc') ?? _fbcFromClick();
  final fbclid = Uri.base.queryParameters['fbclid'] ?? html.window.sessionStorage['oons_fbclid'];
  if (fbp != null && fbp.isNotEmpty) out['X-Fbp'] = fbp;
  if (fbc != null && fbc.isNotEmpty) out['X-Fbc'] = fbc;
  if (fbclid != null && fbclid.isNotEmpty) out['X-Fbclid'] = fbclid;
  final href = html.window.location.href;
  if (href.isNotEmpty) out['X-Page-Url'] = href;
  final ua = html.window.navigator.userAgent;
  if (ua.isNotEmpty) out['X-Client-Ua'] = ua;
  return out;
}

/// Persist fbclid as a first-party cookie on .oons.app (milliseconds, Meta format).
/// sessionStorage alone is lost when the user clicks from oons.app to lady.oons.app.
void persistMetaClickIds() {
  try {
    final fbclid = Uri.base.queryParameters['fbclid'];
    if (fbclid != null && fbclid.isNotEmpty) {
      html.window.sessionStorage['oons_fbclid'] = fbclid;
      final existing = _cookie('_fbc') ?? _cookie('oons_fbc');
      if (existing == null || existing.isEmpty) {
        final fbc = _buildFbc(fbclid);
        _writeDomainCookie('_fbc', fbc);
        _writeDomainCookie('oons_fbc', fbc);
        html.window.sessionStorage['oons_fbc'] = fbc;
      }
    }
  } catch (_) {}
}

String? _fbcFromClick() {
  try {
    final stored = html.window.sessionStorage['oons_fbc'];
    if (stored != null && stored.isNotEmpty) return stored;
    final fbclid = Uri.base.queryParameters['fbclid'] ?? html.window.sessionStorage['oons_fbclid'];
    if (fbclid == null || fbclid.isEmpty) return null;
    final fbc = _buildFbc(fbclid);
    html.window.sessionStorage['oons_fbc'] = fbc;
    _writeDomainCookie('_fbc', fbc);
    _writeDomainCookie('oons_fbc', fbc);
    return fbc;
  } catch (_) {
    return null;
  }
}

String _buildFbc(String fbclid) {
  // Meta requires fb.1.{unix_ms}.{fbclid} — seconds are rejected for matching.
  return 'fb.1.${DateTime.now().millisecondsSinceEpoch}.$fbclid';
}

void _writeDomainCookie(String name, String value) {
  try {
    html.document.cookie =
        '$name=${Uri.encodeComponent(value)}; Domain=.oons.app; Path=/; Max-Age=7776000; Secure; SameSite=Lax';
  } catch (_) {}
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
