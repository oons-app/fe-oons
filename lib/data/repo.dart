import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/geocode.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/reviews.dart';
import 'package:uuid/uuid.dart';

final sessionProvider = StateNotifierProvider<Session, SessionState>((ref) => Session());

class PayLaunch {
  const PayLaunch({
    required this.bundle,
    this.checkoutUrl,
    this.live = false,
    this.poll = false,
    this.iframeId,
    this.method = 'card',
  });

  final BookingBundle bundle;
  final String? checkoutUrl;
  final bool live;
  final bool poll;
  final int? iframeId;
  final String method;
}

class NeedsRegister implements Exception {
  NeedsRegister(this.phone);
  final String phone;
  @override
  String toString() => 'needsRegister';
}

class SessionState {
  const SessionState({
    this.token,
    this.user,
    this.provider,
    this.role = 'client',
    this.online = true,
    this.feeWaived = false,
    this.trustFee = 10000,
  });
  final String? token;
  final UserMe? user;
  final ProviderP? provider;
  final String role;
  final bool online;
  /// Admin-activated platform free trial (0 trust fee + 0 commission).
  final bool feeWaived;
  /// Trust fee in piastres for booking drafts (10000 = 100 EGP when fees apply).
  final int trustFee;
  bool get authed => token != null;
  bool get isProvider => role == 'provider';
}

class Session extends StateNotifier<SessionState> {
  Session() : super(const SessionState()) {
    _restore();
  }

  /// Staff opened the client web app as a provider (web only).
  Future<void> absorbWebImpersonation() async {
    if (!kIsWeb) return;
    final token = Uri.base.queryParameters['impersonate'];
    if (token == null || token.isEmpty) return;
    await api.storage.write(key: 'access', value: token);
    await Hive.box('prefs').put('onboarded', true);
    await Hive.box('prefs').put('role', 'provider');
    try {
      await _applyMe(token, await api.get('/me'));
    } on ApiException catch (e) {
      if (e.status == 401) await signOut();
    } catch (_) {}
  }

  Future<void> _restore() async {
    await absorbWebImpersonation();
    if (state.authed) return;
    final t = await api.storage.read(key: 'access');
    if (t == null) return;
    await Hive.box('prefs').put('onboarded', true);
    state = SessionState(token: t, role: Hive.box('prefs').get('role', defaultValue: 'client') as String);
    try {
      await _applyMe(t, await api.get('/me'));
    } on ApiException catch (e) {
      if (e.status == 401) await signOut();
    } catch (_) {}
  }

  Future<void> _applyMe(String token, Map me) async {
    final role = '${me['role'] ?? 'client'}';
    await Hive.box('prefs').put('role', role);
    state = SessionState(
      token: token,
      role: role,
      user: me['user'] is Map ? UserMe.fromJson({...me['user'] as Map, 'paidBookingCount': me['paidBookingCount']}) : (role == 'provider' ? null : UserMe.fromJson(me)),
      provider: me['provider'] is Map ? ProviderP.fromJson(me['provider'] as Map) : null,
      online: state.online,
      feeWaived: me['feeWaived'] == true,
      trustFee: (me['trustFee'] as num?)?.toInt() ?? (me['feeWaived'] == true ? 0 : 10000),
    );
  }

  Future<bool> requestOtp(String phone, {String role = 'client'}) async {
    final r = await api.post('/auth/otp/request', data: {'phone': phone, 'role': role});
    return r['demo'] == true;
  }

  Future<void> verify(String phone, String code, {String role = 'client'}) async {
    final r = await api.post('/auth/otp/verify', data: {'phone': phone, 'code': code, 'role': role});
    if (r['needsRegister'] == true) {
      throw NeedsRegister(phone);
    }
    final token = r['accessToken'] as String;
    await api.storage.write(key: 'access', value: token);
    await Hive.box('prefs').put('onboarded', true);
    await _applyMe(token, r);
    final resolvedRole = '${r['role'] ?? role}';
    await AppAnalytics.login(role: resolvedRole);
    final uid = state.user?.id ?? state.provider?.id;
    if (uid != null) {
      await AppAnalytics.identify(
        userId: uid,
        audience: resolvedRole == 'provider' ? AnalyticsAudience.provider : AnalyticsAudience.customer,
        area: state.user?.area ?? (state.provider?.areas.isNotEmpty == true ? state.provider!.areas.first : null),
        country: 'EG',
        providerSlug: state.provider?.slug,
      );
    }
  }

  Future<void> registerClient({
    required String phone,
    required String code,
    required String firstName,
    required String lastName,
    bool eligibilityConsent = false,
    bool termsConsent = false,
    bool privacyConsent = false,
    String legalSexMarker = 'female',
  }) async {
    final r = await api.post('/auth/client/register', data: {
      'phone': phone,
      'code': code,
      'firstName': firstName,
      'lastName': lastName,
      'eligibilityConsent': eligibilityConsent,
      'termsConsent': termsConsent,
      'privacyConsent': privacyConsent,
      'legalSexMarker': legalSexMarker,
    });
    final token = r['accessToken'] as String;
    await api.storage.write(key: 'access', value: token);
    await Hive.box('prefs').put('onboarded', true);
    await _applyMe(token, r);
    await AppAnalytics.signUp(role: 'client');
    await AppAnalytics.clientRegistrationCompleted();
    final uid = state.user?.id;
    if (uid != null) {
      await AppAnalytics.identify(userId: uid, audience: AnalyticsAudience.customer, area: state.user?.area, country: 'EG');
    }
  }

  Future<void> registerProvider({
    required String phone,
    required String code,
    required String firstName,
    required String lastName,
    required String service,
    required List<String> areas,
    String? specialty,
    int? years,
    String? legalName,
    String? nationalId,
    String? birthDate,
    String? residenceLine,
    String? payoutHandle,
    Map<String, bool>? consents,
    List<String>? categoryIds,
  }) async {
    final r = await api.post('/auth/provider/register', data: {
      'phone': phone,
      'code': code,
      'firstName': firstName,
      'lastName': lastName,
      'service': service,
      'areas': areas,
      if (specialty != null) 'specialty': specialty,
      if (years != null) 'years': years,
      if (legalName != null) 'legalName': legalName,
      if (nationalId != null) 'nationalId': nationalId,
      if (birthDate != null) 'birthDate': birthDate,
      if (residenceLine != null) 'residenceLine': residenceLine,
      'payoutMethod': 'instapay',
      if (payoutHandle != null) 'payoutHandle': payoutHandle,
      if (consents != null) 'consents': consents,
      if (categoryIds != null && categoryIds.isNotEmpty) 'categoryIds': categoryIds,
    });
    final token = r['accessToken'] as String;
    await api.storage.write(key: 'access', value: token);
    await Hive.box('prefs').put('onboarded', true);
    await _applyMe(token, r);
    await AppAnalytics.signUp(role: 'provider');
    await AppAnalytics.providerRegistrationCompleted(vertical: service);
    final uid = state.provider?.id;
    if (uid != null) {
      await AppAnalytics.identify(
        userId: uid,
        audience: AnalyticsAudience.provider,
        country: 'EG',
        area: areas.isNotEmpty ? areas.first : null,
        providerSlug: state.provider?.slug,
      );
    }
  }

  Future<void> applyProvider(Map r) async {
    if (state.token != null) await _applyMe(state.token!, r);
  }

  Future<void> refreshMe() async {
    if (state.token == null) return;
    try {
      await _applyMe(state.token!, await api.get('/me'));
    } catch (_) {}
  }

  Future<void> signOut() async {
    await api.storage.deleteAll();
    await Hive.box('prefs').delete('role');
    state = SessionState(online: state.online);
    await AppAnalytics.clearIdentity();
  }

  Future<void> patchMe({List<String>? savedIds, String? defaultAddressId, String? locale, String? nationalId}) async {
    final r = await api.patch('/me', data: {
      if (savedIds != null) 'savedIds': savedIds,
      if (defaultAddressId != null) 'defaultAddressId': defaultAddressId,
      if (locale != null) 'locale': locale,
      if (nationalId != null) 'nationalId': nationalId,
    });
    if (state.token != null) await _applyMe(state.token!, r);
  }

  Future<void> syncLocale() async {
    if (state.token == null) return;
    final code = Hive.box('prefs').get('locale', defaultValue: 'ar');
    try {
      await api.patch('/me', data: {'locale': code});
    } catch (_) {}
  }

  Future<void> deleteAccount() async {
    await api.delete('/me');
    await signOut();
  }

  void setUser(UserMe u) => state = SessionState(
        token: state.token,
        user: u,
        provider: state.provider,
        role: state.role,
        online: state.online,
        feeWaived: state.feeWaived,
        trustFee: state.trustFee,
      );

  void setProvider(ProviderP p) => state = SessionState(
        token: state.token,
        user: state.user,
        provider: p,
        role: state.role,
        online: state.online,
        feeWaived: state.feeWaived,
        trustFee: state.trustFee,
      );

  void setOnline(bool v) => state = SessionState(
        token: state.token,
        user: state.user,
        provider: state.provider,
        role: state.role,
        online: v,
        feeWaived: state.feeWaived,
        trustFee: state.trustFee,
      );
}

final repoProvider = Provider((ref) => Repo());

class Repo {
  final box = Hive.box('cache');

  Future<Map<String, dynamic>> home() async {
    try {
      final r = await api.get('/home');
      await box.put('home', jsonEncode(r));
      return r;
    } catch (e) {
      final c = box.get('home');
      if (c is String) return jsonDecode(c) as Map<String, dynamic>;
      rethrow;
    }
  }

  Future<List<ProviderP>> providers({
    required String service,
    String? area,
    int? priceMax,
    String? categoryId,
    String? q,
    String? sort,
    int? minYears,
  }) async {
    try {
      final r = await api.get('/providers', query: {
        if (service.trim().isNotEmpty && service != 'all') 'service': service,
        if (area != null && area.isNotEmpty) 'area': area,
        if (priceMax != null) 'priceMax': priceMax,
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (minYears != null && minYears > 0) 'minYears': minYears,
      });
      await box.put('providers:$service:${categoryId ?? ''}', jsonEncode(r));
      return ((r['providers'] as List?) ?? []).map((e) => ProviderP.fromJson(e as Map)).toList();
    } catch (_) {
      final c = box.get('providers:$service:${categoryId ?? ''}');
      if (c is String) {
        final r = jsonDecode(c) as Map;
        return ((r['providers'] as List?) ?? []).map((e) => ProviderP.fromJson(e as Map)).toList();
      }
      rethrow;
    }
  }

  Future<ProviderP> publicProvider(String slug) async {
    final r = await api.get('/public/p/$slug');
    return ProviderP.fromJson(r['provider'] as Map);
  }

  Future<List<Map<String, dynamic>>> publicAvailability(String slug) async {
    final r = await api.get('/public/p/$slug/availability');
    return (r['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map> legalDoc(String id) async {
    final r = await api.get('/public/legal/$id', query: {'v': '2026-09-06b'});
    return r['document'] as Map;
  }

  Future<List<Map>> legalDocs() async {
    final r = await api.get('/public/legal');
    return (r['documents'] as List).cast<Map>();
  }

  Future<ProviderP> provider(String id) async {
    final r = await api.get('/providers/$id');
    return ProviderP.fromJson(r);
  }

  Future<List<Map<String, dynamic>>> availability(String id) async {
    final r = await api.get('/providers/$id/availability');
    return ((r['days'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<BookingBundle> createBooking({
    required String providerId,
    required String serviceItemId,
    required DateTime slot,
    String? addressId,
    String? notes,
    String? instructionId,
    bool saveInstruction = false,
    List<Map<String, dynamic>>? guests,
    String? couponCode,
  }) async {
    final r = await api.post('/bookings', data: {
      'providerId': providerId,
      'serviceItemId': serviceItemId,
      'slotStart': slot.toUtc().toIso8601String(),
      'addressId': addressId,
      'notes': notes,
      if (instructionId != null && instructionId.isNotEmpty) 'instructionId': instructionId,
      if (saveInstruction && (instructionId == null || instructionId.isEmpty) && (notes ?? '').trim().isNotEmpty) ...{
        'saveInstruction': true,
        'instructionTitle': notes!.trim().split('\n').first,
      },
      if (guests != null && guests.isNotEmpty) 'guests': guests,
      if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim(),
    });
    final bundle = BookingBundle.fromJson(r);
    final addr = bundle.booking.address;
    final svc = bundle.booking.serviceName;
    await AppAnalytics.bookingCreated(
      bookingId: bundle.booking.id,
      providerId: providerId,
      serviceItemId: serviceItemId,
      serviceName: svc.en.isNotEmpty ? svc.en : svc.ar,
      providerName: bundle.provider?.name('en'),
      country: 'EG',
      area: addr?.area,
      city: addr?.area,
      value: bundle.booking.total / 100.0,
      isGroup: bundle.booking.isGroup,
    );
    return bundle;
  }

  /// Live pre-booking check for a coupon code — mirrors the eligibility rules
  /// applied for real at booking time, so the client sees the same verdict
  /// before committing to a slot.
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String providerId,
    required int serviceTotal,
    String? vertical,
    String? area,
    List<String>? categoryIds,
  }) async {
    final r = await api.post('/coupons/validate', data: {
      'code': code,
      'providerId': providerId,
      'serviceTotal': serviceTotal,
      if (vertical != null && vertical.isNotEmpty) 'vertical': vertical,
      if (area != null && area.isNotEmpty) 'area': area,
      if (categoryIds != null && categoryIds.isNotEmpty) 'categoryIds': categoryIds,
    });
    return Map<String, dynamic>.from(r);
  }

  Future<List<Map<String, dynamic>>> categories({
    String? vertical,
    bool includeLocked = true,
    bool activeOnly = false,
    String? area,
    String? parent,
  }) async {
    final areaSlug = (area ?? '').trim().toLowerCase();
    final parentId = (parent ?? '').trim();
    final key = 'categories:${vertical ?? ''}:$includeLocked:$activeOnly:$areaSlug:$parentId';
    try {
      final r = await api.get('/categories', query: {
        if (vertical != null && vertical.isNotEmpty) 'vertical': vertical,
        if (includeLocked && !activeOnly) 'teaser': '1',
        if (activeOnly) 'active': '1',
        if (areaSlug.isNotEmpty) 'area': areaSlug,
        if (parentId.isNotEmpty) 'parent': parentId,
      });
      await box.put(key, jsonEncode(r));
      return ((r['categories'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      final c = box.get(key);
      if (c is String) {
        final r = jsonDecode(c) as Map;
        return ((r['categories'] as List?) ?? []).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> proCategories() async {
    final r = await api.get('/pro/categories');
    return ((r['categories'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> proCatalog() async {
    final r = await api.get('/pro/catalog');
    return Map<String, dynamic>.from(r);
  }

  Future<Map<String, dynamic>> proRequestCatalogName({
    required String categoryId,
    required String suggestedAr,
    String? suggestedEn,
    String? note,
  }) {
    return api.post('/pro/catalog/name-requests', data: {
      'categoryId': categoryId,
      'suggestedAr': suggestedAr,
      'suggestedEn': suggestedEn ?? suggestedAr,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<Map<String, dynamic>> proAddCategory(String categoryId) async {
    return api.post('/pro/categories', data: {'categoryId': categoryId});
  }

  /// Bundles a new-specialty request with its real configured service(s) —
  /// price, duration, cleaning size tiers — so admin reviews the actual
  /// final output in one pass instead of a bare category name followed by
  /// a second, separate per-service approval.
  Future<Map<String, dynamic>> proAddCategoryWithServices(String categoryId, List<Map<String, dynamic>> items) async {
    return api.post('/pro/categories/with-services', data: {'categoryId': categoryId, 'items': items});
  }

  Future<void> proRemoveCategory(String id) async {
    await api.delete('/pro/categories/$id');
  }

  // ---- Services (one at a time) ---------------------------------------
  // patchPro still saves the whole profile in one shot, but it *replaces*
  // the entire items array, so a single unsaveable service anywhere fails
  // the whole request — including the edit she actually made. These touch
  // exactly one service, so adding a haircut can't be blocked by a cleaning
  // bundle still awaiting review under a different specialty.

  Future<Map<String, dynamic>> proCreateService(Map<String, dynamic> item) =>
      api.post('/pro/services', data: item);

  Future<Map<String, dynamic>> proUpdateService(String itemId, Map<String, dynamic> item) =>
      api.patch('/pro/services/$itemId', data: item);

  Future<Map<String, dynamic>> proDeleteService(String itemId) =>
      api.delete('/pro/services/$itemId');

  Future<Map<String, dynamic>> proSetServiceActive(String itemId, bool active) =>
      api.post('/pro/services/$itemId/active', data: {'active': active});

  // ---- Team (workers) -------------------------------------------------

  Future<List<Map<String, dynamic>>> proWorkers() async {
    final r = await api.get('/pro/workers');
    return ((r['workers'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> proCreateWorker(Map<String, dynamic> body) async {
    return api.post('/pro/workers', data: body);
  }

  Future<Map<String, dynamic>> proPatchWorker(String id, Map<String, dynamic> body) async {
    return api.patch('/pro/workers/$id', data: body);
  }

  Future<void> proDeleteWorker(String id) async {
    await api.delete('/pro/workers/$id');
  }

  Future<Map<String, dynamic>> uploadWorkerId(String workerId, List<int> bytes, {String filename = 'id.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/workers/$workerId/id', 'id', bytes, filename: filename, onProgress: onProgress);

  Future<Map<String, dynamic>> uploadWorkerFish(String workerId, List<int> bytes, {String filename = 'fish.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/workers/$workerId/fish', 'fish', bytes, filename: filename, onProgress: onProgress);

  // ---- Coupons (provider-owned) ----------------------------------------

  Future<List<Map<String, dynamic>>> proCoupons() async {
    final r = await api.get('/pro/coupons');
    return ((r['coupons'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> proCreateCoupon(Map<String, dynamic> body) async {
    return api.post('/pro/coupons', data: body);
  }

  Future<Map<String, dynamic>> proPatchCoupon(String id, Map<String, dynamic> body) async {
    return api.patch('/pro/coupons/$id', data: body);
  }

  Future<Map<String, dynamic>> assignWorkers(String bookingId, List<String> workerIds) async {
    return api.post('/bookings/$bookingId/assign-workers', data: {'workerIds': workerIds});
  }

  Future<Map<String, dynamic>> earningsSummary() async => api.get('/pro/earnings/summary');

  Future<Map<String, dynamic>> earningsBreakdown() async => api.get('/pro/earnings/breakdown', query: {'by': 'category'});

  Future<Map<String, dynamic>> earningsHistory({int skip = 0}) async =>
      api.get('/pro/earnings/history', query: {'skip': '$skip'});

  Future<Map<String, dynamic>> setSettlementCadence(String cadence) async =>
      api.patch('/pro/earnings/cadence', data: {'cadence': cadence});

  Future<List<Map<String, dynamic>>> settlements({String? status}) async {
    final r = await api.get('/pro/settlements', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return ((r['settlements'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> settlement(String id) async => api.get('/pro/settlements/$id');

  Future<UserMe> createAddress({
    required String label,
    required String line1,
    required String area,
    String? city,
    String? reachNotes,
    bool isDefault = false,
    double? lat,
    double? lng,
  }) async {
    final fallback = coordsForArea(area);
    final r = await api.post('/me/addresses', data: {
      'label': label,
      'line1': line1,
      if (reachNotes != null && reachNotes.trim().isNotEmpty) 'reachNotes': reachNotes.trim(),
      'area': area,
      'city': city ?? areaName(area, 'en'),
      'lat': lat ?? fallback.$1,
      'lng': lng ?? fallback.$2,
      'isDefault': isDefault,
    });
    return UserMe.fromJson(r['user'] as Map);
  }

  Future<UserMe> patchAddress(String id, Map<String, dynamic> data) async {
    final r = await api.patch('/me/addresses/$id', data: data);
    return UserMe.fromJson(r['user'] as Map);
  }

  Future<UserMe> deleteAddress(String id) async {
    final r = await api.delete('/me/addresses/$id');
    return UserMe.fromJson(r['user'] as Map);
  }

  Future<List<GeoHit>> searchPlaces(String q) async {
    final r = await api.get('/geo/search', query: {'q': q});
    return ((r['places'] as List?) ?? []).map((e) => GeoHit.fromJson(e as Map)).toList();
  }

  Future<GeoHit?> reverseGeocode(double lat, double lng) async {
    final r = await api.get('/geo/reverse', query: {'lat': lat, 'lng': lng});
    if (r.isEmpty) return null;
    return GeoHit.fromJson(r);
  }

  Future<List<Instruction>> instructions() async {
    final r = await api.get('/me/instructions');
    return ((r['instructions'] as List?) ?? []).map((e) => Instruction.fromJson(e as Map)).toList();
  }

  Future<UserMe> _userFrom(Map r) async {
    Map<String, dynamic> raw;
    if (r['user'] is Map) {
      raw = Map<String, dynamic>.from(r['user'] as Map);
    } else {
      final me = await api.get('/me');
      raw = Map<String, dynamic>.from(me['user'] as Map);
      raw['paidBookingCount'] = me['paidBookingCount'];
    }
    if (r.containsKey('paidBookingCount')) raw['paidBookingCount'] = r['paidBookingCount'];
    return UserMe.fromJson(raw);
  }

  Future<UserMe> createInstruction({required String title, required String body}) async {
    final r = await api.post('/me/instructions', data: {'title': title.trim(), 'body': body.trim()});
    return _userFrom(r);
  }

  Future<UserMe> patchInstruction(String id, {String? title, String? body}) async {
    final r = await api.patch('/me/instructions/$id', data: {
      if (title != null) 'title': title.trim(),
      if (body != null) 'body': body.trim(),
    });
    return _userFrom(r);
  }

  Future<UserMe> deleteInstruction(String id) async {
    final r = await api.delete('/me/instructions/$id');
    return _userFrom(r);
  }

  Future<Map<String, dynamic>> patchPro(Map<String, dynamic> data) => api.patch('/pro/me', data: data);

  Future<Map<String, dynamic>> addProDomain(String host) =>
      api.post('/pro/me/domains', data: {'host': host});

  Future<Map<String, dynamic>> verifyProDomain(String host) =>
      api.post('/pro/me/domains/${Uri.encodeComponent(host)}/verify');

  Future<Map<String, dynamic>> deleteProDomain(String host) =>
      api.delete('/pro/me/domains/${Uri.encodeComponent(host)}');

  Future<Map<String, dynamic>> uploadProPhoto(List<int> bytes, {String filename = 'photo.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/photo', 'photo', bytes, filename: filename, onProgress: onProgress);

  Future<Map<String, dynamic>> uploadProID(List<int> bytes, {String filename = 'id.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/id', 'id', bytes, filename: filename, onProgress: onProgress);

  Future<UserMe> uploadClientPhoto(List<int> bytes) async {
    final r = await api.upload('/me/photo', 'photo', bytes);
    return _userFrom(r);
  }

  Future<UserMe> uploadClientID(List<int> bytes) async {
    final r = await api.upload('/me/id', 'id', bytes);
    return _userFrom(r);
  }

  Future<Map<String, dynamic>> uploadProFish(List<int> bytes, {String filename = 'fish.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/fish', 'fish', bytes, filename: filename, onProgress: onProgress);

  Future<Map<String, dynamic>> uploadProPortfolio(List<int> bytes, {String filename = 'photo.jpg', void Function(double)? onProgress}) =>
      api.upload('/pro/portfolio', 'file', bytes, filename: filename, onProgress: onProgress);

  Future<Map<String, dynamic>> deleteProPortfolio(int i) => api.delete('/pro/portfolio/$i');

  Future<BookingBundle> pingLocation(String id, double lat, double lng) async {
    final r = await api.post('/pro/bookings/$id/location', data: {'lat': lat, 'lng': lng});
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> booking(String id) async {
    final r = await api.get('/bookings/$id');
    await box.put('booking:$id', jsonEncode(r));
    return BookingBundle.fromJson(r);
  }

  Future<List<BookingBundle>> bookings(String scope, {int skip = 0, int limit = 50}) async {
    try {
      final r = await api.get('/bookings', query: {
        'scope': scope,
        if (scope == 'past') ...{'skip': '$skip', 'limit': '$limit'},
      });
      await box.put('bookings:$scope', jsonEncode(r));
      return ((r['bookings'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
    } catch (_) {
      final c = box.get('bookings:$scope');
      if (c is String) {
        final r = jsonDecode(c) as Map;
        return ((r['bookings'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
      }
      rethrow;
    }
  }

  Future<PayLaunch> pay(String id, String method) async {
    final r = await api.post('/bookings/$id/pay', data: {'method': method}, idem: const Uuid().v4());
    final checkout = '${r['checkoutUrl'] ?? ''}'.trim();
    final bundle = BookingBundle.fromJson(r);
    if (bundle.booking.status == 'paid') {
      await ensurePurchaseTracked(bundle, method);
    }
    return PayLaunch(
      bundle: bundle,
      checkoutUrl: checkout.isEmpty ? null : checkout,
      live: r['live'] == true,
      poll: r['poll'] == true,
      iframeId: r['iframeId'] is num ? (r['iframeId'] as num).toInt() : int.tryParse('${r['iframeId'] ?? ''}'),
      method: '${r['paymentMethod'] ?? method}',
    );
  }

  Future<void> _trackPurchase(BookingBundle bundle, String method) async {
    final b = bundle.booking;
    num trust = b.trustFeeAmount / 100.0;
    if (trust == 0) {
      for (final li in b.lineItems) {
        if (li.key == 'trust_fee' || li.key == 'amana') trust = li.amount / 100.0;
      }
    }
    num payout = b.serviceEarning / 100.0;
    final vertical = bundle.provider?.service;
    await AppAnalytics.bookingPaid(
      bookingId: b.id,
      method: AppAnalytics.normalizePaymentMethod(method),
      value: b.total / 100.0,
      country: 'EG',
      area: b.address?.area,
      providerId: bundle.provider?.id,
      categoryName: b.serviceName.en.isNotEmpty ? b.serviceName.en : null,
      vertical: vertical,
      platformFeeValue: trust,
      providerPayoutValue: payout,
      pspFeeValue: 0,
      isGroup: b.isGroup,
    );
  }

  Future<BookingBundle> checkPay(String id) async {
    final r = await api.post('/bookings/$id/pay/check');
    final bundle = BookingBundle.fromJson(r);
    await ensurePurchaseTracked(bundle);
    return bundle;
  }

  /// Client closed the Paymob window / left payment without finishing.
  Future<BookingBundle> abandonPay(String id, String method) async {
    final r = await api.post('/bookings/$id/pay/abandon', data: {'method': method});
    return BookingBundle.fromJson(r);
  }

  /// Fires GA `purchase` / `booking_paid` once per booking with the real Paymob method.
  Future<void> ensurePurchaseTracked(BookingBundle bundle, [String? methodHint]) async {
    if (bundle.booking.status != 'paid') return;
    final fromBooking = bundle.booking.paymentMethod;
    final method = AppAnalytics.normalizePaymentMethod(
      (fromBooking != null && fromBooking.trim().isNotEmpty) ? fromBooking : methodHint,
    );
    await _trackPurchase(bundle, method);
  }

  Future<BookingBundle> cancel(String id, String refundTo) async {
    final r = await api.post('/bookings/$id/cancel', data: {'refundTo': refundTo});
    final bundle = BookingBundle.fromJson(r);
    final refund = bundle.booking.refundAmount;
    await AppAnalytics.bookingCancelled(
      bookingId: id,
      reason: refundTo,
      role: 'client',
      tier: refund != null && refund > 0 && refund < bundle.booking.total ? 'partial' : (refund != null && refund > 0 ? 'full' : 'none'),
      refundValue: refund != null ? refund / 100.0 : null,
    );
    return bundle;
  }

  Future<BookingBundle> startVisit(String id) async {
    final r = await api.post('/bookings/$id/start-visit');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> checkIn(String id) async {
    final r = await api.post('/bookings/$id/check-in');
    return BookingBundle.fromJson(r);
  }

  Future<Map<String, dynamic>> handshakeQr(String id, {required double lat, required double lng}) async {
    return api.get('/bookings/$id/handshake', query: {'lat': lat, 'lng': lng});
  }

  Future<BookingBundle> proHandshake(String id, String token, {required double lat, required double lng}) async {
    final r = await api.post('/pro/bookings/$id/handshake', data: {'token': token, 'lat': lat, 'lng': lng});
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> checkout(String id) async {
    final r = await api.post('/bookings/$id/checkout');
    await AppAnalytics.visitCheckout(bookingId: id);
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> releasePayment(String id) async {
    final r = await api.post('/bookings/$id/release');
    return BookingBundle.fromJson(r);
  }

  Future<String> uploadReviewPhoto(String bookingId, List<int> bytes, {bool provider = false}) async {
    final path = provider ? '/pro/bookings/$bookingId/review-photo' : '/bookings/$bookingId/review-photo';
    final r = await api.upload(path, 'photo', bytes);
    return '${r['url'] ?? ''}';
  }

  Future<BookingBundle> rate(
    String id,
    int stars,
    List<String> tags, {
    List<String> images = const [],
    bool release = false,
    String? body,
  }) async {
    final r = await api.post('/bookings/$id/rate', data: {
      'stars': stars,
      'tags': tags,
      if (images.isNotEmpty) 'images': images,
      if (release) 'release': true,
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
    });
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proRate(
    String id,
    int stars,
    List<String> tags, {
    List<String> images = const [],
    String? body,
  }) async {
    final r = await api.post('/pro/bookings/$id/rate', data: {
      'stars': stars,
      'tags': tags,
      if (images.isNotEmpty) 'images': images,
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
    });
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> sos(String id, {double? lat, double? lng}) async {
    final r = await api.post('/bookings/$id/sos', data: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    unawaited(AppAnalytics.sos(bookingId: id, role: 'client'));
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proSos(String id, {double? lat, double? lng}) async {
    final r = await api.post('/pro/bookings/$id/sos', data: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    unawaited(AppAnalytics.sos(bookingId: id, role: 'provider'));
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proArriveProof(String id, List<int> bytes, double lat, double lng) async {
    final r = await api.uploadForm('/pro/bookings/$id/arrive-proof', {
      'photo': MultipartFile.fromBytes(bytes, filename: 'door.jpg'),
      'lat': lat.toString(),
      'lng': lng.toString(),
    });
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> share(String id, List<String> ids) async {
    final r = await api.post('/bookings/$id/share', data: {'contactIds': ids});
    unawaited(AppAnalytics.shareBooking(bookingId: id));
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> acceptReplacement(String id) async {
    final r = await api.post('/bookings/$id/accept-replacement');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> declineReplacement(String id) async {
    final r = await api.post('/bookings/$id/decline-replacement');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> reschedule(String id, DateTime slot) async {
    final r = await api.post('/bookings/$id/reschedule', data: {'slotStart': slot.toUtc().toIso8601String()});
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> dispute(String id, {String? reason}) async {
    final r = await api.post('/bookings/$id/dispute', data: {if (reason != null) 'reason': reason});
    return BookingBundle.fromJson(r);
  }

  Future<List<Review>> reviews({String? providerId}) async {
    try {
      final path = providerId == null || providerId.isEmpty ? '/reviews' : '/providers/$providerId/reviews';
      final r = await api.get(path);
      final list = ((r['reviews'] as List?) ?? []).map((e) => Review.fromJson(e as Map)).toList();
      await box.put(providerId == null ? 'reviews' : 'reviews:$providerId', jsonEncode(r));
      return list;
    } catch (_) {
      final key = providerId == null ? 'reviews' : 'reviews:$providerId';
      final c = box.get(key);
      if (c is String) {
        final r = jsonDecode(c) as Map;
        return ((r['reviews'] as List?) ?? []).map((e) => Review.fromJson(e as Map)).toList();
      }
      return const [];
    }
  }

  Future<({List<BookingBundle> upcoming, List<BookingBundle> past})> proJobs({int skip = 0, int limit = 50}) async {
    try {
      final r = await api.get('/pro/jobs', query: {'skip': '$skip', 'limit': '$limit'});
      final up = ((r['upcoming'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
      final past = ((r['past'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
      await box.put('pro:jobs', jsonEncode(r));
      return (upcoming: up, past: past);
    } catch (_) {
      final c = box.get('pro:jobs');
      if (c is String) {
        final r = jsonDecode(c) as Map;
        final up = ((r['upcoming'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
        final past = ((r['past'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
        return (upcoming: up, past: past);
      }
      rethrow;
    }
  }

  Future<List<BookingBundle>> proBookings(String scope, {int skip = 0, int limit = 50}) async {
    if (scope == 'all') {
      final jobs = await proJobs(skip: skip, limit: limit);
      return [...jobs.upcoming, ...jobs.past];
    }
    final r = await api.get('/pro/bookings', query: {
      'scope': scope,
      if (scope == 'past') ...{'skip': '$skip', 'limit': '$limit'},
    });
    return ((r['bookings'] as List?) ?? []).map((e) => BookingBundle.fromJson(e as Map)).toList();
  }

  Future<({ProviderP provider, List<Map<String, dynamic>> days})> bookBootstrap(String id) async {
    final r = await api.get('/providers/$id/book-bootstrap');
    final prov = ProviderP.fromJson(r['provider'] as Map);
    final days = ((r['days'] as List?) ?? []).cast<Map<String, dynamic>>();
    return (provider: prov, days: days);
  }

  Future<BookingBundle> proBooking(String id) async {
    final r = await api.get('/pro/bookings/$id');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proAccept(String id) async {
    final r = await api.post('/pro/bookings/$id/accept');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proDepart(String id) async {
    final r = await api.post('/pro/bookings/$id/depart');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proCheckIn(String id) async {
    final r = await api.post('/pro/bookings/$id/check-in');
    return BookingBundle.fromJson(r);
  }

  Future<BookingBundle> proCancel(String id, {String? reason}) async {
    final r = await api.post('/pro/bookings/$id/cancel', data: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    final bundle = BookingBundle.fromJson(r);
    await AppAnalytics.bookingCancelled(
      bookingId: id,
      role: 'provider',
      tier: 'provider',
      refundValue: bundle.booking.refundAmount != null ? bundle.booking.refundAmount! / 100.0 : null,
    );
    return bundle;
  }

  Future<Map<String, dynamic>> earnings() async {
    return api.get('/pro/earnings');
  }

  Future<Map<String, dynamic>> withdraw({required int amount, required String method}) async {
    return api.post('/pro/withdraw', data: {'amount': amount, 'method': method});
  }

  Future<List<Map<String, dynamic>>> contacts() async {
    final r = await api.get('/contacts');
    return ((r['contacts'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}
