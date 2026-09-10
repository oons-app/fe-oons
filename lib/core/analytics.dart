import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:oons/core/analytics_platform.dart';

/// GA4 measurement ID for all Oons web hosts (Google tag “oons web”).
const kGaMeasurementId = 'G-C8QWM0FP6T';

/// Google tag ID (GT-) — feeds all destinations linked in Tag Admin.
const kGoogleTagId = 'GT-TQT5V342';

/// Surfaces for Explore / comparisons: landing | customer | admin | provider_public
enum AnalyticsSurface { landing, customer, admin, providerPublic }

/// Audiences: customer (client app) | provider | admin (staff)
enum AnalyticsAudience { customer, provider, admin, anonymous }

class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? _fa;
  static bool ready = false;
  static AnalyticsSurface surface = AnalyticsSurface.customer;
  static AnalyticsAudience audience = AnalyticsAudience.anonymous;

  static String get surfaceName {
    switch (surface) {
      case AnalyticsSurface.landing:
        return 'landing';
      case AnalyticsSurface.customer:
        return 'customer';
      case AnalyticsSurface.admin:
        return 'admin';
      case AnalyticsSurface.providerPublic:
        return 'provider_public';
    }
  }

  static String get audienceName {
    switch (audience) {
      case AnalyticsAudience.customer:
        return 'customer';
      case AnalyticsAudience.provider:
        return 'provider';
      case AnalyticsAudience.admin:
        return 'admin';
      case AnalyticsAudience.anonymous:
        return 'anonymous';
    }
  }

  /// [forceSurface] for admin build (`admin`) or customer app (`customer`).
  static Future<void> init({AnalyticsSurface? forceSurface}) async {
    surface = forceSurface ?? _detectSurface();
    if (kIsWeb) {
      await AnalyticsPlatform.initNative();
      captureWebAcquisition();
      await AnalyticsPlatform.setUserProperties({
        'surface': surfaceName,
        'audience': audienceName,
        'host': Uri.base.host,
      });
      ready = true;
      await logEvent('app_open', {'surface': surfaceName});
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
      await _fa!.setUserProperty(name: 'surface', value: surfaceName);
      ready = true;
    } catch (e, st) {
      debugPrint('Analytics not configured yet: $e');
      assert(() {
        debugPrint('$st');
        return true;
      }());
      ready = false;
    }
  }

  static AnalyticsSurface _detectSurface() {
    if (!kIsWeb) return AnalyticsSurface.customer;
    final host = Uri.base.host.toLowerCase();
    if (host == 'bo.oons.app') return AnalyticsSurface.admin;
    if (host == 'oons.app' || host == 'www.oons.app') return AnalyticsSurface.landing;
    if (host == 'lady.oons.app') return AnalyticsSurface.customer;
    final parts = host.split('.');
    if (parts.length == 3 && parts[1] == 'oons' && parts[2] == 'app') {
      return AnalyticsSurface.providerPublic;
    }
    return AnalyticsSurface.customer;
  }

  static Future<void> setAudience(AnalyticsAudience value) async {
    audience = value;
    await AnalyticsPlatform.setUserProperties({
      'surface': surfaceName,
      'audience': audienceName,
    });
    final fa = _fa;
    if (fa != null) {
      await fa.setUserProperty(name: 'audience', value: audienceName);
      await fa.setUserProperty(name: 'surface', value: surfaceName);
    }
  }

  static Future<void> identify({
    required String userId,
    required AnalyticsAudience audience,
    String? country,
    String? area,
    String? providerSlug,
  }) async {
    await setAudience(audience);
    await AnalyticsPlatform.setUserId(userId);
    final props = <String, String>{
      'audience': audienceName,
      'surface': surfaceName,
      if (country != null && country.isNotEmpty) 'country': country,
      if (area != null && area.isNotEmpty) 'area': area,
      if (providerSlug != null && providerSlug.isNotEmpty) 'provider_slug': providerSlug,
    };
    await AnalyticsPlatform.setUserProperties(props);
    final fa = _fa;
    if (fa != null) {
      await fa.setUserId(id: userId);
      for (final e in props.entries) {
        await fa.setUserProperty(name: e.key, value: e.value);
      }
    }
  }

  static Future<void> clearIdentity() async {
    audience = AnalyticsAudience.anonymous;
    await AnalyticsPlatform.setUserId(null);
    await setAudience(AnalyticsAudience.anonymous);
    await _fa?.setUserId(id: null);
  }

  static Map<String, Object> _base([Map<String, Object>? extra]) {
    final m = <String, Object>{
      'surface': surfaceName,
      'audience': audienceName,
      'host': kIsWeb ? Uri.base.host : 'app',
    };
    if (extra != null) m.addAll(extra);
    return m;
  }

  /// Human-readable SPA titles for GA4 Pages / screens (never bare "Oons").
  static String screenTitleForPath(String path, {String? query}) {
    var p = path;
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (p.isEmpty) p = '/';

    String label;
    if (p == '/home' || p == '/') {
      label = 'Home';
    } else if (p == '/bookings') {
      label = 'My bookings';
    } else if (p == '/profile') {
      label = 'Profile';
    } else if (p == '/auth') {
      label = 'Sign in';
    } else if (p == '/otp') {
      label = 'OTP verify';
    } else if (p == '/register') {
      label = 'Client register';
    } else if (p == '/pro/register') {
      label = 'Provider register';
    } else if (p.startsWith('/onboard')) {
      label = 'Onboarding';
    } else if (p.startsWith('/browse/')) {
      final service = p.split('/').length > 2 ? p.split('/')[2] : 'service';
      label = 'Search · $service';
    } else if (p.startsWith('/provider/')) {
      label = 'Provider profile';
    } else if (p.startsWith('/book/')) {
      label = 'Booking · checkout';
    } else if (p.startsWith('/pay/')) {
      label = 'Payment';
    } else if (p.startsWith('/visit/')) {
      label = 'Live visit';
    } else if (p.startsWith('/p/')) {
      final slug = p.split('/').length > 2 ? p.split('/')[2] : 'provider';
      label = 'Public book · $slug';
    } else if (p.startsWith('/pro/jobs') || p == '/pro/job' || p.startsWith('/pro/job/')) {
      label = p.contains('/job/') ? 'Pro · job detail' : 'Pro · jobs';
    } else if (p.startsWith('/pro/services')) {
      label = 'Pro · services';
    } else if (p.startsWith('/pro/earnings')) {
      label = 'Pro · earnings';
    } else if (p.startsWith('/pro/account')) {
      label = 'Pro · account';
    } else if (p.startsWith('/pro/')) {
      label = 'Pro · ${p.substring(5)}';
    } else if (p.startsWith('/me/')) {
      label = 'Account · ${p.substring(4)}';
    } else if (p.startsWith('/legal/')) {
      label = 'Legal · ${p.substring(7)}';
    } else if (p.startsWith('/reviews')) {
      label = 'Reviews';
    } else if (p.startsWith('/admin') || p == '/' && surface == AnalyticsSurface.admin) {
      label = 'Admin · $p';
    } else {
      label = p;
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      label = '$label · $q';
    }
    return '$label | Oons';
  }

  static String contentGroupForPath(String path) {
    if (path.startsWith('/browse') || path.contains('search')) return 'search';
    if (path.startsWith('/book') || path.startsWith('/pay')) return 'booking';
    if (path.startsWith('/provider') || path.startsWith('/p/')) return 'provider';
    if (path.startsWith('/visit')) return 'visit';
    if (path.startsWith('/pro')) return 'provider_app';
    if (path.startsWith('/auth') || path.startsWith('/otp') || path.startsWith('/register') || path.startsWith('/onboard')) {
      return 'auth';
    }
    if (surface == AnalyticsSurface.admin) return 'admin';
    if (path.startsWith('/bookings')) return 'bookings';
    return 'app';
  }

  static Future<void> logScreen(String name, {String? path}) async {
    final p = path ?? (kIsWeb ? Uri.base.path : name);
    final title = name.contains('| Oons') ? name : screenTitleForPath(p);
    if (kIsWeb) {
      await AnalyticsPlatform.logScreen(title, path: p);
      return;
    }
    await _fa?.logScreenView(screenName: title, parameters: _base({
      'page_path': p,
      'content_group': contentGroupForPath(p),
    }));
  }

  static Future<void> logPageView(String path, {String? title}) async {
    final t = title ?? screenTitleForPath(path);
    await logScreen(t, path: path);
  }

  static Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    final path = kIsWeb ? Uri.base.path : (params?['page_path']?.toString() ?? name);
    final merged = _base({
      'content_group': contentGroupForPath(path),
      'screen_name': screenTitleForPath(path),
      if (params != null) ...params,
    });
    if (kIsWeb) {
      await AnalyticsPlatform.logEvent(name, merged);
      return;
    }
    final flat = <String, Object>{};
    for (final e in merged.entries) {
      final v = e.value;
      if (v is String || v is num || v is bool) {
        flat[e.key] = v is bool ? (v ? 1 : 0) : v;
      }
    }
    await _fa?.logEvent(name: name, parameters: flat);
  }

  /// How the user entered the book flow: search | profile | slug_page | rebook_shortcut.
  static String bookingEntryPoint = 'search';

  /// Last known acquisition channel for purchase attribution.
  static String acquisitionChannel = 'organic';

  static final Set<String> _purchaseFired = <String>{};
  static final Set<String> _refundFired = <String>{};

  static void markBookingEntry(String entryPoint) {
    bookingEntryPoint = entryPoint;
  }

  static void markAcquisition(String channel) {
    if (channel.isNotEmpty) acquisitionChannel = channel;
  }

  static void captureWebAcquisition() {
    if (!kIsWeb) return;
    final q = Uri.base.queryParameters;
    final utm = (q['utm_medium'] ?? q['utm_source'] ?? '').toLowerCase();
    if (utm.contains('cpc') || utm.contains('paid') || utm == 'ads') {
      markAcquisition('paid');
    } else if (utm.contains('referral') || utm == 'ref') {
      markAcquisition('referral');
    } else if (utm.contains('partner')) {
      markAcquisition('partnership');
    } else if (Uri.base.path.startsWith('/p/')) {
      markAcquisition('slug_page');
    }
  }

  // —— Auth / registration funnels ——

  static Future<void> login({required String role}) async {
    final aud = role == 'provider'
        ? AnalyticsAudience.provider
        : role == 'admin'
            ? AnalyticsAudience.admin
            : AnalyticsAudience.customer;
    await setAudience(aud);
    await logEvent('login', {'method': 'otp', 'role': role});
  }

  static Future<void> signUp({required String role}) async {
    await logEvent('sign_up', {'method': 'otp', 'role': role});
  }

  static Future<void> staffLogin() async {
    await setAudience(AnalyticsAudience.admin);
    await logEvent('login', {'method': 'password', 'role': 'admin'});
  }

  static Future<void> clientRegistrationStarted({String? source}) async {
    await logEvent('client_registration_started', {
      if (source != null) 'source': source,
    });
  }

  static Future<void> otpSent({required String role, bool resend = false}) async {
    await logEvent('otp_sent', {'role': role, 'resend': resend ? 1 : 0});
  }

  static Future<void> otpVerificationAttempted({
    required String role,
    required bool success,
    bool needsRegister = false,
  }) async {
    await logEvent('otp_verification_attempted', {
      'role': role,
      'success': success ? 1 : 0,
      'needs_register': needsRegister ? 1 : 0,
    });
  }

  static Future<void> consentScreenViewed({required String consentType, String role = 'client'}) async {
    await logEvent('consent_screen_viewed', {
      'consent_type': consentType,
      'role': role,
    });
  }

  static Future<void> clientRegistrationCompleted() async {
    await logEvent('client_registration_completed', {'method': 'otp'});
  }

  static Future<void> providerRegistrationStarted() async {
    await logEvent('provider_registration_started', {'method': 'otp'});
  }

  static Future<void> providerIdInfoSubmitted() async {
    await logEvent('provider_id_info_submitted', {});
  }

  static Future<void> providerCategorySelected({required String vertical, int? categoryCount}) async {
    await logEvent('provider_category_selected', {
      'item_category': vertical,
      if (categoryCount != null) 'category_count': categoryCount,
    });
  }

  static Future<void> providerPortfolioUploaded() async {
    await logEvent('provider_portfolio_uploaded', {});
  }

  static Future<void> providerRegistrationCompleted({String? vertical}) async {
    await logEvent('provider_registration_completed', {
      if (vertical != null) 'item_category': vertical,
    });
  }

  static Future<void> providerVettingApproved({required String providerId}) async {
    await logEvent('provider_vetting_approved', {'provider_id': providerId});
  }

  static Future<void> providerVettingRejected({required String providerId, String? reason}) async {
    await logEvent('provider_vetting_rejected', {
      'provider_id': providerId,
      if (reason != null && reason.isNotEmpty) 'reason': reason.length > 80 ? reason.substring(0, 80) : reason,
    });
  }

  // —— Search funnel ——

  static Future<void> search({
    required String term,
    String? service,
    int? resultCount,
    String? area,
    String? categoryId,
  }) async {
    final clipped = term.length > 80 ? term.substring(0, 80) : term;
    final title = screenTitleForPath('/browse/${service ?? 'all'}', query: clipped.isEmpty ? null : clipped);
    await logPageView('/browse/${service ?? 'all'}', title: title);
    await logEvent('search', {
      'search_term': clipped,
      if (service != null && service.isNotEmpty) 'item_category': service,
      if (service != null && service.isNotEmpty) 'vertical': service,
      if (resultCount != null) 'result_count': resultCount,
      if (area != null && area.isNotEmpty) 'area': area,
      if (categoryId != null && categoryId.isNotEmpty) 'item_list_id': categoryId,
      'content_group': 'search',
      'page_title': title,
    });
    await logEvent('search_performed', {
      'search_term': clipped,
      if (service != null && service.isNotEmpty) 'vertical': service,
      if (area != null && area.isNotEmpty) 'area': area,
      if (categoryId != null && categoryId.isNotEmpty) 'category': categoryId,
      if (resultCount != null) 'result_count': resultCount,
      'content_group': 'search',
      'page_title': title,
    });
  }

  static Future<void> viewItemList({required String service, int? itemCount, String? area, String? categoryId}) async {
    final title = screenTitleForPath('/browse/$service');
    await logPageView('/browse/$service', title: title);
    await logEvent('view_item_list', {
      'item_list_id': service,
      'item_list_name': service,
      'vertical': service,
      if (itemCount != null) 'item_count': itemCount,
      if (area != null) 'area': area,
      'content_group': 'search',
      'page_title': title,
    });
    if (itemCount != null && itemCount == 0) {
      await logEvent('search_zero_results', {
        'vertical': service,
        if (area != null) 'area': area,
        if (categoryId != null) 'category': categoryId,
        'content_group': 'search',
      });
    } else {
      await logEvent('search_results_shown', {
        'vertical': service,
        if (itemCount != null) 'result_count': itemCount,
        if (area != null) 'area': area,
        if (categoryId != null) 'category': categoryId,
        'content_group': 'search',
      });
    }
  }

  static Future<void> selectProvider({
    required String providerId,
    String? service,
    String? providerName,
  }) async {
    final name = (providerName ?? '').trim();
    final title = name.isEmpty
        ? screenTitleForPath('/provider/$providerId')
        : 'Provider · $name${service != null && service.isNotEmpty ? ' · $service' : ''} | Oons';
    await logPageView('/provider/$providerId', title: title);
    await logEvent('select_item', {
      'item_id': providerId,
      if (name.isNotEmpty) 'item_name': name,
      'item_list_id': service ?? 'browse',
      'item_category': service ?? 'provider',
      'content_type': 'provider',
      'content_group': 'provider',
      'page_title': title,
    });
    await logEvent('provider_profile_viewed', {
      'provider_id': providerId,
      if (name.isNotEmpty) 'provider_name': name,
      if (service != null) 'vertical': service,
      'content_group': 'provider',
      'page_title': title,
    });
  }

  static Future<void> bookingFlowStarted({
    required String providerId,
    String? entryPoint,
    String? serviceItemId,
    String? providerName,
    String? serviceName,
  }) async {
    final entry = entryPoint ?? bookingEntryPoint;
    markBookingEntry(entry);
    final bits = <String>['Booking'];
    if ((serviceName ?? '').trim().isNotEmpty) bits.add(serviceName!.trim());
    if ((providerName ?? '').trim().isNotEmpty) bits.add(providerName!.trim());
    final title = '${bits.join(' · ')} | Oons';
    await logPageView('/book/$providerId', title: title);
    await logEvent('booking_flow_started', {
      'provider_id': providerId,
      if ((providerName ?? '').trim().isNotEmpty) 'provider_name': providerName!.trim(),
      if ((serviceName ?? '').trim().isNotEmpty) 'service_name': serviceName!.trim(),
      'entry_point': entry,
      if (serviceItemId != null) 'service_item_id': serviceItemId,
      'content_group': 'booking',
      'page_title': title,
    });
  }

  static Future<void> beginCheckout({
    required String providerId,
    String? serviceItemId,
    num? value,
    String currency = 'EGP',
    String? entryPoint,
    String? providerName,
    String? serviceName,
  }) async {
    await bookingFlowStarted(
      providerId: providerId,
      entryPoint: entryPoint,
      serviceItemId: serviceItemId,
      providerName: providerName,
      serviceName: serviceName,
    );
    await logEvent('begin_checkout', {
      'provider_id': providerId,
      if ((providerName ?? '').trim().isNotEmpty) 'provider_name': providerName!.trim(),
      if ((serviceName ?? '').trim().isNotEmpty) 'service_name': serviceName!.trim(),
      if (serviceItemId != null) 'service_item_id': serviceItemId,
      if (value != null) 'value': value,
      'currency': currency,
      'entry_point': entryPoint ?? bookingEntryPoint,
      'content_group': 'booking',
    });
  }

  // —— Booking creation funnel (pre-payment) ——

  static Future<void> bookingServiceSelected({
    required String providerId,
    required String serviceItemId,
    num? value,
    String? serviceName,
  }) async {
    await logEvent('booking_service_selected', {
      'provider_id': providerId,
      'service_item_id': serviceItemId,
      if ((serviceName ?? '').trim().isNotEmpty) 'service_name': serviceName!.trim(),
      if (value != null) 'value': value,
      'content_group': 'booking',
    });
  }

  static Future<void> bookingSlotSelected({required String providerId, String? slotStart}) async {
    await logEvent('booking_slot_selected', {
      'provider_id': providerId,
      if (slotStart != null) 'slot_start': slotStart,
    });
  }

  static Future<void> bookingAddressSelected({required String providerId, String? area}) async {
    await logEvent('booking_address_selected', {
      'provider_id': providerId,
      if (area != null && area.isNotEmpty) 'area': area,
    });
  }

  static Future<void> bookingNotesAdded({required String providerId}) async {
    await logEvent('booking_notes_added', {'provider_id': providerId});
  }

  static Future<void> checkoutStarted({
    required String bookingId,
    num? value,
    String currency = 'EGP',
  }) async {
    await logEvent('checkout_started', {
      'booking_id': bookingId,
      if (value != null) 'value': value,
      'currency': currency,
    });
  }

  /// Normalize Paymob / UI method keys for GA4 (`card` | `instapay` | `fawry`).
  static String normalizePaymentMethod(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'instapay':
      case 'wallet':
        return 'instapay';
      case 'fawry':
      case 'kiosk':
        return 'fawry';
      case 'card':
      case 'vpc':
        return 'card';
      default:
        final s = (raw ?? '').trim().toLowerCase();
        return s.isEmpty ? 'unknown' : s;
    }
  }

  /// GA4 recommended ecommerce step when the client picks card / InstaPay / Fawry.
  static Future<void> addPaymentInfo({
    required String bookingId,
    required String method,
    num? value,
    String currency = 'EGP',
  }) async {
    final m = normalizePaymentMethod(method);
    await logEvent('add_payment_info', {
      'booking_id': bookingId,
      'payment_type': m,
      'payment_method': m,
      if (value != null) 'value': value,
      'currency': currency,
      'content_group': 'booking',
    });
  }

  static Future<void> bookingCreated({
    required String bookingId,
    required String providerId,
    String? serviceItemId,
    String? serviceName,
    String? providerName,
    String? country,
    String? area,
    String? city,
    num? value,
    String currency = 'EGP',
    bool isGroup = false,
  }) async {
    final bits = <String>['Booking created'];
    if ((serviceName ?? '').trim().isNotEmpty) bits.add(serviceName!.trim());
    if ((providerName ?? '').trim().isNotEmpty) bits.add(providerName!.trim());
    final title = '${bits.join(' · ')} | Oons';
    await logPageView('/bookings', title: title);
    await logEvent('generate_lead', {
      'booking_id': bookingId,
      'provider_id': providerId,
      if ((providerName ?? '').isNotEmpty) 'provider_name': providerName!,
      if (serviceItemId != null) 'service_item_id': serviceItemId,
      if ((serviceName ?? '').isNotEmpty) 'service_name': serviceName!,
      if (country != null) 'country': country,
      if (area != null) 'area': area,
      if (city != null) 'city': city,
      'content_group': 'booking',
      'page_title': title,
    });
    await logEvent('booking_created', {
      'booking_id': bookingId,
      'provider_id': providerId,
      if ((providerName ?? '').isNotEmpty) 'provider_name': providerName!,
      if (serviceItemId != null) 'service_item_id': serviceItemId,
      if ((serviceName ?? '').isNotEmpty) 'service_name': serviceName!,
      if (country != null) 'country': country,
      if (area != null) 'area': area,
      if (city != null) 'city': city,
      if (value != null) 'value': value,
      'currency': currency,
      'is_group_booking': isGroup ? 1 : 0,
      'entry_point': bookingEntryPoint,
      'content_group': 'booking',
      'page_title': title,
    });
    await logEvent('booking_confirmed', {
      'booking_id': bookingId,
      'provider_id': providerId,
      if ((providerName ?? '').isNotEmpty) 'provider_name': providerName!,
      if ((serviceName ?? '').isNotEmpty) 'service_name': serviceName!,
      if (value != null) 'value': value,
      'currency': currency,
      'content_group': 'booking',
    });
  }

  /// GA4 ecommerce purchase + fee split for revenue reporting.
  static Future<void> bookingPaid({
    required String bookingId,
    required String method,
    num? value,
    String currency = 'EGP',
    String? country,
    String? area,
    String? providerId,
    String? categoryId,
    String? categoryName,
    String? vertical,
    num? platformFeeValue,
    num? providerPayoutValue,
    num? pspFeeValue,
    bool isGroup = false,
    bool isRecurring = false,
  }) async {
    if (_purchaseFired.contains(bookingId)) return;
    _purchaseFired.add(bookingId);
    final payType = normalizePaymentMethod(method);
    final items = <Map<String, Object>>[
      {
        'item_id': categoryId ?? vertical ?? 'service',
        'item_name': categoryName ?? vertical ?? 'Service',
        if (vertical != null) 'item_category': vertical,
        if (value != null) 'price': value,
        'quantity': 1,
      },
    ];
    await logEvent('purchase', {
      'transaction_id': bookingId,
      'booking_id': bookingId,
      'payment_type': payType,
      'payment_method': payType,
      if (value != null) 'value': value,
      'currency': currency,
      if (country != null) 'country': country,
      if (area != null) 'area': area,
      if (providerId != null) 'provider_id': providerId,
      if (platformFeeValue != null) 'platform_fee_value': platformFeeValue,
      if (providerPayoutValue != null) 'provider_payout_value': providerPayoutValue,
      if (pspFeeValue != null) 'psp_fee_value': pspFeeValue,
      'is_group_booking': isGroup ? 1 : 0,
      'is_recurring': isRecurring ? 1 : 0,
      'acquisition_channel': acquisitionChannel,
      'items': items,
    });
    await logEvent('booking_paid', {
      'booking_id': bookingId,
      'payment_type': payType,
      'payment_method': payType,
      if (value != null) 'value': value,
      'currency': currency,
      if (country != null) 'country': country,
      if (area != null) 'area': area,
      if (providerId != null) 'provider_id': providerId,
      if (platformFeeValue != null) 'platform_fee_value': platformFeeValue,
      if (providerPayoutValue != null) 'provider_payout_value': providerPayoutValue,
      if (pspFeeValue != null) 'psp_fee_value': pspFeeValue,
      'acquisition_channel': acquisitionChannel,
    });
  }

  static Future<void> bookingCancelled({
    required String bookingId,
    String? reason,
    String role = 'client',
    String? tier,
    num? refundValue,
    String currency = 'EGP',
  }) async {
    await logEvent('booking_cancelled', {
      'booking_id': bookingId,
      'role': role,
      if (reason != null) 'reason': reason,
      if (tier != null) 'cancellation_tier': tier,
      if (refundValue != null) 'refund_value': refundValue,
      'currency': currency,
    });
    if (refundValue != null && refundValue > 0) {
      await bookingRefund(bookingId: bookingId, value: refundValue, currency: currency);
    }
  }

  static Future<void> bookingRefund({
    required String bookingId,
    num? value,
    String currency = 'EGP',
  }) async {
    if (_refundFired.contains(bookingId)) return;
    _refundFired.add(bookingId);
    await logEvent('refund', {
      'transaction_id': bookingId,
      'booking_id': bookingId,
      if (value != null) 'value': value,
      'currency': currency,
    });
  }

  static Future<void> visitCheckout({required String bookingId}) async {
    await logEvent('booking_checkout', {'booking_id': bookingId});
  }

  static Future<void> publicProviderView({required String slug, String? providerName, String? service}) async {
    await setAudience(AnalyticsAudience.anonymous);
    markAcquisition('slug_page');
    final name = (providerName ?? slug).trim();
    final title = 'Public book · $name${service != null && service.isNotEmpty ? ' · $service' : ''} | Oons';
    await logPageView('/p/$slug', title: title);
    await logEvent('view_item', {
      'item_id': slug,
      'item_name': name,
      'item_category': service ?? 'provider',
      'provider_slug': slug,
      if (service != null) 'vertical': service,
      'content_group': 'provider',
      'page_title': title,
    });
    await logEvent('provider_profile_viewed', {
      'provider_slug': slug,
      'provider_name': name,
      if (service != null) 'vertical': service,
      'entry_point': 'slug_page',
      'content_group': 'provider',
      'page_title': title,
    });
  }

  static Future<void> adminView({required String screen, String? entityId}) async {
    await logEvent('admin_view', {
      'admin_screen': screen,
      if (entityId != null) 'entity_id': entityId,
    });
  }

  static Future<void> sos({required String bookingId, required String role}) async {
    await logEvent('sos', {
      'booking_id': bookingId,
      'role': role,
    });
  }

  static Future<void> shareBooking({required String bookingId}) async {
    await logEvent('share', {
      'content_type': 'booking',
      'item_id': bookingId,
      'method': 'in_app',
    });
  }

  static Future<void> shareProviderLink({required String slug}) async {
    await logEvent('share', {
      'content_type': 'provider',
      'item_id': slug,
      'method': 'copy_link',
    });
  }
}
