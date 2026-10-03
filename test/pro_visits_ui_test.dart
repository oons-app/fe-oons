import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/visits_tab.dart';

import 'pro_v2_fakes.dart';

// Saturday 3 Oct 2026 — the same "today" as the design prototype.
DateTime fixedNow() => DateTime(2026, 10, 3, 8);

FakeProRepo repo({bool empty = false, List<int>? workDays}) {
  final r = FakeProRepo(profile: providerJson(workDays: workDays ?? const [1, 2, 3, 4, 6, 7]));
  if (!empty) {
    r.upcomingJobs = [
      jobBundle('a', '2026-10-03T16:00:00', client: 'سارة', service: 'سويت جسم كامل', area: 'rehab', minutes: 180, earning: 130000),
      jobBundle('b', '2026-10-03T09:00:00', client: 'منى', planTag: 'باقة', area: 'madinaty', minutes: 360, earning: 120000),
      jobBundle('c', '2026-10-06T11:00:00', client: 'ريم', service: 'إزالة شعر', minutes: 60, earning: 120000),
    ];
    r.pastJobs = [
      jobBundle('p1', '2026-09-30T10:00:00', client: 'منى', status: 'completed', earning: 80000, service: 'تنظيف عادي'),
      jobBundle('p2', '2026-09-27T10:00:00', client: 'عميلة', status: 'cancelled_client', earning: 60000, service: 'تنظيف عادي · باقة'),
    ];
  }
  return r;
}

Future<FakeProRepo> open(WidgetTester t, FakeProRepo r) async {
  phone(t, height: 2200);
  ProNav.tab.value = 0;
  await t.pumpWidget(proHost(
    Scaffold(body: ProVisitsTab(now: fixedNow)),
    repo: r,
    routes: [GoRoute(path: '/pro/job/:id', builder: (c, s) => Scaffold(body: Text('JOB ${s.pathParameters['id']}')))],
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return r;
}

void main() {
  setUpAll(initHive);

  testWidgets('three stats: today, this week, expected (what she earns, in pounds)', (t) async {
    await open(t, repo());
    expect(find.text('النهارده'), findsOneWidget);
    expect(find.text('الأسبوع ده'), findsOneWidget);
    expect(find.text('متوقّع · ج.م'), findsOneWidget);
    Finder inStrip(String s) => find.descendant(of: find.byType(DsStatStrip), matching: find.text(s));
    expect(inStrip('٢'), findsOneWidget, reason: 'two visits today');
    expect(inStrip('٣'), findsOneWidget, reason: 'three this week');
    expect(inStrip('٣,٧٠٠'), findsOneWidget, reason: '1300 + 1200 + 1200');
  });

  testWidgets('seven-day strip, Saturday first, today selected, dots on days with visits', (t) async {
    await open(t, repo());
    for (final d in ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('السبت ٣ أكتوبر'), findsOneWidget);
    expect(find.text('زيارتين'), findsOneWidget);
  });

  testWidgets('visit card: time + duration | name, package tag, service, area, price', (t) async {
    await open(t, repo());
    // sorted by time: 09:00 before 16:00
    expect(t.getTopLeft(find.text('٠٩:٠٠')).dy, lessThan(t.getTopLeft(find.text('١٦:٠٠')).dy));
    expect(find.text('٦ س'), findsOneWidget);
    expect(find.text('٣ س'), findsOneWidget);
    expect(find.text('منى'), findsOneWidget);
    expect(find.text('باقة'), findsOneWidget);
    expect(find.text('تنظيف مميز'), findsOneWidget);
    expect(find.text('١,٣٠٠ ج.م'), findsOneWidget);
  });

  testWidgets('another day shows its own visits', (t) async {
    await open(t, repo());
    await t.tap(find.text('تلات'));
    await t.pump();
    expect(find.text('الثلاثاء ٦ أكتوبر'), findsOneWidget);
    expect(find.text('ريم'), findsOneWidget);
    expect(find.text('منى'), findsNothing);
  });

  testWidgets('a quiet day says so; a day she does not work says it is a day off', (t) async {
    await open(t, repo());
    await t.tap(find.text('حد'));
    await t.pump();
    expect(find.text('مفيش زيارات في اليوم ده'), findsOneWidget);
    expect(find.text('الحجوزات الجديدة هتظهر هنا أول ما تتأكد.'), findsOneWidget);
    await t.tap(find.text('جمعة'));
    await t.pump();
    expect(find.text('اليوم ده إجازة'), findsOneWidget);
    expect(find.text('الجمعة مقفولة في مواعيدك.'), findsOneWidget);
  });

  testWidgets('a whole empty week offers areas first, hours second', (t) async {
    await open(t, repo(empty: true));
    expect(find.text('مفيش زيارات الأسبوع ده'), findsOneWidget);
    await t.tap(find.text('زوّدي مناطق'));
    await t.pump();
    expect((ProNav.tab.value, ProNav.servicesSeg.value), (1, ProNav.segAreas));
    await t.tap(find.text('أو زوّدي ساعات'));
    await t.pump();
    expect(ProNav.servicesSeg.value, ProNav.segHours);
  });

  testWidgets('past: done in olive, cancelled in grey with a struck, faint price', (t) async {
    await open(t, repo());
    await t.tap(find.text('اللي فاتت'));
    await t.pump();
    expect(find.text('خلصت'), findsOneWidget);
    expect(find.text('اتلغت'), findsOneWidget);
    final cancelled = t.widget<Text>(find.text('٦٠٠ ج.م'));
    expect(cancelled.style!.decoration, TextDecoration.lineThrough);
    expect(cancelled.style!.color, Ds.textFaint);
    final done = t.widget<Text>(find.text('٨٠٠ ج.م'));
    expect(done.style!.decoration, TextDecoration.none);
    expect(find.text('الأربعاء ٣٠ سبتمبر'), findsNothing, reason: '30 Sep 2026 is a Wednesday — but the row shows the real date');
  });

  testWidgets('past is empty → an empty state', (t) async {
    final r = repo()..pastJobs = [];
    await open(t, r);
    await t.tap(find.text('اللي فاتت'));
    await t.pump();
    expect(find.text('لسه مفيش زيارات فاتت'), findsOneWidget);
  });

  testWidgets('tapping a visit opens its job', (t) async {
    await open(t, repo());
    await t.tap(find.text('سارة'));
    await t.pumpAndSettle();
    expect(find.text('JOB a'), findsOneWidget);
  });

  testWidgets('first load fails → retry state, not a spinner; retry loads', (t) async {
    final r = repo()..jobsFail = true;
    await open(t, r);
    expect(find.text('مقدرناش نحمّل الصفحة'), findsOneWidget);
    r.jobsFail = false;
    await t.tap(find.text('حاولي تاني'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('النهارده'), findsOneWidget);
    expect(find.text('مقدرناش نحمّل الصفحة'), findsNothing);
  });
}
