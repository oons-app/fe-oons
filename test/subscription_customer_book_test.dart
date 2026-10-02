import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/book/book_pricing.dart';
import 'package:oons/features/book/book_screens.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/plan_card.dart';

import 'subscription_customer_fakes.dart';

Map<String, dynamic> _item(String id, String name, {String vertical = 'cleaning', String kind = 'cleaning', int price = 71500}) => {
      'id': id,
      'name': {'en': name, 'ar': name},
      'durationMin': 300,
      'price': price,
      'kind': kind,
      'vertical': vertical,
      'active': true,
      'sizeFromSqm': 0,
    };

class _BookRepo implements Repo {
  _BookRepo({this.withBeauty = true});
  final bool withBeauty;
  @override
  Future<({ProviderP provider, List<Map<String, dynamic>> days, ProcessingFeeSchedule fees})> bookBootstrap(String id, {int? durationMin, String? weekStart}) async {
    final p = ProviderP.fromJson({
      'id': id,
      'firstName': {'en': 'ندى', 'ar': 'ندى'},
      'lastName': {'en': 'س', 'ar': 'س'},
      'initials': {'en': 'ن', 'ar': 'ن'},
      'service': 'cleaning',
      'specialty': {'en': 'x', 'ar': 'x'},
      'areas': ['madinaty'],
      'items': [
        _item('cd', 'تنظيف مميز', price: 120000),
        _item('cr', 'تنظيف عادي'),
        if (withBeauty) _item('bt', 'مكياج', vertical: 'beauty', kind: 'standard', price: 50000),
      ],
    });
    return (provider: p, days: <Map<String, dynamic>>[], fees: const ProcessingFeeSchedule());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Widget _app({String? mode, bool withBeauty = true, bool pilot = true, bool plans = true}) => host(
      BookScreen(providerId: 'p1', initialMode: mode),
      pilot: pilot,
      api: FakeSubApi({
        'GET /providers/p1/plans': {
          'enabled': plans,
          'plans': plans
              ? [
                  planRow('a', payg: 286000, price: 240000, save: 46000, lines: [
                    {'visitType': 'regular', 'quantity': 4, 'catalogItemId': 'cr', 'name': {'ar': 'تنظيف عادي'}}
                  ]),
                  planRow('b', recommended: true),
                ]
              : [],
        },
      }),
      extra: [repoProvider.overrideWithValue(_BookRepo(withBeauty: withBeauty))],
    );

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('oons_book_hive');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await Hive.openBox('cache');
  });

  testWidgets('once mode by default: dashed nudge with the max saving, flips to monthly', (t) async {
    _phone(t);
    await t.pumpWidget(_app());
    await _settle(t);
    expect(find.text(CC.e2Nudge('٤٦٠')), findsOneWidget);
    expect(find.byType(PlanCard), findsNothing);
    await t.tap(find.text(CC.e2Nudge('٤٦٠')));
    await _settle(t);
    expect(find.byType(PlanCard), findsNWidgets(2));
  });

  testWidgets('mode switch shows cards; bar, steps, total and CTA are monthly', (t) async {
    _phone(t);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.tap(find.text(CC.e2Monthly));
    await _settle(t);
    expect(find.text(CC.e2Intro), findsOneWidget);
    expect(find.text('٤ تنظيف عادي في الشهر'), findsOneWidget);
    expect(find.text('١ تنظيف مميز + ٣ عادي في الشهر'), findsOneWidget);
    expect(find.text(CC.recommended), findsOneWidget);
    // recommended plan b is pre-selected: price 2,900 + fee 290 = 3,190
    expect(find.text(CC.e2BarMonthly), findsOneWidget);
    expect(find.text('١ تنظيف مميز + ٣ عادي في الشهر · شامل ١٠٪ رسوم'), findsOneWidget);
    expect(find.text('٣,١٩٠ ج.م'), findsOneWidget);
    expect(find.text(CC.e2CtaMonthly), findsOneWidget);
    expect(find.text(CC.stepPlan), findsOneWidget);
    expect(find.text(CC.stepMonthDates), findsOneWidget);
    expect(find.text(CC.stepPay), findsOneWidget);
    // select the other card: total follows (2,400 + 240 fee... server fee 29000 fixture)
    await t.tap(find.text('٤ تنظيف عادي في الشهر'));
    await _settle(t);
    expect(find.text('٤ تنظيف عادي في الشهر · شامل ١٠٪ رسوم'), findsOneWidget);
    expect(find.text('٢,٦٩٠ ج.م'), findsOneWidget);
  });

  testWidgets('arriving with mode=monthly starts in monthly', (t) async {
    _phone(t);
    await t.pumpWidget(_app(mode: 'monthly'));
    await _settle(t);
    expect(find.byType(PlanCard), findsNWidgets(2));
    expect(find.text(CC.e2CtaMonthly), findsOneWidget);
  });

  testWidgets('CTA opens the schedule route by plan id and provider id', (t) async {
    _phone(t);
    await t.pumpWidget(_app(mode: 'monthly'));
    await _settle(t);
    await t.tap(find.text(CC.e2CtaMonthly));
    await _settle(t);
    expect(find.textContaining('/plans/b/schedule?providerId=p1'), findsOneWidget);
  });

  testWidgets('beauty-tab line only when the provider has plans', (t) async {
    _phone(t);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.tap(find.text('تجميل').first);
    await _settle(t);
    expect(find.text(CC.e2BeautyLine), findsOneWidget);

    await t.pumpWidget(_app(plans: false));
    await _settle(t);
    await t.tap(find.text('تجميل').first);
    await _settle(t);
    expect(find.text(CC.e2BeautyLine), findsNothing);
  });

  testWidgets('flag off: nothing monthly appears', (t) async {
    _phone(t);
    await t.pumpWidget(_app(pilot: false, mode: 'monthly'));
    await _settle(t);
    expect(find.text(CC.e2Monthly), findsNothing);
    expect(find.byType(PlanCard), findsNothing);
  });
}
