import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';

Future<void> initHive() async {
  final dir = await Directory.systemTemp.createTemp('oons_prov_hive');
  Hive.init(dir.path);
  await Hive.openBox('prefs');
  await Hive.openBox('cache');
}

Map<String, dynamic> svcJson(String id, String name,
        {String cat = 'c-reg', int priceEgp = 1200, bool active = true, String kind = 'standard', int from = 0, int? to, int workers = 1, int duration = 360, List<String> benefits = const []}) =>
    {
      'id': id,
      'name': {'ar': name, 'en': name},
      'durationMin': duration,
      'price': priceEgp * 100,
      'categoryId': cat,
      'kind': kind,
      'active': active,
      'sizeFromSqm': from,
      if (to != null) 'sizeToSqm': to,
      'workerCount': workers,
      'benefits': [for (final b in benefits) {'ar': b, 'en': b}],
    };

Map<String, dynamic> catRow(String id, String ar, String vertical, String status) => {
      'categoryId': id,
      'name': {'ar': ar, 'en': ar},
      'vertical': vertical,
      'status': status,
      'slug': id,
    };

/// A signed-in provider whose profile the tests can read back.
class FakeProSession extends StateNotifier<SessionState> implements Session {
  FakeProSession(Map<String, dynamic> json) : super(SessionState(token: 't', role: 'provider', provider: ProviderP.fromJson(json), subscriptionsPilot: true));
  @override
  void setProvider(ProviderP p) => state = SessionState(token: 't', role: 'provider', provider: p, subscriptionsPilot: true);
  @override
  Future<void> refreshMe() async {}
  int signOuts = 0, deletes = 0;
  @override
  Future<void> signOut() async => signOuts++;
  @override
  Future<void> deleteAccount() async => deletes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> providerJson({
  List<Map<String, dynamic>> items = const [],
  List<String> areas = const ['madinaty', 'rehab'],
  List<int> workDays = const [1, 2, 3, 4, 6, 7],
  List<String> slotHours = const [],
  bool paused = false,
  bool linkClosed = false,
  List<Map<String, dynamic>> domains = const [],
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': 'p1',
      'firstName': {'ar': 'ندى', 'en': 'Nada'},
      'lastName': {'ar': 'أحمد', 'en': 'Ahmed'},
      'initials': {'ar': 'ن أ', 'en': 'N A'},
      'service': 'cleaning',
      'specialty': {'ar': 'تنظيف', 'en': 'Cleaning'},
      'areas': areas,
      'years': 3,
      'rating': 4.9,
      'reviewCount': 12,
      'priceFrom': 120000,
      'items': items,
      'workDays': workDays,
      'slotHours': slotHours,
      'vettedAt': '2026-01-01T00:00:00Z',
      'bookingsPaused': paused,
      'linkClosed': linkClosed,
      'slug': 'nada',
      'customDomains': domains,
      ...extra,
    };

/// Scripted repo: records every call, applies changes to [profile] and answers
/// with the whole provider like the real API. `failNext` makes the next
/// mutating call throw.
class FakeProRepo extends Repo {
  FakeProRepo({required this.profile, this.categoryRows = const [], this.catalog = const {'commissionRate': 0.10}});
  Map<String, dynamic> profile;
  List<Map<String, dynamic>> categoryRows;
  Map<String, dynamic> catalog;
  final calls = <String>[];
  final bodies = <String, Object?>{};
  Object? failNext;
  List<BookingBundle> upcomingJobs = [];
  List<BookingBundle> pastJobs = [];
  bool jobsFail = false;
  Map<String, dynamic> earningsData = {};
  bool earningsFail = false;

  @override
  Future<Map<String, dynamic>> earningsSummary() async {
    calls.add('earnings');
    if (earningsFail) throw apiError('offline', 0);
    return earningsData;
  }

  @override
  Future<Map<String, dynamic>> setSettlementCadence(String cadence) async {
    calls.add('cadence $cadence');
    _maybeFail();
    earningsData = {...earningsData, 'pendingCadence': cadence == earningsData['cadence'] ? null : cadence};
    return {'ok': true};
  }

  @override
  Future<({List<BookingBundle> upcoming, List<BookingBundle> past})> proJobs({int skip = 0, int limit = 50}) async {
    calls.add('jobs');
    if (jobsFail) throw apiError('offline', 0);
    return (upcoming: upcomingJobs, past: pastJobs);
  }

  Map<String, dynamic> _answer() => {'provider': profile};

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  List<Map<String, dynamic>> get _items => (profile['items'] as List).cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> proCategories() async => categoryRows;
  @override
  Future<Map<String, dynamic>> proCatalog() async => catalog;
  @override
  Future<List<Map<String, dynamic>>> categories({String? vertical, bool includeLocked = true, bool activeOnly = false, String? area, String? parent}) async => const [];

  @override
  Future<Map<String, dynamic>> proSetServiceActive(String itemId, bool active) async {
    calls.add('active $itemId $active');
    _maybeFail();
    _items.firstWhere((i) => '${i['id']}' == itemId)['active'] = active;
    return _answer();
  }

  @override
  Future<Map<String, dynamic>> proUpdateService(String itemId, Map<String, dynamic> item) async {
    calls.add('update $itemId');
    bodies['update $itemId'] = item;
    _maybeFail();
    final it = _items.firstWhere((i) => '${i['id']}' == itemId);
    it['price'] = item['price'];
    if (item.containsKey('sizeFromSqm')) it['sizeFromSqm'] = item['sizeFromSqm'];
    if (item.containsKey('sizeToSqm')) it['sizeToSqm'] = item['sizeToSqm'];
    if (item.containsKey('workerCount')) it['workerCount'] = item['workerCount'];
    return {'item': it, 'provider': profile};
  }

  @override
  Future<Map<String, dynamic>> proCreateService(Map<String, dynamic> item) async {
    calls.add('create');
    bodies['create'] = item;
    _maybeFail();
    final created = {...item, 'id': 900 + _items.length, 'durationMin': item['durationMin'], 'approvalState': 'pending'};
    _items.add(created);
    return {'item': created, 'provider': profile};
  }

  @override
  Future<Map<String, dynamic>> proDeleteService(String itemId) async {
    calls.add('delete $itemId');
    _maybeFail();
    _items.removeWhere((i) => '${i['id']}' == itemId);
    return _answer();
  }

  @override
  Future<Map<String, dynamic>> addProDomain(String host) async {
    calls.add('domain $host');
    _maybeFail();
    profile['customDomains'] = [...(profile['customDomains'] as List), {'host': host, 'status': 'pending', 'verifyToken': 'tok123', 'tlsStatus': ''}];
    return {'provider': profile, 'dnsHint': 'CNAME book → oons.app'};
  }

  @override
  Future<Map<String, dynamic>> patchPro(Map<String, dynamic> data) async {
    calls.add('patch ${data.keys.join(',')}');
    bodies['patch'] = data;
    _maybeFail();
    data.forEach((k, v) {
      if (k == 'available') {
        profile['bookingsPaused'] = v == false;
      } else if (k == 'linkOpen') {
        profile['linkClosed'] = v == false;
      } else {
        profile[k] = v;
      }
    });
    return _answer();
  }
}

/// Hosts [child] in a router (so `context.push` works) with Arabic + the fakes.
Widget proHost(Widget child, {required FakeProRepo repo, List<GoRoute> routes = const [], List<Override> extra = const []}) {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (c, s) => child),
      ...routes,
    ],
  );
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith((ref) => FakeProSession(repo.profile)),
      repoProvider.overrideWithValue(repo),
      ...extra,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

void phone(WidgetTester t, {double height = 1800}) {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

ApiException apiError(String msg, [int status = 409]) => ApiException(status, msg);


/// One job as GET /pro/jobs returns it. [slot] is local (no zone), earning in piastres.
BookingBundle jobBundle(String id, String slot, {String client = 'منى', String area = 'madinaty', String service = 'تنظيف مميز', int minutes = 360, int earning = 120000, String status = 'paid', String? planTag, String? subscriptionVisitId}) {
  return BookingBundle.fromJson({
    'booking': {
      'id': id,
      'ref': 'OO-$id',
      'status': status,
      'slotStart': slot,
      'total': earning,
      'escrow': 'held',
      'serviceName': {'ar': service, 'en': service},
      'lineItems': [],
      'timeline': [],
      'durationMin': minutes,
      'pricingEra': 'v2',
      'clientServiceFeeAmount': 0,
      'introFeeAmount': 0,
      if (subscriptionVisitId != null) 'subscriptionVisitId': subscriptionVisitId,
    },
    'client': {'firstName': {'ar': client, 'en': client}, 'area': area},
    if (planTag != null) 'planTag': planTag,
    'cancelPreview': {},
  });
}
