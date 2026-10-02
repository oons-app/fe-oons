import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/my_plan_screens.dart';

class FakeSession extends StateNotifier<SessionState> implements Session {
  FakeSession({bool pilot = true}) : super(SessionState(subscriptionsPilot: pilot));
  @override
  Future<void> refreshMe() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers by `METHOD path`; a value that is an Exception is thrown, a function is called.
class FakeSubApi implements CustomerSubApi {
  FakeSubApi(this.routes);
  final Map<String, Object?> routes;
  final calls = <String>[];
  final bodies = <String, Object?>{};

  Future<Map<String, dynamic>> _answer(String key, Object? data) async {
    calls.add(key);
    bodies[key] = data;
    final r = routes[key];
    if (r == null) throw ApiException(404, 'Not found.');
    if (r is Exception) throw r;
    if (r is Function) return await Function.apply(r, [data]) as Map<String, dynamic>;
    return Map<String, dynamic>.from(r as Map);
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _answer('GET $path', query);

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => _answer('POST $path', data);
}

Widget host(Widget child, {required FakeSubApi api, bool pilot = true, List<Override> extra = const [], String? at}) {
  Widget stub(String name) => Scaffold(body: Center(child: Text('STUB $name')));
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (c, s) => child),
      GoRoute(path: '/me/plan', builder: (c, s) => const MyPlanScreen()),
      GoRoute(path: '/home', builder: (c, s) => stub('home')),
      GoRoute(path: '/me/pay', builder: (c, s) => stub('pay')),
      GoRoute(path: '/plan/included', builder: (c, s) => stub('included ${s.uri}')),
      GoRoute(path: '/plans/:id/schedule', builder: (c, s) => stub('schedule ${s.uri}')),
      GoRoute(path: '/book/:id', builder: (c, s) => stub('book ${s.uri}')),
      GoRoute(path: '/me/plan/:id/cancel', builder: (c, s) => stub('cancel ${s.uri}')),
      GoRoute(path: '/me/plan/:id/bill', builder: (c, s) => stub('bill ${s.uri}')),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith((ref) => FakeSession(pilot: pilot)),
      customerSubApiProvider.overrideWithValue(api),
      ...extra,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ar'),
      builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
    ),
  );
}

Map<String, dynamic> planRow(String id, {bool recommended = false, int payg = 334500, int price = 290000, int save = 44500, List<Map<String, dynamic>>? lines}) => {
      'plan': {
        'id': id,
        'providerId': 'p1',
        'recommended': recommended,
        'lines': lines ??
            [
              {'visitType': 'deep', 'quantity': 1, 'catalogItemId': 'cd', 'name': {'ar': 'تنظيف مميز'}},
              {'visitType': 'regular', 'quantity': 3, 'catalogItemId': 'cr', 'name': {'ar': 'تنظيف عادي'}},
            ],
      },
      'quote': {'paygPiastres': payg, 'pricePiastres': price, 'feePiastres': 29000, 'totalPiastres': price + 29000, 'savingPiastres': save, 'savingPct': 13},
    };
