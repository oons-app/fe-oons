/**
 * Meta Pixel — website dataset 4590005284478511 (oons.app in Events Manager).
 * 1782365966426827 is only a linked mobile-app identifier; do not init that.
 * Cookies scoped to .oons.app so a click on oons.app still matches lady.oons.app.
 * Facebook/Instagram in-app browsers almost never tap the cookie banner, so
 * those sessions grant ad storage — that is the paid-click path.
 */
(function () {
  var PIXEL_ID = '4590005284478511';
  var ua = navigator.userAgent || '';
  var iab = /FBAN|FBAV|FB_IAB|FBIOS|FB4A|Instagram/i.test(ua);

  function readCookie(name) {
    var parts = (document.cookie || '').split(';');
    for (var i = 0; i < parts.length; i++) {
      var kv = parts[i].trim();
      var eq = kv.indexOf('=');
      if (eq > 0 && kv.slice(0, eq) === name) {
        try { return decodeURIComponent(kv.slice(eq + 1)); } catch (_) { return kv.slice(eq + 1); }
      }
    }
    return '';
  }

  function writeCookie(name, value) {
    document.cookie = name + '=' + encodeURIComponent(value) +
      '; Domain=.oons.app; Path=/; Max-Age=7776000; Secure; SameSite=Lax';
  }

  // Capture fbclid even when Pixel consent is still revoked — CAPI needs fbc.
  (function persistFbclid() {
    try {
      var params = new URLSearchParams(location.search || '');
      var fbclid = params.get('fbclid');
      if (!fbclid) return;
      try { sessionStorage.setItem('oons_fbclid', fbclid); } catch (_) {}
      if (readCookie('_fbc') || readCookie('oons_fbc')) return;
      var fbc = 'fb.1.' + Date.now() + '.' + fbclid;
      writeCookie('_fbc', fbc);
      writeCookie('oons_fbc', fbc);
      try { sessionStorage.setItem('oons_fbc', fbc); } catch (_) {}
    } catch (_) {}
  })();

  function adsGranted() {
    try {
      var stored = window.__oonsConsent && window.__oonsConsent.stored && window.__oonsConsent.stored();
      if (stored && stored.ad_storage === 'granted') return true;
    } catch (_) {}
    return iab;
  }

  if (iab && window.__oonsConsent && window.__oonsConsent.acceptAll) {
    try { window.__oonsConsent.acceptAll(); } catch (_) {}
  }

  !function (f, b, e, v, n, t, s) {
    if (f.fbq) return;
    n = f.fbq = function () {
      n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
    };
    if (!f._fbq) f._fbq = n;
    n.push = n;
    n.loaded = !0;
    n.version = '2.0';
    n.queue = [];
    t = b.createElement(e);
    t.async = !0;
    t.src = v;
    s = b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t, s);
  }(window, document, 'script', 'https://connect.facebook.net/en_US/fbevents.js');

  fbq('set', 'autoConfig', true, PIXEL_ID);
  fbq('consent', adsGranted() ? 'grant' : 'revoke');
  try { fbq('set', 'cookieDomain', 'oons.app'); } catch (_) {}
  fbq('init', PIXEL_ID);
  fbq('track', 'PageView');

  window.__oonsMetaPixelId = PIXEL_ID;
  window.addEventListener('oons-consent', function (ev) {
    var d = ev && ev.detail;
    fbq('consent', d && d.ad_storage === 'granted' ? 'grant' : 'revoke');
  });
})();
