/**
 * Add to Home Screen for Oons — Safari, Chrome, and in-app browsers
 * (Instagram, Facebook, WhatsApp, TikTok, etc.).
 * No service worker required.
 */
(function () {
  if (typeof document === 'undefined') return;

  var STORAGE_KEY = 'oons_a2hs_dismissed_v1';
  var LOCALE_KEY = 'oons_locale';
  var DISMISS_DAYS = 21;
  var IOS_STORE = 'https://apps.apple.com/eg/app/oons-app/id6811881656';
  var deferredPrompt = null;
  var mountedLang = null;
  var mountedMode = null;

  function ua() {
    return navigator.userAgent || navigator.vendor || '';
  }

  function dismissed() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return false;
      return parseInt(raw, 10) > Date.now();
    } catch (_) {
      return false;
    }
  }

  function dismiss() {
    try {
      localStorage.setItem(STORAGE_KEY, String(Date.now() + DISMISS_DAYS * 864e5));
    } catch (_) {}
  }

  function isStandalone() {
    try {
      if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return true;
      if (window.navigator.standalone === true) return true;
    } catch (_) {}
    return false;
  }

  function isMobile() {
    var s = ua();
    if (/Android|iPhone|iPad|iPod/i.test(s)) return true;
    return Math.min(screen.width || 0, screen.height || 0) <= 820;
  }

  function isIOS() {
    return /iPhone|iPad|iPod/i.test(ua()) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  function isAndroid() {
    return /Android/i.test(ua());
  }

  /** Detect social / messaging in-app browsers (A2HS usually impossible here). */
  function inAppInfo() {
    var s = ua();
    var checks = [
      { id: 'threads', re: /Barcelona/i },
      { id: 'instagram', re: /Instagram/i },
      { id: 'facebook', re: /FBAN|FBAV|FB_IAB|FBIOS|FB4A/i },
      { id: 'messenger', re: /MessengerForiOS|Orca-Android/i },
      { id: 'whatsapp', re: /WhatsApp/i },
      { id: 'tiktok', re: /TikTok|BytedanceWebview|musical_ly|Bytedance/i },
      { id: 'twitter', re: /Twitter|TwitterAndroid/i },
      { id: 'linkedin', re: /LinkedInApp/i },
      { id: 'snapchat', re: /Snapchat/i },
      { id: 'line', re: /\bLine\//i },
      { id: 'telegram', re: /Telegram/i },
      { id: 'pinterest', re: /Pinterest/i },
      { id: 'reddit', re: /Reddit/i },
      { id: 'wechat', re: /MicroMessenger|WeChat/i },
      { id: 'gsa', re: /\bGSA\//i }
    ];
    for (var i = 0; i < checks.length; i++) {
      if (checks[i].re.test(s)) return checks[i].id;
    }
    // Generic Android WebView
    if (isAndroid() && /\bwv\b|; wv\)/i.test(s) && !/Chrome\/[\d.]+ Mobile/i.test(s.replace(/;\s*wv\)/i, ''))) {
      if (/Version\/4\.0/i.test(s) || /; wv\)/i.test(s)) return 'webview';
    }
    // iOS WKWebView heuristic: AppleWebKit without Safari/CriOS/FxiOS/EdgiOS
    if (isIOS() && /AppleWebKit/i.test(s) && !/Safari\//i.test(s) && !/CriOS|FxiOS|EdgiOS|OPiOS/i.test(s)) {
      return 'webview';
    }
    return null;
  }

  function isSafari() {
    var s = ua();
    if (!isIOS()) {
      // Desktop Safari — not our target
      return /Safari/i.test(s) && !/Chrome|Chromium|Edg|OPR|Firefox/i.test(s);
    }
    // Real iOS Safari includes Version/… Safari/… and is not CriOS etc.
    return /Safari\//i.test(s) && /Version\//i.test(s) && !/CriOS|FxiOS|EdgiOS|OPiOS|Chrome/i.test(s) && !inAppInfo();
  }

  function isChromeIOS() {
    return isIOS() && /CriOS/i.test(ua());
  }

  function isChromeAndroid() {
    return isAndroid() && /Chrome\//i.test(ua()) && !/EdgA|OPR|SamsungBrowser|YaBrowser/i.test(ua()) && !inAppInfo();
  }

  /**
   * Mode used for copy + primary CTA:
   * - inapp: trapped in Instagram/WhatsApp/etc.
   * - safari: iOS Safari (best for A2HS)
   * - chromeios: Chrome on iPhone (A2HS still needs Safari)
   * - android: Chrome/Android (menu install or BIP)
   * - other: generic mobile
   */
  function browserMode() {
    if (inAppInfo()) return 'inapp';
    if (isSafari() && isIOS()) return 'safari';
    if (isChromeIOS()) return 'chromeios';
    if (isChromeAndroid() || (isAndroid() && !inAppInfo())) return 'android';
    if (isIOS()) return 'safari'; // prefer Safari instructions on unknown iOS
    return 'other';
  }

  function hostKind() {
    var h = (location.hostname || '').toLowerCase();
    if (h === 'oons.app' || h === 'www.oons.app') return 'landing';
    return 'app';
  }

  function appUrl() {
    var L = lang();
    return 'https://lady.oons.app/?a2hs=1&lang=' + L;
  }

  function lang() {
    try {
      var stored = localStorage.getItem(LOCALE_KEY);
      if (stored === 'en' || stored === 'ar') return stored;
    } catch (_) {}
    try {
      var q = new URLSearchParams(location.search).get('lang');
      if (q === 'en' || q === 'ar') return q;
    } catch (_) {}
    var html = (document.documentElement.lang || '').toLowerCase();
    if (html.indexOf('en') === 0) return 'en';
    return 'ar';
  }

  function setLang(next) {
    try { localStorage.setItem(LOCALE_KEY, next); } catch (_) {}
    try { document.documentElement.lang = next; } catch (_) {}
    remount(true);
  }

  function forceShow() {
    try {
      return new URLSearchParams(location.search).get('a2hs') === '1';
    } catch (_) {
      return false;
    }
  }

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    deferredPrompt = e;
    remount(true);
  });

  window.addEventListener('oons:locale', function (ev) {
    try {
      var code = ev && ev.detail ? String(ev.detail) : '';
      if (code === 'en' || code === 'ar') {
        localStorage.setItem(LOCALE_KEY, code);
        remount(true);
      }
    } catch (_) {}
  });

  window.addEventListener('storage', function (ev) {
    if (ev && ev.key === LOCALE_KEY) remount(true);
  });

  function copyFor(kind, mode, L) {
    var en = L === 'en';
    var base = {
      dismiss: en ? 'Not now' : 'مش دلوقتي',
      langToggle: en ? 'عربي' : 'EN',
      copyLink: en ? 'Copy link' : 'انسخي الرابط',
      copied: en ? 'Copied — paste in Safari' : 'اتنسخ — الصقيه في سفاري',
      openSafari: en ? 'Open in Safari' : 'افتحي في سفاري',
      openBrowser: en ? 'Open in browser' : 'افتحي في المتصفح',
      how: en ? 'Show steps' : 'الخطوات',
      install: en ? 'Add to Home Screen' : 'أضيفي للشاشة الرئيسية'
    };

    if (mode === 'inapp' && isIOS()) {
      return Object.assign(base, {
        title: en ? 'Download Oons on the App Store' : 'حمّلي أُنس من آب ستور',
        body: en
          ? 'Oons is on the App Store in Egypt. Tap to install the iPhone app.'
          : 'أُنس على آب ستور في مصر. اضغطي لتثبيت التطبيق على الآيفون.',
        steps: en
          ? 'If the store doesn’t open, tap Open in Safari, then Download on the App Store.'
          : 'لو آب ستور ما فتحش، افتحي في سفاري بعدين حمّلي من آب ستور.',
        install: en ? 'Download on the App Store' : 'حمّلي من آب ستور'
      });
    }

    if (mode === 'inapp') {
      return Object.assign(base, {
        title: en ? 'Open in Safari to install' : 'افتحي في سفاري عشان تثبّتي',
        body: en
          ? 'In-app browsers can’t add Oons. Open lady.oons.app in Safari, then Share → Add to Home Screen.'
          : 'متصفح واتساب/إنستجرام مش بيضيف للشاشة. افتحي lady.oons.app في سفاري، بعدين مشاركة ← إضافة إلى الشاشة الرئيسية.',
        steps: en
          ? '1) Tap “Open in Safari”\n2) On lady.oons.app: Share → Add to Home Screen → Add\n(Don’t add from oons.app — that opens the marketing site.)'
          : '١) اضغطي «افتحي في سفاري»\n٢) على lady.oons.app: مشاركة ← إضافة إلى الشاشة الرئيسية\n(متضيفيش من oons.app — هتفتح موقع الدعاية مش التطبيق.)'
      });
    }

    if (kind === 'landing') {
      if (isIOS()) {
        return Object.assign(base, {
          title: en ? 'Download Oons on the App Store' : 'حمّلي أُنس من آب ستور',
          body: en
            ? 'Oons is on the App Store in Egypt. Tap to download the iPhone app.'
            : 'أُنس على آب ستور في مصر. اضغطي للتحميل على الآيفون.',
          steps: en
            ? '1) Tap Download on the App Store\n2) Install Oons\n3) Open the app and sign in with your phone'
            : '١) اضغطي تحميل من آب ستور\n٢) ثبّتي أُنس\n٣) افتحي التطبيق وسجّلي برقمك',
          install: en ? 'Download on the App Store' : 'حمّلي من آب ستور'
        });
      }
      return Object.assign(base, {
        title: en ? 'Add the app from lady.oons.app' : 'ثبّتي التطبيق من lady.oons.app',
        body: en
          ? 'Home Screen icons open the page you add from. Open the app first (lady.oons.app), then Share → Add to Home Screen — so the icon opens the app with the Oons logo.'
          : 'أيقونة الشاشة بتفتح الصفحة اللي ضفتي منها. افتحي التطبيق الأول (lady.oons.app)، بعدين مشاركة ← إضافة إلى الشاشة الرئيسية — عشان الأيقونة تفتح التطبيق ولوغو أنس.',
        steps: en
          ? '1) Tap Open Oons\n2) In Safari on lady.oons.app: Share → Add to Home Screen\n3) Delete any old icon that still opens oons.app'
          : '١) اضغطي افتحي أنس\n٢) في سفاري على lady.oons.app: مشاركة ← إضافة إلى الشاشة الرئيسية\n٣) امسحي أي أيقونة قديمة بتفتح oons.app'
      });
    }

    if (mode === 'safari') {
      return Object.assign(base, {
        title: en ? 'Download Oons on the App Store' : 'حمّلي أُنس من آب ستور',
        body: en
          ? 'The iPhone app is on the App Store in Egypt. Tap to download.'
          : 'تطبيق الآيفون على آب ستور في مصر. اضغطي للتحميل.',
        steps: en
          ? '1) Tap Download on the App Store\n2) Install, then open Oons'
          : '١) اضغطي تحميل من آب ستور\n٢) ثبّتي، بعدين افتحي أُنس',
        install: en ? 'Download on the App Store' : 'حمّلي من آب ستور'
      });
    }

    if (mode === 'chromeios') {
      return Object.assign(base, {
        title: en ? 'Download Oons on the App Store' : 'حمّلي أُنس من آب ستور',
        body: en
          ? 'Tap to open the App Store. Chrome on iPhone cannot install the app itself.'
          : 'اضغطي لفتح آب ستور. كروم على الآيفون مش يثبّت التطبيق بنفسه.',
        steps: en
          ? '1) Tap Download on the App Store\n2) Or Open in Safari, then download'
          : '١) اضغطي تحميل من آب ستور\n٢) أو افتحي في سفاري بعدين حمّلي',
        install: en ? 'Download on the App Store' : 'حمّلي من آب ستور',
        openSafari: en ? 'Open in Safari' : 'افتحي في سفاري'
      });
    }

    if (mode === 'android') {
      return Object.assign(base, {
        title: en ? 'Install Oons on your phone' : 'ثبّتي أنس على موبايلك',
        body: en
          ? 'On lady.oons.app in Chrome: menu ⋮ → Install app / Add to Home screen.'
          : 'على lady.oons.app في كروم: القائمة ⋮ ← تثبيت التطبيق / إضافة إلى الشاشة الرئيسية.',
        steps: en
          ? '1) Tap ⋮ (top right)\n2) Install app or Add to Home screen\n3) Confirm'
          : '١) اضغطي ⋮ فوق يمين\n٢) تثبيت التطبيق أو إضافة إلى الشاشة الرئيسية\n٣) أكّدي',
        install: en ? 'Install / show steps' : 'ثبّتي / الخطوات'
      });
    }

    return Object.assign(base, {
      title: en ? 'Add Oons to Home Screen' : 'ثبّتي أنس على الشاشة الرئيسية',
      body: en
        ? 'Open lady.oons.app in Safari (iPhone) or Chrome (Android), then add it to your Home Screen.'
        : 'افتحي lady.oons.app في سفاري (آيفون) أو كروم (أندرويد)، بعدين أضيفيه للشاشة الرئيسية.',
      steps: en
        ? 'iPhone: Safari → Share → Add to Home Screen\nAndroid: Chrome → ⋮ → Install app'
        : 'آيفون: سفاري ← مشاركة ← إضافة إلى الشاشة الرئيسية\nأندرويد: كروم ← ⋮ ← تثبيت التطبيق'
    });
  }

  function escapeToSafari(url) {
    var s = ua();
    var encoded = encodeURIComponent(url);
    // Must run synchronously in a user tap.
    try {
      if (/Barcelona/i.test(s)) {
        location.href = 'barcelona://extbrowser/?url=' + encoded;
        return true;
      }
      if (/Instagram/i.test(s)) {
        location.href = 'instagram://extbrowser/?url=' + encoded;
        return true;
      }
    } catch (_) {}
    try {
      // Works in many non-Meta in-app browsers on iOS
      location.href = 'x-safari-https://' + url.replace(/^https:\/\//i, '');
      return true;
    } catch (_) {}
    try {
      window.open(url, '_blank');
    } catch (_) {}
    return false;
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        ta.remove();
        resolve();
      } catch (err) {
        reject(err);
      }
    });
  }

  function remount(force) {
    var el = document.getElementById('oons-a2hs');
    var L = lang();
    var mode = browserMode();
    if (el && !force && mountedLang === L && mountedMode === mode) {
      remountStoreBanner(false);
      return;
    }
    if (el) el.remove();
    var st = document.getElementById('oons-a2hs-style');
    if (st) st.remove();
    mountedLang = null;
    mountedMode = null;
    mount();
    remountStoreBanner(!!force);
  }

  function storeLabel(L) {
    return L === 'en' ? 'Download on the App Store' : 'حمّلي من آب ستور';
  }

  function remountStoreBanner(force) {
    var el = document.getElementById('oons-ios-store');
    var L = lang();
    var shouldShow = isIOS() && !isStandalone() && !inAppInfo() && !document.getElementById('splash');
    if (!shouldShow) {
      if (el) el.remove();
      var st = document.getElementById('oons-ios-store-style');
      if (st) st.remove();
      try { document.documentElement.classList.remove('oons-has-ios-store'); } catch (_) {}
      return;
    }
    if (el && !force && el.getAttribute('data-lang') === L) return;
    if (el) el.remove();
    var st = document.getElementById('oons-ios-store-style');
    if (st) st.remove();
    try { document.documentElement.classList.remove('oons-has-ios-store'); } catch (_) {}
    mountStoreBanner();
  }

  function mountStoreBanner() {
    if (document.getElementById('oons-ios-store')) return;
    if (!isIOS() || isStandalone() || inAppInfo()) return;
    if (document.getElementById('splash')) return;
    if (!document.body) return;

    var L = lang();
    var kind = hostKind();
    var style = document.createElement('style');
    style.id = 'oons-ios-store-style';
    style.textContent = [
      '#oons-ios-store{position:fixed;inset-inline:0;top:0;z-index:40;',
      'display:flex;align-items:center;justify-content:center;gap:10px;',
      'min-height:46px;padding:8px 12px;padding-top:max(8px,env(safe-area-inset-top,0px));',
      'background:#3A2431;color:#F4EBE1;box-shadow:0 4px 16px rgba(0,0,0,.18);',
      'font:600 13px/1.3 system-ui,-apple-system,sans-serif}',
      '#oons-ios-store a{appearance:none;border:0;border-radius:999px;min-height:34px;',
      'padding:0 14px;font:600 13px/34px system-ui,sans-serif;cursor:pointer;',
      'text-decoration:none;background:#C9B39B;color:#3A2431;white-space:nowrap}'
    ].join('');
    document.head.appendChild(style);

    var bar = document.createElement('div');
    bar.id = 'oons-ios-store';
    bar.setAttribute('data-lang', L);
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', storeLabel(L));
    bar.dir = L === 'ar' ? 'rtl' : 'ltr';
    bar.innerHTML = '<a href="' + IOS_STORE + '" target="_blank" rel="noopener">' + storeLabel(L) + '</a>';
    document.body.appendChild(bar);
    try { document.documentElement.classList.add('oons-has-ios-store'); } catch (_) {}

    try {
      if (window.gtag) {
        gtag('event', 'a2hs_prompt_shown', {
          surface: kind,
          host: location.hostname,
          lang: L,
          browser_mode: 'ios_store_banner',
          in_app: inAppInfo() || ''
        });
      }
    } catch (_) {}
  }

  function mount() {
    if (document.getElementById('oons-a2hs')) return;
    if (isStandalone()) return;
    if (!isMobile() && !forceShow()) return;
    if (dismissed() && !forceShow()) return;
    if (!document.body) return;

    var kind = hostKind();
    var mode = browserMode();
    var L = lang();
    mountedLang = L;
    mountedMode = mode;
    var t = copyFor(kind, mode, L);
    var native = !!deferredPrompt && mode === 'android';
    var targetUrl = isIOS() ? IOS_STORE : (kind === 'landing' ? appUrl() : location.href.split('#')[0]);

    var style = document.createElement('style');
    style.id = 'oons-a2hs-style';
    style.textContent = [
      '#oons-a2hs{position:fixed;inset-inline:12px;bottom:12px;z-index:2147482900;max-width:440px;',
      'background:#3A2431;color:#F4EBE1;border-radius:18px;padding:14px 14px 12px;',
      'box-shadow:0 14px 40px rgba(0,0,0,.4);font:14px/1.45 system-ui,-apple-system,sans-serif;',
      'white-space:pre-line}',
      '#oons-a2hs .head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:6px}',
      '#oons-a2hs h2{margin:0;font-size:16px;font-weight:700;flex:1;white-space:normal}',
      '#oons-a2hs .lang{appearance:none;border:1px solid rgba(244,235,225,.28);background:transparent;',
      'color:#F4EBE1;border-radius:999px;min-height:32px;padding:0 10px;font:600 12px/32px system-ui,sans-serif;cursor:pointer}',
      '#oons-a2hs p{margin:0 0 8px;opacity:.92;white-space:normal}',
      '#oons-a2hs .steps{margin:0 0 10px;padding:10px 12px;border-radius:12px;',
      'background:rgba(244,235,225,.08);font-size:13px;line-height:1.55}',
      '#oons-a2hs .steps[hidden]{display:none!important}',
      '#oons-a2hs .hint{margin:0 0 10px;font-size:12px;opacity:.75;white-space:normal}',
      '#oons-a2hs .row{display:flex;flex-wrap:wrap;gap:8px}',
      '#oons-a2hs button,#oons-a2hs a.btn{appearance:none;border:0;border-radius:12px;min-height:40px;',
      'padding:0 12px;font:600 13px/40px system-ui,sans-serif;cursor:pointer;text-decoration:none;display:inline-block;white-space:nowrap}',
      '#oons-a2hs .primary{background:#C9B39B;color:#3A2431}',
      '#oons-a2hs .ghost{background:transparent;color:#F4EBE1;border:1px solid rgba(244,235,225,.3)}',
      '#oons-a2hs .muted{background:transparent;color:#BAA9AF;border:1px solid rgba(244,235,225,.18)}'
    ].join('');
    document.head.appendChild(style);

    var box = document.createElement('div');
    box.id = 'oons-a2hs';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-live', 'polite');
    box.dir = L === 'ar' ? 'rtl' : 'ltr';

    var primaryHtml = '';
    if (isIOS()) {
      primaryHtml = '<a class="btn primary" href="' + IOS_STORE + '" target="_blank" rel="noopener">' + t.install + '</a>';
      if (mode === 'inapp' || mode === 'chromeios') {
        primaryHtml +=
          '<button type="button" class="ghost" data-a2hs-escape>' + t.openSafari + '</button>' +
          '<button type="button" class="ghost" data-a2hs-copy>' + t.copyLink + '</button>';
      }
    } else if (kind === 'landing' && mode !== 'inapp' && mode !== 'chromeios') {
      primaryHtml = '<a class="btn primary" href="' + appUrl() + '">' + (L === 'en' ? 'Open Oons' : 'افتحي أنس') + '</a>';
    } else if (mode === 'inapp' || mode === 'chromeios') {
      primaryHtml =
        '<button type="button" class="primary" data-a2hs-escape>' +
        (isIOS() || mode === 'chromeios' ? t.openSafari : t.openBrowser) +
        '</button>' +
        '<button type="button" class="ghost" data-a2hs-copy>' + t.copyLink + '</button>';
    } else if (native) {
      primaryHtml = '<button type="button" class="primary" data-a2hs-install>' + t.install + '</button>';
    } else {
      primaryHtml = '<button type="button" class="primary" data-a2hs-howto>' + t.install + '</button>';
    }

    var showSteps = forceShow() || mode === 'safari' || mode === 'inapp' || mode === 'chromeios';
    var envHint = '';
    if (mode === 'safari') envHint = L === 'en' ? 'Safari on iPhone' : 'سفاري على الآيفون';
    else if (mode === 'android') envHint = L === 'en' ? 'Chrome / Android' : 'كروم / أندرويد';
    else if (mode === 'chromeios') envHint = L === 'en' ? 'Chrome on iPhone' : 'كروم على الآيفون';
    else if (mode === 'inapp') {
      var app = inAppInfo() || 'webview';
      envHint = (L === 'en' ? 'Opened inside ' : 'مفتوحة جوّه ') + app;
    }

    box.innerHTML =
      '<div class="head">' +
      '<h2>' + t.title + '</h2>' +
      '<button type="button" class="lang" data-a2hs-lang>' + t.langToggle + '</button>' +
      '</div>' +
      (envHint ? '<div class="hint">' + envHint + '</div>' : '') +
      '<p>' + t.body + '</p>' +
      '<div class="steps" data-a2hs-steps' + (showSteps ? '' : ' hidden') + '>' + t.steps + '</div>' +
      '<div class="row">' + primaryHtml +
      '<button type="button" class="ghost" data-a2hs-howto>' + t.how + '</button>' +
      '<button type="button" class="muted" data-a2hs-dismiss>' + t.dismiss + '</button>' +
      '</div>';

    document.body.appendChild(box);

    box.addEventListener('click', function (e) {
      var target = e.target.closest
        ? e.target.closest('[data-a2hs-dismiss],[data-a2hs-howto],[data-a2hs-install],[data-a2hs-lang],[data-a2hs-escape],[data-a2hs-copy]')
        : e.target;
      if (!target || !box.contains(target)) return;

      if (target.getAttribute('data-a2hs-lang') != null) {
        e.preventDefault();
        setLang(L === 'ar' ? 'en' : 'ar');
        return;
      }
      if (target.getAttribute('data-a2hs-dismiss') != null) {
        e.preventDefault();
        dismiss();
        box.remove();
        return;
      }
      if (target.getAttribute('data-a2hs-howto') != null) {
        e.preventDefault();
        var s = box.querySelector('[data-a2hs-steps]');
        if (s) {
          if (s.hasAttribute('hidden')) s.removeAttribute('hidden');
          else s.setAttribute('hidden', '');
        }
        return;
      }
      if (target.getAttribute('data-a2hs-copy') != null) {
        e.preventDefault();
        copyText(targetUrl).then(function () {
          target.textContent = t.copied;
        }).catch(function () {
          window.prompt(L === 'en' ? 'Copy this link' : 'انسخي الرابط', targetUrl);
        });
        return;
      }
      if (target.getAttribute('data-a2hs-escape') != null) {
        e.preventDefault();
        // Prefer lady app URL so Home Screen icon opens the app.
        var url = isIOS() ? IOS_STORE : (kind === 'landing' || mode === 'inapp' || mode === 'chromeios' ? appUrl() : targetUrl);
        if (!/^https:\/\//i.test(url)) url = isIOS() ? IOS_STORE : appUrl();
        escapeToSafari(url);
        // Also copy as fallback if scheme is blocked (Meta sometimes still blocks).
        setTimeout(function () {
          copyText(url).catch(function () {});
        }, 400);
        return;
      }
      if (target.getAttribute('data-a2hs-install') != null) {
        e.preventDefault();
        if (deferredPrompt) {
          deferredPrompt.prompt();
          Promise.resolve(deferredPrompt.userChoice).then(function () {
            deferredPrompt = null;
            dismiss();
            box.remove();
          }).catch(function () {
            var s2 = box.querySelector('[data-a2hs-steps]');
            if (s2) s2.removeAttribute('hidden');
          });
        } else {
          var s3 = box.querySelector('[data-a2hs-steps]');
          if (s3) s3.removeAttribute('hidden');
        }
      }
    });

    try {
      if (window.gtag) {
        gtag('event', 'a2hs_prompt_shown', {
          surface: kind,
          host: location.hostname,
          lang: L,
          browser_mode: mode,
          in_app: inAppInfo() || ''
        });
      }
    } catch (_) {}
  }

  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a') : null;
    if (!a || !a.href) return;
    if (!/apps\.apple\.com|itunes\.apple\.com/i.test(a.href)) return;
    try {
      if (window.gtag) {
        gtag('event', 'download_app', {
          app_platform: 'ios',
          link_url: a.href,
          surface: window.__oonsSurface || (hostKind() === 'landing' ? 'landing' : 'customer')
        });
      }
    } catch (_) {}
  }, true);

  function start() {
    var tries = 0;
    var timer = setInterval(function () {
      tries += 1;
      remount(false);
      remountStoreBanner(false);
      if (tries > 40) clearInterval(timer);
    }, 250);
    setInterval(function () {
      if (lang() !== mountedLang || browserMode() !== mountedMode) remount(true);
      remountStoreBanner(false);
    }, 800);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
