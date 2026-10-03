import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/areas_hours.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/services_tab.dart';
import 'package:oons/features/pro/v2/specialty_page.dart';

import 'pro_v2_fakes.dart';

FakeProRepo repoWith({List<Map<String, dynamic>>? items, List<Map<String, dynamic>>? rows, Map<String, dynamic>? profile}) {
  return FakeProRepo(
    profile: profile ??
        providerJson(items: items ?? [
          svcJson('1', 'تنظيف مميز', priceEgp: 1200, benefits: ['نفس المنظّفة', 'مواد التنظيف']),
          svcJson('2', 'تنظيف عادي + عميق', priceEgp: 1600, active: false),
          svcJson('3', 'شقة', cat: 'c-post', priceEgp: 1200),
          svcJson('4', 'قص', cat: 'b-hair', priceEgp: 500, duration: 60),
        ]),
    categoryRows: rows ??
        [
          catRow('c-reg', 'تنظيف عادي', 'cleaning', 'active'),
          catRow('c-post', 'تنظيف بعد التشطيب', 'cleaning', 'active'),
          catRow('b-hair', 'شعر', 'beauty', 'active'),
          catRow('b-nails', 'أظافر', 'beauty', 'pending_addition_approval'),
        ],
  );
}

List<GoRoute> get routes => [
      GoRoute(path: '/pro/specialty/:id', builder: (c, s) => ProSpecialtyScreen(categoryId: s.pathParameters['id']!)),
      GoRoute(path: '/pro/link', builder: (c, s) => const Scaffold(body: Text('LINK PAGE'))),
    ];

Future<void> openTab(WidgetTester t, FakeProRepo repo) async {
  phone(t);
  ProNav.servicesSeg.value = ProNav.segServices;
  await t.pumpWidget(proHost(const Scaffold(body: ProServicesTab()), repo: repo, routes: routes));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> openSpecialty(WidgetTester t, FakeProRepo repo, String text) async {
  await openTab(t, repo);
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

Finder switchOf(String serviceName) => find.byWidgetPredicate((w) => w is DsSwitch && w.label.startsWith(serviceName));

void main() {
  setUpAll(initHive);

  group('خدماتي — category → specialty → service', () {
    testWidgets('one section per category, her own first, with real counts', (t) async {
      await openTab(t, repoWith());
      expect(find.text('التنظيف المنزلي'), findsOneWidget);
      expect(find.text('التجميل والعناية'), findsOneWidget);
      expect(find.text('تخصصين · ٣ خدمات'), findsOneWidget, reason: '2 specialties, 3 services in cleaning');
      expect(find.text('تخصصين · خدمة واحدة'), findsOneWidget, reason: 'beauty: hair + nails, one service');
      // cleaning (her vertical) is listed before beauty
      expect(t.getTopLeft(find.text('التنظيف المنزلي')).dy, lessThan(t.getTopLeft(find.text('التجميل والعناية')).dy));
      expect(find.text('خدمتين · ١ ظاهرة'), findsOneWidget);
      expect(find.text('خدمة واحدة · ١ ظاهرة'), findsNWidgets(2));
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('تظهر بعد المراجعة'), findsOneWidget);
      expect(find.text('اطلبي تخصصا جديدا'), findsOneWidget);
      expect(find.text('أي تخصص جديد يُراجع قبل أن يظهر للعميلات'), findsOneWidget);
      expect(find.textContaining('احفظي التغييرات'), findsNothing, reason: 'no global save button any more');
    });

    testWidgets('the booking-link pill reflects the link and opens its page', (t) async {
      await openTab(t, repoWith(profile: providerJson(linkClosed: true)));
      expect(find.text('رابط الحجز مغلق'), findsOneWidget);
      await t.tap(find.text('رابط الحجز مغلق'));
      await t.pumpAndSettle();
      expect(find.text('LINK PAGE'), findsOneWidget);
    });

    testWidgets('no specialties yet → an empty state with the one action', (t) async {
      await openTab(t, repoWith(items: const [], rows: const []));
      expect(find.text('لا خدمات بعد'), findsOneWidget);
      expect(find.text('اطلبي تخصصا جديدا'), findsWidgets);
    });

    testWidgets('segments switch to areas and hours', (t) async {
      await openTab(t, repoWith());
      await t.tap(find.text('المناطق'));
      await t.pump();
      expect(find.text('تحجزك العميلات في هذه المناطق فقط.'), findsOneWidget);
      await t.tap(find.text('المواعيد'));
      await t.pump();
      expect(find.text('أيام العمل'), findsOneWidget);
      expect(find.text('ساعات الحجز'), findsOneWidget);
    });
  });

  group('صفحة التخصص', () {
    testWidgets('breadcrumb, title, filters and compact service cards with the real net', (t) async {
      await openSpecialty(t, repoWith(), 'تنظيف عادي');
      expect(find.text('خدماتي · التنظيف المنزلي'), findsOneWidget);
      expect(find.text('الكل ٢'), findsOneWidget);
      expect(find.text('ظاهرة ١'), findsOneWidget);
      expect(find.text('مخفية ١'), findsOneWidget);
      expect(find.text('١,٢٠٠ ج.م'), findsOneWidget);
      expect(find.text('تدفع العميلة ١,٣٢٠'), findsOneWidget, reason: '1200 plus the 10% fee on top');
      expect(find.text('٦ ساعات · ٢ بنود'), findsOneWidget);
      expect(find.text('أضيفي خدمة في تنظيف عادي'), findsOneWidget);
    });

    testWidgets('filter chips narrow the list', (t) async {
      await openSpecialty(t, repoWith(), 'تنظيف عادي');
      await t.tap(find.text('مخفية ١'));
      await t.pump();
      expect(find.text('تنظيف عادي + عميق'), findsOneWidget);
      expect(find.text('تنظيف مميز'), findsNothing);
      await t.tap(find.text('ظاهرة ١'));
      await t.pump();
      expect(find.text('تنظيف مميز'), findsOneWidget);
    });

    testWidgets('visibility switch saves by itself and says «اتحفظ»', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(switchOf('تنظيف مميز'));
      await t.pump();
      expect(t.widget<DsSwitch>(switchOf('تنظيف مميز')).on, isFalse, reason: 'instant, before the server answers');
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.calls, contains('active 1 false'));
      expect(find.text('أُخفيت الخدمة'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a refused change rolls back and shows an error toast', (t) async {
      final repo = repoWith()..failNext = apiError('مقدرناش نحفظ الخدمة دي');
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(switchOf('تنظيف مميز'));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.widget<DsSwitch>(switchOf('تنظيف مميز')).on, isTrue, reason: 'put back');
      expect(find.text('أُخفيت الخدمة'), findsNothing);
      expect(find.text('مقدرناش نحفظ الخدمة دي'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('editor: base and final price drive each other, fee added on top', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تنظيف مميز'));
      await t.pumpAndSettle();
      await t.tap(find.text('عدّلي الخدمة'));
      await t.pumpAndSettle();
      expect(find.text('سعرك الأساسي'), findsOneWidget);
      expect(find.text('السعر النهائي (ما تدفعه العميلة)'), findsOneWidget);
      TextField fieldWith(String text) => t.widget<TextField>(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text));
      expect(fieldWith('1200'), isNotNull);
      expect(fieldWith('1320'), isNotNull);
      // typing the base price fills the final price
      await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '1200'), '800');
      await t.pump();
      expect(fieldWith('880'), isNotNull);
      expect(find.textContaining('تُضاف رسوم أُنس ١٠٪ فوق سعركِ'), findsOneWidget);
      // typing the final price fills the base price
      await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '880'), '1100');
      await t.pump();
      expect(fieldWith('1000'), isNotNull);
    });

    testWidgets('tapping the card opens the service sheet; the switch does not', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تنظيف مميز'));
      await t.pumpAndSettle();
      expect(find.text('تدفع العميلة'), findsOneWidget);
      expect(find.text('سعرك'), findsOneWidget);
      expect(find.text('المدة'), findsOneWidget);
      expect(find.text('تشمل الخدمة'), findsOneWidget);
      expect(find.text('نفس المنظّفة'), findsOneWidget);
      expect(find.text('عدّلي الخدمة'), findsOneWidget);
      expect(find.text('أخفيها'), findsOneWidget);
      expect(find.text('نسخة'), findsOneWidget);
      expect(find.text('احذفي'), findsOneWidget);
    });

    testWidgets('sheet · copy creates a hidden copy that goes back to review', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تنظيف مميز'));
      await t.pumpAndSettle();
      await t.tap(find.text('نسخة'));
      await t.pumpAndSettle();
      expect(repo.calls, contains('create'));
      expect((repo.bodies['create'] as Map)['active'], isFalse, reason: 'a copy starts hidden');
      expect(find.text('أُنشئت نسخة. تُراجع قبل أن تظهر'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('sheet · delete asks first, then deletes', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تنظيف مميز'));
      await t.pumpAndSettle();
      await t.tap(find.text('احذفي'));
      await t.pumpAndSettle();
      expect(find.text('تحذفين هذه الخدمة؟'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('delete')), isEmpty, reason: 'nothing deleted before she confirms');
      await t.tap(find.text('احذفي').last);
      await t.pumpAndSettle();
      expect(repo.calls, contains('delete 1'));
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('edit all prices: ±10% applies to THIS specialty only, rounded to 5', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تعديل كل الأسعار'));
      await t.pumpAndSettle();
      await t.tap(find.text('+١٠٪'));
      await t.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('update')).toSet(), {'update 1', 'update 2'}, reason: 'the other specialties are untouched');
      expect((repo.bodies['update 1'] as Map)['price'], 132000);
      expect((repo.bodies['update 2'] as Map)['price'], 176000);
      expect(find.text('زادت الأسعار ١٠٪'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('bulk change that fails midway is rolled back', (t) async {
      final repo = repoWith()..failNext = apiError('مقدرناش نعدّل الأسعار');
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تعديل كل الأسعار'));
      await t.pumpAndSettle();
      await t.tap(find.text('−١٠٪'));
      await t.pumpAndSettle();
      expect(find.text('١,٢٠٠ ج.م'), findsOneWidget, reason: 'the old price is shown again');
      expect(find.text('مقدرناش نعدّل الأسعار'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a pending specialty can already be filled; the add form opens with it selected', (t) async {
      await openSpecialty(t, repoWith(), 'أظافر');
      expect(find.text('هذا التخصص قيد المراجعة. جهّزي خدماتك، وتظهر بعد الموافقة.'), findsWidgets);
      expect(find.text('تعديل كل الأسعار'), findsNothing);
      expect(find.text('أضيفي خدمة في أظافر'), findsOneWidget);
      await t.tap(find.text('أضيفي خدمة في أظافر'));
      await t.pumpAndSettle();
      expect(find.text('أظافر ✓'), findsOneWidget, reason: 'the only specialty is already chosen');
      expect(find.text('اختاري تخصص الأول'), findsNothing);
    });

    testWidgets('adding a service from a specialty page sends it and closes the form cleanly', (t) async {
      final repo = repoWith();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('أضيفي خدمة في تنظيف عادي'));
      await t.pumpAndSettle();
      expect(find.text('تنظيف عادي ✓'), findsOneWidget, reason: 'the specialty is preselected');
      await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '800'), '800');
      await t.pump();
      final add = find.text('+ خدمة');
      await t.dragUntilVisible(add, find.byType(ListView).last, const Offset(0, -300));
      await t.tap(add);
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      await t.pump(const Duration(seconds: 2));
      expect(repo.calls, contains('create'));
      expect(repo.bodies['create'], containsPair('price', 80000));
      expect(t.takeException(), isNull, reason: 'no use-after-dispose while the sheet closes');
    });

    testWidgets('a specialty with no services yet shows the empty state and its action', (t) async {
      final repo = repoWith(rows: [catRow('c-reg', 'تنظيف عادي', 'cleaning', 'active')], items: const []);
      await openSpecialty(t, repo, 'تنظيف عادي');
      expect(find.text('لا خدمات في تنظيف عادي بعد'), findsOneWidget);
      expect(find.text('أضيفي خدمة في تنظيف عادي'), findsOneWidget);
    });
  });

  group('أسعار بالمساحة', () {
    FakeProRepo tiered() => repoWith(
          rows: [catRow('c-reg', 'تنظيف عادي', 'cleaning', 'active')],
          items: [
            svcJson('t1', 'شريحة ١', kind: 'cleaning', from: 120, to: 150, priceEgp: 800),
            svcJson('t2', 'شريحة ٢', kind: 'cleaning', from: 151, to: 180, priceEgp: 800),
            svcJson('t3', 'شريحة ٣', kind: 'cleaning', from: 181, to: 250, workers: 2, priceEgp: 1500),
          ],
        );

    testWidgets('read-only table with helpers, price and net', (t) async {
      await openSpecialty(t, tiered(), 'تنظيف عادي');
      expect(find.text('أسعار بالمساحة'), findsOneWidget);
      expect(find.text('١٢٠–١٥٠ م²'), findsOneWidget);
      expect(find.text('١٨١–٢٥٠ م²'), findsOneWidget);
      expect(find.text('مساعدتين'), findsOneWidget);
      expect(find.text('٨٠٠ ج.م'), findsNWidgets(2));
      expect(find.text('تدفع العميلة ٨٨٠'), findsNWidgets(2));
      expect(find.text('تعديل'), findsOneWidget);
    });

    testWidgets('a new tier starts from the last one and is saved', (t) async {
      final repo = tiered();
      await openSpecialty(t, repo, 'تنظيف عادي');
      await t.tap(find.text('تعديل'));
      await t.pumpAndSettle();
      await t.tap(find.text('شريحة جديدة'));
      await t.pumpAndSettle();
      await t.tap(find.text('احفظي الأسعار'));
      await t.pumpAndSettle();
      final created = repo.bodies['create'] as Map;
      expect(created['sizeFromSqm'], 251, reason: 'continues where the last tier ends');
      expect(created['sizeToSqm'], 300);
      expect(created['price'], 150000, reason: 'pre-filled with the last tier\'s price');
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('المناطق والمواعيد — حفظ تلقائي', () {
    Future<FakeProRepo> openView(WidgetTester t, Widget view, {FakeProRepo? repo}) async {
      phone(t);
      final r = repo ?? repoWith();
      await t.pumpWidget(proHost(Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: view))), repo: r));
      await t.pump();
      return r;
    }

    testWidgets('toggling an area saves just the areas', (t) async {
      final repo = await openView(t, const ProAreasView());
      await t.tap(find.text('العاصمة الإدارية'));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.calls, ['patch areas']);
      expect((repo.bodies['patch'] as Map)['areas'], containsAll(['madinaty', 'rehab', 'capital']));
      expect(find.text('اتحفظ'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('she always keeps at least one area', (t) async {
      final repo = repoWith(profile: providerJson(areas: ['madinaty']));
      await openView(t, const ProAreasView(), repo: repo);
      await t.tap(find.text('مدينتي'));
      await t.pump(const Duration(milliseconds: 100));
      expect(repo.calls, isEmpty);
      expect(find.text('أبقي منطقة واحدة على الأقل.'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a refused area change goes back', (t) async {
      final repo = repoWith()..failNext = apiError('المنطقة دي مقفولة');
      await openView(t, const ProAreasView(), repo: repo);
      await t.tap(find.text('الرحاب'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('المنطقة دي مقفولة'), findsOneWidget);
      final chip = t.widget<DsChip>(find.widgetWithText(DsChip, 'الرحاب'));
      expect(chip.on, isTrue, reason: 'it was on before and is on again');
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('work days: Saturday first, saves workDays only', (t) async {
      final repo = await openView(t, const ProHoursView());
      final chips = t.widgetList<DsChip>(find.byType(DsChip)).take(7).map((c) => c.label).toList();
      expect(chips, ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة']);
      await t.tap(find.widgetWithText(DsChip, 'جمعة'));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.calls, ['patch workDays']);
      expect((repo.bodies['patch'] as Map)['workDays'], [1, 2, 3, 4, 5, 6, 7]);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('hours: mono chips in Arabic digits; saves slotHours (UTC) only', (t) async {
      final repo = await openView(t, const ProHoursView());
      expect(find.text('٠٨:٠٠'), findsOneWidget);
      expect(find.text('٢٠:٠٠'), findsOneWidget);
      await t.tap(find.text('٠٨:٠٠'));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.calls, ['patch slotHours']);
      expect(((repo.bodies['patch'] as Map)['slotHours'] as List).length, 12, reason: 'one fewer than the 13 default hours');
      expect(find.textContaining('١٢ متاحة في كل يوم عمل'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('she keeps at least one work day', (t) async {
      final repo = repoWith(profile: providerJson(workDays: [6]));
      await openView(t, const ProHoursView(), repo: repo);
      await t.tap(find.widgetWithText(DsChip, 'سبت'));
      await t.pump(const Duration(milliseconds: 100));
      expect(repo.calls, isEmpty);
      expect(find.text('أبقي يوم عمل واحدا على الأقل.'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });
  });
}
