/// Shared Google tag boot for Flutter web (lady / bo / vanity).
/// Requires consent.js to run first (Consent Mode v2 Advanced).
/// Google tag: GT-TQT5V342 → destinations include GA4 G-C8QWM0FP6T (“oons web”).
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
window.gtag = gtag;

(function () {
  var GOOGLE_TAG_ID = 'GT-TQT5V342';
  var MEASUREMENT_ID = 'G-C8QWM0FP6T';
  var host = (location.hostname || '').toLowerCase();
  var surface = 'customer';
  if (host === 'bo.oons.app') surface = 'admin';
  else if (host === 'oons.app' || host === 'www.oons.app') surface = 'landing';
  else if (host === 'lady.oons.app') surface = 'customer';
  else if (host.endsWith('.oons.app') && host.split('.').length === 3) surface = 'provider_public';

  // Prefer path-based title until Flutter SPA sets a richer one.
  // Avoid first hit showing bare static <title>Oons</title>.
  function bootTitle(path) {
    var p = path || '/';
    if (p.length > 1 && p.charAt(p.length - 1) === '/') p = p.slice(0, -1);
    if (p === '/' || p === '/home') return 'Home | Oons';
    if (p === '/bookings') return 'My bookings | Oons';
    if (p === '/profile') return 'Profile | Oons';
    if (p.indexOf('/browse/') === 0) return 'Search | Oons';
    if (p.indexOf('/book/') === 0) return 'Booking · checkout | Oons';
    if (p.indexOf('/provider/') === 0) return 'Provider profile | Oons';
    if (p.indexOf('/p/') === 0) return 'Public book | Oons';
    if (p.indexOf('/pro/') === 0) return 'Pro | Oons';
    if (surface === 'admin') return 'Admin | Oons';
    if (surface === 'landing') return 'Landing | Oons';
    return (p + ' | Oons');
  }

  var path = location.pathname + (location.search || '');
  var title = bootTitle(location.pathname);
  try { document.title = title; } catch (_) {}

  // Flutter SPA owns page_view via AppAnalytics — disable auto send to avoid
  // duplicate “Oons” hits from the static shell title.
  var cfg = {
    send_page_view: false,
    cookie_domain: 'oons.app',
    linker: {
      domains: ['oons.app', 'www.oons.app', 'lady.oons.app', 'bo.oons.app'],
      accept_incoming: true
    },
    surface: surface,
    traffic_type: surface,
    page_title: title,
    page_path: path,
    page_location: location.href
  };

  gtag('js', new Date());
  // Primary Google tag (routes to all linked destinations in Tag Admin).
  gtag('config', GOOGLE_TAG_ID, cfg);
  // Explicit GA4 destination (same property as Admin “oons web”).
  gtag('config', MEASUREMENT_ID, cfg);
  gtag('set', 'user_properties', {
    surface: surface,
    host: host
  });
  // Initial hit with a meaningful title (before Flutter mounts).
  gtag('event', 'page_view', {
    page_title: title,
    page_location: location.href,
    page_path: path,
    surface: surface
  });
  window.__oonsSurface = surface;
  window.__oonsGaId = MEASUREMENT_ID;
  window.__oonsGoogleTagId = GOOGLE_TAG_ID;
})();
