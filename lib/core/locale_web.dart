import 'dart:html' as html;

void syncWebLocale(String code) {
  try {
    html.window.localStorage['oons_locale'] = code;
    html.document.documentElement?.setAttribute('lang', code);
    html.window.dispatchEvent(html.CustomEvent('oons:locale', detail: code));
  } catch (_) {}
}
