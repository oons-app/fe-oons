/**
 * Lightweight bilingual cookie banner for Consent Mode v2.
 */
(function () {
  if (typeof document === 'undefined') return;
  var api = window.__oonsConsent;
  if (!api) return;
  if (api.stored()) return; // already chose

  var lang = (document.documentElement.lang || 'ar').toLowerCase().indexOf('en') === 0 ? 'en' : 'ar';
  try {
    var q = new URLSearchParams(location.search).get('lang');
    if (q === 'en' || q === 'ar') lang = q;
  } catch (_) {}

  var copy = {
    ar: {
      title: 'ملفات تعريف الارتباط',
      body: 'نستخدم ملفات تعريف الارتباط لقياس استخدام الموقع وتحسينه. يمكنك قبول التحليلات فقط، أو الكل، أو الرفض.',
      all: 'قبول الكل',
      analytics: 'التحليلات فقط',
      reject: 'رفض'
    },
    en: {
      title: 'Cookies',
      body: 'We use cookies to measure and improve the site. Accept analytics only, all cookies, or reject.',
      all: 'Accept all',
      analytics: 'Analytics only',
      reject: 'Reject'
    }
  };
  var t = copy[lang] || copy.ar;

  var style = document.createElement('style');
  style.textContent = [
    '#oons-consent{position:fixed;inset-inline:16px;bottom:16px;z-index:2147483000;max-width:420px;',
    'background:#3A2431;color:#F4EBE1;border-radius:16px;padding:16px 16px 14px;',
    'box-shadow:0 12px 40px rgba(0,0,0,.35);font:14px/1.45 system-ui,-apple-system,sans-serif}',
    '#oons-consent h2{margin:0 0 8px;font-size:16px;font-weight:700}',
    '#oons-consent p{margin:0 0 12px;opacity:.9}',
    '#oons-consent .row{display:flex;flex-wrap:wrap;gap:8px}',
    '#oons-consent button{appearance:none;border:0;border-radius:12px;min-height:40px;padding:0 12px;',
    'font:600 13px/1 system-ui,sans-serif;cursor:pointer}',
    '#oons-consent .all{background:#C9B39B;color:#3A2431}',
    '#oons-consent .analytics{background:transparent;color:#F4EBE1;border:1px solid rgba(244,235,225,.35)}',
    '#oons-consent .reject{background:transparent;color:#BAA9AF;border:1px solid rgba(244,235,225,.2)}'
  ].join('');
  document.head.appendChild(style);

  var box = document.createElement('div');
  box.id = 'oons-consent';
  box.setAttribute('role', 'dialog');
  box.setAttribute('aria-live', 'polite');
  box.dir = lang === 'ar' ? 'rtl' : 'ltr';
  box.innerHTML =
    '<h2>' + t.title + '</h2>' +
    '<p>' + t.body + '</p>' +
    '<div class="row">' +
    '<button type="button" class="all">' + t.all + '</button>' +
    '<button type="button" class="analytics">' + t.analytics + '</button>' +
    '<button type="button" class="reject">' + t.reject + '</button>' +
    '</div>';

  function done() {
    if (box.parentNode) box.parentNode.removeChild(box);
  }

  box.querySelector('.all').onclick = function () { api.acceptAll(); done(); };
  box.querySelector('.analytics').onclick = function () { api.acceptAnalytics(); done(); };
  box.querySelector('.reject').onclick = function () { api.rejectAll(); done(); };

  function mount() {
    document.body.appendChild(box);
  }
  if (document.body) mount();
  else document.addEventListener('DOMContentLoaded', mount);
})();
