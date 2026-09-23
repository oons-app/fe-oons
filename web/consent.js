/**
 * Consent Mode v2 — ads cookies wait for the banner.
 * GA4 visit measurement is always on. Facebook/Instagram in-app browsers
 * almost never tap the banner, so gating analytics_storage hid every ad click.
 * https://developers.google.com/tag-platform/security/guides/consent?consentmode=advanced
 */
window.dataLayer = window.dataLayer || [];
function gtag(){ dataLayer.push(arguments); }
window.gtag = gtag;

(function () {
  var KEY = 'oons_consent_v2';

  function readStored() {
    try {
      var raw = localStorage.getItem(KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  function writeStored(state) {
    try {
      localStorage.setItem(KEY, JSON.stringify(state));
    } catch (_) {}
  }

  function withAnalytics(partial) {
    return {
      ad_storage: (partial && partial.ad_storage) || 'denied',
      ad_user_data: (partial && partial.ad_user_data) || 'denied',
      ad_personalization: (partial && partial.ad_personalization) || 'denied',
      analytics_storage: 'granted'
    };
  }

  var defaults = Object.assign(withAnalytics({}), { wait_for_update: 500 });

  gtag('consent', 'default', defaults);
  gtag('set', 'ads_data_redaction', true);
  gtag('set', 'url_passthrough', true);

  window.__oonsConsent = {
    key: KEY,
    apply: function (partial) {
      var next = withAnalytics(partial);
      gtag('consent', 'update', next);
      writeStored(next);
      window.dispatchEvent(new CustomEvent('oons-consent', { detail: next }));
      return next;
    },
    acceptAll: function () {
      return window.__oonsConsent.apply({
        ad_storage: 'granted',
        ad_user_data: 'granted',
        ad_personalization: 'granted'
      });
    },
    acceptAnalytics: function () {
      return window.__oonsConsent.apply({
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied'
      });
    },
    rejectAll: function () {
      // Reject advertising cookies only — visits stay counted.
      return window.__oonsConsent.acceptAnalytics();
    },
    stored: readStored
  };

  var stored = readStored();
  if (stored) {
    gtag('consent', 'update', withAnalytics(stored));
  }
})();
