import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/reviews.dart';
import 'package:oons/features/browse/browse_screens.dart';
import 'package:oons/features/subscribe/customer_copy.dart';

import 'subscription_customer_fakes.dart';

class _FakeRepo implements Repo {
  _FakeRepo(this.providers_);
  final List<Map<String, dynamic>> providers_;
  @override
  Future<List<ProviderP>> providers({required String service, String? area, int? priceMax, String? categoryId, String? q, String? sort, int? minYears}) async =>
      [for (final p in providers_) ProviderP.fromJson(p)];
  @override
  Future<List<Map<String, dynamic>>> categories({String? vertical, bool includeLocked = true, bool activeOnly = false, String? area, String? parent}) async => [];
  @override
  Future<ProviderP> provider(String id) async => ProviderP.fromJson(providers_.firstWhere((p) => p['id'] == id));
  @override
  Future<List<Review>> reviews({String? providerId}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _prov(String id, String first, {bool plans = false}) => {
      'id': id,
      'firstName': {'en': first, 'ar': first},
      'lastName': {'en': 'س', 'ar': 'س'},
      'initials': {'en': 'N', 'ar': 'ن'},
      'service': 'cleaning',
      'specialty': {'en': 'cleaning', 'ar': 'تنظيف'},
      'areas': ['madinaty'],
      'years': 3,
      'rating': 4.5,
      'reviewCount': 2,
      'priceFrom': 71500,
      'items': <Map>[],
      if (plans) 'planBadge': {'count': 3, 'fromPiastres': 240000, 'savePct': 16},
    };

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 150));
  await t.pump(const Duration(milliseconds: 150));
}

Widget _app(Widget child, {bool pilot = true, List<Map<String, dynamic>>? providers}) => host(
      child,
      api: FakeSubApi({}),
      pilot: pilot,
      extra: [repoProvider.overrideWithValue(_FakeRepo(providers ?? [_prov('a', 'ندى', plans: true), _prov('b', 'منى')]))],
    );

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('oons_sub_hive');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await Hive.openBox('cache');
  });

  group('E1 listing', () {
    testWidgets('filter row: Arabic count with suffix, check mark when on, filters list, result count', (t) async {
      _phone(t);
      await t.pumpWidget(_app(const BrowseScreen(service: 'cleaning')));
      await _settle(t);
      expect(find.text('١ متخصصة'), findsOneWidget);
      expect(find.text(CC.e1PlanFilter), findsOneWidget);
      expect(find.text('٢ متخصصة متاحة'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-check')), findsNothing);
      expect(find.text('ندى س'), findsOneWidget);
      expect(find.text('منى س'), findsOneWidget);
      await t.tap(find.text(CC.e1PlanFilter));
      await _settle(t);
      expect(find.text('منى س'), findsNothing);
      expect(find.text('ندى س'), findsOneWidget);
      expect(find.text('١ متخصصة متاحة'), findsOneWidget);
    });

    testWidgets('plan box only for providers with plans; text and no box otherwise', (t) async {
      _phone(t);
      await t.pumpWidget(_app(const BrowseScreen(service: 'cleaning')));
      await _settle(t);
      expect(find.text('باقة شهرية · ٣ باقات'), findsOneWidget);
      expect(find.text('من ٢,٤٠٠ ج.م/شهر · وفّري لحد ١٦٪'), findsOneWidget);
    });

    testWidgets('flag off: no plan box, no filter, original count format', (t) async {
      _phone(t);
      await t.pumpWidget(_app(const BrowseScreen(service: 'cleaning'), pilot: false));
      await _settle(t);
      expect(find.text(CC.e1PlanFilter), findsNothing);
      expect(find.textContaining('باقة شهرية'), findsNothing);
    });
  });

  group('S1 provider profile', () {
    testWidgets('plan info block + two actions', (t) async {
      _phone(t);
      final api = FakeSubApi({
        'GET /providers/a/plans': {
          'enabled': true,
          'plans': [planRow('p1', save: 44500), planRow('p2', save: 61000), planRow('p3', save: 10000)],
        },
      });
      await t.pumpWidget(host(
        const ProviderScreen(id: 'a'),
        api: api,
        extra: [repoProvider.overrideWithValue(_FakeRepo([_prov('a', 'ندى', plans: true)]))],
      ));
      await _settle(t);
      expect(find.text('عندها ٣ باقات شهرية'), findsOneWidget);
      expect(find.text('نفس المتخصصة كل مرة، وتوفّري لحد ٦١٠ ج.م في الشهر عن الحجز زيارة زيارة.'), findsOneWidget);
      expect(find.text('وفّري لحد ١٦٪ لما تحجزي بانتظام'), findsOneWidget);
      expect(find.text(CC.s1Subscribe), findsOneWidget);
      expect(find.text(CC.s1Once), findsOneWidget);
      final subBtn = t.getSize(find.ancestor(of: find.text(CC.s1Subscribe), matching: find.byType(Container)).first);
      final onceBtn = t.getSize(find.ancestor(of: find.text(CC.s1Once), matching: find.byType(Container)).first);
      expect(subBtn.height, 54);
      expect(onceBtn.height, 54);
      expect(subBtn.width / onceBtn.width, closeTo(1.7, 0.05));
    });

    testWidgets('provider without plans shows the normal sticky bar', (t) async {
      _phone(t);
      await t.pumpWidget(host(
        const ProviderScreen(id: 'b'),
        api: FakeSubApi({}),
        extra: [repoProvider.overrideWithValue(_FakeRepo([_prov('b', 'منى')]))],
      ));
      await _settle(t);
      expect(find.text(CC.s1Subscribe), findsNothing);
      expect(find.textContaining('باقات شهرية'), findsNothing);
    });
  });
}
