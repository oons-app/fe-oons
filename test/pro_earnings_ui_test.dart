import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/earnings_tab.dart';

import 'pro_v2_fakes.dart';

Map<String, dynamic> summary() => {
      'heroAmount': 80000,
      'cadence': 'biweekly',
      'pendingCadence': null,
      'nextSettlementAt': '2026-10-06T10:00:00',
      'periodStart': '2026-09-22T00:00:00',
      'periodEnd': '2026-10-06T00:00:00',
      'payoutHandleMasked': '011****581',
      'cycleLines': [
        {'status': 'ready', 'amount': 80000, 'checkedOutAt': '2026-09-29T14:00:00', 'serviceName': {'ar': 'تنظيف عادي', 'en': 'Regular'}, 'clientName': 'منى إ.'},
        {'status': 'held', 'amount': 120000, 'checkedOutAt': '2026-10-02T14:00:00', 'serviceName': {'ar': 'تنظيف مميز', 'en': 'Premium'}, 'clientName': 'سارة'},
      ],
      'categories': [
        {'key': 'cleaning', 'name': {'ar': 'التنظيف المنزلي', 'en': 'Home cleaning'}, 'amount': 150000},
        {'key': 'beauty', 'name': {'ar': 'التجميل والعناية', 'en': 'Beauty'}, 'amount': 50000},
      ],
    };

Future<FakeProRepo> open(WidgetTester t, {Map<String, dynamic>? data, bool fail = false}) async {
  phone(t, height: 2400);
  final r = FakeProRepo(profile: {...providerJson(), 'payoutHandle': '01130031581'})
    ..earningsData = data ?? summary()
    ..earningsFail = fail;
  await t.pumpWidget(proHost(
    const Scaffold(body: ProEarningsTab()),
    repo: r,
    routes: [GoRoute(path: '/pro/profile', builder: (c, s) => const Scaffold(body: Text('PROFILE PAGE')))],
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return r;
}

void main() {
  setUpAll(initHive);

  testWidgets('hero: what she can withdraw, big and mono, and the next settlement', (t) async {
    await open(t);
    expect(find.text('متاح للسحب'), findsOneWidget);
    expect(find.text('٨٠٠'), findsOneWidget);
    expect(find.text('ج.م'), findsWidgets);
    expect(find.text('التسوية الجاية'), findsOneWidget);
    expect(find.text('الثلاثاء ٦ أكتوبر'), findsOneWidget);
    expect(find.text('يتحول مبلغ كل زيارة إلى رصيدك فور انتهائها.'), findsOneWidget);
  });

  testWidgets('payout: her InstaPay number in mono Arabic digits; edit goes to بياناتي', (t) async {
    await open(t);
    expect(find.text('إنستاباي'), findsOneWidget);
    expect(find.text('٠١١٣٠٠٣١٥٨١'), findsOneWidget);
    await t.tap(find.text('تعديل'));
    await t.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);
  });

  testWidgets('cycle: current one is selected; picking another saves by itself with the right note', (t) async {
    final r = await open(t);
    expect(t.widget<DsSegmented>(find.byType(DsSegmented)).index, 1);
    expect(find.text('يبدأ التغيير من الدورة القادمة.'), findsOneWidget);
    await t.tap(find.text('شهري'));
    await t.pump();
    expect(t.widget<DsSegmented>(find.byType(DsSegmented)).index, 2, reason: 'instant');
    await t.pump(const Duration(milliseconds: 300));
    expect(r.calls, contains('cadence monthly'));
    expect(find.text('يُطبّق من الدورة القادمة'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('a refused cycle change goes back with an error', (t) async {
    final r = await open(t);
    r.failNext = apiError('مقدرناش نغيّر الدورة');
    await t.tap(find.text('أسبوعي'));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.widget<DsSegmented>(find.byType(DsSegmented)).index, 1);
    expect(find.text('مقدرناش نغيّر الدورة'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('current cycle: its dates and every movement with its status', (t) async {
    await open(t);
    expect(find.text('الدورة الحالية'), findsOneWidget);
    expect(find.text('٢٢ سبتمبر – ٥ أكتوبر'), findsOneWidget);
    expect(find.text('تنظيف عادي · منى إ.'), findsOneWidget);
    expect(find.text('١,٢٠٠ ج.م'), findsOneWidget);
  });

  testWidgets('by specialty: amounts with plum bars sized by share', (t) async {
    await open(t);
    expect(find.text('حسب الفئة'), findsOneWidget);
    expect(find.text('التنظيف المنزلي'), findsOneWidget);
    final meters = t.widgetList<DsMeter>(find.byType(DsMeter)).toList();
    expect(meters.map((m) => m.value), [0.75, 0.25]);
  });

  testWidgets('no movements → an empty state, not a blank card', (t) async {
    await open(t, data: {...summary(), 'cycleLines': [], 'categories': []});
    expect(find.text('لا حركة في هذه الدورة'), findsOneWidget);
    expect(find.text('حسب الفئة'), findsNothing);
  });

  testWidgets('load failure → retry', (t) async {
    final r = await open(t, fail: true);
    expect(find.text('تعذر تحميل الصفحة'), findsOneWidget);
    r.earningsFail = false;
    await t.tap(find.text('حاولي مرة أخرى'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('متاح للسحب'), findsOneWidget);
  });
}
