/**
 * Consent Mode v2 (Advanced) — must run before gtag config.
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

  var denied = {
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
    analytics_storage: 'denied',
    wait_for_update: 500
  };

  // Default: denied (Advanced mode still sends cookieless pings).
  // EEA/UK/CH explicitly denied; other regions same until banner choice.
  gtag('consent', 'default', Object.assign({}, denied, { region: ['AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE','IS','LI','NO','GB','CH'] }));
  gtag('consent', 'default', denied);

  gtag('set', 'ads_data_redaction', true);
  gtag('set', 'url_passthrough', true);

  window.__oonsConsent = {
    key: KEY,
    apply: function (partial) {
      var next = {
        ad_storage: partial.ad_storage || 'denied',
        ad_user_data: partial.ad_user_data || 'denied',
        ad_personalization: partial.ad_personalization || 'denied',
        analytics_storage: partial.analytics_storage || 'denied'
      };
      gtag('consent', 'update', next);
      writeStored(next);
      window.dispatchEvent(new CustomEvent('oons-consent', { detail: next }));
      return next;
    },
    acceptAll: function () {
      return window.__oonsConsent.apply({
        ad_storage: 'granted',
        ad_user_data: 'granted',
        ad_personalization: 'granted',
        analytics_storage: 'granted'
      });
    },
    acceptAnalytics: function () {
      return window.__oonsConsent.apply({
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        analytics_storage: 'granted'
      });
    },
    rejectAll: function () {
      return window.__oonsConsent.apply({
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        analytics_storage: 'denied'
      });
    },
    stored: readStored
  };

  var stored = readStored();
  if (stored) {
    gtag('consent', 'update', stored);
  }
})();
